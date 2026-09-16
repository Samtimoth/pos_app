// Visual check of the phone POS layout. Renders PosScreen(desktop:false) at a
// phone size with products served from the offline cache and writes PNGs to
// build/screenshots/. Run:  flutter test test/screenshot
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:donel_pos/models/business.dart';
import 'package:donel_pos/models/user.dart';
import 'package:donel_pos/providers/app_provider.dart';
import 'package:donel_pos/providers/cart_provider.dart';
import 'package:donel_pos/providers/held_sales_provider.dart';
import 'package:donel_pos/providers/theme_provider.dart';
import 'package:donel_pos/screens/dashboard_screen.dart';
import 'package:donel_pos/screens/pos_screen.dart';
import 'package:donel_pos/screens/reports_screen.dart';
import 'package:donel_pos/services/connectivity_service.dart';
import 'package:donel_pos/services/local_db.dart';
import 'package:donel_pos/services/storage_service.dart';
import 'package:donel_pos/services/sync_service.dart';
import 'package:donel_pos/theme/app_theme.dart';

const _biz = 7;

Future<void> _loadFonts() async {
  final dir = Directory(r'C:\flutter\bin\cache\artifacts\material_fonts');
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    final file = File('${dir.path}\\$f');
    if (file.existsSync()) {
      roboto.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    }
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(
        File('${dir.path}\\materialicons-regular.otf').readAsBytesSync().buffer.asByteData()));
  await icons.load();
}

