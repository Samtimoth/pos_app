import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _businesses = [];
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  late final _tab = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.user == null) return;
    setState(() => _loading = true);
    try {
      final res = await app.api!.getSuperAdminBusinesses(
        requesterUserId: app.user!.userId,
        q: _search,
      );
      if (mounted && res['success'] == true) {
        setState(() {
          _businesses = (res['businesses'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _plans = (res['plans'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final nav = Navigator.of(context);
    await context.read<AppProvider>().logout();
    if (!mounted) return;
    context.read<CartProvider>().clear();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openActions(Map<String, dynamic> biz) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubscriptionActionSheet(business: biz, plans: _plans),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Super Admin',
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Simamia Biashara na Subscriptions',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Dashibodi'),
            Tab(text: 'Biashara'),
            Tab(text: 'Malipo'),
            Tab(text: 'Matangazo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SuperAdminDashboardTab(onNavigateTab: (i) => _tab.animateTo(i)),
          _buildBusinessesTab(),
          const _PaymentsTab(),
          _AnnouncementsTab(businesses: _businesses),
        ],
      ),
    );
  }

  // Groups the flat business list by owner, preserving first-seen order.
  List<MapEntry<String, List<Map<String, dynamic>>>> _groupByOwner() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final biz in _businesses) {
      final ownerId = biz['owner_id'];
      final key = ownerId != null ? 'id_$ownerId' : 'biz_${biz['business_id']}';
      groups.putIfAbsent(key, () => []).add(biz);
    }
    return groups.entries.toList();
  }

  Widget _buildBusinessesTab() {
    final owners = _groupByOwner();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(
              hintText: 'Tafuta biashara, shop code, mmiliki...',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.bgCard,
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
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (v) => _search = v,
            onSubmitted: (_) => _load(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _businesses.isEmpty
              ? Center(
                  child: Text(
                    'Hakuna biashara',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: owners.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _OwnerGroupCard(
                    businesses: owners[i].value,
                    onBusinessTap: _openActions,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Tab — Aggregate stats overview
// ─────────────────────────────────────────────────────────────────────────────
class _SuperAdminDashboardTab extends StatefulWidget {
  final void Function(int) onNavigateTab;
  const _SuperAdminDashboardTab({required this.onNavigateTab});
  @override
  State<_SuperAdminDashboardTab> createState() =>
      _SuperAdminDashboardTabState();
}

class _SuperAdminDashboardTabState extends State<_SuperAdminDashboardTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  final _numFmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.user == null) return;
    setState(() => _loading = true);
    try {
      final res = await app.api!.getSuperAdminStats(app.user!.userId);
      if (mounted && res['success'] == true) {
        setState(() => _stats = Map<String, dynamic>.from(res['stats'] as Map));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final app = context.watch<AppProvider>();
    final s = _stats ?? {};
    final revenue = ((s['total_revenue_cents'] ?? 0) as int) / 100;
    final pendingAmt = ((s['pending_amount_cents'] ?? 0) as int) / 100;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(revenue, app.user?.fullname ?? 'SuperAdmin'),
          ),
          SliverToBoxAdapter(child: _buildKpiRow(s, pendingAmt)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader(double revenue, String fullname) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withAlpha(25),
              child: Text(
                fullname.isNotEmpty ? fullname[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Habari,',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    fullname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Mapato Yote Yaliyokusanywa',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        AnimatedCounter(
          value: revenue,
          prefix: 'TZS ',
          formatter: (v) => _numFmt.format(v),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kutoka kwa malipo yaliyoidhinishwa',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _headerActionBtn(
                'Ona Biashara',
                Icons.storefront_rounded,
                () => widget.onNavigateTab(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _headerActionBtn(
                'Ona Malipo',
                Icons.receipt_long_rounded,
                () => widget.onNavigateTab(2),
                outlined: true,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _headerActionBtn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : AppColors.accent,
          borderRadius: BorderRadius.circular(14),
          border: outlined
              ? Border.all(color: Colors.white.withAlpha(60), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: outlined ? Colors.white : AppColors.bgDark,
              size: 17,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: outlined ? Colors.white : AppColors.bgDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(Map<String, dynamic> s, double pendingAmt) {
    final items = [
      _KpiItem(
        'Biashara Zote',
        '${s['total_businesses'] ?? 0}',
        Icons.storefront_rounded,
        AppColors.primaryLt,
      ),
      _KpiItem(
        'Vifaa Vinavyotumika',
        '${s['total_devices'] ?? 0}',
        Icons.devices_rounded,
        AppColors.chartBlue,
      ),
      _KpiItem(
        'Zinazolipia',
        '${s['subscription_active'] ?? 0}',
        Icons.verified_rounded,
        AppColors.accent,
      ),
      _KpiItem(
        'Kwenye Trial',
        '${s['subscription_trial'] ?? 0}',
        Icons.timer_outlined,
        AppColors.chartOrange,
      ),
      _KpiItem(
        'Hazina Subscription',
        '${s['subscription_none'] ?? 0}',
        Icons.error_outline_rounded,
        AppColors.chartRed,
      ),
      _KpiItem(
        'Malipo Yanayosubiri (TZS ${_numFmt.format(pendingAmt)})',
        '${s['pending_payments_count'] ?? 0}',
        Icons.hourglass_top_rounded,
        AppColors.chartPurple,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: items
            .asMap()
            .entries
            .map(
              (e) => Padding(
                padding: EdgeInsets.only(left: e.key == 0 ? 0 : 10),
                child: SizedBox(
                  width: 130,
                  child: StaggeredItem(
                    index: e.key,
                    delay: const Duration(milliseconds: 70),
                    child: _kpiCard(e.value),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _kpiCard(_KpiItem item) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: item.color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(
          item.value,
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _KpiItem {
  final String label, value;
  final IconData icon;
  final Color color;
  _KpiItem(this.label, this.value, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Payments Tab — Review pending manual payment submissions
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab();
  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.user == null) return;
    setState(() => _loading = true);
    try {
      final res = await app.api!.getSuperAdminPayments(
        requesterUserId: app.user!.userId,
        status: _filter,
      );
      if (mounted && res['success'] == true) {
        setState(() {
          _payments = (res['payments'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _review(Map<String, dynamic> payment, String action) async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.user == null) return;
    try {
      final res = await app.api!.reviewPayment(
        requesterUserId: app.user!.userId,
        paymentId: payment['payment_id'] as int,
        action: action,
      );
      if (!mounted) return;
      AppNotification.show(
        context,
        res['message'] as String? ?? '✅',
        res['success'] == true ? AppColors.accent : AppColors.chartRed,
        icon: res['success'] == true
            ? Icons.check_circle_rounded
            : Icons.error_rounded,
      );
      if (res['success'] == true) _load();
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          '$e',
          AppColors.chartRed,
          icon: Icons.error_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              _filterChip(
                'pending',
                'Pending',
                Icons.hourglass_top_rounded,
                AppColors.chartOrange,
              ),
              const SizedBox(width: 8),
              _filterChip(
                'approved',
                'Approved',
                Icons.check_circle_rounded,
                AppColors.accent,
              ),
              const SizedBox(width: 8),
              _filterChip(
                'rejected',
                'Rejected',
                Icons.cancel_rounded,
                Colors.redAccent,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _payments.isEmpty
              ? Center(
                  child: Text(
                    'Hakuna malipo',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _payments.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _PaymentCard(
                    payment: _payments[i],
                    onApprove: () => _review(_payments[i], 'approve'),
                    onReject: () => _review(_payments[i], 'reject'),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label, IconData icon, Color color) {
    final selected = _filter == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 15, color: selected ? Colors.white : color),
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filter = value);
        _load();
      },
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.bgCard,
      side: BorderSide(color: selected ? color : AppColors.border),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Announcements Tab — SuperAdmin push notification broadcasts
// ─────────────────────────────────────────────────────────────────────────────
class _AnnouncementsTab extends StatefulWidget {
  final List<Map<String, dynamic>> businesses;
  const _AnnouncementsTab({required this.businesses});
  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;
  bool _sending = false;
  bool _fcmConfigured = true;
  Map<String, dynamic>? _target; // null = Zote (biashara zote)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null) return;
    setState(() => _loadingHistory = true);
    try {
      final res = await app.api!.listAnnouncements();
      if (mounted && res['success'] == true) {
        setState(() {
          _history = (res['announcements'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _fcmConfigured = res['fcm_configured'] == true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Andika kichwa na ujumbe', AppColors.chartOrange);
      return;
    }
    final app = context.read<AppProvider>();
    if (app.api == null) return;
    setState(() => _sending = true);
    try {
      final res = await app.api!.sendAnnouncement(
        title: title,
        body: body,
        businessId: _target?['business_id'] as int?,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        setState(() => _target = null);
        _snack('${res['message'] ?? '✅'}', AppColors.accent);
        _load();
      } else {
        _snack('${res['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          if (!_fcmConfigured)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.chartOrange.withAlpha(24), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.chartOrange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Firebase bado haijawekwa kikamilifu server-side — matangazo yanahifadhiwa lakini hayafiki kwenye vifaa bado.',
                    style: TextStyle(color: AppColors.chartOrange, fontSize: 12),
                  ),
                ),
              ]),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tuma Tangazo Jipya', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              _field(_titleCtrl, 'Kichwa cha Habari', Icons.title_rounded),
              const SizedBox(height: 10),
              _field(_bodyCtrl, 'Ujumbe', Icons.notes_rounded, maxLines: 3),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showModalBottomSheet<Map<String, dynamic>?>(
                    context: context,
                    backgroundColor: AppColors.bgCard,
                    builder: (_) => _TargetPicker(businesses: widget.businesses),
                  );
                  if (mounted) setState(() => _target = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Icon(Icons.campaign_outlined, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_target == null ? 'Lengo: Biashara Zote' : 'Lengo: ${_target!['business_name']}',
                          style: TextStyle(color: AppColors.textWhite, fontSize: 13)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Inatuma...' : 'Tuma Tangazo', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Text('Historia ya Matangazo', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          if (_loadingHistory)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Hakuna tangazo bado', style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final a in _history) _announcementRow(a),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(color: AppColors.textWhite, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        ),
      );

  Widget _announcementRow(Map<String, dynamic> a) {
    final sent = (a['sent_count'] as num?)?.toInt() ?? 0;
    final failed = (a['failed_count'] as num?)?.toInt() ?? 0;
    final configured = a['fcm_configured'] == true;
    final date = DateTime.tryParse('${a['created_at']}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${a['title']}', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13))),
          Text(date == null ? '' : DateFormat('dd MMM, HH:mm').format(date), style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ]),
        const SizedBox(height: 4),
        Text('${a['body']}', style: TextStyle(color: AppColors.textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(children: [
          Text(a['business_name'] != null ? 'Lengo: ${a['business_name']}' : 'Lengo: Biashara Zote',
              style: TextStyle(color: AppColors.chartBlue, fontSize: 10.5)),
          const Spacer(),
          if (!configured)
            Text('Halijatumwa', style: TextStyle(color: AppColors.chartOrange, fontSize: 10.5, fontWeight: FontWeight.w700))
          else
            Text('Vifaa: $sent/${sent + failed}', style: TextStyle(color: AppColors.accent, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _TargetPicker extends StatelessWidget {
  final List<Map<String, dynamic>> businesses;
  const _TargetPicker({required this.businesses});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Chagua Lengo la Tangazo', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        ListTile(
          leading: Icon(Icons.public_rounded, color: AppColors.accent),
          title: Text('Biashara Zote', style: TextStyle(color: AppColors.textWhite)),
          onTap: () => Navigator.pop(context, null),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: businesses.length,
            itemBuilder: (_, i) {
              final b = businesses[i];
              return ListTile(
                leading: Icon(Icons.storefront_outlined, color: AppColors.textMuted),
                title: Text('${b['business_name']}', style: TextStyle(color: AppColors.textWhite, fontSize: 13)),
                onTap: () => Navigator.pop(context, b),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _PaymentCard({
    required this.payment,
    required this.onApprove,
    required this.onReject,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return AppColors.accent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return AppColors.chartOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,###', 'en_US');
    final amount = numFmt.format(((payment['amount_cents'] as int) / 100));
    final status = payment['status'] as String;
    final pending = status == 'pending';
    final color = _statusColor(status);
    String paidAt = '';
    try {
      paidAt = DateFormat(
        'dd MMM yyyy, HH:mm',
      ).format(DateTime.parse(payment['paid_at'] as String));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            payment['business_name'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${payment['submitted_by']} · ${payment['plan_name']}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.payments_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                '${payment['currency']} $amount',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (paidAt.isNotEmpty) ...[
                const Spacer(),
                Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 3),
                Text(
                  paidAt,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Ref: ${payment['ref_code']}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          if ((payment['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              payment['notes'] as String,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if (payment['proof_file'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    payment['proof_file'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Idhinisha'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Kataa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owner Group — one card per owner, expandable to reveal all their businesses
// ─────────────────────────────────────────────────────────────────────────────
class _OwnerGroupCard extends StatefulWidget {
  final List<Map<String, dynamic>> businesses;
  final void Function(Map<String, dynamic>) onBusinessTap;
  const _OwnerGroupCard({
    required this.businesses,
    required this.onBusinessTap,
  });

  @override
  State<_OwnerGroupCard> createState() => _OwnerGroupCardState();
}

class _OwnerGroupCardState extends State<_OwnerGroupCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final first = widget.businesses.first;
    final ownerName = (first['owner_name'] as String? ?? '').trim();
    final ownerUsername = (first['owner_username'] as String? ?? '');
    final count = widget.businesses.length;
    final totalDevices = widget.businesses.fold<int>(
      0,
      (sum, b) => sum + ((b['device_count'] as int?) ?? 0),
    );
    final activeCount = widget.businesses
        .where((b) => b['subscription_active'] == true)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.gradPurple,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          ownerName.isNotEmpty
                              ? ownerName[0].toUpperCase()
                              : 'O',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
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
                            ownerName.isNotEmpty ? ownerName : ownerUsername,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@$ownerUsername · $count biashara · $activeCount zinalipia',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.devices_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$totalDevices',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: widget.businesses
                    .map(
                      (biz) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _BusinessSubCard(
                          biz: biz,
                          onTap: () => widget.onBusinessTap(biz),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _BusinessSubCard extends StatelessWidget {
  final Map<String, dynamic> biz;
  final VoidCallback onTap;
  const _BusinessSubCard({required this.biz, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'trial':
        return AppColors.chartOrange;
      case 'active':
        return AppColors.accent;
      case 'past_due':
        return Colors.redAccent;
      case 'canceled':
      case 'expired':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = biz['subscription_active'] as bool;
    final status = biz['subscription_status'] as String;
    final daysLeft = biz['subscription_days_left'] as int;
    final color = _statusColor(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.gradPrimary),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (biz['business_name'] as String).isNotEmpty
                        ? (biz['business_name'] as String)[0].toUpperCase()
                        : 'B',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                      biz['business_name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${biz['owner_name']} · ${biz['owner_username']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.devices_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${biz['device_count'] ?? 0} vifaa',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withAlpha(80)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active ? '$daysLeft siku zimebaki' : 'Imeisha',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionActionSheet extends StatefulWidget {
  final Map<String, dynamic> business;
  final List<Map<String, dynamic>> plans;
  const _SubscriptionActionSheet({required this.business, required this.plans});

  @override
  State<_SubscriptionActionSheet> createState() =>
      _SubscriptionActionSheetState();
}

class _SubscriptionActionSheetState extends State<_SubscriptionActionSheet> {
  late int? _planId = widget.plans.isNotEmpty
      ? widget.plans.first['plan_id'] as int
      : null;
  final _daysCtrl = TextEditingController(text: '90');
  bool _saving = false;

  @override
  void dispose() {
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(String action) async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.user == null) return;
    final days = int.tryParse(_daysCtrl.text.trim());

    setState(() => _saving = true);
    try {
      final res = await app.api!.manageSubscription(
        requesterUserId: app.user!.userId,
        businessId: widget.business['business_id'] as int,
        action: action,
        planId: _planId,
        days: days,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotification.show(
          context,
          res['message'] as String? ?? '✅',
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
    final biz = widget.business;
    return Container(
      margin: EdgeInsets.only(top: mq.padding.top + 80),
      padding: EdgeInsets.fromLTRB(20, 12, 20, mq.viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              biz['business_name'] as String? ?? '',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${biz['owner_name']} · Hali: ${biz['subscription_status']}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),

            Text(
              'Mpango',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _planId,
                  isExpanded: true,
                  dropdownColor: AppColors.bgCard,
                  style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                  items: widget.plans
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['plan_id'] as int,
                          child: Text(
                            '${p['name']} (${p['currency']} ${((p['price_cents'] as int) / 100).toStringAsFixed(0)})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _planId = v),
                ),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _daysCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                labelText: 'Idadi ya siku',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                prefixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.textMuted,
                  size: 17,
                ),
                filled: true,
                fillColor: AppColors.bg,
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
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    'Washa (Active)',
                    AppColors.accent,
                    () => _run('activate_paid'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    'Trial',
                    AppColors.chartOrange,
                    () => _run('start_trial'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    'Ongeza Muda',
                    AppColors.chartBlue,
                    () => _run('extend'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    'Sitisha',
                    Colors.redAccent,
                    () => _run('cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      ElevatedButton(
        onPressed: _saving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
}
