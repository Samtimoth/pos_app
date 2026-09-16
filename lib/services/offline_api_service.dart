import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import 'connectivity_service.dart';
import 'device_id_service.dart';
import 'local_db.dart';
import 'storage_service.dart';

/// Thrown when an operation needs the server and we are offline with no
/// usable local data.
class OfflineException implements Exception {
  final String message;
  OfflineException([this.message = 'Hakuna mtandao. Jaribu tena ukiwa online.']);
  @override
  String toString() => message;
}

/// Drop-in replacement for [ApiService] that keeps working without network.
///
/// Reads:  server first → cache the response → on failure serve the cache.
/// Writes: server first → on failure apply the change locally and queue it
///         for [SyncService] to push later. Every write carries a
///         `client_op_id` so a retry can never duplicate a record.
class OfflineApiService extends ApiService {
  OfflineApiService(super.baseUrl, {super.client}) {
    ConnectivityService.instance.setBaseUrl(baseUrl);
  }

  static const _uuid = Uuid();
  final _db = LocalDb.instance;
  final _conn = ConnectivityService.instance;

  /// Fired after a write was queued (so the sync UI can refresh counts).
  static void Function()? onQueued;

  // ══════════════════════════════════════════════════════════════════════════
  // helpers
  // ══════════════════════════════════════════════════════════════════════════
  static bool isNetworkError(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException ||
      e is HandshakeException ||
      e is HttpException ||
      e is FormatException || // HTML error page instead of JSON (502/504…)
      e is OfflineException;

  /// Whether it is worth hitting the network right now.
  Future<bool> _online() async {
    if (!_db.isReady) return true; // no local store → always try the network
    if (_conn.isOnline) return true;
    return _conn.probe();
  }

  /// Run [fetch] against the server, caching under [key]; fall back to cache.
  Future<T> _cached<T>(String key, Future<T> Function() fetch,
      {T Function(dynamic raw)? decode}) async {
    if (await _online()) {
      try {
        final r = await fetch();
        _conn.reportSuccess();
        await _db.putCache(key, r as Object);
        return r;
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    final c = await _db.getCache(key);
    if (c == null) throw OfflineException();
    return decode != null ? decode(c) : c as T;
  }

  /// Try [online]; if the network is down run [offline] instead.
  Future<Map<String, dynamic>> _write(
    Future<Map<String, dynamic>> Function() online,
    Future<Map<String, dynamic>> Function() offline,
  ) async {
    if (await _online()) {
      try {
        final r = await online();
        _conn.reportSuccess();
        return r;
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    final r = await offline();
    onQueued?.call();
    return r;
  }

  Future<void> _enqueue(String type, int businessId, String label,
      Map<String, dynamic> payload, {String? opId}) =>
      _db.enqueue(
        opId: opId ?? _uuid.v4(),
        opType: type,
        businessId: businessId,
        label: label,
        payload: payload,
      );

  /// Negative, unique-enough id for records created offline.
  static int newTempId() =>
      -(DateTime.now().microsecondsSinceEpoch % 2000000000);

  /// Local wall-clock, for display in the app.
  static String _now() => DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');

  /// What we send to the server: UTC with an explicit 'Z'. The PHP side runs
  /// in a different timezone; strtotime() converts this correctly, whereas a
  /// naive local timestamp would be off by the zone difference.
  static String _nowUtc() => DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> _offlineOk(String msg, [Map<String, dynamic>? extra]) =>
      {'success': true, 'offline': true, 'message': msg, ...?extra};

  static String _pwHash(String username, String password, String deviceId) =>
      sha256.convert(utf8.encode('$username|$password|$deviceId')).toString();

  // ══════════════════════════════════════════════════════════════════════════
  // Auth
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    final deviceId = await DeviceIdService.getDeviceId();
    if (await _online()) {
      try {
        final res = await super.login(username, password);
        _conn.reportSuccess();
        if (res['success'] == true) {
          // Remember credentials hash so the same user can log in offline.
          await StorageService.saveString(
              'offline_login_user', username.toLowerCase());
          await StorageService.saveString(
              'offline_login_hash', _pwHash(username.toLowerCase(), password, deviceId));
          await _db.putCache('login:${username.toLowerCase()}', res);
        }
        return res;
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    final savedUser = StorageService.getString('offline_login_user');
    final savedHash = StorageService.getString('offline_login_hash');
    if (savedUser == username.toLowerCase() &&
        savedHash == _pwHash(username.toLowerCase(), password, deviceId)) {
      final cached = await _db.getCache('login:${username.toLowerCase()}');
      if (cached is Map) {
        return {...Map<String, dynamic>.from(cached), 'offline': true};
      }
    }
    return {
      'success': false,
      'message': 'Hakuna mtandao. Ingia ukiwa online mara ya kwanza kwenye kifaa hiki.',
    };
  }

  @override
  Future<Map<String, dynamic>> getMyBusinesses(int userId) => _cached(
        'businesses:$userId',
        () => super.getMyBusinesses(userId),
        decode: (r) => Map<String, dynamic>.from(r as Map),
      );

  @override
  Future<Map<String, dynamic>> getProfile(int userId) => _cached(
        'profile:$userId',
        () => super.getProfile(userId),
        decode: (r) => Map<String, dynamic>.from(r as Map),
      );

  @override
  Future<List<Map<String, dynamic>>> getPlans() => _cached(
        'plans',
        () => super.getPlans(),
        decode: (r) =>
            (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );

  @override
  Future<Map<String, dynamic>> getMySubscription(int userId) => _cached(
        'subscription:$userId',
        () => super.getMySubscription(userId),
        decode: (r) => Map<String, dynamic>.from(r as Map),
      );

  @override
  Future<Map<String, dynamic>> getMyPayments(int userId) => _cached(
        'mypayments:$userId',
        () => super.getMyPayments(userId),
        decode: (r) => Map<String, dynamic>.from(r as Map),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // Products (read)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<List<dynamic>> getProducts(int businessId,
      {int? branchId, String search = '', String? category}) async {
    if (await _online()) {
      try {
        // Always pull the full list so the cache is complete; filter locally.
        final raw = await super.getProducts(businessId, branchId: branchId);
        _conn.reportSuccess();
        await _db.replaceProducts(businessId, raw);
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    final local = await _db.getProducts(businessId);
    if (local.isEmpty && !_conn.isOnline) throw OfflineException();
    final q = search.trim().toLowerCase();
    return local.where((p) {
      if (category != null && category.isNotEmpty &&
          '${p['category'] ?? ''}' != category) {
        return false;
      }
      if (q.isEmpty) return true;
      return '${p['name'] ?? ''}'.toLowerCase().contains(q) ||
          '${p['barcode'] ?? ''}'.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()));
  }

  @override
  Future<List<dynamic>> getCategories(int businessId) => _cached(
        'categories:$businessId',
        () => super.getCategories(businessId),
        decode: (r) => r as List,
      );

  @override
  Future<List<dynamic>> listCategories(int businessId) => _cached(
        'categories_admin:$businessId',
        () => super.listCategories(businessId),
        decode: (r) => r as List,
      );

  @override
  Future<List<String>> getUnits(int businessId) => _cached(
        'units:$businessId',
        () => super.getUnits(businessId),
        decode: (r) => (r as List).map((e) => '$e').toList(),
      );

  @override
  Future<List<dynamic>> listUnits(int businessId) => _cached(
        'units_admin:$businessId',
        () => super.listUnits(businessId),
        decode: (r) => r as List,
      );

  @override
  Future<List<dynamic>> getProductBatches(int productId, int businessId) async {
    if (productId < 0) return _localBatches(productId);
    if (await _online()) {
      try {
        final r = await super.getProductBatches(productId, businessId);
        _conn.reportSuccess();
        await _db.putCache('batches:$productId', r);
        return r;
      } catch (_) {
        _conn.reportFailure();
      }
    }
    final c = await _db.getCache('batches:$productId');
    return [...(c as List? ?? []), ...await _localBatches(productId)];
  }

  /// Batches added offline live in the queue until synced.
  Future<List<dynamic>> _localBatches(int productId) async {
    final q = await _db.queue();
    return q
        .where((o) => o['op_type'] == 'add_batch' &&
            o['payload']['productId'] == productId)
        .map((o) => {
              'batch_id': -o['id'],
              'product_id': productId,
              'quantity': o['payload']['quantity'],
              'remaining_qty': o['payload']['quantity'],
              'buy_price': o['payload']['buyPrice'],
              'batch_number': o['payload']['batchNumber'],
              'expiry_date': o['payload']['expiryDate'],
              'notes': o['payload']['notes'],
              'created_at': o['payload']['createdAt'],
              'sync_status': o['status'],
            })
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Products (write)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<Map<String, dynamic>> addProduct({
    required int businessId,
    required int branchId,
    required String name,
    required String category,
    required String unit,
    required double buyPrice,
    required double sellPrice,
    required int stock,
    int minStock = 5,
    String barcode = '',
    String description = '',
    String productCode = '',
    double? wholesalePrice,
    String expiryDate = '',
    String? imagePath,
    String? clientOpId,
  }) {
    final opId = clientOpId ?? _uuid.v4();
    return _write(
      () => super.addProduct(
        businessId: businessId, branchId: branchId, name: name,
        category: category, unit: unit, buyPrice: buyPrice,
        sellPrice: sellPrice, stock: stock, minStock: minStock,
        barcode: barcode, description: description, productCode: productCode,
        wholesalePrice: wholesalePrice, expiryDate: expiryDate,
        imagePath: imagePath, clientOpId: opId,
      ),
      () async {
        final tempId = newTempId();
        await _db.upsertProduct(businessId, {
          'product_id': tempId,
          'name': name,
          'category': category,
          'sellPrice': sellPrice,
          'buyPrice': buyPrice,
          'qty': stock,
          'min_stock': minStock,
          'unit': unit,
          'image': '',
          'barcode': barcode,
          'expiry_date': expiryDate.isEmpty ? null : expiryDate,
          'description': description,
          'product_code': productCode,
          'units': <Map<String, dynamic>>[],
          'sync_status': 'pending',
        });
        await _enqueue('add_product', businessId, 'Bidhaa mpya: $name', {
          'tempId': tempId,
          'businessId': businessId, 'branchId': branchId, 'name': name,
          'category': category, 'unit': unit, 'buyPrice': buyPrice,
          'sellPrice': sellPrice, 'stock': stock, 'minStock': minStock,
          'barcode': barcode, 'description': description,
          'productCode': productCode, 'wholesalePrice': wholesalePrice,
          'expiryDate': expiryDate, 'imagePath': imagePath,
        }, opId: opId);
        return _offlineOk('Bidhaa imehifadhiwa offline — itatumwa ukiwa online',
            {'product_id': tempId});
      },
    );
  }

  @override
  Future<Map<String, dynamic>> updateProduct({
    required int productId,
    required int businessId,
    required int branchId,
    required String name,
    required String category,
    required String unit,
    required double buyPrice,
    required double sellPrice,
    required int stock,
    int minStock = 5,
    String barcode = '',
    String description = '',
    String productCode = '',
    double? wholesalePrice,
    String expiryDate = '',
    String? imagePath,
    String? clientOpId,
  }) {
    final opId = clientOpId ?? _uuid.v4();
    Future<Map<String, dynamic>> offline() async {
      final existing = await _db.getProduct(businessId, productId) ?? {};
      await _db.upsertProduct(businessId, {
        ...existing,
        'product_id': productId,
        'name': name, 'category': category, 'sellPrice': sellPrice,
        'buyPrice': buyPrice, 'qty': stock, 'min_stock': minStock,
        'unit': unit, 'barcode': barcode,
        'expiry_date': expiryDate.isEmpty ? null : expiryDate,
        'description': description, 'product_code': productCode,
      });
      await _enqueue('update_product', businessId, 'Badiliko: $name', {
        'productId': productId, 'businessId': businessId, 'branchId': branchId,
        'name': name, 'category': category, 'unit': unit, 'buyPrice': buyPrice,
        'sellPrice': sellPrice, 'stock': stock, 'minStock': minStock,
        'barcode': barcode, 'description': description,
        'productCode': productCode, 'wholesalePrice': wholesalePrice,
        'expiryDate': expiryDate, 'imagePath': imagePath,
      }, opId: opId);
      return _offlineOk('Imehifadhiwa offline — itatumwa ukiwa online');
    }

    // A product that only exists locally cannot be updated on the server yet.
    if (productId < 0) return offline().then((r) { onQueued?.call(); return r; });
    return _write(
      () => super.updateProduct(
        productId: productId, businessId: businessId, branchId: branchId,
        name: name, category: category, unit: unit, buyPrice: buyPrice,
        sellPrice: sellPrice, stock: stock, minStock: minStock,
        barcode: barcode, description: description, productCode: productCode,
        wholesalePrice: wholesalePrice, expiryDate: expiryDate,
        imagePath: imagePath, clientOpId: opId,
      ),
      offline,
    );
  }

  @override
  Future<Map<String, dynamic>> deleteProduct({
    required int productId,
    required int businessId,
    String? clientOpId,
  }) {
    Future<Map<String, dynamic>> offline() async {
      await _db.deleteProduct(businessId, productId);
      await _enqueue('delete_product', businessId, 'Futa bidhaa #$productId',
          {'productId': productId, 'businessId': businessId},
          opId: clientOpId);
      return _offlineOk('Imefutwa offline — itatumwa ukiwa online');
    }

    if (productId < 0) return offline().then((r) { onQueued?.call(); return r; });
    return _write(
      () => super.deleteProduct(
          productId: productId, businessId: businessId, clientOpId: clientOpId),
      offline,
    );
  }

  @override
  Future<Map<String, dynamic>> addProductBatch({
    required int productId,
    required int businessId,
    required int quantity,
    required double buyPrice,
    String batchNumber = '',
    String expiryDate = '',
    String notes = '',
    String? clientOpId,
  }) {
    Future<Map<String, dynamic>> offline() async {
      await _db.adjustStock(businessId, productId, quantity.toDouble());
      await _enqueue('add_batch', businessId, 'Stock +$quantity (#$productId)', {
        'productId': productId, 'businessId': businessId,
        'quantity': quantity, 'buyPrice': buyPrice,
        'batchNumber': batchNumber, 'expiryDate': expiryDate, 'notes': notes,
        'createdAt': _now(),
      }, opId: clientOpId);
      return _offlineOk('Stock imeongezwa offline — itatumwa ukiwa online');
    }

    if (productId < 0) return offline().then((r) { onQueued?.call(); return r; });
    return _write(
      () => super.addProductBatch(
        productId: productId, businessId: businessId, quantity: quantity,
        buyPrice: buyPrice, batchNumber: batchNumber, expiryDate: expiryDate,
        notes: notes, clientOpId: clientOpId,
      ),
      offline,
    );
  }

  @override
  Future<Map<String, dynamic>> manageProductUnits({
    required int productId,
    required int businessId,
    required List<Map<String, dynamic>> units,
    String? clientOpId,
  }) {
    Future<Map<String, dynamic>> offline() async {
      final prod = await _db.getProduct(businessId, productId);
      if (prod != null) {
        var i = 0;
        prod['units'] = units
            .map((u) => {...u, 'unit_id': -(++i), 'product_id': productId})
            .toList();
        await _db.upsertProduct(businessId, prod);
      }
      await _enqueue('manage_units', businessId, 'Vipimo vya bidhaa #$productId',
          {'productId': productId, 'businessId': businessId, 'units': units},
          opId: clientOpId);
      return _offlineOk('Vipimo vimehifadhiwa offline');
    }

    if (productId < 0) return offline().then((r) { onQueued?.call(); return r; });
    return _write(
      () => super.manageProductUnits(
          productId: productId, businessId: businessId, units: units,
          clientOpId: clientOpId),
      offline,
    );
  }

  @override
  Future<Map<String, dynamic>> importProductsBulk({
    required int businessId,
    required int branchId,
    required List<Map<String, dynamic>> products,
    String? clientOpId,
  }) =>
      _write(
        () => super.importProductsBulk(
            businessId: businessId, branchId: branchId, products: products,
            clientOpId: clientOpId),
        () async {
          for (final p in products) {
            await _db.upsertProduct(businessId, {
              'product_id': newTempId(),
              'name': p['product_name'] ?? '',
              'category': p['product_category'] ?? '',
              'sellPrice': p['sell_price'] ?? 0,
              'buyPrice': p['purchase_price'] ?? 0,
              'qty': p['stock'] ?? 0,
              'min_stock': p['min_stock'] ?? 5,
              'unit': p['product_satuan'] ?? '',
              'image': '',
              'barcode': p['barcode'] ?? '',
              'description': p['description'] ?? '',
              'units': <Map<String, dynamic>>[],
              'sync_status': 'pending',
            });
          }
          await _enqueue('import_products', businessId,
              'Import bidhaa ${products.length}', {
            'businessId': businessId, 'branchId': branchId, 'products': products,
          }, opId: clientOpId);
          return _offlineOk('Bidhaa ${products.length} zimehifadhiwa offline', {
            'inserted': products.length, 'skipped': 0, 'errors': <String>[],
          });
        },
      );

  // ══════════════════════════════════════════════════════════════════════════
  // Categories / units admin
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<Map<String, dynamic>> manageCategory(int businessId, String action,
      {int? id, String? name, String? clientOpId}) =>
      _write(
        () => super.manageCategory(businessId, action,
            id: id, name: name, clientOpId: clientOpId),
        () async {
          await _applyListEdit('categories_admin:$businessId', action, id, name);
          await _applyListEdit('categories:$businessId', action, id, name);
          await _enqueue('manage_category', businessId, 'Kategoria: ${name ?? id}',
              {'businessId': businessId, 'action': action, 'id': id, 'name': name},
              opId: clientOpId);
          return _offlineOk('Imehifadhiwa offline');
        },
      );

  @override
  Future<Map<String, dynamic>> manageUnit(int businessId, String action,
      {int? id, String? name, String? shortName, String? clientOpId}) =>
      _write(
        () => super.manageUnit(businessId, action,
            id: id, name: name, shortName: shortName, clientOpId: clientOpId),
        () async {
          await _applyListEdit('units_admin:$businessId', action, id, name,
              extra: {'short_name': shortName});
          final u = await _db.getCache('units:$businessId');
          if (u is List && name != null) {
            final list = u.map((e) => '$e').toList();
            if (action == 'add') list.add(name);
            await _db.putCache('units:$businessId', list);
          }
          await _enqueue('manage_unit', businessId, 'Kipimo: ${name ?? id}', {
            'businessId': businessId, 'action': action, 'id': id,
            'name': name, 'shortName': shortName,
          }, opId: clientOpId);
          return _offlineOk('Imehifadhiwa offline');
        },
      );

  /// Apply add/edit/delete to a cached list of `{id, name}` maps.
  Future<void> _applyListEdit(String key, String action, int? id, String? name,
      {Map<String, dynamic> extra = const {}}) async {
    final raw = await _db.getCache(key);
    final list = (raw as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    switch (action) {
      case 'add':
        list.add({'id': newTempId(), 'name': name ?? '', ...extra,
          'sync_status': 'pending'});
      case 'edit':
      case 'update':
        for (final m in list) {
          if ('${m['id']}' == '$id') {
            if (name != null) m['name'] = name;
            m.addAll(extra..removeWhere((_, v) => v == null));
          }
        }
      case 'delete':
        list.removeWhere((m) => '${m['id']}' == '$id');
    }
    await _db.putCache(key, list);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Sales
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<List<dynamic>> getSales(int businessId,
      {int? branchId, String? dateFrom, String? dateTo, String? status}) async {
    if (await _online()) {
      try {
        final raw = await super.getSales(businessId,
            branchId: branchId, dateFrom: dateFrom, dateTo: dateTo, status: status);
        _conn.reportSuccess();
        // Only cache the unfiltered list – filtered calls would wipe the rest.
        if (dateFrom == null && dateTo == null && status == null) {
          await _db.replaceSyncedSales(businessId, raw);
        } else {
          return raw;
        }
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    final local = await _db.getSales(businessId, branchId: branchId);
    // Pending sales first (they are the newest anyway), then by date.
    local.sort((a, b) {
      final pa = a['sync_status'] == 'synced' ? 1 : 0;
      final pb = b['sync_status'] == 'synced' ? 1 : 0;
      if (pa != pb) return pa - pb;
      return '${b['created_at']}'.compareTo('${a['created_at']}');
    });
    if (status != null) {
      return local.where((s) => '${s['payment_status']}' == status).toList();
    }
    return local;
  }

  @override
  Future<Map<String, dynamic>> getSaleDetail(int saleId) async {
    final row = await _db.getSaleRow(saleId);
    final createdOffline =
        row != null && !'${row['local_id']}'.startsWith('srv-');
    if (saleId < 0 || createdOffline) {
      return {
        'success': true,
        'offline': true,
        'sale': row?['sale'],
        'items': row?['items'] ?? [],
      };
    }
    return _cached(
      'saledetail:$saleId',
      () => super.getSaleDetail(saleId),
      decode: (r) => Map<String, dynamic>.from(r as Map),
    );
  }

  @override
  Future<List<dynamic>> getSalePayments(int saleId) async {
    final row = await _db.getSaleRow(saleId);
    final localPays = (row?['payments'] as List?) ?? [];
    final createdOffline =
        row != null && !'${row['local_id']}'.startsWith('srv-');
    if (saleId < 0 || createdOffline) return localPays;
    List<dynamic> server = [];
    if (await _online()) {
      try {
        server = await super.getSalePayments(saleId);
        _conn.reportSuccess();
        await _db.putCache('salepay:$saleId', server);
      } catch (_) {
        _conn.reportFailure();
        server = (await _db.getCache('salepay:$saleId') as List?) ?? [];
      }
    } else {
      server = (await _db.getCache('salepay:$saleId') as List?) ?? [];
    }
    return [...server, ...localPays];
  }

  @override
  Future<Map<String, dynamic>> createSale({
    required int businessId,
    required int branchId,
    required String customerName,
    required String transactionType,
    required List<Map<String, dynamic>> items,
    double? amountPaid,
    String? clientOpId,
    String? createdAt,
    String customerPhone = '',
    int? customerId,
    List<Map<String, dynamic>>? payments,
  }) {
    final opId = clientOpId ?? _uuid.v4();
    final when = createdAt ?? _now();
    final whenUtc = _nowUtc();
    return _write(
      () async {
        final res = await super.createSale(
          businessId: businessId, branchId: branchId,
          customerName: customerName, transactionType: transactionType,
          items: items, amountPaid: amountPaid, clientOpId: opId, createdAt: whenUtc,
          customerPhone: customerPhone, customerId: customerId, payments: payments,
        );
        if (res['success'] == true && _deductsStock(transactionType)) {
          // Keep local stock in step so the POS grid is right immediately.
          for (final it in items) {
            await _db.adjustStock(businessId,
                int.tryParse('${it['product_id']}') ?? 0,
                -_baseUnits(it));
          }
        }
        return res;
      },
      () async {
        final tempId = newTempId();
        final saleNo = 'OFF-${when.substring(2, 10).replaceAll('-', '')}-${(-tempId) % 10000}';
        final total = items.fold<double>(
            0, (s, i) => s + (double.tryParse('${i['qty']}') ?? 0) *
                (double.tryParse('${i['unit_price']}') ?? 0));
        final fin = _paymentFigures(transactionType, total, amountPaid);
        final phone = customerPhone.isNotEmpty
            ? customerPhone
            : RegExp(r'PHONE:(\S+)').firstMatch(customerName)?.group(1) ?? '';
        final name = customerName.split('|').first.trim();

        final saleJson = <String, dynamic>{
          'sale_id': tempId,
          'sale_no': saleNo,
          'business_id': businessId,
          'branch_id': branchId,
          'customer_name': name,
          'customer_phone': phone,
          'subtotal_amount': total,
          'discount_amount': 0,
          'total_amount': total,
          'paid_amount': fin.paid,
          'balance_amount': fin.balance,
          'sale_type': fin.saleType,
          'payment_status': fin.status,
          'payment_method': transactionType,
          'notes': '',
          'created_at': when,
          'item_count': items.length,
          'client_op_id': opId,
        };
        final itemRows = <Map<String, dynamic>>[];
        for (final it in items) {
          final pid = int.tryParse('${it['product_id']}') ?? 0;
          final prod = await _db.getProduct(businessId, pid);
          final qty = double.tryParse('${it['qty']}') ?? 0;
          final price = double.tryParse('${it['unit_price']}') ?? 0;
          itemRows.add({
            'product_id': pid,
            'product_name': prod?['name'] ?? 'Bidhaa #$pid',
            'quantity': qty,
            'unit_price': price,
            'line_total': qty * price,
            'unit': '${it['unit_name'] ?? ''}'.isNotEmpty
                ? it['unit_name']
                : (prod?['unit'] ?? ''),
            'conversion_qty': it['conversion_qty'] ?? 1,
          });
          if (_deductsStock(transactionType)) {
            await _db.adjustStock(businessId, pid, -_baseUnits(it));
          }
        }
        await _db.insertLocalSale(
          localId: opId, tempSaleId: tempId, businessId: businessId,
          branchId: branchId, sale: saleJson, items: itemRows,
        );
        await _enqueue('create_sale', businessId, 'Mauzo $saleNo', {
          'tempSaleId': tempId, 'businessId': businessId, 'branchId': branchId,
          'customerName': customerName, 'transactionType': transactionType,
          'items': items, 'amountPaid': amountPaid, 'createdAt': whenUtc,
          'customerPhone': phone, 'customerId': customerId,
          if (payments != null && payments.isNotEmpty) 'payments': payments,
        }, opId: opId);
        var change = 0.0;
        if (payments != null) {
          for (final p in payments) {
            final amt = double.tryParse('${p['amount']}') ?? 0;
            final tendered = double.tryParse('${p['tendered'] ?? ''}');
            if (tendered != null && tendered > amt) change += tendered - amt;
          }
        }
        return _offlineOk('Mauzo yamehifadhiwa offline — yatatumwa ukiwa online', {
          'sale_id': tempId, 'sale_no': saleNo, 'receipt_no': saleNo,
          'data': saleJson, 'change_amount': change,
        });
      },
    );
  }

  static double _baseUnits(Map<String, dynamic> it) =>
      (double.tryParse('${it['qty']}') ?? 0) *
      (double.tryParse('${it['conversion_qty'] ?? 1}') ?? 1);

  /// Mirrors the mapping in create_sale.php so an offline receipt shows the
  /// same figures the server will store once synced.
  static ({double paid, double balance, String status, String saleType})
      _paymentFigures(String type, double total, double? amountPaid) {
    switch (type) {
      case 'loan':
        return (paid: 0, balance: total, status: 'unpaid', saleType: 'loan');
      case 'slow_payment':
        final paid = (amountPaid ?? 0) > 0
            ? (amountPaid!).clamp(0, total).toDouble()
            : 0.0;
        return (paid: paid, balance: total - paid, status: 'partial', saleType: 'partial');
      case 'cash_not_collected':
        return (paid: 0, balance: total, status: 'pending', saleType: 'cash_not_collected');
      case 'bank_transfer':
        return (paid: 0, balance: total, status: 'pending', saleType: 'bank_transfer');
      default: // cash
        return (paid: total, balance: 0, status: 'paid', saleType: 'cash');
    }
  }

  /// create_sale.php only deducts stock for these types (slow_payment is an
  /// installment plan – stock stays until collected).
  static bool _deductsStock(String type) => type != 'slow_payment';

  @override
  Future<Map<String, dynamic>> saleAction(int saleId, String action,
      {double? amount, String? note, String? clientOpId}) {
    Future<Map<String, dynamic>> offline() async {
      final row = await _db.getSaleRow(saleId);
      if (row != null) {
        final s = Map<String, dynamic>.from(row['sale'] as Map);
        final pays = List<Map<String, dynamic>>.from(row['payments'] as List);
        final total = double.tryParse('${s['total_amount']}') ?? 0;
        var paid = double.tryParse('${s['paid_amount']}') ?? 0;
        switch (action) {
          case 'void_sale':
            s['payment_status'] = 'voided';
            // Give stock back.
            for (final it in (row['items'] as List)) {
              final m = Map<String, dynamic>.from(it as Map);
              final q = (double.tryParse('${m['quantity']}') ?? 0) *
                  (double.tryParse('${m['conversion_qty'] ?? 1}') ?? 1);
              await _db.adjustStock(
                  int.tryParse('${s['business_id']}') ?? 0,
                  int.tryParse('${m['product_id']}') ?? 0, q);
            }
          case 'record_payment':
            paid += amount ?? 0;
            pays.add({'id': -pays.length - 1, 'amount': amount, 'note': note ?? '',
              'created_at': _now(), 'sync_status': 'pending'});
          case 'collect_cash':
          case 'confirm_bank_transfer':
            paid = total;
        }
        if (action != 'void_sale') {
          s['paid_amount'] = paid;
          s['balance_amount'] = (total - paid).clamp(0, double.infinity);
          s['payment_status'] =
              paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');
        }
        // A synced sale edited offline becomes 'pending' so the list flags it.
        await _db.updateSale(saleId, sale: s, payments: pays,
            syncStatus: row['sync_status'] == 'synced' ? 'pending' : null);
      }
      await _enqueue('sale_action',
          int.tryParse('${row?['sale']?['business_id'] ?? 0}') ?? 0,
          '${_actionLabel(action)} (#${row?['sale']?['sale_no'] ?? saleId})', {
        'saleId': saleId, 'action': action, 'amount': amount, 'note': note,
      }, opId: clientOpId);
      return _offlineOk('Imehifadhiwa offline — itatumwa ukiwa online');
    }

    if (saleId < 0) return offline().then((r) { onQueued?.call(); return r; });
    return _write(
      () async {
        final res = await super.saleAction(saleId, action,
            amount: amount, note: note, clientOpId: clientOpId);
        if (res['success'] == true) await _db.removeCache('saledetail:$saleId');
        return res;
      },
      offline,
    );
  }

  static String _actionLabel(String a) => switch (a) {
        'void_sale' => 'Futa mauzo',
        'record_payment' => 'Malipo ya deni',
        'collect_cash' => 'Pesa imepokelewa',
        'confirm_bank_transfer' => 'Thibitisha benki',
        _ => a,
      };

  // ══════════════════════════════════════════════════════════════════════════
  // Dashboard
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<Map<String, dynamic>> getDashboard(int businessId,
      {int? branchId, String? dateFrom, String? dateTo}) async {
    final key = 'dashboard:$businessId:${branchId ?? 0}';
    if (dateFrom == null && dateTo == null && await _online()) {
      try {
        final r = await super.getDashboard(businessId, branchId: branchId);
        _conn.reportSuccess();
        if (r['success'] == true) await _db.putCache(key, r);
        return r;
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    } else if (dateFrom != null || dateTo != null) {
      if (await _online()) {
        try {
          final r = await super.getDashboard(businessId,
              branchId: branchId, dateFrom: dateFrom, dateTo: dateTo);
          _conn.reportSuccess();
          return r;
        } catch (e) {
          if (!isNetworkError(e)) rethrow;
          _conn.reportFailure();
        }
      }
    }
    final cached = await _db.getCache(key);
    final base = cached is Map
        ? Map<String, dynamic>.from(
            (cached['data'] is Map ? cached['data'] : cached) as Map)
        : <String, dynamic>{};
    return {
      'success': true,
      'offline': true,
      'data': await _overlayLocal(businessId, branchId, base),
    };
  }

  /// Merge offline sales/products into the last server snapshot.
  Future<Map<String, dynamic>> _overlayLocal(
      int businessId, int? branchId, Map<String, dynamic> base) async {
    double num_(dynamic v) => double.tryParse('$v') ?? 0;
    final sales = await _db.getSales(businessId, branchId: branchId);
    final pending = sales.where((s) => s['sync_status'] != 'synced').toList();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    double todayRev = num_(base['today_revenue']);
    int todayCnt = (int.tryParse('${base['today_sales_count'] ?? 0}') ?? 0);
    double totalRev = num_(base['total_revenue']);
    double loansAmt = num_(base['unpaid_loans_amount']);
    int loansCnt = int.tryParse('${base['unpaid_loans_count'] ?? 0}') ?? 0;

    for (final s in pending) {
      if (s['payment_status'] == 'voided') continue;
      final t = num_(s['total_amount']);
      final b = num_(s['balance_amount']);
      totalRev += t;
      if ('${s['created_at']}'.startsWith(today)) {
        todayRev += t;
        todayCnt += 1;
      }
      if (b > 0) {
        loansAmt += b;
        loansCnt += 1;
      }
    }

    final prods = await _db.getProducts(businessId);
    int low = 0, out = 0;
    for (final p in prods) {
      final q = num_(p['qty']);
      final min = num_(p['min_stock'] ?? 5);
      if (q <= 0) {
        out++;
      } else if (q <= min) {
        low++;
      }
    }

    // Weekly chart: server snapshot + pending sales by day.
    final weekly = (base['weekly_sales'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (weekly.isEmpty) {
      const days = ['Jumatatu','Jumanne','Jumatano','Alhamisi','Ijumaa','Jumamosi','Jumapili'];
      for (var i = 6; i >= 0; i--) {
        final d = DateTime.now().subtract(Duration(days: i));
        weekly.add({
          'date': d.toIso8601String().substring(0, 10),
          'day_label': days[d.weekday - 1].substring(0, 3),
          'total': 0.0,
        });
      }
    }
    for (final s in pending) {
      if (s['payment_status'] == 'voided') continue;
      final d = '${s['created_at']}'.substring(0, 10);
      for (final w in weekly) {
        if ('${w['date'] ?? ''}' == d) {
          w['total'] = num_(w['total']) + num_(s['total_amount']);
        }
      }
    }

    return {
      ...base,
      'today_revenue': todayRev,
      'today_sales_count': todayCnt,
      'total_revenue': totalRev,
      'unpaid_loans_amount': loansAmt,
      'unpaid_loans_count': loansCnt,
      'total_products': prods.isNotEmpty ? prods.length : base['total_products'] ?? 0,
      'low_stock_count': prods.isNotEmpty ? low : base['low_stock_count'] ?? 0,
      'out_of_stock_count': prods.isNotEmpty ? out : base['out_of_stock_count'] ?? 0,
      'weekly_sales': weekly,
      'pending_sync_count': pending.length,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Reports & expenses
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<Map<String, dynamic>> getReport(int businessId,
      {int? branchId, required String dateFrom, required String dateTo}) {
    final key = 'report:$businessId:${branchId ?? 0}:$dateFrom:$dateTo';
    return _cached(
      key,
      () => super.getReport(businessId, branchId: branchId, dateFrom: dateFrom, dateTo: dateTo),
      decode: (raw) => {...Map<String, dynamic>.from(raw as Map), 'offline': true},
    );
  }

  /// Expense rows live in kv cache under one key per business; offline
  /// adds/edits are applied to that list and queued.
  String _expKey(int biz) => 'expenses:$biz';

  @override
  Future<List<dynamic>> listExpenses(int businessId,
      {int? branchId, String? dateFrom, String? dateTo}) async {
    if (await _online()) {
      try {
        // full list → cache; filter locally so offline sees the same data
        final raw = await super.listExpenses(businessId);
        _conn.reportSuccess();
        final pending = (await _db.getCache(_expKey(businessId)) as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => e['sync_status'] != null && e['sync_status'] != 'synced')
            .toList();
        await _db.putCache(_expKey(businessId), [...pending, ...raw]);
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _conn.reportFailure();
      }
    }
    final all = (await _db.getCache(_expKey(businessId)) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return all.where((e) {
      final d = '${e['expense_date'] ?? ''}';
      if (dateFrom != null && d.compareTo(dateFrom) < 0) return false;
      if (dateTo != null && d.compareTo(dateTo) > 0) return false;
      if (branchId != null && e['branch_id'] != null &&
          int.tryParse('${e['branch_id']}') != branchId) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => '${b['expense_date']}'.compareTo('${a['expense_date']}'));
  }

  @override
  Future<Map<String, dynamic>> saveExpense({
    required int businessId,
    int? expenseId,
    int? branchId,
    int? userId,
    required String category,
    required String description,
    required double amount,
    required String expenseDate,
    String? clientOpId,
  }) {
    final opId = clientOpId ?? _uuid.v4();
    Future<Map<String, dynamic>> offline() async {
      final list = (await _db.getCache(_expKey(businessId)) as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final id = expenseId ?? newTempId();
      final row = {
        'expense_id': id, 'business_id': businessId, 'branch_id': branchId,
        'category': category, 'description': description, 'amount': amount,
        'expense_date': expenseDate, 'created_at': _now(), 'sync_status': 'pending',
      };
      final idx = list.indexWhere((e) => '${e['expense_id']}' == '$id');
      if (idx >= 0) {
        list[idx] = {...list[idx], ...row};
      } else {
        list.insert(0, row);
      }
      await _db.putCache(_expKey(businessId), list);
      await _enqueue(
        expenseId == null ? 'expense_add' : 'expense_update',
        businessId,
        'Matumizi: $category ${amount.toStringAsFixed(0)}',
        {
          'expenseId': id, 'businessId': businessId, 'branchId': branchId,
          'userId': userId, 'category': category, 'description': description,
          'amount': amount, 'expenseDate': expenseDate,
        },
        opId: opId,
      );
      return _offlineOk('Matumizi yamehifadhiwa offline', {'expense_id': id});
    }

    if (expenseId != null && expenseId < 0) {
      return offline().then((r) { onQueued?.call(); return r; });
    }
    return _write(
      () async {
        final r = await super.saveExpense(
          businessId: businessId, expenseId: expenseId, branchId: branchId,
          userId: userId, category: category, description: description,
          amount: amount, expenseDate: expenseDate, clientOpId: opId,
        );
        if (r['success'] == true) await _db.removeCacheWhere('report:$businessId');
        return r;
      },
      offline,
    );
  }

  @override
  Future<Map<String, dynamic>> deleteExpense({
    required int businessId,
    required int expenseId,
    String? clientOpId,
  }) {
    Future<Map<String, dynamic>> offline() async {
      final list = (await _db.getCache(_expKey(businessId)) as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..removeWhere((e) => '${e['expense_id']}' == '$expenseId');
      await _db.putCache(_expKey(businessId), list);
      if (expenseId > 0) {
        await _enqueue('expense_delete', businessId, 'Futa matumizi #$expenseId',
            {'expenseId': expenseId, 'businessId': businessId}, opId: clientOpId);
      }
      return _offlineOk('Imefutwa offline');
    }

    if (expenseId < 0) return offline().then((r) { onQueued?.call(); return r; });
    return _write(
      () async {
        final r = await super.deleteExpense(
            businessId: businessId, expenseId: expenseId, clientOpId: clientOpId);
        if (r['success'] == true) await _db.removeCacheWhere('report:$businessId');
        return r;
      },
      offline,
    );
  }

  @override
  Future<Map<String, dynamic>> getChartData(int businessId,
      {int? branchId, String? period}) => _cached(
        'chart:$businessId:${branchId ?? 0}:${period ?? ''}',
        () => super.getChartData(businessId, branchId: branchId, period: period),
        decode: (r) => Map<String, dynamic>.from(r as Map),
      );
}
