import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'services/storage_service.dart';
import 'services/local_db.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/business_select_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/superadmin_screen.dart';
import 'widgets/brand_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  // Offline-first: local SQLite cache + connectivity watcher.
  // Never let a storage problem stop the app – fall back to online-only.
  try {
    await LocalDb.instance.init();
  } catch (e) {
    debugPrint('LocalDb init failed (online-only mode): $e');
  }
  try {
    await ConnectivityService.instance.init();
  } catch (e) {
    debugPrint('Connectivity init failed: $e');
  }
  // Load theme preference before first frame so correct palette is active
  final tp = ThemeProvider();
  await tp.load();
  runApp(DonelPOSApp(themeProvider: tp));
}

class DonelPOSApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const DonelPOSApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider.value(value: ConnectivityService.instance),
        ChangeNotifierProvider.value(value: SyncService.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (ctx, theme, _) => MaterialApp(
          title: 'Duka Kiganjani',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.themeMode,
          builder: (context, child) => ScrollConfiguration(
            behavior: const PremiumScrollBehavior(),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const _SplashScreen(),
        ),
      ),
    );
  }
}

// ── Splash / Boot Screen ─────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _boot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final app = context.read<AppProvider>();
    await app.loadSavedUser();
    if (!mounted) return;

    Widget nextPage;
    if (!app.isLoggedIn) {
      nextPage = const LoginScreen();
    } else if (app.isSuperAdmin) {
      nextPage = const SuperAdminScreen();
    } else if (app.isReady) {
      nextPage = const DashboardScreen();
    } else {
      // Logged in but no business selected yet
      nextPage = const BusinessSelectScreen();
    }

    final onboardingDone =
        StorageService.getBool('onboarding_done_v1') ?? false;
    final targetPage = onboardingDone
        ? nextPage
        : OnboardingScreen(nextPage: nextPage);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => targetPage,
        transitionsBuilder: (ctx, anim, sa, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06130F), Color(0xFF0B2A24), Color(0xFF0E3B2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: const BrandLogo(size: 138, radius: 32),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Duka Kiganjani',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage mauzi yako mkononi',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 44),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
