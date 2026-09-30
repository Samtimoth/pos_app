// Regression: Simamia (Manage) mobile — header mpya (gradient + captions +
// chip selector) na staff empty-state mpya, kwa kutumia deep-link
// initialTabKey: 'staff'. Pia inathibitisha hakuna RenderFlex overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:donel_pos/models/business.dart';
import 'package:donel_pos/models/user.dart';
import 'package:donel_pos/providers/app_provider.dart';
import 'package:donel_pos/providers/cart_provider.dart';
import 'package:donel_pos/providers/held_sales_provider.dart';
import 'package:donel_pos/providers/shift_provider.dart';
import 'package:donel_pos/providers/theme_provider.dart';
import 'package:donel_pos/screens/manage_screen.dart';
import 'package:donel_pos/services/connectivity_service.dart';
import 'package:donel_pos/services/local_db.dart';
import 'package:donel_pos/services/storage_service.dart';
import 'package:donel_pos/services/sync_service.dart';
import 'package:donel_pos/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  testWidgets('Simamia mobile: header mpya + staff empty state', (tester) async {
    SharedPreferences.setMockInitialValues({
      for (var i = 0; i < 6; i++) 'tutorial_seen_dashboard_nav_$i': true,
      'tutorial_seen_reports': true,
    });
    await StorageService.init();
    await LocalDb.instance.init(path: inMemoryDatabasePath);
    await LocalDb.instance.clearAll();

    final app = AppProvider();
    await app.setUser(const User(
      userId: 1,
      username: 'demo',
      fullname: 'Demo Owner',
      globalRole: 'User',
      role: 'Owner',
      serverUrl: 'http://127.0.0.1:9/pos/api',
    ));
    await app.selectBusinessAndBranch(
      const Business(
        businessId: 7,
        businessName: 'Duka la Demo',
        tradeName: 'Demo',
        role: 'Owner',
        country: 'TZ',
        currency: 'TZS',
        phone: '',
        timezone: '',
        address: '',
        logoPath: '',
        shopCode: '',
        isActive: true,
        branchCount: 1,
        branches: [
          Branch(
            branchId: 1,
            branchName: 'Main',
            branchCode: 'M',
            phone: '',
            address: '',
            isActive: true,
          ),
        ],
      ),
      const Branch(
        branchId: 1,
        branchName: 'Main',
        branchCode: 'M',
        phone: '',
        address: '',
        isActive: true,
      ),
    );

    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ThemeProvider()),
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => HeldSalesProvider()),
          ChangeNotifierProvider(create: (_) => ShiftProvider()),
          ChangeNotifierProvider.value(value: ConnectivityService.instance),
          ChangeNotifierProvider.value(value: SyncService.instance),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const ManageScreen(desktop: false, initialTabKey: 'staff'),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    // ── Header mpya ──
    expect(find.text('Simamia'), findsOneWidget);
    expect(find.text('Dhibiti biashara yako'), findsOneWidget);
    expect(
      find.text('Bidhaa, manunuzi, wasambazaji, wafanyakazi na zaidi'),
      findsOneWidget,
    );

    // ── Staff empty-state card ──
    expect(find.text('Hakuna wafanyakazi bado'), findsOneWidget);
    expect(
      find.text(
        'Ongeza wafanyakazi na uwapangie majukumu kwenye biashara yako.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ongeza Mfanyakazi'), findsOneWidget); // kitufe cha kadi

    // ── Quick actions (zisizo na functionality zimeachwa non-interactive) ──
    expect(find.text('Mambo unayoweza kufanya'), findsOneWidget);
    expect(find.text('Ongeza mfanyakazi'), findsOneWidget);
    expect(find.text('Pangia majukumu'), findsOneWidget);
    expect(find.text('Fuatilia shughuli'), findsOneWidget);

    SyncService.instance.stopBackgroundTimers();
    ConnectivityService.instance.stopBackgroundTimers();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
