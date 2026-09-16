import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import 'connectivity_service.dart';
import 'local_db.dart';
import 'offline_api_service.dart';

/// Customers · payment history · stock ledger (Hatua 2 + 3).
///
/// Kept separate from [ApiService] so it can evolve without touching the
/// core file. Reads are cached in [LocalDb]; writes fall back to the sync
/// queue when offline (same pattern as [OfflineApiService]).
class CrmApi {
  final String baseUrl;
  CrmApi(this.baseUrl);

  static const _uuid = Uuid();
  final _db = LocalDb.instance;
  final _conn = ConnectivityService.instance;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (ApiService.authToken != null) 'Authorization': 'Bearer ${ApiService.authToken}',
      };

  Future<Map<String, dynamic>> _get(String file, Map<String, String> params) async {
    final uri = Uri.parse('$baseUrl/$file').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) throw AuthException();
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String file, Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('$baseUrl/$file'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) throw AuthException();
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> _online() async {
    if (!_db.isReady) return true;
    if (_conn.isOnline) return true;
    return _conn.probe();
  }

  /// Server first (cache the reply), else the cached copy.
  Future<Map<String, dynamic>> _cached(String key, Future<Map<String, dynamic>> Function() fetch) async {
    if (await _online()) {
      try {
        final r = await fetch();
        _conn.reportSuccess();
        if (r['success'] == true) await _db.putCache(key, r);
        return r;
      } catch (e) {
        if (!OfflineApiService.isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    final c = await _db.getCache(key);
    if (c == null) throw OfflineException();
    return {...Map<String, dynamic>.from(c as Map), 'offline': true};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Customers
  // ═══════════════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> listCustomers(int businessId, {String q = ''}) async {
    final r = await _cached('customers:$businessId',
        () => _get('customers.php', {'action': 'list', 'business_id': '$businessId'}));
    final all = ((r['customers'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    // offline-created customers live in a side list until synced
    final pending = ((await _db.getCache('customers_pending:$businessId')) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map));
    final merged = [...pending, ...all];
    if (q.trim().isEmpty) return merged;
    final s = q.trim().toLowerCase();
    return merged
        .where((c) => '${c['name']}'.toLowerCase().contains(s) || '${c['phone']}'.contains(s))
        .toList();
  }

  Future<Map<String, dynamic>> getCustomer(int businessId, int customerId) => _cached(
        'customer:$businessId:$customerId',
        () => _get('customers.php', {'action': 'get', 'business_id': '$businessId', 'customer_id': '$customerId'}),
      );

  Future<Map<String, dynamic>> saveCustomer({
    required int businessId,
    int? customerId,
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String customerType = 'retail',
    double creditLimit = 0,
    String notes = '',
  }) async {
    final opId = _uuid.v4();
    final body = {
      'action': customerId == null ? 'add' : 'update',
      'business_id': businessId,
      'customer_id': ?customerId,
      'name': name, 'phone': phone, 'email': email, 'address': address,
      'customer_type': customerType, 'credit_limit': creditLimit, 'notes': notes,
      'client_op_id': opId,
    };
    if (await _online() && (customerId == null || customerId > 0)) {
      try {
        final r = await _post('customers.php', body);
        _conn.reportSuccess();
        if (r['success'] == true) await _db.removeCache('customers:$businessId');
        return r;
      } catch (e) {
        if (!OfflineApiService.isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    // offline: keep in the pending list + queue
    final id = customerId ?? OfflineApiService.newTempId();
    final pend = ((await _db.getCache('customers_pending:$businessId')) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    pend.removeWhere((c) => '${c['customer_id']}' == '$id');
    pend.insert(0, {
      'customer_id': id, 'name': name, 'phone': phone, 'email': email, 'address': address,
      'customer_type': customerType, 'credit_limit': creditLimit, 'notes': notes,
      'sync_status': 'pending',
    });
    await _db.putCache('customers_pending:$businessId', pend);
    await _db.enqueue(
      opId: opId, opType: 'customer_save', businessId: businessId,
      label: 'Mteja: $name', payload: {...body, 'customer_id': id},
    );
    OfflineApiService.onQueued?.call();
    return {'success': true, 'offline': true, 'customer_id': id, 'message': 'Mteja amehifadhiwa offline'};
  }

  Future<Map<String, dynamic>> deleteCustomer(int businessId, int customerId) async {
    final r = await _post('customers.php', {
      'action': 'delete', 'business_id': businessId, 'customer_id': customerId,
    });
    if (r['success'] == true) await _db.removeCache('customers:$businessId');
    return r;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Stock ledger
  // ═══════════════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> stockCard(int businessId, int productId) async {
    if (productId < 0) return []; // offline-created product: no server history yet
    final r = await _cached('stockcard:$businessId:$productId',
        () => _get('stock_movements.php', {'action': 'card', 'business_id': '$businessId', 'product_id': '$productId'}));
    return ((r['movements'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> recentMovements(int businessId, {String type = 'all'}) async {
    final r = await _cached('ledger:$businessId:$type',
        () => _get('stock_movements.php', {'action': 'recent', 'business_id': '$businessId', 'type': type, 'limit': '300'}));
    return ((r['movements'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> adjustStock({
    required int businessId,
    required int productId,
    required String adjustType,
    required double qty,
    String reason = '',
    String direction = 'plus',
  }) async {
    final opId = _uuid.v4();
    final body = {
      'action': 'adjust', 'business_id': businessId, 'product_id': productId,
      'adjust_type': adjustType, 'qty': qty, 'reason': reason, 'direction': direction,
      'client_op_id': opId,
    };
    if (await _online() && productId > 0) {
      try {
        final r = await _post('stock_movements.php', body);
        _conn.reportSuccess();
        if (r['success'] == true) {
          await _db.removeCacheWhere('stockcard:$businessId:$productId');
          await _db.removeCacheWhere('ledger:$businessId');
          final after = double.tryParse('${r['stock_after']}');
          if (after != null) {
            final p = await _db.getProduct(businessId, productId);
            if (p != null) { p['qty'] = after == after.roundToDouble() ? after.toInt() : after; await _db.upsertProduct(businessId, p); }
          }
        }
        return r;
      } catch (e) {
        if (!OfflineApiService.isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    // offline: apply to local stock + queue
    final p = await _db.getProduct(businessId, productId);
    final cur = double.tryParse('${p?['qty'] ?? 0}') ?? 0;
    final delta = switch (adjustType) {
      'damaged' || 'lost' || 'expired' || 'return_supplier' => -qty,
      'count' => qty - cur,
      'correction' => direction == 'minus' ? -qty : qty,
      _ => qty,
    };
    if (cur + delta < 0) return {'success': false, 'message': 'Stock haiwezi kuwa chini ya 0 (ipo: $cur)'};
    await _db.adjustStock(businessId, productId, delta);
    await _db.enqueue(
      opId: opId, opType: 'stock_adjust', businessId: businessId,
      label: 'Stock: $adjustType ${qty.toStringAsFixed(0)} (#$productId)', payload: body,
    );
    OfflineApiService.onQueued?.call();
    return {'success': true, 'offline': true, 'message': 'Marekebisho yamehifadhiwa offline',
            'stock_before': cur, 'stock_after': cur + delta, 'delta': delta};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Sync helpers (called by SyncService)
  // ═══════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> pushCustomerSave(Map<String, dynamic> payload) async {
    final id = payload['customer_id'];
    final body = Map<String, dynamic>.from(payload);
    if (id is int && id < 0) { body.remove('customer_id'); body['action'] = 'add'; }
    final r = await _post('customers.php', body);
    if (r['success'] == true || r['exists'] == true) {
      final biz = payload['business_id'] as int;
      final pend = ((await _db.getCache('customers_pending:$biz')) as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..removeWhere((c) => '${c['customer_id']}' == '$id');
      await _db.putCache('customers_pending:$biz', pend);
      await _db.removeCache('customers:$biz');
      // Let queued sales that reference this offline-created customer (by its
      // temp id) resolve to the real server id once they sync.
      if (id is int && id < 0) {
        final realId = int.tryParse('${r['customer_id']}');
        if (realId != null && realId > 0) await _db.putIdMap('customer', id, realId);
      }
      if (r['exists'] == true) return {'success': true, 'message': r['message']};
    }
    return r;
  }

  Future<Map<String, dynamic>> pushStockAdjust(Map<String, dynamic> payload, int realProductId) async {
    final body = Map<String, dynamic>.from(payload)..['product_id'] = realProductId;
    final r = await _post('stock_movements.php', body);
    if (r['success'] == true) {
      final biz = payload['business_id'] as int;
      await _db.removeCacheWhere('stockcard:$biz:$realProductId');
      await _db.removeCacheWhere('ledger:$biz');
    }
    return r;
  }
}
