import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/business.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo_data.dart';
import 'dashboard_screen.dart';

// ── Field hint definitions ─────────────────────────────────────────────────────
const _kHints = {
  'fullname':      'Andika jina lako kamili kama linavyoonekana kwenye kitambulisho. Mfano: "Samantha Timothy"',
  'username':      'Chagua jina la kipekee la kuingia. Tumia herufi, nambari, au _ pekee. Mfano: "mama_anna123"',
  'email':         'Ingiza barua pepe yako halisi. Itatumika kama njia ya kurejesha akaunti. Mfano: "mama@gmail.com"',
  'phone':         'Nambari ya simu yako ya kibinafsi (hiari). Mfano: "+255 763 417 711"',
  'password':      'Nywila yenye usalama — angalau herufi 6. Changanya herufi kubwa, ndogo, na nambari.',
  'confirm_pass':  'Andika tena nywila ile ile uliyoandika hapo juu ili kuthibitisha.',
  'biz_name':      'Jina rasmi la biashara yako. Mfano: "Duka la Mama Anna" au "Anatoth Shop"',
  'trade_name':    '(Hiari) Jina la kibiashara linaloonekana kwa wateja kama ni tofauti na jina rasmi.',
  'biz_phone':     'Nambari ya simu ya biashara yako. Wateja wataweza kuwasiliana nawe kupitia nambari hii.',
  'address':       'Anwani kamili ya biashara yako. Mfano: "Kariakoo, Dar es Salaam" au "Mbeya Mjini"',
  'country':       'Nchi ambapo biashara yako ipo. Hii itaathiri mipangilio ya fedha na muda.',
  'currency':      'Sarafu inayotumika katika biashara yako kwa malipo na ripoti za mauzo.',
};

