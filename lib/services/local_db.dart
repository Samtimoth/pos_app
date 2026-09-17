import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Local SQLite store used for offline-first behaviour.
///
/// Tables
///  • kv_cache   – generic cached API responses keyed by string
///  • products   – one row per product (JSON blob, same shape as get_products)
///  • sales      – synced + pending sales (JSON blob, same shape as get_sales)
///  • sync_queue – write operations waiting to be pushed to the server
///  • id_map     – temp (negative) id → real server id, per entity
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;
  bool get isReady => _db != null;

  /// Web uses SQLite compiled to wasm on top of IndexedDB (needs
  /// web/sqlite3.wasm); every other platform uses native sqflite.
  static bool get supported => true;

  /// [path] overrides the on-disk location (tests pass
  /// [inMemoryDatabasePath]); the caller then sets `databaseFactory` itself.
  Future<void> init({String? path}) async {
    if (!supported || _db != null) return;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      path ??= 'duka_kiganjani.db';
    } else if (path == null && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    if (path == null) {
      final dir = await getApplicationSupportDirectory();
      path = p.join(dir.path, 'duka_kiganjani.db');
    }
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE kv_cache (
            key        TEXT PRIMARY KEY,
            value      TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE products (
            product_id  INTEGER NOT NULL,
            business_id INTEGER NOT NULL,
            json        TEXT NOT NULL,
            updated_at  INTEGER NOT NULL,
            PRIMARY KEY (product_id, business_id)
          )''');
        await db.execute('''
          CREATE TABLE sales (
            local_id    TEXT PRIMARY KEY,
            sale_id     INTEGER NOT NULL,
            business_id INTEGER NOT NULL,
            branch_id   INTEGER NOT NULL,
            json        TEXT NOT NULL,
            items_json  TEXT NOT NULL,
            payments_json TEXT NOT NULL DEFAULT '[]',
            sync_status TEXT NOT NULL,
            created_at  TEXT NOT NULL
          )''');
        await db.execute(
            'CREATE INDEX idx_sales_biz ON sales(business_id, created_at)');
        await db.execute('''
          CREATE TABLE sync_queue (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            op_id       TEXT UNIQUE NOT NULL,
            op_type     TEXT NOT NULL,
            business_id INTEGER NOT NULL,
            label       TEXT NOT NULL,
            payload     TEXT NOT NULL,
            status      TEXT NOT NULL,
            attempts    INTEGER NOT NULL DEFAULT 0,
            last_error  TEXT,
            created_at  INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE id_map (
            entity   TEXT NOT NULL,
            temp_id  INTEGER NOT NULL,
            real_id  INTEGER NOT NULL,
            PRIMARY KEY (entity, temp_id)
          )''');
      },
    );
  }

  Database get _d {
    final d = _db;
    if (d == null) throw StateError('LocalDb not initialised');
    return d;
  }

  // ── kv cache ──────────────────────────────────────────────────────────────
  Future<void> putCache(String key, Object value) async {
    if (!isReady) return;
    await _d.insert(
      'kv_cache',
      {
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> getCache(String key) async {
    if (!isReady) return null;
    final rows = await _d.query('kv_cache', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value'] as String);
  }

  Future<void> removeCache(String key) async {
    if (!isReady) return;
    await _d.delete('kv_cache', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> removeCacheWhere(String prefix) async {
    if (!isReady) return;
    await _d.delete('kv_cache', where: 'key LIKE ?', whereArgs: ['$prefix%']);
  }

  // ── products ──────────────────────────────────────────────────────────────
  Future<void> replaceProducts(int businessId, List<dynamic> products) async {
    if (!isReady) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _d.transaction((txn) async {
      // Keep locally-created (temp, negative id) products – they are not on
      // the server yet and would otherwise disappear.
      await txn.delete('products',
          where: 'business_id = ? AND product_id > 0', whereArgs: [businessId]);
      final batch = txn.batch();
      for (final raw in products) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = int.tryParse('${m['product_id']}') ?? 0;
        if (id == 0) continue;
        batch.insert(
          'products',
          {
            'product_id': id,
            'business_id': businessId,
            'json': jsonEncode(m),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> getProducts(int businessId) async {
    if (!isReady) return [];
    final rows = await _d.query('products',
        where: 'business_id = ?', whereArgs: [businessId]);
    return rows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<Map<String, dynamic>?> getProduct(int businessId, int productId) async {
    if (!isReady) return null;
    final rows = await _d.query('products',
        where: 'business_id = ? AND product_id = ?',
        whereArgs: [businessId, productId]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['json'] as String));
  }

  Future<void> upsertProduct(int businessId, Map<String, dynamic> product) async {
    if (!isReady) return;
    final id = int.tryParse('${product['product_id']}') ?? 0;
    await _d.insert(
      'products',
      {
        'product_id': id,
        'business_id': businessId,
        'json': jsonEncode(product),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProduct(int businessId, int productId) async {
    if (!isReady) return;
    await _d.delete('products',
        where: 'business_id = ? AND product_id = ?',
        whereArgs: [businessId, productId]);
  }

  /// Adjust stock (base units) of a product by [delta] (negative = sold).
  Future<void> adjustStock(int businessId, int productId, double delta) async {
    final prod = await getProduct(businessId, productId);
    if (prod == null) return;
    final cur = double.tryParse('${prod['qty'] ?? 0}') ?? 0;
    final next = cur + delta;
    prod['qty'] = next == next.truncateToDouble() ? next.toInt() : next;
    await upsertProduct(businessId, prod);
  }

  /// Re-key a temp product id to the real server id.
  Future<void> remapProductId(int businessId, int tempId, int realId) async {
    if (!isReady) return;
    final prod = await getProduct(businessId, tempId);
    if (prod == null) return;
    prod['product_id'] = realId;
    await _d.transaction((txn) async {
      await txn.delete('products',
          where: 'business_id = ? AND product_id = ?',
          whereArgs: [businessId, tempId]);
      await txn.insert(
        'products',
        {
          'product_id': realId,
          'business_id': businessId,
          'json': jsonEncode(prod),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ── sales ─────────────────────────────────────────────────────────────────
  /// Replace all *synced* sales of a business with the server list.
  Future<void> replaceSyncedSales(int businessId, List<dynamic> sales) async {
    if (!isReady) return;
    await _d.transaction((txn) async {
      // Sales edited offline (void / payment) keep their local version until
      // the edit has been pushed – don't let the server copy overwrite it.
      final dirty = (await txn.query('sales',
              columns: ['sale_id'],
              where: "business_id = ? AND sync_status != 'synced'",
              whereArgs: [businessId]))
          .map((r) => r['sale_id'] as int)
          .toSet();
      await txn.delete('sales',
          where: "business_id = ? AND sync_status = 'synced'",
          whereArgs: [businessId]);
      final batch = txn.batch();
      for (final raw in sales) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = int.tryParse('${m['sale_id']}') ?? 0;
        if (id == 0 || dirty.contains(id)) continue;
        batch.insert(
          'sales',
          {
            'local_id': 'srv-$id',
            'sale_id': id,
            'business_id': businessId,
            'branch_id': int.tryParse('${m['branch_id'] ?? 0}') ?? 0,
            'json': jsonEncode(m),
            'items_json': '[]',
            'payments_json': '[]',
            'sync_status': 'synced',
            'created_at': '${m['created_at'] ?? ''}',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertLocalSale({
    required String localId,
    required int tempSaleId,
    required int businessId,
    required int branchId,
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
  }) async {
    if (!isReady) return;
    await _d.insert(
      'sales',
      {
        'local_id': localId,
        'sale_id': tempSaleId,
        'business_id': businessId,
        'branch_id': branchId,
        'json': jsonEncode(sale),
        'items_json': jsonEncode(items),
        'payments_json': '[]',
        'sync_status': 'pending',
        'created_at': '${sale['created_at'] ?? ''}',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSales(int businessId,
      {int? branchId}) async {
    if (!isReady) return [];
    final rows = await _d.query(
      'sales',
      where: branchId == null
          ? 'business_id = ?'
          : 'business_id = ? AND (branch_id = ? OR branch_id = 0)',
      whereArgs: branchId == null ? [businessId] : [businessId, branchId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      final m = Map<String, dynamic>.from(jsonDecode(r['json'] as String));
      m['sync_status'] = r['sync_status'];
      m['local_id'] = r['local_id'];
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>?> getSaleRow(int saleId) async {
    if (!isReady) return null;
    final rows =
        await _d.query('sales', where: 'sale_id = ?', whereArgs: [saleId]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'local_id': r['local_id'],
      'sale_id': r['sale_id'],
      'sync_status': r['sync_status'],
      'sale': Map<String, dynamic>.from(jsonDecode(r['json'] as String)),
      'items': (jsonDecode(r['items_json'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      'payments': (jsonDecode(r['payments_json'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    };
  }

  Future<void> updateSale(
    int saleId, {
    Map<String, dynamic>? sale,
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? payments,
    String? syncStatus,
    int? newSaleId,
  }) async {
    if (!isReady) return;
    final values = <String, Object?>{};
    if (sale != null) {
      values['json'] = jsonEncode(sale);
      values['created_at'] = '${sale['created_at'] ?? ''}';
    }
    if (items != null) values['items_json'] = jsonEncode(items);
    if (payments != null) values['payments_json'] = jsonEncode(payments);
    if (syncStatus != null) values['sync_status'] = syncStatus;
    if (newSaleId != null) values['sale_id'] = newSaleId;
    if (values.isEmpty) return;
    await _d.update('sales', values, where: 'sale_id = ?', whereArgs: [saleId]);
  }

  Future<void> deleteSale(int saleId) async {
    if (!isReady) return;
    await _d.delete('sales', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  // ── sync queue ────────────────────────────────────────────────────────────
  Future<void> enqueue({
    required String opId,
    required String opType,
    required int businessId,
    required String label,
    required Map<String, dynamic> payload,
  }) async {
    if (!isReady) return;
    await _d.insert('sync_queue', {
      'op_id': opId,
      'op_type': opType,
      'business_id': businessId,
      'label': label,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> queue({String? status}) async {
    if (!isReady) return [];
    final rows = await _d.query(
      'sync_queue',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'id ASC',
    );
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['payload'] = Map<String, dynamic>.from(jsonDecode(r['payload'] as String));
      return m;
    }).toList();
  }

  Future<int> queueCount(String status) async {
    if (!isReady) return 0;
    final r = await _d.rawQuery(
        'SELECT COUNT(*) c FROM sync_queue WHERE status = ?', [status]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> markQueue(int id,
      {required String status, String? error, bool bumpAttempts = false}) async {
    if (!isReady) return;
    await _d.rawUpdate(
      'UPDATE sync_queue SET status = ?, last_error = ?, attempts = attempts + ? WHERE id = ?',
      [status, error, bumpAttempts ? 1 : 0, id],
    );
  }

  Future<void> updateQueuePayload(int id, Map<String, dynamic> payload) async {
    if (!isReady) return;
    await _d.update('sync_queue', {'payload': jsonEncode(payload)},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteQueue(int id) async {
    if (!isReady) return;
    await _d.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> retryAllFailed() async {
    if (!isReady) return;
    await _d.update('sync_queue', {'status': 'pending', 'last_error': null},
        where: "status = 'failed'");
  }

  // ── id map ────────────────────────────────────────────────────────────────
  Future<void> putIdMap(String entity, int tempId, int realId) async {
    if (!isReady) return;
    await _d.insert(
      'id_map',
      {'entity': entity, 'temp_id': tempId, 'real_id': realId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> realId(String entity, int tempId) async {
    if (!isReady || tempId >= 0) return tempId;
    final rows = await _d.query('id_map',
        where: 'entity = ? AND temp_id = ?', whereArgs: [entity, tempId]);
    if (rows.isEmpty) return null;
    return rows.first['real_id'] as int;
  }

  /// Wipe everything (on logout).
  Future<void> clearAll() async {
    if (!isReady) return;
    await _d.transaction((txn) async {
      for (final t in ['kv_cache', 'products', 'sales', 'sync_queue', 'id_map']) {
        await txn.delete(t);
      }
    });
  }
}
