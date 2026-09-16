import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/first_run_tutorial.dart';
import 'payment_screen.dart';
import 'manage_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _fullnameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _curPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();

  bool _loading      = true;
  bool _saving       = false;
  bool _showPassword = false;
  bool _obscureCur = true, _obscureNew = true, _obscureConf = true;
  String _globalRole = 'User';
  String _subStatus  = 'trial';

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _fullnameCtrl.dispose();
    _emailCtrl.dispose();
    _curPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final user = app.user;
    if (app.api == null || user == null) return;
    try {
      final res = await app.api!.getProfile(user.userId);
      if (!mounted) return;
      if (res['success'] == true) {
        final d = res['data'] as Map<String, dynamic>;
        _fullnameCtrl.text = (d['fullname'] as String? ?? user.fullname);
        _emailCtrl.text    = (d['email'] as String? ?? '');
        _globalRole = (d['global_role'] as String? ?? user.globalRole);
        _subStatus  = (d['subscription_status'] as String? ?? 'trial');
      } else {
        _fullnameCtrl.text = user.fullname;
      }
    } catch (_) {
      _fullnameCtrl.text = user.fullname;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _animCtrl.forward();
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_newPassCtrl.text.isNotEmpty && _newPassCtrl.text != _confPassCtrl.text) {
      AppNotification.show(context, 'Nywila mpya hazifanani', AppColors.chartRed,
          icon: Icons.error_rounded);
      return;
    }

    final app  = context.read<AppProvider>();
    final user = app.user;
    if (app.api == null || user == null) return;

    setState(() => _saving = true);
    try {
      final res = await app.api!.updateProfile(
        userId: user.userId,
        fullname: _fullnameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        currentPassword: _curPassCtrl.text,
        newPassword: _newPassCtrl.text,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        app.updateUserFullname(_fullnameCtrl.text.trim());
        AppNotification.show(context, '✅ Wasifu umesasishwa', AppColors.accent,
            icon: Icons.check_circle_rounded);
        _curPassCtrl.clear();
        _newPassCtrl.clear();
        _confPassCtrl.clear();
        setState(() => _showPassword = false);
      } else {
        AppNotification.show(context, res['message'] as String? ?? 'Hitilafu',
            AppColors.chartRed, icon: Icons.error_rounded);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLt))
          : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                    .animate(_fadeAnim),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(user?.fullname ?? '', user?.username ?? '')),
                    SliverToBoxAdapter(child: _buildQuickLinks()),
                    SliverToBoxAdapter(child: _buildForm()),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(String fullname, String username) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: AppColors.gradHeader,
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 32),
        child: Column(children: [
          Row(children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            const Text('Wasifu Wangu',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: AppColors.gradLime),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
                border: Border.all(color: Colors.white.withAlpha(50), width: 3),
              ),
              child: Center(
                child: Text(fullname.isNotEmpty ? fullname[0].toUpperCase() : 'U',
                    style: TextStyle(color: AppColors.bgDark, fontSize: 34, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(fullname, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text('@$username', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pill(_globalRole, Icons.verified_user_rounded),
            const SizedBox(width: 8),
            _pill(_subStatus == 'trial' ? 'Jaribio' : _subStatus, Icons.workspace_premium_rounded),
          ]),
        ]),
      ),
    ),
  );

  Widget _pill(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withAlpha(40)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white70),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildQuickLinks() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('🏢', 'Usimamizi wa Biashara'),
      const SizedBox(height: 14),
      _linkRow(
        icon: Icons.workspace_premium_rounded,
        color: AppColors.accent,
        title: 'Subscription na Malipo',
        subtitle: 'Ona hali ya subscription, lipia muda, historia ya malipo',
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentScreen())),
      ),
      const SizedBox(height: 10),
      _linkRow(
        icon: Icons.people_alt_rounded,
        color: AppColors.chartPurple,
        title: 'Simamia Wafanyakazi',
        subtitle: 'Ongeza, badilisha cheo, ondoa wafanyakazi',
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManageScreen(initialTab: 2))),
      ),
      const SizedBox(height: 10),
      _linkRow(
        icon: Icons.school_rounded,
        color: AppColors.primaryLt,
        title: 'Onyesha mafunzo tena',
        subtitle: 'Maelekezo ya hatua kwa hatua kwenye kila screen',
        onTap: () async {
          await FirstRunTutorial.resetAll();
          if (!mounted) return;
          AppNotification.show(context, 'Mafunzo yataonekana tena kwenye kila screen',
              AppColors.accent, icon: Icons.check_circle_rounded);
          Navigator.of(context).pop();
        },
      ),
    ]),
  );

  Widget _linkRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ]),
      ),
    ),
  );

  Widget _buildForm() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('👤', 'Taarifa Binafsi'),
        const SizedBox(height: 14),
        _field(ctrl: _fullnameCtrl, label: 'Jina Kamili', icon: Icons.badge_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Jina linahitajika' : null),
        const SizedBox(height: 14),
        _field(ctrl: _emailCtrl, label: 'Barua Pepe', icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 24),

        GestureDetector(
          onTap: () => setState(() => _showPassword = !_showPassword),
          child: Row(children: [
            _sectionTitle('🔑', 'Badilisha Nywila'),
            const Spacer(),
            Icon(_showPassword ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppColors.textMuted),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showPassword
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(children: [
                    _passField(_curPassCtrl, 'Nywila ya Sasa', _obscureCur,
                        () => setState(() => _obscureCur = !_obscureCur)),
                    const SizedBox(height: 14),
                    _passField(_newPassCtrl, 'Nywila Mpya', _obscureNew,
                        () => setState(() => _obscureNew = !_obscureNew)),
                    const SizedBox(height: 14),
                    _passField(_confPassCtrl, 'Thibitisha Nywila Mpya', _obscureConf,
                        () => setState(() => _obscureConf = !_obscureConf)),
                  ]),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi Mabadiliko',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    ),
  );

  Widget _sectionTitle(String emoji, String text) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 15)),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(color: AppColors.textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
  ]);

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    validator: validator,
    style: TextStyle(color: AppColors.textWhite, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      filled: true,
      fillColor: AppColors.bgInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
    ),
  );

  Widget _passField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) =>
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(color: AppColors.textWhite, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textMuted, size: 18),
            onPressed: toggle,
          ),
          filled: true,
          fillColor: AppColors.bgInput,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
        ),
      );
}