class RegisterScreen extends StatefulWidget {
  final String serverUrl;
  const RegisterScreen({super.key, required this.serverUrl});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {

  final _pageCtrl = PageController();
  int  _step    = 0;
  bool _loading = false;
  String? _error;

  // ── Step 1 controllers ────────────────────────────────
  final _step1Key  = GlobalKey<FormState>();
  final _urlCtrl   = TextEditingController();
  final _fullCtrl  = TextEditingController();
  final _userCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool  _obs1 = true, _obs2 = true;

  // ── Step 2 controllers ────────────────────────────────
  final _step2Key  = GlobalKey<FormState>();
  final _bizCtrl   = TextEditingController();
  final _tradeCtrl = TextEditingController();
  final _bizPhCtrl = TextEditingController();
  final _addrCtrl  = TextEditingController();
  String _country  = 'Tanzania';
  String _currency = 'TZS';

  // ── Animations ─────────────────────────────────────────
  late AnimationController _stepCtrl;
  late Animation<double>   _stepFade;
  late AnimationController _successCtrl;

  @override
  void initState() {
    super.initState();
    // Use provided URL, fallback to localhost
    final provided = widget.serverUrl.trim();
    _urlCtrl.text = (provided.isNotEmpty && provided != 'http://192.168.1.100/pos/api')
        ? provided
        : 'https://focustec.co.tz/pos/api';

    _stepCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _stepFade    = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeInOut);
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _stepCtrl.value = 1;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _stepCtrl.dispose();
    _successCtrl.dispose();
    for (final c in [
      _urlCtrl, _fullCtrl, _userCtrl, _emailCtrl, _phoneCtrl,
      _passCtrl, _pass2Ctrl, _bizCtrl, _tradeCtrl, _bizPhCtrl, _addrCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────
  void _nextStep() {
    if (!_step1Key.currentState!.validate()) return;
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() => _error = 'Nywila hazifanani. Tafadhali angalia tena.');
      return;
    }
    setState(() { _error = null; _step = 1; });
    _stepCtrl.reverse().then((_) {
      _pageCtrl.animateToPage(1,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
      _stepCtrl.forward();
    });
  }

  void _prevStep() {
    setState(() { _step = 0; _error = null; });
    _stepCtrl.reverse().then((_) {
      _pageCtrl.animateToPage(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
      _stepCtrl.forward();
    });
  }

  // ── Registration API call ──────────────────────────────
  Future<void> _register() async {
    if (!_step2Key.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final serverUrl = _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
      final api = ApiService(serverUrl);

      final res = await api.register(
        fullname:      _fullCtrl.text.trim(),
        username:      _userCtrl.text.trim(),
        email:         _emailCtrl.text.trim(),
        phone:         _phoneCtrl.text.trim(),
        password:      _passCtrl.text,
        businessName:  _bizCtrl.text.trim(),
        tradeName:     _tradeCtrl.text.trim().isNotEmpty
            ? _tradeCtrl.text.trim() : _bizCtrl.text.trim(),
        businessPhone: _bizPhCtrl.text.trim(),
        address:       _addrCtrl.text.trim(),
        country:       _country,
        currency:      _currency,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final data    = res['data'] as Map<String, dynamic>;
        final bizData = data['business'] as Map<String, dynamic>;

        final user = User.fromJson({ ...data, 'global_role': 'User' }, serverUrl);
        final biz  = Business.fromJson({
          ...bizData,
          'role':             'Owner',
          'country':          _country,
          'currency':         _currency,
          'trade_name':       _tradeCtrl.text.trim(),
          'phone':            _bizPhCtrl.text.trim(),
          'timezone':         'Africa/Dar_es_Salaam',
          'address':          _addrCtrl.text.trim(),
          'logo_path':        '',
          'is_active':        true,
          'branch_count':     1,
          'default_branch_id': data['branch_id'],
          'branches': [{
            'branch_id':   data['branch_id'],
            'branch_name': 'Main Branch',
            'branch_code': 'MAIN',
            'phone':       _bizPhCtrl.text.trim(),
            'address':     _addrCtrl.text.trim(),
            'is_active':   1,
          }],
        });

        final app = context.read<AppProvider>();
        await app.setUser(user);
        await app.selectBusinessAndBranch(biz, biz.branches.first);

        await _successCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder:        (ctx, a1, a2) => const DashboardScreen(),
            transitionsBuilder: (ctx, anim, sa, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (_) => false,
        );
      } else {
        setState(() => _error = res['message'] as String? ?? 'Hitilafu ya usajili');
      }
    } on Exception catch (e) {
      String msg = e.toString();
      if (msg.contains('TimeoutException') || msg.contains('timeout')) {
        msg = 'Imeshindwa kufikia server.\n\nHakikisha:\n• XAMPP inaendesha (Apache + MySQL)\n• URL ni sahihi (mf. http://localhost/pos/api)\n• Nambari ya IP ni sahihi kwa WiFi';
      } else if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        msg = 'Server haipatikani. Angalia URL na uhakikishe XAMPP inaendesha.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Searchable picker (countries/currencies) ───────────
  Future<void> _pickCountry() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SearchPickerDialog(
        title: 'Chagua Nchi',
        items: kCountries,
        labelOf: (v) => v,
        current: _country,
      ),
    );
    if (result != null) setState(() => _country = result);
  }

  Future<void> _pickCurrency() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SearchPickerDialog(
        title: 'Chagua Sarafu',
        items: kCurrencies.map((c) => c.$1).toList(),
        labelOf: (v) {
          final match = kCurrencies.firstWhere(
            (c) => c.$1 == v, orElse: () => (v, ''));
          return match.$2.isNotEmpty ? '$v — ${match.$2}' : v;
        },
        current: _currency,
      ),
    );
    if (result != null) setState(() => _currency = result);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textMuted),
          onPressed: _step == 1 ? _prevStep : () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sajili Biashara',
                style: TextStyle(color: AppColors.textWhite, fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              _step == 0 ? 'Hatua 1/2 — Akaunti yako' : 'Hatua 2/2 — Biashara yako',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
      body: isWide ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── Desktop layout ──────────────────────────────────────
  Widget _buildDesktop() => Row(children: [
    Expanded(flex: 4, child: _buildLeftPanel()),
    Expanded(
      flex: 6,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _buildFormPages(),
        ),
      ),
    ),
  ]);

  // ── Mobile layout ───────────────────────────────────────
  Widget _buildMobile() => Column(children: [
    _buildStepBar(),
    Expanded(child: _buildFormPages()),
  ]);

