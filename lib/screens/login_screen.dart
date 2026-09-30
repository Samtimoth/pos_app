import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/offline_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/first_run_tutorial.dart';
import 'business_select_screen.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import 'superadmin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController(
    text: 'https://focustec.co.tz/pos/api',
  );
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstRunTutorial.showIfNeeded(
        context,
        storageKey: 'login',
        steps: const [
          TutorialStep(
            icon: Icons.person_rounded,
            title: 'Username au email',
            body: 'Andika hapa username au email uliyopewa.',
            targetId: 'login_user',
          ),
          TutorialStep(
            icon: Icons.lock_rounded,
            title: 'Nywila',
            body: 'Weka nywila yako, kisha bonyeza Ingia. Ukishaingia mara moja, app inafanya kazi hata bila mtandao.',
            targetId: 'login_pass',
          ),
          TutorialStep(
            icon: Icons.storefront_rounded,
            title: 'Huna akaunti?',
            body: 'Bonyeza hapa kusajili biashara mpya — inachukua dakika moja.',
            targetId: 'login_register',
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serverUrl = _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
      final api = OfflineApiService(serverUrl);
      final res = await api.login(_userCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final user = User.fromJson(data, serverUrl);
        final app = context.read<AppProvider>();
        await app.setUser(user);
        if (!mounted) return;

        if (user.isSuperAdmin) {
          Navigator.of(
            context,
          ).pushReplacement(_fade(const SuperAdminScreen()));
          return;
        }

        final businesses = await app.loadBusinesses();
        if (!mounted) return;

        if (businesses.isEmpty) {
          setState(() {
            _error = 'Hakuna biashara. Wasiliana na msimamizi.';
          });
          return;
        }
        if (businesses.length == 1 && businesses.first.branches.length == 1) {
          final biz = businesses.first;
          await app.selectBusinessAndBranch(biz, biz.branches.first);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(_fade(const DashboardScreen()));
          return;
        }
        Navigator.of(
          context,
        ).pushReplacement(_fade(const BusinessSelectScreen()));
      } else {
        setState(
          () => _error = res['message'] as String? ?? 'Imeshindwa kuingia',
        );
      }
    } catch (e) {
      setState(() => _error = 'Hitilafu ya mtandao: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  PageRoute _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (ctx, a1, a2) => page,
    transitionsBuilder: (ctx, anim, sa, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 400),
  );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PremiumPageEntrance(
        child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ── Desktop: split-screen ──────────────────────────────
  Widget _buildDesktopLayout() => Row(
    children: [
      // Left branding panel
      Expanded(
        flex: 4,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1B4B), Color(0xFF1A3A6E), Color(0xFF0F3460)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -60,
                left: -60,
                child: _glowCircle(200, AppColors.primary.withAlpha(30)),
              ),
              Positioned(
                bottom: -80,
                right: -80,
                child: _glowCircle(260, AppColors.accent.withAlpha(20)),
              ),
              Positioned(
                top: 200,
                right: -40,
                child: _glowCircle(120, AppColors.chartPurple.withAlpha(20)),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 52,
                  vertical: 60,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    const BrandLogo(size: 92, radius: 24),
                    const SizedBox(height: 28),
                    const Text(
                      'Duka Kiganjani',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage mauzi yako\nmkononi',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Feature bullets
                    ...[
                      ('📊', 'Dashboard na grafu za mauzo'),
                      ('🛒', 'POS ya haraka na inventory'),
                      ('🏪', 'Multi-biashara & matawi'),
                      ('📱', 'Mobile na Desktop'),
                    ].map((f) => _featureBullet(f.$1, f.$2)),
                    const Spacer(flex: 2),
                    const Text(
                      'Duka Kiganjani',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Right form panel
      Expanded(
        flex: 5,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 48,
                  ),
                  child: _buildFormCard(desktop: true),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _glowCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _featureBullet(String emoji, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    ),
  );

  // ── Mobile: single column, vertically centered like a native app ──
  Widget _buildMobileLayout() => SafeArea(
    child: FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMobileHeader(),
                      const SizedBox(height: 32),
                      _buildFormCard(desktop: false),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildMobileHeader() => Column(
    children: [
      const BrandLogo(size: 112, radius: 28),
      const SizedBox(height: 20),
      Text(
        'Duka Kiganjani',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textWhite,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Manage mauzi yako mkononi',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    ],
  );

  // ── Form card (shared) ─────────────────────────────────
  Widget _buildFormCard({required bool desktop}) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (desktop) ...[
          Text(
            'Karibu! 👋',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Ingia kwenye akaunti yako',
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 28),
        ],
        // ── Username ────────────────────────────────────────
        _fieldLabel('👤  Jina la Mtumiaji'),
        TutorialTarget(
          id: 'login_user',
          child: _textField(
          controller: _userCtrl,
          hint: 'username au email',
          icon: Icons.person_outline_rounded,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Ingiza jina la mtumiaji'
              : null,
          action: TextInputAction.next,
        ),
        ),
        const SizedBox(height: 18),

        // ── Password ────────────────────────────────────────
        _fieldLabel('🔑  Nywila'),
        TutorialTarget(
          id: 'login_pass',
          child: TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          style: TextStyle(color: AppColors.textWhite, fontSize: 15),
          decoration: _inputDeco('••••••••', Icons.lock_outline_rounded)
              .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
          validator: (v) => (v == null || v.isEmpty) ? 'Ingiza nywila' : null,
          onFieldSubmitted: (_) => _login(),
        ),
        ),
        const SizedBox(height: 22),

        // ── Error ───────────────────────────────────────────
        if (_error != null) _errorBox(_error!),
        if (_error != null) const SizedBox(height: 12),

        // ── Login button ────────────────────────────────────
        _loginButton(),
        const SizedBox(height: 20),

        // ── Divider ─────────────────────────────────────────
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'au',
                style: TextStyle(
                  color: AppColors.textMuted.withAlpha(150),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 20),

        // ── Register link ───────────────────────────────────
        TutorialTarget(
          id: 'login_register',
          child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RegisterScreen(serverUrl: _urlCtrl.text.trim()),
            ),
          ),
          icon: const Icon(
            Icons.store_rounded,
            size: 18,
            color: AppColors.accent,
          ),
          label: const Text(
            'Sajili Biashara Mpya',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.accent, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        ),

        if (!desktop) ...[const SizedBox(height: 28), _buildFooter()],
      ],
    ),
  );

  Widget _loginButton() => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      gradient: _loading
          ? null
          : const LinearGradient(
              colors: AppColors.gradPrimary,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
      color: _loading ? AppColors.border : null,
      borderRadius: BorderRadius.circular(14),
      boxShadow: _loading
          ? null
          : [
              BoxShadow(
                color: AppColors.primary.withAlpha(60),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    ),
    child: ElevatedButton(
      onPressed: _loading ? null : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ingia Sasa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _buildFooter() => Column(
    children: [
      Text(
        'Powered by Focus Tec',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 4),
      Text(
        'v1.0.0',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.border, fontSize: 11),
      ),
    ],
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.textLight,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? action,
  }) => TextFormField(
    controller: controller,
    style: TextStyle(color: AppColors.textWhite, fontSize: 15),
    decoration: _inputDeco(hint, icon),
    validator: validator,
    keyboardType: keyboardType,
    textInputAction: action ?? TextInputAction.next,
    autocorrect: false,
  );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
    filled: true,
    fillColor: AppColors.bgInput,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  );

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.red.shade900.withAlpha(55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.redAccent.withAlpha(120)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