Future<void> _snap(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/screenshots/$name.png')..createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<(AppProvider, CartProvider)> _setup({Set<int> showTutorialFor = const {}}) async {
  await _loadFonts();
  SharedPreferences.setMockInitialValues({
    for (var i = 0; i < 6; i++)
      if (!showTutorialFor.contains(i)) 'tutorial_seen_dashboard_nav_$i': true,
    'tutorial_seen_reports': true,
  });
  await StorageService.init();
  await LocalDb.instance.init(path: inMemoryDatabasePath);
  await LocalDb.instance.clearAll();
  final names = [
    'Pepsi 500ml', 'Coca Cola 500ml', 'Maji Kilimanjaro 1L', 'Sukari 1kg',
    'Unga wa Ngano 2kg', 'Mafuta ya Kupikia 1L', 'Sabuni ya Unga', 'Mchele 5kg',
    'Maziwa Tanga Fresh', 'Mkate', 'Chumvi', 'Biskuti Nice',
  ];
  final cats = ['Vinywaji', 'Vinywaji', 'Vinywaji', 'Chakula', 'Chakula',
    'Chakula', 'Usafi', 'Chakula', 'Vinywaji', 'Chakula', 'Chakula', 'Chakula'];
  await LocalDb.instance.replaceProducts(_biz, [
    for (var i = 0; i < names.length; i++)
      {
        'product_id': i + 1, 'name': names[i], 'category': cats[i],
        'sellPrice': 500 + i * 700, 'buyPrice': 300, 'qty': i == 3 ? 0 : 12 + i,
        'min_stock': 5, 'unit': i < 3 ? 'Chupa' : 'Kipande', 'image': '',
        'barcode': '60000$i', 'units': [],
      },
  ]);
  await LocalDb.instance.putCache('categories:$_biz', [
    {'id': 1, 'name': 'Vinywaji'}, {'id': 2, 'name': 'Chakula'}, {'id': 3, 'name': 'Usafi'},
  ]);
  // a few sales so the dashboard/sales tab have content
  await LocalDb.instance.replaceSyncedSales(_biz, [
    for (var i = 0; i < 6; i++)
      {
        'sale_id': 100 + i, 'sale_no': 'SL-2026091$i-00$i', 'branch_id': 1,
        'customer_name': ['Walk-in Customer', 'Asha', 'Juma', 'Neema', 'Walk-in Customer', 'Baraka'][i],
        'customer_phone': '', 'subtotal_amount': 4500 + i * 1300, 'discount_amount': 0,
        'total_amount': 4500 + i * 1300, 'paid_amount': i == 1 ? 0 : 4500 + i * 1300,
        'balance_amount': i == 1 ? 5800 : 0, 'sale_type': i == 1 ? 'loan' : 'cash',
        'payment_status': i == 1 ? 'unpaid' : 'paid', 'payment_method': 'cash', 'notes': '',
        'created_at': '2026-09-14 1$i:20:00', 'item_count': 2 + i,
      },
  ]);
  await LocalDb.instance.putCache('dashboard:$_biz:1', {
    'success': true,
    'data': {
      'today_revenue': 48200, 'today_sales_count': 6, 'total_revenue': 1250000,
      'revenue_change_pct': 12.5, 'unpaid_loans_amount': 5800, 'unpaid_loans_count': 1,
      'total_products': 12, 'low_stock_count': 1, 'out_of_stock_count': 1,
      'total_staff': 2, 'active_devices_count': 1,
      'weekly_sales': [
        for (var i = 0; i < 7; i++)
          {'date': '2026-09-0${8 + i}'.substring(0, 10), 'day_label': ['Jtt','Jnn','Jtn','Alh','Iju','Jms','Jpl'][i], 'total': 20000.0 + i * 7000},
      ],
    },
  });

  final now = DateTime.now();
  final from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  final to = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  await LocalDb.instance.putCache('report:$_biz:1:$from:$to', {
    'success': true,
    'range': {'from': from, 'to': to},
    'sales': {
      'count': 42, 'revenue': 1250000, 'collected': 1100000, 'outstanding': 150000,
      'discounts': 12000, 'voided_count': 2, 'voided_amount': 18000, 'units_sold': 310,
      'by_day': [for (var i = 1; i <= 14; i++) {'date': from.substring(0, 8) + i.toString().padLeft(2, '0'), 'count': 3, 'revenue': 60000 + i * 9000, 'collected': 55000 + i * 8000}],
      'by_status': [{'status': 'paid', 'count': 36, 'amount': 1100000}, {'status': 'unpaid', 'count': 4, 'amount': 150000}],
      'by_type': [{'type': 'cash', 'count': 30, 'amount': 900000}, {'type': 'loan', 'count': 8, 'amount': 250000}, {'type': 'bank_transfer', 'count': 4, 'amount': 100000}],
      'by_category': [{'category': 'Vinywaji', 'revenue': 700000}, {'category': 'Chakula', 'revenue': 450000}, {'category': 'Usafi', 'revenue': 100000}],
      'top_products': [
        {'name': 'Pepsi 500ml', 'category': 'Vinywaji', 'qty': 120, 'revenue': 120000, 'cost': 84000, 'profit': 36000},
        {'name': 'Mchele 5kg', 'category': 'Chakula', 'qty': 20, 'revenue': 108000, 'cost': 90000, 'profit': 18000},
        {'name': 'Maji Kilimanjaro 1L', 'category': 'Vinywaji', 'qty': 90, 'revenue': 90000, 'cost': 63000, 'profit': 27000},
      ],
    },
    'expenses': {
      'total': 265000,
      'by_category': [{'category': 'Kodi ya duka', 'amount': 150000, 'count': 1}, {'category': 'Umeme', 'amount': 65000, 'count': 2}, {'category': 'Usafiri', 'amount': 50000, 'count': 5}],
      'by_day': [],
      'items': [
        {'expense_id': 1, 'category': 'Kodi ya duka', 'description': 'Septemba', 'amount': 150000, 'expense_date': from},
        {'expense_id': 2, 'category': 'Umeme', 'description': 'LUKU', 'amount': 40000, 'expense_date': to},
        {'expense_id': 3, 'category': 'Usafiri', 'description': 'Bodaboda mzigo', 'amount': 10000, 'expense_date': to},
      ],
    },
    'pnl': {
      'revenue': 1250000, 'cogs': 870000, 'gross_profit': 380000, 'gross_margin_pct': 30.4,
      'expenses': 265000, 'net_profit': 115000, 'net_margin_pct': 9.2,
      'monthly': [for (var i = 1; i <= 9; i++) {'month': '2026-0$i', 'revenue': 800000 + i * 50000, 'cogs': 560000 + i * 35000, 'expenses': 200000 + i * 5000, 'gross_profit': 240000 + i * 15000, 'net_profit': 40000 + i * 10000}],
    },
  });
  final app = AppProvider();
  await app.setUser(const User(
    userId: 1, username: 'demo', fullname: 'Demo Owner', globalRole: 'User',
    role: 'Owner', serverUrl: 'http://127.0.0.1:9/pos/api',
  ));
  await app.selectBusinessAndBranch(
    const Business(
      businessId: _biz, businessName: 'Duka la Demo', tradeName: 'Demo',
      role: 'Owner', country: 'TZ', currency: 'TZS', phone: '', timezone: '',
      address: '', logoPath: '', shopCode: '', isActive: true, branchCount: 1,
      branches: [Branch(branchId: 1, branchName: 'Main', branchCode: 'M', phone: '', address: '', isActive: true)],
    ),
    const Branch(branchId: 1, branchName: 'Main', branchCode: 'M', phone: '', address: '', isActive: true),
  );
  return (app, CartProvider());
}

