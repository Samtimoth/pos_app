import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:donel_pos/models/sale.dart';
import 'package:donel_pos/models/product.dart';
import 'package:donel_pos/services/local_db.dart';
import 'package:donel_pos/services/offline_api_service.dart';
import 'package:donel_pos/services/storage_service.dart';

/// A base URL nothing listens on → every network call fails fast, which is
/// exactly the "duka lina network mbovu" scenario we want to exercise.
const _deadServer = 'http://127.0.0.1:9/pos/api';
const _biz = 7;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late OfflineApiService api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await LocalDb.instance.init(path: inMemoryDatabasePath);
    await LocalDb.instance.clearAll();
    api = OfflineApiService(_deadServer);
    // Seed the product cache as if a previous online session fetched it.
    await LocalDb.instance.replaceProducts(_biz, [
      {
        'product_id': 1, 'name': 'Pepsi', 'category': 'Vinywaji',
        'sellPrice': 1000, 'buyPrice': 700, 'qty': 24, 'min_stock': 5,
        'unit': 'Chupa', 'image': '', 'barcode': '111',
        'units': [
          {'unit_id': 5, 'product_id': 1, 'unit_name': 'Dozen',
           'conversion_qty': 12, 'selling_price': 11000},
        ],
      },
      {
        'product_id': 2, 'name': 'Maji', 'category': 'Vinywaji',
        'sellPrice': 500, 'buyPrice': 300, 'qty': 3, 'min_stock': 5,
        'unit': 'Chupa', 'image': '', 'barcode': '222', 'units': [],
      },
    ]);
  });

  group('offline reads', () {
    test('products come from cache and parse into Product', () async {
      final raw = await api.getProducts(_biz);
      final prods = raw.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      expect(prods.map((p) => p.name), ['Maji', 'Pepsi']);
      expect(prods.last.units.single.unitName, 'Dozen');
    });

    test('search / category filters work locally', () async {
      expect((await api.getProducts(_biz, search: 'pep')).length, 1);
      expect((await api.getProducts(_biz, search: '222')).length, 1);
      expect((await api.getProducts(_biz, category: 'Vinywaji')).length, 2);
      expect((await api.getProducts(_biz, category: 'Chakula')).length, 0);
    });

    test('cached read with no cache throws OfflineException', () async {
      expect(() => api.getMyBusinesses(1), throwsA(isA<OfflineException>()));
    });
  });

  group('offline sale', () {
    test('is stored locally, queued, and reduces stock (incl. units)', () async {
      final res = await api.createSale(
        businessId: _biz, branchId: 1,
        customerName: 'Juma | TYPE:REGISTERED | PHONE:0712000000',
        transactionType: 'cash',
        items: [
          {'product_id': 1, 'qty': 2, 'unit_price': 11000,
           'unit_name': 'Dozen', 'conversion_qty': 12, 'discount_total': 0},
          {'product_id': 2, 'qty': 1, 'unit_price': 500,
           'unit_name': '', 'conversion_qty': 1, 'discount_total': 0},
        ],
      );
      expect(res['success'], true);
      expect(res['offline'], true);
      expect('${res['sale_no']}', startsWith('OFF-'));

      // Stock: Pepsi 24 - 2*12 = 0, Maji 3 - 1 = 2
      final pepsi = await LocalDb.instance.getProduct(_biz, 1);
      final maji = await LocalDb.instance.getProduct(_biz, 2);
      expect(pepsi!['qty'], 0);
      expect(maji!['qty'], 2);

      // Appears in the sales list, flagged pending, parsed by Sale model.
      final sales = await api.getSales(_biz);
      expect(sales.length, 1);
      final sale = Sale.fromJson(sales.first as Map<String, dynamic>);
      expect(sale.isOfflinePending, true);
      expect(sale.customerName, 'Juma');
      expect(sale.customerPhone, '0712000000');
      expect(sale.totalAmount, 22500);
      expect(sale.paidAmount, 22500);
      expect(sale.isPaid, true);
      expect(sale.saleId, lessThan(0));

      // Detail carries the line items for the receipt / detail sheet.
      final detail = await api.getSaleDetail(sale.saleId);
      expect((detail['items'] as List).length, 2);
      expect(detail['items'][0]['product_name'], 'Pepsi');
      expect(detail['items'][0]['line_total'], 22000);

      // And exactly one queued op with the right type.
      final q = await LocalDb.instance.queue();
      expect(q.length, 1);
      expect(q.first['op_type'], 'create_sale');
      expect(q.first['status'], 'pending');
      expect(q.first['payload']['tempSaleId'], sale.saleId);
    });

    test('slow_payment with deposit → partial, and stock is NOT deducted (server rule)', () async {
      final res = await api.createSale(
        businessId: _biz, branchId: 1, customerName: 'Asha',
        transactionType: 'slow_payment', amountPaid: 300,
        items: [
          {'product_id': 2, 'qty': 2, 'unit_price': 500,
           'unit_name': '', 'conversion_qty': 1, 'discount_total': 0},
        ],
      );
      final s = Sale.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      expect(s.totalAmount, 1000);
      expect(s.paidAmount, 300);
      expect(s.balanceAmount, 700);
      expect(s.isPartial, true);
      expect(s.isInstallment, true);
      // create_sale.php keeps stock for installment plans
      expect((await LocalDb.instance.getProduct(_biz, 2))!['qty'], 3);
    });

    test('loan ignores amount_paid exactly like create_sale.php', () async {
      final res = await api.createSale(
        businessId: _biz, branchId: 1, customerName: 'Asha',
        transactionType: 'loan', amountPaid: 300,
        items: [
          {'product_id': 2, 'qty': 2, 'unit_price': 500,
           'unit_name': '', 'conversion_qty': 1, 'discount_total': 0},
        ],
      );
      final s = Sale.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      expect(s.paidAmount, 0);
      expect(s.balanceAmount, 1000);
      expect(s.isUnpaid, true);
      expect(s.isLoan, true);
      expect((await LocalDb.instance.getProduct(_biz, 2))!['qty'], 1);
    });

    test('loan with no payment is unpaid, not paid', () async {
      final res = await api.createSale(
        businessId: _biz, branchId: 1, customerName: 'Asha',
        transactionType: 'loan',
        items: [
          {'product_id': 2, 'qty': 1, 'unit_price': 500,
           'unit_name': '', 'conversion_qty': 1, 'discount_total': 0},
        ],
      );
      final s = Sale.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      expect(s.paidAmount, 0);
      expect(s.isUnpaid, true);
    });

    test('void offline restores stock; record_payment updates balance', () async {
      final res = await api.createSale(
        businessId: _biz, branchId: 1, customerName: 'Asha',
        transactionType: 'loan',
        items: [
          {'product_id': 2, 'qty': 2, 'unit_price': 500,
           'unit_name': '', 'conversion_qty': 1, 'discount_total': 0},
        ],
      );
      final saleId = res['sale_id'] as int;
      expect((await LocalDb.instance.getProduct(_biz, 2))!['qty'], 1);

      await api.saleAction(saleId, 'record_payment', amount: 400, note: 'kwa mkono');
      var row = await LocalDb.instance.getSaleRow(saleId);
      expect(row!['sale']['paid_amount'], 400);
      expect(row['sale']['balance_amount'], 600);
      expect(row['sale']['payment_status'], 'partial');
      expect((row['payments'] as List).single['note'], 'kwa mkono');

      await api.saleAction(saleId, 'void_sale');
      row = await LocalDb.instance.getSaleRow(saleId);
      expect(row!['sale']['payment_status'], 'voided');
      expect((await LocalDb.instance.getProduct(_biz, 2))!['qty'], 3);

      final q = await LocalDb.instance.queue();
      expect(q.map((o) => o['op_type']),
          ['create_sale', 'sale_action', 'sale_action']);
      expect(q[1]['payload']['note'], 'kwa mkono');
    });
  });

  group('offline product management', () {
    test('add product gets a temp id and shows in list', () async {
      final res = await api.addProduct(
        businessId: _biz, branchId: 1, name: 'Sukari', category: 'Chakula',
        unit: 'Kg', buyPrice: 2500, sellPrice: 3000, stock: 10,
      );
      expect(res['success'], true);
      final id = res['product_id'] as int;
      expect(id, lessThan(0));
      final names = (await api.getProducts(_biz)).map((p) => p['name']);
      expect(names, contains('Sukari'));

      // Selling the offline product then works and references the temp id.
      await api.createSale(
        businessId: _biz, branchId: 1, customerName: 'x',
        transactionType: 'cash',
        items: [{'product_id': id, 'qty': 4, 'unit_price': 3000,
                 'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
      );
      expect((await LocalDb.instance.getProduct(_biz, id))!['qty'], 6);
    });

    test('server product list refresh keeps offline-created products', () async {
      final res = await api.addProduct(
        businessId: _biz, branchId: 1, name: 'Sukari', category: 'Chakula',
        unit: 'Kg', buyPrice: 2500, sellPrice: 3000, stock: 10,
      );
      await LocalDb.instance.replaceProducts(_biz, [
        {'product_id': 1, 'name': 'Pepsi', 'qty': 100},
      ]);
      final ids = (await LocalDb.instance.getProducts(_biz)).map((p) => p['product_id']);
      expect(ids, containsAll([1, res['product_id']]));
      expect(ids, isNot(contains(2))); // removed on server → removed locally
    });

    test('temp id remap rewrites the product row', () async {
      final res = await api.addProduct(
        businessId: _biz, branchId: 1, name: 'Sukari', category: 'Chakula',
        unit: 'Kg', buyPrice: 2500, sellPrice: 3000, stock: 10,
      );
      final temp = res['product_id'] as int;
      await LocalDb.instance.remapProductId(_biz, temp, 55);
      expect(await LocalDb.instance.getProduct(_biz, temp), isNull);
      expect((await LocalDb.instance.getProduct(_biz, 55))!['name'], 'Sukari');
    });

    test('add batch bumps stock and is queued', () async {
      await api.addProductBatch(productId: 2, businessId: _biz, quantity: 20, buyPrice: 280);
      expect((await LocalDb.instance.getProduct(_biz, 2))!['qty'], 23);
      final b = await api.getProductBatches(2, _biz);
      expect(b.length, 1);
      expect(b.first['sync_status'], 'pending');
    });

    test('categories edited offline are visible immediately', () async {
      await LocalDb.instance.putCache('categories:$_biz', [{'id': 1, 'name': 'Vinywaji'}]);
      await api.manageCategory(_biz, 'add', name: 'Chakula');
      final cats = await api.getCategories(_biz);
      expect(cats.map((c) => c['name']), ['Vinywaji', 'Chakula']);
    });
  });

  group('dashboard overlay', () {
    test('pending sales are added onto the cached snapshot', () async {
      await LocalDb.instance.putCache('dashboard:$_biz:0', {
        'success': true,
        'data': {'today_revenue': 5000, 'today_sales_count': 2, 'total_revenue': 90000,
                 'unpaid_loans_amount': 0, 'unpaid_loans_count': 0, 'weekly_sales': []},
      });
      await api.createSale(
        businessId: _biz, branchId: 1, customerName: 'x', transactionType: 'loan',
        items: [{'product_id': 2, 'qty': 2, 'unit_price': 500,
                 'unit_name': '', 'conversion_qty': 1, 'discount_total': 0}],
      );
      final d = (await api.getDashboard(_biz))['data'] as Map<String, dynamic>;
      expect(d['today_revenue'], 6000);
      expect(d['today_sales_count'], 3);
      expect(d['total_revenue'], 91000);
      expect(d['unpaid_loans_count'], 1);
      expect(d['unpaid_loans_amount'], 1000);
      expect(d['out_of_stock_count'], 0);
      expect(d['low_stock_count'], 1); // Maji 3-2 = 1 ≤ min 5
      expect((d['weekly_sales'] as List).length, 7);
      expect(d['pending_sync_count'], 1);
    });
  });

  group('offline login', () {
    test('rejects when never logged in online', () async {
      final r = await api.login('samweli', 'pass');
      expect(r['success'], false);
    });
  });
}
