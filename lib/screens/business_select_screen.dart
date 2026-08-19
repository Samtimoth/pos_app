import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business.dart';
import '../providers/app_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/geo_data.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../widgets/first_run_tutorial.dart';

class BusinessSelectScreen extends StatefulWidget {
  /// Auto-continue to the dashboard when the account has only one
  /// business + one branch. Should be true only for the initial
  /// login/splash flow — disable it when the user explicitly opened
  /// this screen to switch or manage businesses.
  final bool autoSelectIfSingle;

  const BusinessSelectScreen({super.key, this.autoSelectIfSingle = true});

  @override
  State<BusinessSelectScreen> createState() => _BusinessSelectScreenState();
}

class _BusinessSelectScreenState extends State<BusinessSelectScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Business> _businesses = [];

  // Selected branch per business
  final Map<int, Branch?> _selectedBranch = {};

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _tutorialQueued = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadBusinesses();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = context.read<AppProvider>();
      final list = await app.loadBusinesses();
      if (!mounted) return;

      if (list.isEmpty) {
        setState(() {
          _error = 'Hakuna biashara zilizounganishwa na akaunti yako.';
          _loading = false;
        });
        return;
      }

      // Pre-select default branch for each business
      for (final biz in list) {
        final defBranch = biz.defaultBranchId != null
            ? biz.branches.firstWhere(
                (b) => b.branchId == biz.defaultBranchId,
                orElse: () => biz.branches.first,
              )
            : (biz.branches.isNotEmpty ? biz.branches.first : null);
        _selectedBranch[biz.businessId] = defBranch;
      }

      setState(() {
        _businesses = list;
        _loading = false;
      });
      _fadeCtrl.forward();

      // Auto-select if only 1 business + 1 branch (initial login flow only)
      final shouldAutoSelect =
          widget.autoSelectIfSingle &&
          list.length == 1 &&
          list.first.branches.length == 1;
      if (shouldAutoSelect) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _selectBusiness(list.first);
        return;
      }
      _queueTutorial();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Hitilafu: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  void _queueTutorial() {
    if (_tutorialQueued) return;
    _tutorialQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstRunTutorial.showIfNeeded(
        context,
        storageKey: 'business_select',
        steps: const [
          TutorialStep(
            icon: Icons.storefront_rounded,
            title: 'Chagua biashara',
            body:
                'Gusa biashara unayotaka kuendesha. Kama biashara ina matawi mengi, chagua tawi kwanza.',
          ),
          TutorialStep(
            icon: Icons.add_business_rounded,
            title: 'Ongeza biashara',
            body:
                'Kitufe cha chini kinakuwezesha kuongeza biashara mpya kwenye akaunti hii.',
          ),
          TutorialStep(
            icon: Icons.logout_rounded,
            title: 'Toka kwa usalama',
            body:
                'Ukibonyeza logout app itafuta session na kukurudisha login bila kubakiza screens za zamani.',
          ),
        ],
      );
    });
  }

  Future<void> _selectBusiness(Business biz) async {
    final branch = _selectedBranch[biz.businessId];
    if (branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tafadhali chagua tawi kwanza')),
      );
      return;
    }
    // Save references BEFORE the async gap to avoid context-across-async-gap lint
    final appProvider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    await appProvider.selectBusinessAndBranch(biz, branch);
    if (!mounted) return;
    navigator.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const DashboardScreen(),
        transitionsBuilder: (ctx, anim, sa, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PremiumPageEntrance(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                  ? _buildError()
                  : FadeTransition(opacity: _fadeAnim, child: _buildList()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBusiness,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text(
          'Ongeza Biashara',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: AppColors.gradHeader,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 22),
        child: Row(
          children: [
            if (Navigator.canPop(context))
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chagua Biashara',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Bonyeza biashara unayotaka kuingia',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
              ),
              tooltip: 'Wasifu Wangu',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadBusinesses,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Toka',
              onPressed: () async {
                final nav = Navigator.of(context);
                await context.read<AppProvider>().logout();
                if (!mounted) return;
                context.read<CartProvider>().clear();
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showAddBusiness() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddBusinessSheet(),
    );
    if (created == true) _loadBusinesses();
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadBusinesses,
            icon: const Icon(Icons.refresh),
            label: const Text('Jaribu Tena'),
          ),
        ],
      ),
    ),
  );

  Widget _buildList() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    itemCount: _businesses.length,
    itemBuilder: (ctx, i) {
      final biz = _businesses[i];
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + i * 90),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 24),
            child: Transform.scale(scale: 0.94 + (0.06 * v), child: child),
          ),
        ),
        child: _BusinessCard(
          business: biz,
          selectedBranch: _selectedBranch[biz.businessId],
          onBranchChanged: (b) =>
              setState(() => _selectedBranch[biz.businessId] = b),
          onSelect: () => _selectBusiness(biz),
          onEdited: (updated) {
            setState(() {
              _businesses[i] = updated;
            });
            context.read<AppProvider>().updateLocalBusiness(updated);
          },
        ),
      );
    },
  );
}