  // ── Left panel ──────────────────────────────────────────
  Widget _buildLeftPanel() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0D1B4B), Color(0xFF133060), Color(0xFF0E4A3A)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Stack(children: [
      Positioned(top: -70, left: -70,
          child: _glowBall(220, AppColors.primary.withAlpha(25))),
      Positioned(bottom: -80, right: -60,
          child: _glowBall(260, AppColors.accent.withAlpha(20))),
      Positioned(top: 180, right: -30,
          child: _glowBall(130, AppColors.chartPurple.withAlpha(15))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Spacer(),
          // Icon
          Container(
            width: 74, height: 74,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.gradGreen),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                color: AppColors.accent.withAlpha(100),
                blurRadius: 22, offset: const Offset(0, 8),
              )],
            ),
            child: const Icon(Icons.storefront_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 22),
          const Text('Anza Biashara\nYako Leo! 🚀',
              style: TextStyle(
                  color: Colors.white, fontSize: 34,
                  fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 12),
          const Text('Jisajili bure na upate:\n✨ Trial ya miezi 3 bila malipo',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6)),
          const SizedBox(height: 32),
          ...[
            ('✅', 'Akaunti na biashara kwa hatua 2 tu'),
            ('🆓', 'Trial ya miezi 3 bila malipo yoyote'),
            ('🏪', 'Tawi la kwanza (Main Branch) tayari'),
            ('📊', 'Dashboard, POS, inventory — zote!'),
            ('🔒', 'Data yako iko salama kabisa'),
          ].map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(children: [
              Text(f.$1, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 11),
              Expanded(
                child: Text(f.$2,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ]),
          )),
          const Spacer(flex: 2),
          _buildStepIndicatorVertical(),
        ]),
      ),
    ]),
  );

  Widget _glowBall(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  // ── Step bars ───────────────────────────────────────────
  Widget _buildStepBar() => Container(
    color: AppColors.bgCard,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    child: Row(children: [
      _stepDot(0, 'Akaunti', AppColors.primary),
      Expanded(child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 2, color: _step >= 1 ? AppColors.primary : AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      )),
      _stepDot(1, 'Biashara', AppColors.accent),
    ]),
  );

  Widget _buildStepIndicatorVertical() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _vertDot(0, 'Hatua 1 — Akaunti', AppColors.primary),
      Padding(
        padding: const EdgeInsets.only(left: 15, top: 2, bottom: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 2, height: 24,
          color: _step >= 1 ? AppColors.accent : Colors.white24,
        ),
      ),
      _vertDot(1, 'Hatua 2 — Biashara', AppColors.accent),
    ],
  );

  Widget _stepDot(int idx, String label, Color color) {
    final done   = _step > idx;
    final active = _step == idx;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 34, height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : (active ? color : AppColors.bgCard),
          border: Border.all(color: active || done ? color : AppColors.border, width: 2),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text('${idx + 1}',
                  style: TextStyle(
                    color: active ? color : AppColors.textMuted,
                    fontWeight: FontWeight.bold, fontSize: 13,
                  )),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
            color: active ? color : AppColors.textMuted,
            fontSize: 10, fontWeight: FontWeight.w600,
          )),
    ]);
  }

  Widget _vertDot(int idx, String label, Color color) {
    final done   = _step > idx;
    final active = _step == idx;
    return Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : (active ? color.withAlpha(30) : Colors.white12),
          border: Border.all(color: active || done ? color : Colors.white24, width: 2),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
              : Text('${idx + 1}',
                  style: TextStyle(
                    color: active ? color : Colors.white54,
                    fontWeight: FontWeight.bold, fontSize: 12,
                  )),
        ),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
    ]);
  }

  // ── Form pages ──────────────────────────────────────────
  Widget _buildFormPages() => FadeTransition(
    opacity: _stepFade,
    child: PageView(
      controller: _pageCtrl,
      physics: const NeverScrollableScrollPhysics(),
      children: [_buildStep1(), _buildStep2()],
    ),
  );

  // ══════════════════════════════════════════════════════
  // Step 1 — Account
  // ══════════════════════════════════════════════════════
  Widget _buildStep1() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
    child: Form(
      key: _step1Key,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader('👤', 'Maelezo ya Akaunti',
            'Habari zako za kibinafsi za kuingia mfumoni'),
        const SizedBox(height: 22),

        _fieldRow(
          label: 'Jina Kamili *',
          hint: 'fullname',
          child: TextFormField(
            controller: _fullCtrl,
            style: _txtStyle,
            decoration: _deco('Jina lako kamili', Icons.badge_outlined),
            validator: (v) => v == null || v.trim().isEmpty ? 'Jina kamili linahitajika' : null,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Username *',
          hint: 'username',
          child: TextFormField(
            controller: _userCtrl,
            style: _txtStyle,
            decoration: _deco('mama_anna123', Icons.person_outline_rounded),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Username inahitajika';
              if (v.trim().length < 3) return 'Herufi 3 au zaidi';
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                return 'Herufi, nambari, au _ tu';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
            autocorrect: false,
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Barua Pepe (Email) *',
          hint: 'email',
          child: TextFormField(
            controller: _emailCtrl,
            style: _txtStyle,
            decoration: _deco('email@mfano.com', Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email inahitajika';
              if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$').hasMatch(v.trim())) {
                return 'Email si sahihi';
              }
              return null;
            },
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Simu (Hiari)',
          hint: 'phone',
          child: TextFormField(
            controller: _phoneCtrl,
            style: _txtStyle,
            decoration: _deco('+255 7xx xxx xxx', Icons.phone_outlined),
            keyboardType: TextInputType.phone,
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Nywila *',
          hint: 'password',
          child: TextFormField(
            controller: _passCtrl,
            obscureText: _obs1,
            style: _txtStyle,
            decoration: _deco('Min. herufi 6', Icons.lock_outline_rounded).copyWith(
              suffixIcon: _eyeBtn(_obs1, () => setState(() => _obs1 = !_obs1)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Nywila inahitajika';
              if (v.length < 6) return 'Angalau herufi 6';
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Thibitisha Nywila *',
          hint: 'confirm_pass',
          child: TextFormField(
            controller: _pass2Ctrl,
            obscureText: _obs2,
            style: _txtStyle,
            decoration: _deco('Andika nywila tena', Icons.lock_outline_rounded).copyWith(
              suffixIcon: _eyeBtn(_obs2, () => setState(() => _obs2 = !_obs2)),
            ),
            validator: (v) => v != _passCtrl.text ? 'Nywila hazifanani' : null,
          ),
        ),
        const SizedBox(height: 24),

        if (_error != null) ...[_errorBox(_error!), const SizedBox(height: 14)],

        _primaryBtn(
          label: 'Endelea — Biashara →',
          icon: Icons.arrow_forward_rounded,
          color: AppColors.primary,
          onTap: _nextStep,
        ),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════
  // Step 2 — Business
  // ══════════════════════════════════════════════════════
  Widget _buildStep2() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
    child: Form(
      key: _step2Key,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader('🏪', 'Maelezo ya Biashara',
            'Tawi la kwanza "Main Branch" litaundwa moja kwa moja'),
        const SizedBox(height: 22),

        _fieldRow(
          label: 'Jina la Biashara *',
          hint: 'biz_name',
          child: TextFormField(
            controller: _bizCtrl,
            style: _txtStyle,
            decoration: _deco('mf. Duka la Mama Anna', Icons.storefront_outlined),
            validator: (v) => v == null || v.trim().isEmpty ? 'Jina la biashara linahitajika' : null,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Trade Name (Hiari)',
          hint: 'trade_name',
          child: TextFormField(
            controller: _tradeCtrl,
            style: _txtStyle,
            decoration: _deco('Kama ni tofauti na jina rasmi', Icons.business_center_outlined),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Simu ya Biashara',
          hint: 'biz_phone',
          child: TextFormField(
            controller: _bizPhCtrl,
            style: _txtStyle,
            decoration: _deco('+255 7xx xxx xxx', Icons.phone_outlined),
            keyboardType: TextInputType.phone,
          ),
        ),
        const SizedBox(height: 16),

        _fieldRow(
          label: 'Anwani / Mahali',
          hint: 'address',
          child: TextFormField(
            controller: _addrCtrl,
            style: _txtStyle,
            decoration: _deco('mf. Kariakoo, Dar es Salaam', Icons.location_on_outlined),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),

        // Country picker
        _fieldRow(
          label: 'Nchi',
          hint: 'country',
          child: GeoPickerTile(
            value: _country,
            icon: Icons.flag_outlined,
            placeholder: 'Chagua nchi...',
            onTap: _pickCountry,
          ),
        ),
        const SizedBox(height: 16),

        // Currency picker
        _fieldRow(
          label: 'Sarafu',
          hint: 'currency',
          child: GeoPickerTile(
            value: () {
              final m = kCurrencies.firstWhere(
                (c) => c.$1 == _currency, orElse: () => (_currency, ''));
              return m.$2.isNotEmpty ? '$_currency — ${m.$2}' : _currency;
            }(),
            icon: Icons.attach_money_rounded,
            placeholder: 'Chagua sarafu...',
            onTap: _pickCurrency,
          ),
        ),
        const SizedBox(height: 22),

        if (_error != null) ...[_errorBox(_error!), const SizedBox(height: 14)],

        // Trial notice
        _trialCard(),
        const SizedBox(height: 20),

        _primaryBtn(
          label: _loading ? 'Inasajili...' : '🎉  Sajili Biashara',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.accent,
          onTap: _loading ? null : _register,
          loading: _loading,
        ),
        const SizedBox(height: 12),

        TextButton.icon(
          onPressed: _loading ? null : _prevStep,
          icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textMuted),
          label: Text('Rudi — Akaunti',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      ]),
    ),
  );

  // ── Shared field row with tooltip ──────────────────────
  Widget _fieldRow({
    required String label,
    required String hint,
    required Widget child,
    Widget? extra,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text(label,
          style: TextStyle(
              color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      _InfoIcon(message: _kHints[hint] ?? ''),
    ]),
    const SizedBox(height: 8),
    child,
    if (extra != null) ...[const SizedBox(height: 6), extra],
  ]);

  // ── Section header ─────────────────────────────────────
  Widget _sectionHeader(String emoji, String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      Text(sub, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ],
  );

  Widget _trialCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.accent.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.accent.withAlpha(60)),
    ),
    child: Row(children: [
      const Text('🎁', style: TextStyle(fontSize: 22)),
      const SizedBox(width: 12),
      const Expanded(
        child: Text(
          'Utapata trial ya BURE ya miezi 3 baada ya kusajili!\nHuhitaji kadi ya benki.',
          style: TextStyle(color: AppColors.accent, fontSize: 12,
              fontWeight: FontWeight.w600, height: 1.5),
        ),
      ),
    ]),
  );

  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool loading = false,
  }) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: loading || onTap == null
              ? null
              : LinearGradient(
                  colors: [color, color.withAlpha(180)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight),
          color: loading ? AppColors.border : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading || onTap == null
              ? null
              : [BoxShadow(color: color.withAlpha(70), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Icon(icon, color: Colors.white, size: 20),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.red.shade900.withAlpha(55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.redAccent.withAlpha(120)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(msg,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.5)),
      ),
    ]),
  );

  Widget _eyeBtn(bool obscure, VoidCallback toggle) => IconButton(
    icon: Icon(
      obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      color: AppColors.textMuted, size: 20,
    ),
    onPressed: toggle,
  );

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
    filled: true,
    fillColor: AppColors.bgInput,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  TextStyle get _txtStyle => TextStyle(color: AppColors.textWhite, fontSize: 14);
}

// ── Info Icon with Tooltip popup ───────────────────────────────────────────────
class _InfoIcon extends StatelessWidget {
  final String message;
  const _InfoIcon({required this.message});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '', // we show custom dialog on tap
      child: InkWell(
        onTap: () => _show(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.primary),
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    final overlay = Overlay.of(context);
    final entry   = OverlayEntry(builder: (_) => _InfoBubble(message: message));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), entry.remove);
  }
}

class _InfoBubble extends StatefulWidget {
  final String message;
  const _InfoBubble({required this.message});
  @override
  State<_InfoBubble> createState() => _InfoBubbleState();
}

class _InfoBubbleState extends State<_InfoBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3, milliseconds: 500),
        () { if (mounted) _ctrl.reverse(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.12,
      left: 20, right: 20,
      child: ScaleTransition(
        scale: _anim,
        child: FadeTransition(
          opacity: _anim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(100)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(50),
                    blurRadius: 16, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.message,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.5)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
