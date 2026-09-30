import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:donel_pos/services/connectivity_service.dart';
import 'package:donel_pos/services/local_db.dart';
import 'package:donel_pos/services/offline_api_service.dart';
import 'package:donel_pos/services/storage_service.dart';
import 'package:donel_pos/services/sync_service.dart';

const _biz = 7;
const _base = 'http://fake.local/pos/api';

/// Stand-in for the PHP API. `up == false` → every call fails like a dead
/// network. Records requests so the test can assert what sync sent.
class _FakeServer {
  bool up = false;
  final requests = <Map<String, dynamic>>[]; // {path, body}
  final seenOps = <String, String>{};       // client_op_id → response (idempotency)
  int nextSale = 900;

  late final http.Client client = MockClient(handle);

  Future<http.Response> handle(http.Request req) async {
    if (!up) throw const SocketException('Network is unreachable');
    final path = req.url.path.split('/').last;
    Map<String, dynamic> body = {};
    final ct = req.headers['content-type'] ?? '';
    if (ct.startsWith('application/json')) {
      body = req.body.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(req.body));
    } else if (ct.startsWith('multipart/')) {
      for (final m in RegExp(r'name="([^"]+)"\r\n\r\n([^\r]*)').allMatches(req.body)) {
        body[m.group(1)!] = m.group(2)!;
      }
    }
    requests.add({'path': path, 'body': body});