// ── Business Card ──────────────────────────────────────────────────────────────
class _BusinessCard extends StatelessWidget {
  final Business business;
  final Branch? selectedBranch;
  final ValueChanged<Branch?> onBranchChanged;
  final VoidCallback onSelect;
  final ValueChanged<Business> onEdited;

  const _BusinessCard({
    required this.business,
    required this.selectedBranch,
    required this.onBranchChanged,
    required this.onSelect,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final biz = business;
    final multiBranch = biz.branches.length > 1;
    final canEdit = biz.role == 'Owner' || biz.role == 'Admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: multiBranch ? null : onSelect,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row: logo · name/subtitle · arrow ──────────────
                Row(
                  children: [
                    _buildLogo(biz),
                    const SizedBox(width: 12),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            biz.branchCount == 1
                                ? '1 tawi · ${biz.role}'
                                : '${biz.branchCount} matawi · ${biz.role}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: AppColors.textMuted,
                          size: 19,
                        ),
                        tooltip: 'Hariri Biashara',
                        onPressed: () => _EditBusinessSheet.show(
                          context,
                          biz,
                          onSaved: onEdited,
                        ),
                      ),
                    if (!multiBranch)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 22,
                      ),
                  ],
                ),

                // ── Branch Selector (only shown when a choice is needed) ──
                if (multiBranch) ...[
                  const SizedBox(height: 12),
                  _BranchDropdown(
                    branches: biz.branches,
                    selected: selectedBranch,
                    onChanged: onBranchChanged,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Ingia',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Business biz) {
    // If logo URL available, show network image
    if (biz.logoPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          biz.logoPath,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => _avatarFallback(biz),
        ),
      );
    }
    return _avatarFallback(biz);
  }

  Widget _avatarFallback(Business biz) {
    final letter = biz.businessName.isNotEmpty
        ? biz.businessName[0].toUpperCase()
        : 'B';
    final colors = _roleGradient(biz.role);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<Color> _roleGradient(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return AppColors.gradPrimary;
      case 'admin':
        return AppColors.gradPurple;
      case 'manager':
        return AppColors.gradGreen;
      case 'cashier':
        return AppColors.gradOrange;
      default:
        return [const Color(0xFF475569), const Color(0xFF334155)];
    }
  }
}

// ── Branch Dropdown ────────────────────────────────────────────────────────────
class _BranchDropdown extends StatelessWidget {
  final List<Branch> branches;
  final Branch? selected;
  final ValueChanged<Branch?> onChanged;

