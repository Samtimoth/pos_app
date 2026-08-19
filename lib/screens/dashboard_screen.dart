import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/user.dart';
import '../models/business.dart';
import '../models/sale.dart';
import '../providers/app_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';
import '../widgets/brand_logo.dart';
import '../widgets/first_run_tutorial.dart';
import 'login_screen.dart';
import 'business_select_screen.dart';
import 'pos_screen.dart';
import 'sales_screen.dart';
import 'products_screen.dart';
import 'manage_screen.dart';
import 'payment_screen.dart';

const double _kDesktop = 900;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _nav = 0;
  int _manageInitialTab = 0;
  Map<String, dynamic> _stats = {};
  List<dynamic> _salesChart = [];
  List<Sale> _recentSales = [];
  bool _loading = true;
  String? _error;
  final _numFmt = NumberFormat('#,###', 'en_US');
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late DateTime _now;
  Timer? _clockTimer;
  bool _balanceVisible = true;
  final int _productsRefreshKey = 0;
  int? _lastTutorialNav;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        app.api!.getDashboard(
          app.selectedBusiness!.businessId,
          branchId: app.selectedBranch?.branchId,
        ),
        app.api!.getSales(
          app.selectedBusiness!.businessId,
          branchId: app.selectedBranch?.branchId,
        ),
      ]);
      if (!mounted) return;
      final dashRes = results[0] as Map<String, dynamic>;
      final salesRes = results[1] as List<dynamic>;
      if (dashRes['success'] == true) {
        final data = dashRes['data'] as Map<String, dynamic>? ?? dashRes;
        setState(() {
          _stats = data;
          _salesChart = (data['weekly_sales'] as List?) ?? [];
          _recentSales = salesRes
              .take(5)
              .map((e) => Sale.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _animCtrl.forward(from: 0);
      } else {
        setState(() => _error = dashRes['message']?.toString() ?? 'Hitilafu');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final l = L.of(context);
    final app = context.read<AppProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _FintechDialog(
        icon: Icons.logout_rounded,
        iconColor: Colors.redAccent,
        title: l.logout,
        body: l.logoutConfirm,
        confirmLabel: l.yes,
        cancelLabel: l.no,
        confirmColor: Colors.redAccent,
      ),
    );
    if (ok == true && mounted) {
      await app.logout();
      if (!mounted) return;
      context.read<CartProvider>().clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _queueTutorialForNav();
    final w = MediaQuery.of(context).size.width;
    return w >= _kDesktop ? _buildDesktop() : _buildMobile();
  }

  void _queueTutorialForNav() {
    if (_lastTutorialNav == _nav) return;
    _lastTutorialNav = _nav;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstRunTutorial.showIfNeeded(
        context,
        storageKey: 'dashboard_nav_$_nav',
        steps: _tutorialStepsForNav(_nav),
      );
    });
  }

  List<TutorialStep> _tutorialStepsForNav(int nav) {
    final l = L.of(context);
    switch (nav) {
      case 1:
        return [
          TutorialStep(
            icon: Icons.point_of_sale_rounded,
            title: l.pos.split('—').first.trim(),
            body:
                'Tafuta bidhaa, ongeza kwenye kikapu, badili idadi na kamilisha malipo kwa haraka.',
          ),
          const TutorialStep(
            icon: Icons.shopping_cart_checkout_rounded,
            title: 'Kikapu cha mauzo',
            body:
                'Kagua jumla, punguzo na bidhaa kabla ya kutuma mauzo kwenda kwenye server.',
          ),
        ];
      case 2:
        return [
          TutorialStep(
            icon: Icons.receipt_long_rounded,
            title: l.sales,
            body:
                'Hapa unaona historia ya mauzo, risiti na taarifa za kila transaction.',
          ),
          const TutorialStep(
            icon: Icons.refresh_rounded,
            title: 'Refresh taarifa',
            body:
                'Vuta chini au tumia refresh kupata mauzo mapya kutoka kwenye server.',
          ),
        ];
      case 3:
        return [
          TutorialStep(
            icon: Icons.inventory_2_rounded,
            title: l.products,
            body:
                'Simamia bidhaa, bei, stock, batch na barcode kwa kila tawi la biashara.',
          ),
          const TutorialStep(
            icon: Icons.add_box_rounded,
            title: 'Ongeza stock',
            body:
                'Tumia vitufe vya kuongeza bidhaa au batch ili stock yako ibaki sahihi.',
          ),
        ];
      case 4:
        return [
          TutorialStep(
            icon: Icons.tune_rounded,
            title: l.manage,
            body:
                'Hapa unasimamia wafanyakazi, settings, matawi na taarifa za biashara.',
          ),
          const TutorialStep(
            icon: Icons.group_rounded,
            title: 'Ruhusa za wafanyakazi',
            body:
                'Angalia roles za wafanyakazi ili kila mtu afanye kazi zinazomfaa.',
          ),
        ];
      default:
        return [
          TutorialStep(
            icon: Icons.dashboard_rounded,
            title: l.dashboard,
            body:
                'Dashboard inaonyesha mauzo ya leo, madeni, bidhaa zilizoisha na mwenendo wa biashara.',
          ),
          const TutorialStep(
            icon: Icons.touch_app_rounded,
            title: 'Vitufe vya haraka',
            body:
                'Tumia shortcuts kwenda POS, sales, products au manage bila kupoteza muda.',
          ),
          const TutorialStep(
            icon: Icons.visibility_rounded,
            title: 'Ficha au onyesha salio',
            body:
                'Unaweza kuficha namba kubwa ukiwa mbele ya mteja, kisha kuzionyesha tena unapohitaji.',
          ),
        ];
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    final app = context.watch<AppProvider>();
    if (app.user == null) {
      return const SizedBox.shrink(); // logging out — navigating away
    }
    final user = app.user!;
    final biz = app.selectedBusiness;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          _buildSidebar(user, biz, app),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(user, biz, app),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.015, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_nav),
                      child: _pageContent(desktop: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop Sidebar ───────────────────────────────────────────────
  Widget _buildSidebar(User user, Business? biz, AppProvider app) {
    final l = L.of(context);
    return Container(
      width: 255,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF0D1F35)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(
              children: [
                const BrandLogo(size: 46, radius: 14, showShadow: false),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duka Kiganjani',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'Mauzo mkononi',
                      style: TextStyle(
                        color: AppColors.textGreen,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Business chip
          if (biz != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha(60),
                    AppColors.primaryMid.withAlpha(40),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryLt.withAlpha(40)),
              ),
              child: Row(
                children: [
                  _bizAvatar(biz),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          biz.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          app.selectedBranch?.branchName ?? l.mainBranch,
                          style: TextStyle(
                            color: AppColors.textGreen,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MENU',
                style: TextStyle(
                  color: AppColors.textMuted.withAlpha(160),
                  fontSize: 9,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Nav items
          _sidebarItem(
            0,
            Icons.dashboard_outlined,
            Icons.dashboard_rounded,
            l.dashboard,
          ),
          _sidebarItem(
            1,
            Icons.point_of_sale_outlined,
            Icons.point_of_sale_rounded,
            l.pos,
          ),
          _sidebarItem(
            2,
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            l.sales,
          ),
          _sidebarItem(
            3,
            Icons.inventory_2_outlined,
            Icons.inventory_2_rounded,
            l.products,
          ),
          _sidebarItem(4, Icons.tune_outlined, Icons.tune_rounded, l.manage),

          const Spacer(),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 4),

          _sidebarAction(
            Icons.language_rounded,
            l.language,
            AppColors.chartBlue,
            () => app.toggleLanguage(),
          ),
          _sidebarAction(
            Icons.swap_horiz_rounded,
            l.switchBiz,
            AppColors.chartOrange,
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const BusinessSelectScreen(autoSelectIfSingle: false),
              ),
            ),
          ),
          _sidebarAction(
            Icons.logout_rounded,
            l.logout,
            Colors.redAccent,
            _logout,
          ),

          const SizedBox(height: 4),
          Container(height: 1, color: AppColors.border),

          // User
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withAlpha(80),
                  child: Text(
                    user.fullname.isNotEmpty
                        ? user.fullname[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.accentBright,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        biz?.role ?? user.role,
                        style: TextStyle(
                          color: AppColors.textGreen,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Language badge
                GestureDetector(
                  onTap: app.toggleLanguage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withAlpha(60)),
                    ),
                    child: Text(
                      app.isSw ? 'SW' : 'EN',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bizAvatar(Business biz) {
    const grads = [
      AppColors.gradPrimary,
      AppColors.gradLime,
      AppColors.gradPurple,
    ];
    final grad = grads[biz.businessId % grads.length];
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: grad),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          biz.businessName.isNotEmpty ? biz.businessName[0].toUpperCase() : 'B',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, IconData iconA, String label) {
    final active = _nav == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _nav = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryMid.withAlpha(50)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: AppColors.primaryLt.withAlpha(60))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                active ? iconA : icon,
                color: active ? AppColors.primaryLt : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.primaryLt : AppColors.textMuted,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (active) ...[
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accentBright,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Desktop Top Bar ───────────────────────────────────────────────
  Widget _buildDesktopTopBar(User user, Business? biz, AppProvider app) {
    final l = L.of(context);
    final titles = [l.dashboard, l.pos, l.sales, l.products, l.manage];
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            titles[_nav],
            style: TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
          Text(
            biz?.businessName ?? '',
            style: TextStyle(color: AppColors.textGreen, fontSize: 13),
          ),

          const Spacer(),

          // Cart badge
          if (_nav == 1)
            Consumer<CartProvider>(
              builder: (ctx, cart, ch) => cart.count > 0
                  ? Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withAlpha(70),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_cart_rounded,
                              color: AppColors.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${cart.count} ${l.items}  •  TZS ${_numFmt.format(cart.total)}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

          // Lang toggle
          GestureDetector(
            onTap: app.toggleLanguage,
            child: Tooltip(
              message: l.language,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      color: AppColors.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      app.isSw ? 'SW' : 'EN',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Theme toggle
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ThemeToggleButton(onWhiteBackground: true),
          ),

          // Date
          Text(
            _fmtDate(DateTime.now()),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(width: 16),

          // Avatar
          Tooltip(
            message: '${user.fullname}\n${biz?.role ?? user.role}',
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withAlpha(80),
              child: Text(
                user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: AppColors.accentBright,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT — Fintech Style (like the image)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final app = context.watch<AppProvider>();
    if (app.user == null) {
      return const SizedBox.shrink(); // logging out — navigating away
    }
    final user = app.user!;
    final biz = app.selectedBusiness;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey('mobile_$_nav-$_productsRefreshKey'),
          child: _nav == 0
              ? _buildMobileDashFull(user, biz, app)
              : _pageContent(desktop: false),
        ),
      ),
      bottomNavigationBar: _buildFintechBottomNav(app),
    );
  }

  // ── Fintech-style bottom nav (center button elevated) ────────────
  Widget _buildFintechBottomNav(AppProvider app) {
    final l = L.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.bgCard.withAlpha(248),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.border.withAlpha(180),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // Dashboard
              _navItem(
                0,
                Icons.dashboard_outlined,
                Icons.dashboard_rounded,
                l.dashboard,
              ),
              // Manage (center button handles POS, so this slot shows Manage)
              _navItem(4, Icons.tune_outlined, Icons.tune_rounded, l.manage),
              // Center: POS shortcut (prominent)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _nav = 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.gradLime,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withAlpha(100),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_shopping_cart_rounded,
                          color: AppColors.bgDark,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Mauzo
              _navItem(
                2,
                Icons.receipt_long_outlined,
                Icons.receipt_long_rounded,
                l.sales,
              ),
              // Bidhaa
              _navItem(
                3,
                Icons.inventory_2_outlined,
                Icons.inventory_2_rounded,
                l.products,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData iconActive, String label) {
    final active = _nav == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _nav = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? iconActive : icon,
                color: active ? AppColors.primaryLt : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.primaryLt : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Full mobile dashboard (fintech-style) ─────────────────────────
  Widget _buildMobileDashFull(User user, Business? biz, AppProvider app) {
    final l = L.of(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Sticky green header ──────────────────────────────────────
        SliverToBoxAdapter(child: _buildFintechHeader(user, biz, app, l)),

        // ── Subscription banner ─────────────────────────────────────
        SliverToBoxAdapter(child: _buildSubscriptionBanner(biz)),

        // ── Quick actions ──────────────────────────────────────────
        SliverToBoxAdapter(child: _buildMobileQuickActions(l)),

        // ── KPI Cards ─────────────────────────────────────────────
        SliverToBoxAdapter(child: _buildMobileKpiRow(l)),

        // ── Chart ─────────────────────────────────────────────────
        SliverToBoxAdapter(child: _buildMobileChart(l)),

        // ── Recent Sales ──────────────────────────────────────────
        SliverToBoxAdapter(child: _buildRecentSalesSection(l)),

        // Bottom padding for nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Fintech Header (dark green, like the image) ────────────────
  Widget _buildFintechHeader(User user, Business? biz, AppProvider app, L l) {
    final revenue = (_stats['today_revenue'] ?? 0.0).toDouble();
    final count = (_stats['today_sales_count'] ?? 0) as int;
    final change = (_stats['revenue_change_pct'] ?? 0.0).toDouble();
    final up = change >= 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              // ── Top row: greeting + icons ──────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BusinessSelectScreen(
                          autoSelectIfSingle: false,
                        ),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withAlpha(25),
                      child: Text(
                        user.fullname.isNotEmpty
                            ? user.fullname[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.isSw ? 'Karibu tena,' : 'Welcome back,',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          user.fullname.isNotEmpty
                              ? user.fullname
                              : user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Language toggle
                  GestureDetector(
                    onTap: app.toggleLanguage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            app.isSw ? 'SW' : 'EN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Theme toggle
                  _ThemeToggleButton(onWhiteBackground: false),
                  const SizedBox(width: 10),
                  // Notifications / refresh
                  GestureDetector(
                    onTap: _loadData,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _DashboardClockStrip(
                now: _now,
                businessName: biz?.businessName,
                branchName: app.selectedBranch?.branchName,
                isSw: l.isSw,
              ),

              const SizedBox(height: 24),

              // ── Balance / Revenue ──────────────────────────────────
              Text(
                l.todayRevenue,
                style: TextStyle(
                  color: AppColors.textGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _balanceVisible
                        ? AnimatedCounter(
                            key: ValueKey(revenue),
                            value: revenue,
                            prefix: 'TZS ',
                            formatter: (v) => _numFmt.format(v),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          )
                        : const Text(
                            'TZS ••••••',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _balanceVisible = !_balanceVisible),
                    child: Icon(
                      _balanceVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: Colors.white54,
                      size: 22,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (up ? Colors.green : Colors.red).withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (up ? Colors.greenAccent : Colors.redAccent)
                            .withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 14,
                          color: up ? Colors.greenAccent : Colors.redAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${up ? "+" : ""}${change.toStringAsFixed(1)}% vs jana',
                          style: TextStyle(
                            color: up ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count ${l.kpiTodayCount}'.toLowerCase(),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Action buttons (lime, like image) ──────────────────
              Row(
                children: [
                  Expanded(
                    child: _headerButton(
                      l.sellNow,
                      Icons.point_of_sale_rounded,
                      () => setState(() => _nav = 1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _headerButton(
                      l.viewSales,
                      Icons.receipt_long_rounded,
                      () => setState(() => _nav = 2),
                      outlined: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Branch chips ───────────────────────────────────────
              if (biz != null)
                Row(
                  children: [
                    const Text(
                      '',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    _branchChip(
                      biz.businessName,
                      true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BusinessSelectScreen(
                            autoSelectIfSingle: false,
                          ),
                        ),
                      ),
                    ),
                    if (app.selectedBranch != null) ...[
                      const SizedBox(width: 8),
                      _branchChip(app.selectedBranch!.branchName, false),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: Colors.white54,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l.logout,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : AppColors.accent,
          borderRadius: BorderRadius.circular(14),
          border: outlined
              ? Border.all(color: Colors.white.withAlpha(60), width: 1.5)
              : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(80),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: outlined ? Colors.white : AppColors.bgDark,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: outlined ? Colors.white : AppColors.bgDark,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchChip(String label, bool isPrimary, {VoidCallback? onTap}) {
    final chip = Container(
      padding: EdgeInsets.fromLTRB(12, 5, onTap != null ? 8 : 12, 5),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.accent.withAlpha(30)
            : Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? AppColors.accent.withAlpha(80)
              : Colors.white.withAlpha(30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isPrimary ? AppColors.accentBright : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.swap_horiz_rounded,
              size: 13,
              color: AppColors.accentBright,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: chip,
      ),
    );
  }

  // ── Subscription status banner — always visible, tappable entry point
  // to the subscription/payment screen (not just when expiring/expired).
  Widget _buildSubscriptionBanner(Business? biz) {
    if (biz == null) return const SizedBox.shrink();
    final expired = !biz.subscriptionActive;
    final expiringSoon =
        biz.subscriptionActive && biz.subscriptionDaysLeft <= 3;

    final Color color;
    final IconData icon;
    final String msg;
    if (expired) {
      color = Colors.redAccent;
      icon = Icons.lock_clock_rounded;
      msg =
          'Muda wa matumizi umeisha. Baadhi ya vitendo (kuuza, kuongeza bidhaa/wafanyakazi) vimezuiwa.';
    } else if (expiringSoon) {
      color = AppColors.chartOrange;
      icon = Icons.timer_outlined;
      msg =
          'Muda wako unaisha baada ya siku ${biz.subscriptionDaysLeft}. Wasiliana na msimamizi kuongeza muda.';
    } else {
      color = AppColors.accent;
      icon = Icons.verified_rounded;
      msg =
          'Subscription inaendelea vizuri · siku ${biz.subscriptionDaysLeft} zimebaki. Gusa kuona/simamia malipo.';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PaymentScreen())),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick Actions (circle icons like image) ───────────────────────
  Widget _buildMobileQuickActions(L l) {
    final actions = [
      _QA(
        Icons.point_of_sale_rounded,
        l.pos.split('—').first.trim(),
        AppColors.primaryLt,
        () => setState(() => _nav = 1),
      ),
      _QA(
        Icons.receipt_long_rounded,
        l.sales,
        AppColors.accent,
        () => setState(() => _nav = 2),
      ),
      _QA(
        Icons.inventory_2_rounded,
        l.products,
        AppColors.chartPurple,
        () => setState(() => _nav = 3),
      ),
      _QA(
        Icons.tune_rounded,
        l.manage,
        AppColors.chartBlue,
        () => setState(() => _nav = 4),
      ),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions
            .asMap()
            .entries
            .map(
              (e) => StaggeredItem(
                index: e.key,
                delay: const Duration(milliseconds: 80),
                child: _quickActionItem(e.value),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _quickActionItem(_QA qa) => GestureDetector(
    onTap: qa.onTap,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: qa.color.withAlpha(22),
            shape: BoxShape.circle,
            border: Border.all(color: qa.color.withAlpha(60), width: 1.5),
          ),
          child: Icon(qa.icon, color: qa.color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          qa.label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  // ── KPI Row (mobile) ─────────────────────────────────────────────
  Widget _buildMobileKpiRow(L l) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                child: const ShimmerBox(width: double.infinity, height: 80),
              ),
            ),
          ),
        ),
      );
    }

    final items = _kpiItems(l);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: items
            .asMap()
            .entries
            .map(
              (e) => Padding(
                padding: EdgeInsets.only(left: e.key == 0 ? 0 : 10),
                child: SizedBox(
                  width: 120,
                  child: StaggeredItem(
                    index: e.key,
                    delay: const Duration(milliseconds: 70),
                    child: _kpiCard(e.value, compact: true),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // Shared KPI item list (with navigation) used by both mobile and desktop rows.
  List<_KpiItem> _kpiItems(L l) => [
    _KpiItem(
      l.kpiProducts,
      '${_stats['total_products'] ?? 0}',
      Icons.inventory_2_rounded,
      AppColors.primaryLt,
      onTap: () => setState(() => _nav = 3),
    ),
    _KpiItem(
      l.kpiLowStock,
      '${_stats['low_stock_count'] ?? 0}',
      Icons.warning_amber_rounded,
      AppColors.chartOrange,
      onTap: () => setState(() => _nav = 3),
    ),
    _KpiItem(
      l.kpiDebts,
      '${_stats['unpaid_loans_count'] ?? 0}',
      Icons.receipt_long_rounded,
      AppColors.chartRed,
      onTap: () => setState(() => _nav = 2),
    ),
    _KpiItem(
      l.kpiStaff,
      '${_stats['total_staff'] ?? 0}',
      Icons.people_rounded,
      AppColors.chartPurple,
      onTap: () => setState(() {
        _manageInitialTab = 2;
        _nav = 4;
      }),
    ),
    _KpiItem(
      l.kpiDevices,
      '${_stats['active_devices_count'] ?? 0}',
      Icons.devices_rounded,
      AppColors.chartBlue,
      onTap: () => AppNotification.show(
        context,
        'Idadi ya vifaa (simu/tablet) vilivyowahi kuingia kwenye biashara hii',
        AppColors.chartBlue,
        icon: Icons.devices_rounded,
      ),
    ),
  ];

  Widget _kpiCard(_KpiItem item, {bool compact = false}) {
    final card = Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: item.color.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: compact ? 16 : 18,
                ),
              ),
              if (item.onTap != null) ...[
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          _CountUpValue(
            value: item.value,
            color: item.color,
            fontSize: compact ? 20 : 26,
          ),
          Text(
            item.label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
    if (item.onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.onTap,
        child: card,
      ),
    );
  }

  // ── Mobile Chart ─────────────────────────────────────────────────
  Widget _buildMobileChart(L l) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 18, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLt.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primaryLt,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l.weeklyChart,
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              PulseWidget(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLt.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.live,
                    style: const TextStyle(
                      color: AppColors.primaryLt,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryLt,
                      strokeWidth: 2,
                    ),
                  )
                : _salesChart.isEmpty
                ? Center(
                    child: Text(
                      l.noData,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : BarChart(_buildBarChartData()),
          ),
        ],
      ),
    );
  }

  // ── Recent Sales ─────────────────────────────────────────────────
  Widget _buildRecentSalesSection(L l) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l.recentSales,
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _nav = 2),
                child: Text(
                  l.seeAll,
                  style: const TextStyle(
                    color: AppColors.primaryLt,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const ShimmerBox(width: 40, height: 40, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(
                              width: double.infinity,
                              height: 12,
                              radius: 6,
                            ),
                            const SizedBox(height: 6),
                            const ShimmerBox(width: 100, height: 10, radius: 5),
                          ],
                        ),
                      ),
                      const ShimmerBox(width: 70, height: 16, radius: 8),
                    ],
                  ),
                ),
              ),
            )
          else if (_recentSales.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l.noSales,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ..._recentSales.asMap().entries.map(
              (e) => StaggeredItem(
                index: e.key,
                delay: const Duration(milliseconds: 70),
                child: _recentSaleRow(e.value, l),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentSaleRow(Sale sale, L l) {
    final color = sale.isPaid
        ? AppColors.primaryLt
        : sale.isUnpaid
        ? AppColors.chartRed
        : AppColors.chartOrange;
    final icon = sale.isPaid
        ? Icons.check_circle_rounded
        : sale.isUnpaid
        ? Icons.pending_rounded
        : Icons.timelapse_rounded;
    DateTime? dt;
    try {
      dt = DateTime.parse(sale.createdAt);
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.customerName.isNotEmpty
                      ? sale.customerName
                      : 'Mteja #${sale.saleId}',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dt != null
                      ? DateFormat('dd MMM, HH:mm').format(dt)
                      : sale.saleNo,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TZS ${_numFmt.format(sale.totalAmount)}',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (sale.balanceAmount > 0)
                Text(
                  'Deni: ${_numFmt.format(sale.balanceAmount)}',
                  style: const TextStyle(
                    color: AppColors.chartRed,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DESKTOP DASHBOARD CONTENT
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDesktopDash(L l) {
    if (_loading) return _buildDesktopSkeleton();
    if (_error != null) return _buildError(l);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(l),
            _buildSubscriptionBanner(
              context.read<AppProvider>().selectedBusiness,
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: _buildRevenueBanner(l)),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: _buildChartCard(l, height: 200)),
              ],
            ),
            const SizedBox(height: 20),
            _buildDesktopKpiRow(l),
            const SizedBox(height: 20),
            _buildDesktopMiniCards(l),
            const SizedBox(height: 20),
            _buildDesktopQuickActions(l),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                flex: 4,
                child: ShimmerBox(width: double.infinity, height: 180),
              ),
              const SizedBox(width: 20),
              const Expanded(
                flex: 6,
                child: ShimmerBox(width: double.infinity, height: 180),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 12 : 0),
                  child: const ShimmerBox(width: double.infinity, height: 90),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(L l) => Row(
    children: [
      Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 6),
      Text(
        DateFormat('EEEE, d MMMM yyyy', 'en_US').format(DateTime.now()),
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
      const Spacer(),
      PulseWidget(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryLt.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryLt.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 5),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLt,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                l.live,
                style: const TextStyle(
                  color: AppColors.primaryLt,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildRevenueBanner(L l) {
    final revenue = (_stats['today_revenue'] ?? 0.0).toDouble();
    final count = (_stats['today_sales_count'] ?? 0) as int;
    final change = (_stats['revenue_change_pct'] ?? 0.0).toDouble();
    final up = change >= 0;
    return GradientCard(
      colors: AppColors.gradPrimary,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      up
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 13,
                      color: up ? AppColors.accentBright : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${up ? "+" : ""}${change.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: up ? AppColors.accentBright : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.todayRevenue,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          AnimatedCounter(
            value: revenue,
            prefix: 'TZS ',
            formatter: (v) => _numFmt.format(v),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count ${l.kpiTodayCount}',
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(L l, {required double height}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLt.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primaryLt,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l.weeklyChart,
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: height,
            child: _salesChart.isEmpty
                ? Center(
                    child: Text(
                      l.noData,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : BarChart(_buildBarChartData()),
          ),
        ],
      ),
    );
  }

  BarChartData _buildBarChartData() {
    final spots = <BarChartGroupData>[];
    double maxY = 0;
    for (int i = 0; i < _salesChart.length && i < 7; i++) {
      final v = (_salesChart[i]['total'] ?? 0.0).toDouble();
      if (v > maxY) maxY = v;
      spots.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              gradient: const LinearGradient(
                colors: [AppColors.primaryMid, AppColors.accentDk],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ],
        ),
      );
    }
    final labels = _salesChart
        .map((d) => (d['day_label'] as String?) ?? '')
        .toList();
    return BarChartData(
      barGroups: spots,
      maxY: maxY > 0 ? maxY * 1.3 : 100,
      gridData: FlGridData(
        show: true,
        horizontalInterval: maxY > 0 ? maxY / 4 : 25,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppColors.border, strokeWidth: 0.5),
        drawVerticalLine: false,
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              return Text(
                i < labels.length ? labels[i] : '',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 52,
            getTitlesWidget: (v, _) => Text(
              _compact(v),
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.bgDark,
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
            'TZS ${_numFmt.format(rod.toY)}',
            TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopKpiRow(L l) {
    final items = _kpiItems(l);
    return Row(
      children: items
          .asMap()
          .entries
          .map(
            (e) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: e.key == 0 ? 0 : 12),
                child: StaggeredItem(index: e.key, child: _kpiCard(e.value)),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDesktopMiniCards(L l) {
    final cards = [
      _MCard(
        l.todayRevenue,
        'TZS ${_compact((_stats['today_revenue'] ?? 0.0).toDouble())}',
        AppColors.gradPrimary,
        Icons.today_rounded,
      ),
      _MCard(
        l.totalRevenue,
        'TZS ${_compact((_stats['total_revenue'] ?? 0.0).toDouble())}',
        AppColors.gradGreen,
        Icons.show_chart_rounded,
      ),
      _MCard(
        l.kpiDebts,
        'TZS ${_compact((_stats['unpaid_loans_amount'] ?? 0.0).toDouble())}',
        AppColors.gradRed,
        Icons.money_off_rounded,
      ),
      _MCard(
        l.kpiOutStock,
        '${_stats['out_of_stock_count'] ?? 0} ${l.products.toLowerCase()}',
        AppColors.gradOrange,
        Icons.remove_shopping_cart_rounded,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.summary,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: cards
              .asMap()
              .entries
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: e.key == 0 ? 0 : 12),
                    child: StaggeredItem(
                      index: e.key,
                      child: GradientCard(
                        colors: e.value.gradient,
                        radius: 18,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(e.value.icon, color: Colors.white70, size: 20),
                            const SizedBox(height: 12),
                            Text(
                              e.value.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              e.value.label,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDesktopQuickActions(L l) {
    final actions = [
      _QA(
        Icons.point_of_sale_rounded,
        l.pos.split('—').first.trim(),
        AppColors.primaryLt,
        () => setState(() => _nav = 1),
      ),
      _QA(
        Icons.receipt_long_rounded,
        l.sales,
        AppColors.accent,
        () => setState(() => _nav = 2),
      ),
      _QA(
        Icons.inventory_2_rounded,
        l.products,
        AppColors.chartPurple,
        () => setState(() => _nav = 3),
      ),
      _QA(
        Icons.tune_rounded,
        l.manage,
        AppColors.chartBlue,
        () => setState(() => _nav = 4),
      ),
      _QA(Icons.refresh_rounded, l.refresh, AppColors.chartGray, _loadData),
      _QA(Icons.logout_rounded, l.logout, AppColors.chartRed, _logout),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.quickActions,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions
              .map(
                (qa) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: InkWell(
                      onTap: qa.onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: qa.color.withAlpha(15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: qa.color.withAlpha(50)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: qa.color.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(qa.icon, color: qa.color, size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              qa.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: qa.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildError(L l) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: Text(l.tryAgain),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════
  // PAGE ROUTER
  // ══════════════════════════════════════════════════════════════════
  Widget _pageContent({required bool desktop}) {
    final l = L.of(context);
    switch (_nav) {
      case 0:
        return desktop ? _buildDesktopDash(l) : _buildDashContent(l);
      case 1:
        return PosScreen(
          desktop: desktop,
          onNavChange: (i) => setState(() => _nav = i),
        );
      case 2:
        return SalesScreen(
          desktop: desktop,
          onBack: () => setState(() => _nav = 0),
        );
      case 3:
        return ProductsScreen(
          key: ValueKey('products_$_productsRefreshKey'),
          desktop: desktop,
          showMobileFab: !desktop,
          onBack: () => setState(() => _nav = 0),
        );
      case 4:
        return ManageScreen(desktop: desktop, initialTab: _manageInitialTab);
      default:
        return desktop ? _buildDesktopDash(l) : _buildDashContent(l);
    }
  }

  // Mobile dashboard content (when _nav == 0 but not using fintech header path)
  Widget _buildDashContent(L l) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLt),
      );
    }
    if (_error != null) return _buildError(l);
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryLt,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _buildMobileQuickActions(l),
          const SizedBox(height: 8),
          _buildMobileKpiRow(l),
          const SizedBox(height: 8),
          _buildMobileChart(l),
          const SizedBox(height: 8),
          _buildRecentSalesSection(l),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const wd = ['Jt', 'Jm', 'Ju', 'Al', 'Ij', 'Ij', 'Jp'];
    const mn = [
      'Jan',
      'Feb',
      'Mac',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${wd[d.weekday - 1]}, ${d.day} ${mn[d.month - 1]} ${d.year}';
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────
class _KpiItem {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _KpiItem(this.label, this.value, this.icon, this.color, {this.onTap});
}

// ── Animated count-up number (falls back to plain text if not numeric) ──────
class _CountUpValue extends StatelessWidget {
  final String value;
  final Color color;
  final double fontSize;
  const _CountUpValue({
    required this.value,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(value);
    final style = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );
    if (target == null) return Text(value, style: style);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Text('$v', style: style),
    );
  }
}

class _MCard {
  final String label, value;
  final List<Color> gradient;
  final IconData icon;
  const _MCard(this.label, this.value, this.gradient, this.icon);
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.icon, this.label, this.color, this.onTap);
}

class _DashboardClockStrip extends StatelessWidget {
  final DateTime now;
  final String? businessName;
  final String? branchName;
  final bool isSw;

  const _DashboardClockStrip({
    required this.now,
    required this.businessName,
    required this.branchName,
    required this.isSw,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm:ss').format(now);
    final date = DateFormat('EEE, dd MMM yyyy').format(now);
    final location = [
      if ((businessName ?? '').isNotEmpty) businessName!,
      if ((branchName ?? '').isNotEmpty) branchName!,
    ].join(' • ');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey(time),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(36)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.accentBright,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSw ? 'Saa ya biashara' : 'Business time',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.isEmpty ? date : location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme Toggle Button ───────────────────────────────────────────────────────
// Tap → cycles: auto → dark → light → auto
// Long-press → bottom sheet to pick directly
class _ThemeToggleButton extends StatelessWidget {
  /// true = dark background pill style (desktop toolbar)
  /// false = white-on-green ghost style (mobile header)
  final bool onWhiteBackground;
  const _ThemeToggleButton({required this.onWhiteBackground});

  static const _order = ['auto', 'dark', 'light'];

  void _cycle(BuildContext ctx) {
    final tp = ctx.read<ThemeProvider>();
    final next = _order[(_order.indexOf(tp.preference) + 1) % _order.length];
    tp.setPreference(next);
  }

  void _showPicker(BuildContext ctx) {
    final tp = ctx.read<ThemeProvider>();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: tp,
        child: const _ThemePickerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;
    final pref = theme.preference;

    final icon = switch (pref) {
      'dark' => Icons.dark_mode_rounded,
      'light' => Icons.light_mode_rounded,
      _ => isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
    };

    final label = switch (pref) {
      'dark' => 'Usiku',
      'light' => 'Mchana',
      _ => 'Auto',
    };

    final Color iconColor = onWhiteBackground
        ? (isDark ? AppColors.primaryLt : AppColors.accentDk)
        : Colors.white;

    final Color bgColor = onWhiteBackground
        ? (isDark
              ? AppColors.primary.withAlpha(45)
              : AppColors.accentDk.withAlpha(20))
        : Colors.white.withAlpha(25);

    final Color borderColor = onWhiteBackground
        ? (isDark
              ? AppColors.primaryLt.withAlpha(80)
              : AppColors.accentDk.withAlpha(60))
        : Colors.white.withAlpha(40);

    return GestureDetector(
      onTap: () => _cycle(context),
      onLongPress: () => _showPicker(context),
      child: Tooltip(
        message: 'Mandhari: $label  (hold = chagua)',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.elasticOut,
                  ),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: iconColor,
                  size: 14,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme Picker Bottom Sheet ─────────────────────────────────────────────────
class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.elasticOut,
                  ),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  key: ValueKey(theme.isDark),
                  theme.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: theme.isDark
                      ? AppColors.primaryLt
                      : AppColors.accentDk,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mandhari',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Chagua jinsi unavyotaka muonekano',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Three option cards
          ...[
            (
              'auto',
              Icons.schedule_rounded,
              'Kiotomatiki (Saa)',
              'Usiku kuanzia 18:00 hadi 06:00 • Mchana wakati mwingine',
            ),
            (
              'dark',
              Icons.nights_stay_rounded,
              'Usiku Daima',
              'Mandhari ya giza, mazuri kwa jicho usiku',
            ),
            (
              'light',
              Icons.wb_sunny_rounded,
              'Mchana Daima',
              'Mandhari nyeupe, rahisi kusomea mchana',
            ),
          ].map((item) {
            final (pref, icon, title, sub) = item;
            final isActive = theme.preference == pref;
            return GestureDetector(
              onTap: () {
                theme.setPreference(pref);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withAlpha(35)
                      : AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? AppColors.primaryLt : AppColors.border,
                    width: isActive ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withAlpha(80)
                            : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: isActive ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.textWhite
                                  : AppColors.textLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Fintech Confirm Dialog ────────────────────────────────────────────────────
class _FintechDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, body, confirmLabel, cancelLabel;
  final Color confirmColor;

  const _FintechDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.bgCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
      ],
    ),
    content: Text(body, style: TextStyle(color: AppColors.textMuted)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(cancelLabel, style: TextStyle(color: AppColors.textMuted)),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
      ),
    ],
  );
}