Widget _wrap(AppProvider app, CartProvider cart, GlobalKey key, Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: ThemeProvider()),
    ChangeNotifierProvider.value(value: app),
    ChangeNotifierProvider.value(value: cart),
    ChangeNotifierProvider(create: (_) => HeldSalesProvider()),
    ChangeNotifierProvider.value(value: ConnectivityService.instance),
    ChangeNotifierProvider.value(value: SyncService.instance),
  ],
  child: RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: child,
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.text('Endelea').last);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _finish(WidgetTester tester) async {
  SyncService.instance.stopBackgroundTimers();
  ConnectivityService.instance.stopBackgroundTimers();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  testWidgets('phone POS layout', (tester) async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({
      for (var i = 0; i < 6; i++) 'tutorial_seen_dashboard_nav_$i': true,
      'tutorial_seen_pos': true,
    });
    await StorageService.init();
    await LocalDb.instance.init(path: inMemoryDatabasePath);
    await LocalDb.instance.clearAll();
    final names = [
      'Pepsi 500ml', 'Coca Cola 500ml', 'Maji Kilimanjaro 1L', 'Sukari 1kg',
      'Unga wa Ngano 2kg', 'Mafuta ya Kupikia 1L', 'Sabuni ya Unga', 'Mchele 5kg',
      'Maziwa Tanga Fresh', 'Mkate', 'Chumvi', 'Biskuti Nice',
    ];
    final cats = ['Vinywaji', 'Vinywaji', 'Vinywaji', 'Chakula', 'Chakula',
      'Chakula', 'Usafi', 'Chakula', 'Vinywaji', 'Chakula', 'Chakula', 'Chakula'];
    await LocalDb.instance.replaceProducts(_biz, [
      for (var i = 0; i < names.length; i++)
        {
          'product_id': i + 1, 'name': names[i], 'category': cats[i],
          'sellPrice': 500 + i * 700, 'buyPrice': 300, 'qty': i == 3 ? 0 : 12 + i,
          'min_stock': 5, 'unit': i < 3 ? 'Chupa' : 'Kipande', 'image': '',
          'barcode': '60000$i', 'units': [],
        },
    ]);
    await LocalDb.instance.putCache('categories:$_biz', [
      {'id': 1, 'name': 'Vinywaji'}, {'id': 2, 'name': 'Chakula'}, {'id': 3, 'name': 'Usafi'},
    ]);

    final app = AppProvider();
    await app.setUser(const User(
      userId: 1, username: 'demo', fullname: 'Demo', globalRole: 'User',
      role: 'Owner', serverUrl: 'http://127.0.0.1:9/pos/api',
    ));
    await app.selectBusinessAndBranch(
      const Business(
        businessId: _biz, businessName: 'Duka la Demo', tradeName: 'Demo',
        role: 'Owner', country: 'TZ', currency: 'TZS', phone: '', timezone: '',
        address: '', logoPath: '', shopCode: '', isActive: true, branchCount: 1,
        branches: [Branch(branchId: 1, branchName: 'Main', branchCode: 'M', phone: '', address: '', isActive: true)],
      ),
      const Branch(branchId: 1, branchName: 'Main', branchCode: 'M', phone: '', address: '', isActive: true),
    );

    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final cart = CartProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ThemeProvider()),
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider(create: (_) => HeldSalesProvider()),
          ChangeNotifierProvider.value(value: ConnectivityService.instance),
          ChangeNotifierProvider.value(value: SyncService.instance),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: RepaintBoundary(
            key: key,
            child: const Scaffold(body: PosScreen(desktop: false)),
          ),
        ),
      ),
    );
    // let the offline load + entrance animations finish
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Pepsi 500ml'), findsOneWidget);
    await _snap(tester, key, 'pos_mobile_1_grid');

    // add two items → FAB + hero summary
    await tester.tap(find.text('Pepsi 500ml'));
    await tester.tap(find.text('Coca Cola 500ml'));
    await tester.pump(const Duration(milliseconds: 400));
    await _snap(tester, key, 'pos_mobile_2_cart');

    // scroll: hero goes away, search stays pinned
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 500));
    await _snap(tester, key, 'pos_mobile_3_scrolled');

    // invariants run before tearDown → stop singleton timers here
    SyncService.instance.stopBackgroundTimers();
    ConnectivityService.instance.stopBackgroundTimers();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('phone dashboard + sales tab', (tester) async {
    final (app, cart) = await _setup();
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(_wrap(app, cart, key, const DashboardScreen()));
    await _settle(tester);
    await _snap(tester, key, 'dash_mobile_1_home');

    // Sales tab (index 2 in the bottom nav)
    final salesTab = find.byIcon(Icons.receipt_long_outlined);
    if (salesTab.evaluate().isNotEmpty) {
      await tester.tap(salesTab.first);
      await _settle(tester);
      await _snap(tester, key, 'dash_mobile_2_sales');
    }
    await _finish(tester);
  });

  testWidgets('coach-mark tutorial on dashboard and POS', (tester) async {
    final (app, cart) = await _setup(showTutorialFor: {0, 1});
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(_wrap(app, cart, key, const DashboardScreen()));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Profile na biashara'), findsOneWidget);
    await _snap(tester, key, 'tut_1_dash_avatar');

    await _next(tester);
    await _snap(tester, key, 'tut_2_dash_eye');
    await _next(tester);
    await _next(tester);
    await _snap(tester, key, 'tut_3_dash_nav');
    await tester.tap(find.text('Maliza').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // POS tab → its own coach marks (search field first)
    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Tafuta bidhaa'), findsWidgets);
    await _snap(tester, key, 'tut_4_pos_search');
    await _next(tester);
    await _next(tester);
    await _snap(tester, key, 'tut_5_pos_categories');
    await tester.tap(find.text('Ruka').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await _finish(tester);
  });

  testWidgets('products, manage and cart sheet', (tester) async {
    final (app, cart) = await _setup();
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(_wrap(app, cart, key, const DashboardScreen()));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await _settle(tester);
    await _snap(tester, key, 'p1_products');

    await tester.tap(find.byIcon(Icons.tune_outlined).first);
    await _settle(tester);
    await _snap(tester, key, 'p2_manage');

    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
    await _settle(tester);
    await tester.tap(find.text('Pepsi 500ml'));
    await tester.tap(find.text('Mkate'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(FloatingActionButton).first);
    await _settle(tester);
    await _snap(tester, key, 'p3_cart_sheet');
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 500));
    await _snap(tester, key, 'p4_cart_sheet_scrolled');
    await _finish(tester);
  });

  testWidgets('reports and sales filters', (tester) async {
    final (app, cart) = await _setup();
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(_wrap(app, cart, key, const ReportsScreen()));
    await _settle(tester);
    await _snap(tester, key, 'r1_pnl');
    await tester.tap(find.text('Mauzo').first);
    await _settle(tester);
    await _snap(tester, key, 'r2_sales');
    await tester.tap(find.text('Matumizi').first);
    await _settle(tester);
    await _snap(tester, key, 'r3_expenses');

    await tester.pumpWidget(_wrap(app, cart, key, const DashboardScreen()));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.receipt_long_outlined).first);
    await _settle(tester);
    await _snap(tester, key, 'r4_sales_screen');
    await _finish(tester);
  });

  testWidgets('desktop: dashboard, pos, reports', (tester) async {
    final (app, cart) = await _setup();
    tester.view.physicalSize = const Size(1366 * 2, 768 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(_wrap(app, cart, key, const DashboardScreen()));
    await _settle(tester);
    await _snap(tester, key, 'd1_dashboard');
    await tester.tap(find.byIcon(Icons.point_of_sale_outlined).first);
    await _settle(tester);
    await _snap(tester, key, 'd2_pos');
    await tester.tap(find.text('Ripoti').first);
    await _settle(tester);
    await _snap(tester, key, 'd3_reports');
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await _settle(tester);
    await _snap(tester, key, 'd4_products');
    await _finish(tester);
  });
}