  const _BranchDropdown({
    required this.branches,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<Branch>(
    // ignore: deprecated_member_use
    value: selected,
    isExpanded: true,
    decoration: InputDecoration(
      filled: true,
      fillColor: AppColors.bgInput,
      prefixIcon: Icon(
        Icons.store_rounded,
        color: AppColors.textMuted,
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    ),
    dropdownColor: AppColors.bgCard,
    style: TextStyle(color: AppColors.textWhite, fontSize: 14),
    items: branches
        .map(
          (b) => DropdownMenuItem(
            value: b,
            child: Row(
              children: [
                Icon(
                  b.isActive ? Icons.circle : Icons.circle_outlined,
                  size: 8,
                  color: b.isActive ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(b.branchName, overflow: TextOverflow.ellipsis),
                ),
                if (b.branchCode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    b.branchCode,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

// ── Edit Business Sheet ──────────────────────────────────────────────────────
class _EditBusinessSheet extends StatefulWidget {
  final Business business;
  final ValueChanged<Business> onSaved;

  const _EditBusinessSheet({required this.business, required this.onSaved});

  static void show(
    BuildContext context,
    Business business, {
    required ValueChanged<Business> onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBusinessSheet(business: business, onSaved: onSaved),
    );
  }

  @override
  State<_EditBusinessSheet> createState() => _EditBusinessSheetState();
}

class _EditBusinessSheetState extends State<_EditBusinessSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(
    text: widget.business.businessName,
  );
  late final _tradeCtrl = TextEditingController(
    text: widget.business.tradeName,
  );
  late final _phoneCtrl = TextEditingController(text: widget.business.phone);
  late final _addressCtrl = TextEditingController(
    text: widget.business.address,
  );
  late final _receiptHeaderCtrl = TextEditingController(
    text: widget.business.receiptHeader,
  );
  late final _receiptFooterCtrl = TextEditingController(
    text: widget.business.receiptFooter,
  );
  late String _country = widget.business.country;
  late String _currency = widget.business.currency;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tradeCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _receiptHeaderCtrl.dispose();
    _receiptFooterCtrl.dispose();
    super.dispose();
  }

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
        labelOf: currencyLabel,
        current: _currency,
      ),
    );
    if (result != null) setState(() => _currency = result);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final app = context.read<AppProvider>();
    final user = app.user;
    if (app.api == null || user == null) return;

    setState(() => _saving = true);
    try {
      final res = await app.api!.updateBusiness(
        userId: user.userId,
        businessId: widget.business.businessId,
        businessName: _nameCtrl.text.trim(),
        tradeName: _tradeCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        country: _country,
        currency: _currency,
        receiptHeader: _receiptHeaderCtrl.text.trim(),
        receiptFooter: _receiptFooterCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['success'] == true) {
        widget.onSaved(
          Business(
            businessId: widget.business.businessId,
            businessName: _nameCtrl.text.trim(),
            tradeName: _tradeCtrl.text.trim(),
            receiptHeader: _receiptHeaderCtrl.text.trim(),
            receiptFooter: _receiptFooterCtrl.text.trim(),
            role: widget.business.role,
            country: _country,
            currency: _currency,
            phone: _phoneCtrl.text.trim(),
            timezone: widget.business.timezone,
            address: _addressCtrl.text.trim(),
            logoPath: widget.business.logoPath,
            shopCode: widget.business.shopCode,
            isActive: widget.business.isActive,
            branchCount: widget.business.branchCount,
            defaultBranchId: widget.business.defaultBranchId,
            branches: widget.business.branches,
          ),
        );
        AppNotification.show(
          context,
          '✅ Biashara imesasishwa',
          AppColors.accent,
          icon: Icons.check_circle_rounded,
        );
        Navigator.pop(context);
      } else {
        AppNotification.show(
          context,
          res['message'] as String? ?? 'Hitilafu',
          AppColors.chartRed,
          icon: Icons.error_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          '$e',
          AppColors.chartRed,
          icon: Icons.error_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.only(top: mq.padding.top + 60),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.6,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scroll) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.gradPrimary,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hariri Biashara',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.textMuted,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _sheetField(
                        _nameCtrl,
                        'Jina la Biashara',
                        Icons.storefront_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Jina linahitajika'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _sheetField(
                        _tradeCtrl,
                        'Jina la Kibiashara (hiari)',
                        Icons.badge_outlined,
                      ),
                      const SizedBox(height: 14),
                      _sheetField(
                        _phoneCtrl,
                        'Simu',
                        Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _sheetField(
                        _addressCtrl,
                        'Anwani',
                        Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _labeledPicker(
                              'Nchi',
                              GeoPickerTile(
                                value: _country,
                                icon: Icons.flag_outlined,
                                placeholder: 'Chagua nchi...',
                                onTap: _pickCountry,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _labeledPicker(
                              'Sarafu',
                              GeoPickerTile(
                                value: _currency,
                                icon: Icons.attach_money_rounded,
                                placeholder: 'Chagua sarafu...',
                                onTap: _pickCurrency,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.textMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Muonekano wa Risiti',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _sheetField(
                        _receiptHeaderCtrl,
                        'Kichwa cha Risiti (hiari)',
                        Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Ikiachwa wazi, jina la biashara ('
                          '${_nameCtrl.text.isEmpty ? "Jina la Biashara" : _nameCtrl.text}'
                          ') litatumika',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sheetField(
                        _receiptFooterCtrl,
                        'Ujumbe wa Chini ya Risiti (hiari)',
                        Icons.notes_outlined,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'mfano: "Asante kwa kununua kwetu!"',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer (sticky Save button) ──────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                mq.viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _saving ? 'Inahifadhi...' : 'Hifadhi',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.textWhite, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 17),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
          borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5),
        ),
      ),
    );
  }

  Widget _labeledPicker(String label, Widget picker) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
      picker,
    ],
  );
}

// ── Add Business Sheet ───────────────────────────────────────────────────────
class _AddBusinessSheet extends StatefulWidget {
  const _AddBusinessSheet();

  @override
  State<_AddBusinessSheet> createState() => _AddBusinessSheetState();
}

class _AddBusinessSheetState extends State<_AddBusinessSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _country = 'Tanzania';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final app = context.read<AppProvider>();
    final user = app.user;
    if (app.api == null || user == null) return;

    setState(() => _saving = true);
    try {
      final res = await app.api!.createBusiness(
        userId: user.userId,
        businessName: _nameCtrl.text.trim(),
        country: _country,
        address: _addressCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotification.show(
          context,
          '✅ Biashara mpya imeongezwa',
          AppColors.accent,
          icon: Icons.check_circle_rounded,
        );
        Navigator.pop(context, true);
      } else {
        AppNotification.show(
          context,
          res['message'] as String? ?? 'Hitilafu',
          AppColors.chartRed,
          icon: Icons.error_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          '$e',
          AppColors.chartRed,
          icon: Icons.error_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.only(top: mq.padding.top + 100),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, mq.viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradPrimary,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.add_business_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ongeza Biashara Mpya',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameCtrl,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Jina linahitajika'
                    : null,
                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Jina la Biashara',
                  labelStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.storefront_outlined,
                    color: AppColors.textMuted,
                    size: 17,
                  ),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.primaryLt,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _addressCtrl,
                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Anwani (hiari)',
                  labelStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: AppColors.textMuted,
                    size: 17,
                  ),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.primaryLt,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Nchi',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              GeoPickerTile(
                value: _country,
                icon: Icons.flag_outlined,
                placeholder: 'Chagua nchi...',
                onTap: _pickCountry,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _saving ? 'Inahifadhi...' : 'Ongeza',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