    Map<String, dynamic> out;
    final opId = body['client_op_id'] as String?;
    if (opId != null && seenOps.containsKey(opId)) {
      out = jsonDecode(seenOps[opId]!);
      out['replayed'] = true;
    } else {
      switch (path) {
        case 'ping.php':
          out = {'success': true};
        case 'add_product.php':
          out = {'success': true, 'product_id': 500};
        case 'create_sale.php':
          final pid = (body['items'] as List).first['product_id'];
          if (pid is int && pid < 0) {
            out = {'success': false, 'message': 'bad temp product id $pid'};
          } else {
            nextSale++;
            out = {'success': true, 'sale_id': nextSale, 'sale_no': 'S-$nextSale'};
          }
        case 'sale_action.php':
          out = {'success': true, 'message': 'ok'};
        default:
          out = {'success': true};
      }
      if (opId != null && out['success'] == true) seenOps[opId] = jsonEncode(out);
    }
    return http.Response(jsonEncode(out), 200,
        headers: {'content-type': 'application/json'});
  }
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late _FakeServer server;
  late OfflineApiService api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await LocalDb.instance.init(path: inMemoryDatabasePath);
    await LocalDb.instance.clearAll();
    server = _FakeServer();
    ConnectivityService.instance.client = server.client;
    api = OfflineApiService(_base, client: server.client);
    SyncService.instance.configure(_base, client: server.client);
    await LocalDb.instance.replaceProducts(_biz, [
      {'product_id': 1, 'name': 'Pepsi', 'sellPrice': 1000, 'qty': 24, 'units': []},
    ]);
  });

  tearDown(() => ConnectivityService.instance.reportFailure());

  test('offline product → offline sale → offline payment sync in order with id remap',
      () async {
    // 1. Everything happens while the server is unreachable.
    final p = await api.addProduct(
      businessId: _biz, branchId: 1, name: 'Sukari', category: 'Chakula',
      unit: 'Kg', buyPrice: 2500, sellPrice: 3000, stock: 10,
    );
    final tempPid = p['product_id'] as int;
    final s = await api.createSale(
      businessId: _biz, branchId: 1, customerName: 'Asha',
      transactionType: 'loan',
      items: [{'product_id': tempPid, 'qty': 2, 'unit_price': 3000,
               'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
    );
    final tempSid = s['sale_id'] as int;
    await api.saleAction(tempSid, 'record_payment', amount: 1000, note: 'advance');

    await SyncService.instance.refreshCounts();
    expect(SyncService.instance.pending, 3);
    expect(ConnectivityService.instance.isOnline, false);
    expect(server.requests, isEmpty);

    // 2. Network comes back.
    server.up = true;
    await SyncService.instance.syncNow();

    expect(SyncService.instance.pending, 0, reason: 'all ops pushed');
    expect(SyncService.instance.failed, 0);
    expect(ConnectivityService.instance.isOnline, true);

    final paths = server.requests.map((r) => r['path']).toList();
    expect(paths, containsAllInOrder(['add_product.php', 'create_sale.php', 'sale_action.php']));

    // Sale referenced the REAL product id, payment referenced the REAL sale id.
    final saleReq = server.requests.firstWhere((r) => r['path'] == 'create_sale.php');
    expect(saleReq['body']['items'][0]['product_id'], 500);
    expect(saleReq['body']['created_at'], isNotNull);
    expect(saleReq['body']['client_op_id'], isNotNull);
    final payReq = server.requests.firstWhere((r) => r['path'] == 'sale_action.php');
    expect(payReq['body']['sale_id'], 901);
    expect(payReq['body']['note'], 'advance');

    // Local rows were re-keyed and marked synced.
    expect(await LocalDb.instance.getProduct(_biz, tempPid), isNull);
    expect((await LocalDb.instance.getProduct(_biz, 500))!['name'], 'Sukari');
    expect(await LocalDb.instance.getSaleRow(tempSid), isNull);
    final row = await LocalDb.instance.getSaleRow(901);
    expect(row!['sync_status'], 'synced');
    expect(row['sale']['sale_no'], 'S-901');
  });

  test('server rejection marks the op failed and flags the sale', () async {
    final s = await api.createSale(
      businessId: _biz, branchId: 1, customerName: 'x', transactionType: 'cash',
      items: [{'product_id': -12345, 'qty': 1, 'unit_price': 10,
               'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
    );
    // -12345 never got an id_map entry → sync must refuse, not send garbage.
    server.up = true;
    await SyncService.instance.syncNow();
    expect(SyncService.instance.failed, 1);
    expect(server.requests.where((r) => r['path'] == 'create_sale.php'), isEmpty);
    final row = await LocalDb.instance.getSaleRow(s['sale_id'] as int);
    expect(row!['sync_status'], 'failed');
    expect(row['sale']['sync_error'], contains('haijasync'));
  });

  test('network dropping mid-sync leaves the rest pending, no failures', () async {
    for (var i = 0; i < 3; i++) {
      await api.createSale(
        businessId: _biz, branchId: 1, customerName: 'x', transactionType: 'cash',
        items: [{'product_id': 1, 'qty': 1, 'unit_price': 1000,
                 'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
      );
    }
    server.up = true;
    // Kill the link right after the first sale lands.
    var count = 0;
    final flaky = MockClient((req) async {
      if (req.url.path.endsWith('create_sale.php') && ++count == 2) {
        server.up = false;
      }
      return server.handle(req);
    });
    SyncService.instance.configure(_base, client: flaky);
    await SyncService.instance.syncNow();
    expect(SyncService.instance.failed, 0);
    expect(SyncService.instance.pending, 2);
    expect(ConnectivityService.instance.isOnline, false);
  });

  test('the same client_op_id is never applied twice', () async {
    await api.createSale(
      businessId: _biz, branchId: 1, customerName: 'x', transactionType: 'cash',
      items: [{'product_id': 1, 'qty': 1, 'unit_price': 1000,
               'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
    );
    final opId = (await LocalDb.instance.queue()).single['op_id'] as String;
    server.up = true;
    await SyncService.instance.syncNow();
    expect(server.seenOps.keys, [opId]);
    // A "lost response" retry with the same id replays instead of inserting.
    final again = await api.createSale(
      businessId: _biz, branchId: 1, customerName: 'x', transactionType: 'cash',
      items: [{'product_id': 1, 'qty': 1, 'unit_price': 1000,
               'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
      clientOpId: opId,
    );
    expect(again['replayed'], true);
    expect(server.nextSale, 901, reason: 'only one sale row was ever created');
  });

  test('online sale still goes straight to the server and updates local stock',
      () async {
    server.up = true;
    await ConnectivityService.instance.probe(force: true);
    final res = await api.createSale(
      businessId: _biz, branchId: 1, customerName: 'x', transactionType: 'cash',
      items: [{'product_id': 1, 'qty': 3, 'unit_price': 1000,
               'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
    );
    expect(res['offline'], isNull);
    expect(res['sale_id'], 901);
    expect((await LocalDb.instance.getProduct(_biz, 1))!['qty'], 21);
    expect(await LocalDb.instance.queue(), isEmpty);
  });
}
