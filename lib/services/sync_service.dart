import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'connectivity_service.dart';
import 'crm_api.dart';
import 'local_db.dart';
import 'offline_api_service.dart';

/// Pushes queued offline operations to the server, in order.
///
/// Every op carries the same `client_op_id` on each attempt, so the server
/// (see server_patch/sync_helper.php) can safely ignore duplicates.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _db = LocalDb.instance;
  ApiService? _api; // the *plain* ApiService – always talks to the network

  bool _syncing = false;
  int _pending = 0;
  int _failed = 0;
  DateTime? _lastSync;
  String? _lastMessage;
  Timer? _timer;
  bool _wired = false;

  bool get syncing => _syncing;
  int get pending => _pending;
  int get failed => _failed;
  DateTime? get lastSync => _lastSync;
  String? get lastMessage => _lastMessage;
  bool get hasWork => _pending > 0 || _failed > 0;

  /// Fired after a successful sync pass that changed something, so screens
  /// can reload (e.g. temp sale ids became real ones).
  final List<VoidCallback> _changeListeners = [];
  void addChangeListener(VoidCallback cb) => _changeListeners.add(cb);
  void removeChangeListener(VoidCallback cb) => _changeListeners.remove(cb);

  void configure(String? baseUrl, {http.Client? client}) {
    _api = baseUrl == null ? null : ApiService(baseUrl, client: client);
    if (!_wired) {
      _wired = true;
      ConnectivityService.instance.addOnlineListener(() => syncNow());
      OfflineApiService.onQueued = () {
        refreshCounts();
        // If we are actually online (server hiccup) try again shortly.
        Future.delayed(const Duration(seconds: 20), () => syncNow());
      };
      _timer ??= Timer.periodic(const Duration(minutes: 2), (_) => syncNow());
    }
    refreshCounts();
  }

  Future<void> refreshCounts() async {
    _pending = await _db.queueCount('pending');
    _failed = await _db.queueCount('failed');
    notifyListeners();
  }

  Future<void> retryFailed() async {
    await _db.retryAllFailed();
    await refreshCounts();
    await syncNow();
  }

  Future<void> discard(int queueId) async {
    await _db.deleteQueue(queueId);
    await refreshCounts();
  }

  Future<List<Map<String, dynamic>>> queueItems() => _db.queue();

  /// Process the queue. Safe to call often; no-ops while already running.
  Future<void> syncNow() async {
    final api = _api;
    if (api == null || _syncing || !_db.isReady) return;
    await refreshCounts();
    if (_pending == 0) return;
    if (!await ConnectivityService.instance.probe(force: true)) return;

    _syncing = true;
    notifyListeners();
    var changed = false;
    try {
      final ops = await _db.queue(status: 'pending');
      for (final op in ops) {
        final id = op['id'] as int;
        try {
          final res = await _push(api, op);
          if (res['success'] == true) {
            await _db.deleteQueue(id);
            changed = true;
          } else {
            // Server said no (e.g. stock too low) – needs a human.
            await _db.markQueue(id,
                status: 'failed',
                error: '${res['message'] ?? 'Server imekataa'}',
                bumpAttempts: true);
            await _markEntityFailed(op, '${res['message'] ?? ''}');
            changed = true;
          }
        } catch (e, st) {
          if (OfflineApiService.isNetworkError(e)) {
            // Lost the link mid-way; keep the rest pending, stop this pass.
            _lastMessage = 'Network: $e';
            debugPrint('SyncService: network error on ${op['op_type']}: $e');
            ConnectivityService.instance.reportFailure();
            break;
          }
          debugPrint('SyncService: ${op['op_type']} failed: $e');
          debugPrintStack(stackTrace: st, maxFrames: 6);
          await _db.markQueue(id,
              status: 'failed', error: '$e', bumpAttempts: true);
          await _markEntityFailed(op, '$e');
          changed = true;
        }
      }
      _lastSync = DateTime.now();
    } finally {
      _syncing = false;
      await refreshCounts();
      if (changed) {
        for (final cb in List.of(_changeListeners)) {
          cb();
        }
      }
    }
  }

  // ── push one op ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _push(ApiService api, Map<String, dynamic> op) async {
    final p = Map<String, dynamic>.from(op['payload'] as Map);
    final opId = op['op_id'] as String;
    final biz = op['business_id'] as int;

    switch (op['op_type'] as String) {
      case 'create_sale':
        final items = (p['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final it in items) {
          it['product_id'] = await _real('product', it['product_id']);
        }
        final res = await api.createSale(
          businessId: biz,
          branchId: p['branchId'] as int,
          customerName: p['customerName'] as String,
          transactionType: p['transactionType'] as String,
          items: items,
          amountPaid: (p['amountPaid'] as num?)?.toDouble(),
          clientOpId: opId,
          createdAt: p['createdAt'] as String?,
        );
        if (res['success'] == true) {
          final data = res['data'];
          final realId = int.tryParse(
                  '${res['sale_id'] ?? (data is Map ? data['sale_id'] : null) ?? 0}') ??
              0;
          final saleNo = res['sale_no'] ?? res['receipt_no'] ??
              (data is Map ? (data['sale_no'] ?? data['receipt_no']) : null);
          final tempId = p['tempSaleId'] as int;
          final row = await _db.getSaleRow(tempId);
          if (row != null) {
            final s = Map<String, dynamic>.from(row['sale'] as Map);
            if (realId != 0) s['sale_id'] = realId;
            if (saleNo != null) s['sale_no'] = '$saleNo';
            await _db.updateSale(tempId,
                sale: s, syncStatus: 'synced',
                newSaleId: realId != 0 ? realId : null);
          }
          if (realId != 0) await _db.putIdMap('sale', tempId, realId);
        }
        return res;

      case 'sale_action':
        final saleId = await _real('sale', p['saleId']);
        final res = await api.saleAction(saleId, p['action'] as String,
            amount: (p['amount'] as num?)?.toDouble(),
            note: p['note'] as String?, clientOpId: opId);
        if (res['success'] == true) {
          await _db.updateSale(saleId, syncStatus: 'synced');
          await _db.removeCache('saledetail:$saleId');
          await _db.removeCache('salepay:$saleId');
        }
        return res;

      case 'add_product':
        final res = await api.addProduct(
          businessId: biz,
          branchId: p['branchId'] as int,
          name: p['name'] as String,
          category: p['category'] as String,
          unit: p['unit'] as String,
          buyPrice: (p['buyPrice'] as num).toDouble(),
          sellPrice: (p['sellPrice'] as num).toDouble(),
          stock: p['stock'] as int,
          minStock: p['minStock'] as int? ?? 5,
          barcode: p['barcode'] as String? ?? '',
          description: p['description'] as String? ?? '',
          productCode: p['productCode'] as String? ?? '',
          wholesalePrice: (p['wholesalePrice'] as num?)?.toDouble(),
          expiryDate: p['expiryDate'] as String? ?? '',
          imagePath: p['imagePath'] as String?,
          clientOpId: opId,
        );
        if (res['success'] == true) {
          final realId = int.tryParse('${res['product_id'] ?? 0}') ?? 0;
          final tempId = p['tempId'] as int;
          if (realId != 0) {
            await _db.putIdMap('product', tempId, realId);
            await _db.remapProductId(biz, tempId, realId);
            final prod = await _db.getProduct(biz, realId);
            if (prod != null) {
              prod.remove('sync_status');
              await _db.upsertProduct(biz, prod);
            }
          }
        } else if (res['exists'] == true) {
          // Duplicate barcode/name already on server – treat as done.
          return {'success': true, 'message': res['message']};
        }
        return res;

      case 'update_product':
        return api.updateProduct(
          productId: await _real('product', p['productId']),
          businessId: biz,
          branchId: p['branchId'] as int,
          name: p['name'] as String,
          category: p['category'] as String,
          unit: p['unit'] as String,
          buyPrice: (p['buyPrice'] as num).toDouble(),
          sellPrice: (p['sellPrice'] as num).toDouble(),
          stock: p['stock'] as int,
          minStock: p['minStock'] as int? ?? 5,
          barcode: p['barcode'] as String? ?? '',
          description: p['description'] as String? ?? '',
          productCode: p['productCode'] as String? ?? '',
          wholesalePrice: (p['wholesalePrice'] as num?)?.toDouble(),
          expiryDate: p['expiryDate'] as String? ?? '',
          imagePath: p['imagePath'] as String?,
          clientOpId: opId,
        );

      case 'delete_product':
        final pid = p['productId'] as int;
        if (pid < 0) {
          // Created and deleted while offline – nothing to tell the server.
          final real = await _db.realId('product', pid);
          if (real == null || real == pid) return {'success': true};
          return api.deleteProduct(productId: real, businessId: biz, clientOpId: opId);
        }
        return api.deleteProduct(productId: pid, businessId: biz, clientOpId: opId);

      case 'add_batch':
        return api.addProductBatch(
          productId: await _real('product', p['productId']),
          businessId: biz,
          quantity: p['quantity'] as int,
          buyPrice: (p['buyPrice'] as num).toDouble(),
          batchNumber: p['batchNumber'] as String? ?? '',
          expiryDate: p['expiryDate'] as String? ?? '',
          notes: p['notes'] as String? ?? '',
          clientOpId: opId,
        );

      case 'manage_units':
        return api.manageProductUnits(
          productId: await _real('product', p['productId']),
          businessId: biz,
          units: (p['units'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          clientOpId: opId,
        );

      case 'manage_category':
        final id = p['id'] as int?;
        if (id != null && id < 0 && p['action'] != 'add') {
          // Editing/deleting a category that was itself created offline:
          // we never learned its server id – re-fetch will reconcile.
          return {'success': true};
        }
        final res = await api.manageCategory(biz, p['action'] as String,
            id: id, name: p['name'] as String?, clientOpId: opId);
        await _db.removeCache('categories:$biz');
        await _db.removeCache('categories_admin:$biz');
        return res;

      case 'manage_unit':
        final id = p['id'] as int?;
        if (id != null && id < 0 && p['action'] != 'add') return {'success': true};
        final res = await api.manageUnit(biz, p['action'] as String,
            id: id, name: p['name'] as String?,
            shortName: p['shortName'] as String?, clientOpId: opId);
        await _db.removeCache('units:$biz');
        await _db.removeCache('units_admin:$biz');
        return res;

      case 'import_products':
        final res = await api.importProductsBulk(
          businessId: biz,
          branchId: p['branchId'] as int,
          products: (p['products'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          clientOpId: opId,
        );
        if (res['success'] == true) {
          // We don't get ids back – drop the temp rows; next getProducts
          // pulls the real ones.
          final prods = await _db.getProducts(biz);
          for (final pr in prods) {
            final id = int.tryParse('${pr['product_id']}') ?? 0;
            if (id < 0 && pr['sync_status'] == 'pending' &&
                (pr['units'] as List? ?? []).isEmpty) {
              await _db.deleteProduct(biz, id);
            }
          }
        }
        return res;

      case 'expense_add':
      case 'expense_update':
        final tempId = p['expenseId'] as int;
        final res = await api.saveExpense(
          businessId: biz,
          expenseId: op['op_type'] == 'expense_add' ? null : await _real('expense', tempId),
          branchId: p['branchId'] as int?,
          userId: p['userId'] as int?,
          category: p['category'] as String,
          description: p['description'] as String? ?? '',
          amount: (p['amount'] as num).toDouble(),
          expenseDate: p['expenseDate'] as String,
          clientOpId: opId,
        );
        if (res['success'] == true) {
          final realId = int.tryParse('${res['expense_id'] ?? 0}') ?? 0;
          final list = (await _db.getCache('expenses:$biz') as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          for (final e in list) {
            if ('${e['expense_id']}' == '$tempId') {
              if (realId != 0) e['expense_id'] = realId;
              e['sync_status'] = 'synced';
            }
          }
          await _db.putCache('expenses:$biz', list);
          if (tempId < 0 && realId != 0) await _db.putIdMap('expense', tempId, realId);
          await _db.removeCacheWhere('report:$biz');
        }
        return res;

      case 'expense_delete':
        final res = await api.deleteExpense(
          businessId: biz,
          expenseId: await _real('expense', p['expenseId']),
          clientOpId: opId,
        );
        if (res['success'] == true) await _db.removeCacheWhere('report:$biz');
        return res;

      case 'customer_save':
        return CrmApi(api.baseUrl).pushCustomerSave(p);

      case 'stock_adjust':
        return CrmApi(api.baseUrl).pushStockAdjust(p, await _real('product', p['product_id']));

      default:
        return {'success': false, 'message': 'Unknown op ${op['op_type']}'};
    }
  }

  /// Resolve a possibly-temporary id to the real server id.
  Future<int> _real(String entity, dynamic raw) async {
    final id = int.tryParse('$raw') ?? 0;
    if (id >= 0) return id;
    final real = await _db.realId(entity, id);
    if (real == null || real < 0) {
      throw StateError(
          'Inategemea ${entity == 'sale' ? 'mauzo' : 'bidhaa'} ambayo bado haijasync');
    }
    return real;
  }

  Future<void> _markEntityFailed(Map<String, dynamic> op, String error) async {
    if (op['op_type'] == 'create_sale') {
      final tempId = (op['payload'] as Map)['tempSaleId'] as int;
      final row = await _db.getSaleRow(tempId);
      if (row != null) {
        final s = Map<String, dynamic>.from(row['sale'] as Map);
        s['sync_error'] = error;
        await _db.updateSale(tempId, sale: s, syncStatus: 'failed');
      }
    }
  }

  /// Tests: stop the periodic timer without disposing the singleton.
  void stopBackgroundTimers() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
