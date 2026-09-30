import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/first_run_tutorial.dart';
import '../widgets/premium_empty_state.dart';
import '../l10n/app_l10n.dart';
import 'purchase_orders_screen.dart';
import 'purchases_screen.dart';
import 'quotations_screen.dart';
import 'stock_transfers_screen.dart';
import 'suppliers_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Manage Screen — Categories + Units
// ─────────────────────────────────────────────────────────────────────────────
class ManageScreen extends StatefulWidget {
  final bool desktop;
  final int initialTab;
  /// Tab key (matches `_visible`'s string keys, e.g. 'staff', 'purchases')
  /// to jump to directly — more reliable than [initialTab]'s raw index,
  /// since tab positions shift depending on which tabs a role/business can
  /// see. Takes precedence over [initialTab] when the key is found.
  final String? initialTabKey;
  const ManageScreen({super.key, this.desktop = false, this.initialTab = 0, this.initialTabKey});
  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Hatua 1: tabs zinaonekana kwa role ──
  // Categories/Units: canManageProducts · Staff: canManageStaff
  late final List<String> _visible;

  // ── Mobile chip selector (premium scrollable tabs) ──
  int _selected = 0;
  final ScrollController _chipScroll = ScrollController();
  final List<GlobalKey> _chipKeys = [];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    final user = app.user;
    final multiBranch = (app.selectedBusiness?.branches.length ?? 0) > 1;
    _visible = [
      if (user == null || user.canManageProducts) ...[
        'categories', 'units', 'suppliers', 'purchase_orders', 'purchases', 'quotations',
        if (multiBranch) 'stock_transfers',
      ],
      if (user == null || user.canManageStaff) 'staff',
    ];
    var initIdx = widget.initialTab;
    if (widget.initialTabKey != null) {
      final keyed = _visible.indexOf(widget.initialTabKey!);
      if (keyed >= 0) initIdx = keyed;
    }
    if (_visible.isEmpty) {
      initIdx = 0;
    } else if (initIdx >= _visible.length) {
      initIdx = _visible.length - 1;
    }
    _tab = TabController(
      length: _visible.length,
      vsync: this,
      initialIndex: initIdx,
    );
    _selected = initIdx;
    _chipKeys.addAll(List.generate(_visible.length, (_) => GlobalKey()));
    _tab.addListener(_handleTabChanged);
    // Reveal the initially selected chip after the first layout — deep links
    // (initialTabKey) can start on a tab whose chip is off-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelectedChip());
  }

  @override
  void dispose() {
    _tab.removeListener(_handleTabChanged);
    _tab.dispose();
    _chipScroll.dispose();
    super.dispose();
  }

  // ── Mobile chip selector: tab sync + auto-reveal ────────────────────────
  void _handleTabChanged() {
    if (!mounted || _selected == _tab.index) return;
    setState(() => _selected = _tab.index);
    _revealSelectedChip();
  }

  void _selectTab(int i) {
    if (_selected == i) return;
    setState(() => _selected = i);
    _tab.animateTo(i);
  }

  void _revealSelectedChip() {
    if (_selected < 0 || _selected >= _chipKeys.length) return;
    final key = _chipKeys[_selected];
    if (key.currentContext == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  IconData _tabIcon(String key) => switch (key) {
    'categories' => Icons.category_rounded,
    'units' => Icons.straighten_rounded,
    'suppliers' => Icons.local_shipping_outlined,
    'purchase_orders' => Icons.request_quote_outlined,
    'purchases' => Icons.move_to_inbox_outlined,
    'quotations' => Icons.description_outlined,
    'stock_transfers' => Icons.sync_alt_rounded,
    _ => Icons.people_alt_rounded,
  };

  String _tabLabel(String key, L l) => switch (key) {
    'categories' => l.categoriesTab,
    'units' => l.unitsTab,
    'suppliers' => l.isSw ? 'Wasambazaji' : 'Suppliers',
    'purchase_orders' => l.isSw ? 'Maagizo' : 'Orders',
    'purchases' => l.isSw ? 'Manunuzi' : 'Purchases',
    'quotations' => l.isSw ? 'Nukuu' : 'Quotes',
    'stock_transfers' => l.isSw ? 'Uhamisho' : 'Transfers',
    _ => l.staffTab,
  };

  // ── Mobile: premium horizontally scrollable chip selector ───────────────
  Widget _buildMobileSelector() {
    return TutorialTarget(
      id: 'manage_tabs',
      child: SizedBox(
        height: 40,
        child: ListView(
          controller: _chipScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (var i = 0; i < _visible.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              KeyedSubtree(key: _chipKeys[i], child: _buildChip(i)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(int i) {
    final selected = _selected == i;
    final l = L.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(colors: AppColors.gradGreen)
            : null,
        color: selected ? null : Colors.white.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? Colors.white.withAlpha(130)
              : Colors.white.withAlpha(45),
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppColors.primaryLt.withAlpha(90)
                : Colors.transparent,
            blurRadius: selected ? 10 : 0,
            offset: Offset(0, selected ? 3 : 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectTab(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _tabIcon(_visible[i]),
                  size: 15,
                  color: selected ? Colors.white : Colors.white.withAlpha(170),
                ),
                const SizedBox(width: 6),
                Text(
                  _tabLabel(_visible[i], l),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : Colors.white.withAlpha(195),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    // ── Hatua 1: hakuna ruhusa yoyote → empty state (si crash) ──
    if (_visible.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                l.isSw ? 'Huna ruhusa ya sehemu hii' : 'You do not have permission for this section',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildTabBar({required bool onGradient}) => TutorialTarget(
      id: 'manage_tabs',
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: onGradient ? Colors.white.withAlpha(25) : AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onGradient ? Colors.white.withAlpha(45) : AppColors.border,
        ),
      ),
      child: TabBar(
        controller: _tab,
        isScrollable: _visible.length > 4,
        indicator: BoxDecoration(
          gradient: onGradient
              ? const LinearGradient(colors: [Colors.white, Colors.white])
              : const LinearGradient(colors: AppColors.gradPrimary),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        labelColor: onGradient ? AppColors.primary : Colors.white,
        unselectedLabelColor: onGradient ? Colors.white70 : AppColors.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          for (final t in _visible)
            if (t == 'categories')
              Tab(
                icon: const Icon(Icons.category_rounded, size: 16),
                text: l.categoriesTab,
              )
            else if (t == 'units')
              Tab(
                icon: const Icon(Icons.straighten_rounded, size: 16),
                text: l.unitsTab,
              )
            else if (t == 'suppliers')
              Tab(
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                text: l.isSw ? 'Wasambazaji' : 'Suppliers',
              )
            else if (t == 'purchase_orders')
              Tab(
                icon: const Icon(Icons.request_quote_outlined, size: 16),
                text: l.isSw ? 'Maagizo' : 'Orders',
              )
            else if (t == 'purchases')
              Tab(
                icon: const Icon(Icons.move_to_inbox_outlined, size: 16),
                text: l.isSw ? 'Manunuzi' : 'Purchases',
              )
            else if (t == 'quotations')
              Tab(
                icon: const Icon(Icons.description_outlined, size: 16),
                text: l.isSw ? 'Nukuu' : 'Quotes',
              )
            else if (t == 'stock_transfers')
              Tab(
                icon: const Icon(Icons.sync_alt_rounded, size: 16),
                text: l.isSw ? 'Uhamisho' : 'Transfers',
              )
            else
              Tab(
                icon: const Icon(Icons.people_alt_rounded, size: 16),
                text: l.staffTab,
              ),
        ],
      ),
    ),
    );
    final tabBar = buildTabBar(onGradient: false);

    if (widget.desktop) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
            color: Colors.transparent,
            child: tabBar,
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                for (final t in _visible)
                  if (t == 'categories')
                    _CategoryTab(desktop: true)
                  else if (t == 'units')
                    _UnitTab(desktop: true)
                  else if (t == 'suppliers')
                    const SuppliersScreen(desktop: true)
                  else if (t == 'purchase_orders')
                    const PurchaseOrdersScreen(desktop: true)
                  else if (t == 'purchases')
                    const PurchasesScreen(desktop: true)
                  else if (t == 'quotations')
                    const QuotationsScreen(desktop: true)
                  else if (t == 'stock_transfers')
                    const StockTransfersScreen(desktop: true)
                  else
                    _StaffTab(desktop: true),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PremiumPageEntrance(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.gradHeader,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (Navigator.of(context).canPop())
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            )
                          else
                            const SizedBox(width: 48),
                          Expanded(
                            child: Text(
                              l.manage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const _CompactThemeButton(),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.isSw
                                  ? 'Dhibiti biashara yako'
                                  : 'Manage your business',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l.isSw
                                  ? 'Bidhaa, manunuzi, wasambazaji, wafanyakazi na zaidi'
                                  : 'Products, purchases, suppliers, staff and more',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withAlpha(190),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMobileSelector(),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  for (final t in _visible)
                    if (t == 'categories')
                      _CategoryTab(desktop: false)
                    else if (t == 'units')
                      _UnitTab(desktop: false)
                    else if (t == 'suppliers')
                      const SuppliersScreen(desktop: false)
                    else if (t == 'purchase_orders')
                      const PurchaseOrdersScreen(desktop: false)
                    else if (t == 'purchases')
                      const PurchasesScreen(desktop: false)
                    else if (t == 'quotations')
                      const QuotationsScreen(desktop: false)
                    else if (t == 'stock_transfers')
                      const StockTransfersScreen(desktop: false)
                    else
                      _StaffTab(desktop: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact theme toggle for Manage's mobile header — desktop already has the
// global theme pill in its persistent top bar (angalia dashboard_screen.dart's
// _ThemeToggleButton), hivyo hapa hatuhitaji zaidi ya kitufe kimoja kidogo:
// tap inazungusha auto→usiku→mchana, long-press inafungua chaguo la moja kwa moja.
// ─────────────────────────────────────────────────────────────────────────────
class _CompactThemeButton extends StatelessWidget {
  const _CompactThemeButton();

  static const _order = ['auto', 'dark', 'light'];

  void _cycle(BuildContext context) {
    final tp = context.read<ThemeProvider>();
    final next = _order[(_order.indexOf(tp.preference) + 1) % _order.length];
    tp.setPreference(next);
  }

  void _showPicker(BuildContext context) {
    final tp = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
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
    final icon = switch (theme.preference) {
      'dark' => Icons.dark_mode_rounded,
      'light' => Icons.light_mode_rounded,
      _ => isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
    };
    return IconButton(
      onPressed: () => _cycle(context),
      onLongPress: () => _showPicker(context),
      icon: Icon(icon, color: Colors.white, size: 20),
      tooltip: 'Mandhari',
    );
  }
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    Widget option(String pref, IconData icon, String label) {
      final isActive = theme.preference == pref;
      return ListTile(
        leading: Icon(icon, color: isActive ? AppColors.primaryLt : AppColors.textMuted),
        title: Text(label, style: TextStyle(color: AppColors.textWhite)),
        trailing: isActive ? Icon(Icons.check_rounded, color: AppColors.primaryLt) : null,
        onTap: () {
          context.read<ThemeProvider>().setPreference(pref);
          Navigator.pop(context);
        },
      );
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Mandhari', style: TextStyle(
                    color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            option('auto', Icons.schedule_rounded, 'Kiotomatiki'),
            option('dark', Icons.dark_mode_rounded, 'Usiku daima'),
            option('light', Icons.light_mode_rounded, 'Mchana daima'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Tab
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryTab extends StatefulWidget {
  final bool desktop;
  const _CategoryTab({required this.desktop});
  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  List<Map<String, dynamic>> _cats = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await app.api!.listCategories(
        app.selectedBusiness!.businessId,
      );
      if (mounted) {
        setState(() {
          _cats = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered => _search.isEmpty
      ? _cats
      : _cats
            .where(
              (c) => (c['name'] as String).toLowerCase().contains(
                _search.toLowerCase(),
              ),
            )
            .toList();

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  Future<void> _showAddEdit({Map<String, dynamic>? cat}) async {
    final l = L.of(context);
    final ctrl = TextEditingController(text: cat?['name'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradPrimary),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.category_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cat == null ? l.addCategory : l.editCategory,
                style: TextStyle(color: AppColors.textWhite, fontSize: 16),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: l.catNameHint,
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(
              Icons.label_outline_rounded,
              color: AppColors.textMuted,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              l.save,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      ctrl.dispose();
      return;
    }
    final name = ctrl.text.trim();
    if (name.isEmpty) {
      ctrl.dispose();
      return;
    }

    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) {
      ctrl.dispose();
      return;
    }

    try {
      final res = cat == null
          ? await app.api!.manageCategory(
              app.selectedBusiness!.businessId,
              'add',
              name: name,
            )
          : await app.api!.manageCategory(
              app.selectedBusiness!.businessId,
              'edit',
              id: cat['id'] as int,
              name: name,
            );
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      if (res['success'] == true) {
        _snack(res['message'] as String? ?? '✅', AppColors.accent);
        _load();
      } else {
        _snack(
          res['message'] as String? ?? L.of(context).error,
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    }
    ctrl.dispose();
  }

  Future<void> _delete(Map<String, dynamic> cat) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.deleteConfirm,
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          '${cat['name']}',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.no, style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    try {
      final res = await app.api!.manageCategory(
        app.selectedBusiness!.businessId,
        'delete',
        id: cat['id'] as int,
      );
      if (mounted) {
        _snack(res['message'] as String? ?? '🗑️', AppColors.chartOrange);
        _load();
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: widget.desktop
              ? 0
              : MediaQuery.of(context).viewPadding.bottom + 76,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEdit(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            l.addCategory,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.desktop ? 24 : 12,
              14,
              widget.desktop ? 24 : 12,
              6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      hintText: l.catNameHint,
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
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
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: _load,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Count label
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.desktop ? 24 : 12,
              vertical: 4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} ${l.categoriesTab.toLowerCase()}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ),
          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : filtered.isEmpty
                ? PremiumEmptyState(
                    icon: Icons.category_outlined,
                    title: l.isSw ? 'Hakuna kategoria bado' : 'No categories yet',
                    subtitle: l.isSw
                        ? 'Ongeza kategoria kupanga bidhaa zako kwa urahisi.'
                        : 'Add categories to organize your products.',
                    buttonLabel: l.addCategory,
                    onButtonTap: () => _showAddEdit(),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      widget.desktop ? 24 : 12,
                      4,
                      widget.desktop ? 24 : 12,
                      100,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CategoryTile(
                      cat: filtered[i],
                      onEdit: () => _showAddEdit(cat: filtered[i]),
                      onDelete: () => _delete(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

}

// Category Tile
class _CategoryTile extends StatelessWidget {
  final Map<String, dynamic> cat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CategoryTile({
    required this.cat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      AppColors.primaryLt,
      AppColors.accent,
      AppColors.chartPurple,
      AppColors.chartBlue,
      AppColors.chartOrange,
    ];
    final color = colors[(cat['id'] as int? ?? 0) % colors.length];
    final isGlobal = cat['is_global'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: isGlobal ? null : onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Center(
                  child: Text(
                    (cat['name'] as String).isNotEmpty
                        ? (cat['name'] as String)[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cat['name'] as String? ?? '—',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isGlobal)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: 'Chaguo la kawaida la mfumo',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  tooltip: L.of(context).tapToEdit,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  tooltip: L.of(context).delete,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unit Tab
// ─────────────────────────────────────────────────────────────────────────────
class _UnitTab extends StatefulWidget {
  final bool desktop;
  const _UnitTab({required this.desktop});
  @override
  State<_UnitTab> createState() => _UnitTabState();
}

class _UnitTabState extends State<_UnitTab> {
  List<Map<String, dynamic>> _units = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await app.api!.listUnits(app.selectedBusiness!.businessId);
      if (mounted) {
        setState(() {
          _units = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered => _search.isEmpty
      ? _units
      : _units
            .where(
              (u) =>
                  (u['name'] as String).toLowerCase().contains(
                    _search.toLowerCase(),
                  ) ||
                  (u['short_name'] as String? ?? '').toLowerCase().contains(
                    _search.toLowerCase(),
                  ),
            )
            .toList();

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  Future<void> _showAddEdit({Map<String, dynamic>? unit}) async {
    final l = L.of(context);
    final nameCtrl = TextEditingController(
      text: unit?['name'] as String? ?? '',
    );
    final snCtrl = TextEditingController(
      text: unit?['short_name'] as String? ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradLime),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.straighten_rounded,
                color: AppColors.bgDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                unit == null ? l.addUnit : l.editUnit,
                style: TextStyle(color: AppColors.textWhite, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                hintText: l.unitNameHint,
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.label_outline_rounded,
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                labelText: l.unit,
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: snCtrl,
              style: TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                hintText: l.shortNameHint,
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.short_text_rounded,
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                labelText: 'Short Name',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              l.save,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      snCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      nameCtrl.dispose();
      snCtrl.dispose();
      return;
    }

    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) {
      nameCtrl.dispose();
      snCtrl.dispose();
      return;
    }

    try {
      final res = unit == null
          ? await app.api!.manageUnit(
              app.selectedBusiness!.businessId,
              'add',
              name: name,
              shortName: snCtrl.text.trim(),
            )
          : await app.api!.manageUnit(
              app.selectedBusiness!.businessId,
              'edit',
              id: unit['id'] as int,
              name: name,
              shortName: snCtrl.text.trim(),
            );
      if (!mounted) {
        nameCtrl.dispose();
        snCtrl.dispose();
        return;
      }
      if (res['success'] == true) {
        _snack(res['message'] as String? ?? '✅', AppColors.accent);
        _load();
      } else {
        _snack(
          res['message'] as String? ?? L.of(context).error,
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    }
    nameCtrl.dispose();
    snCtrl.dispose();
  }

  Future<void> _delete(Map<String, dynamic> unit) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.deleteConfirm,
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          '${unit['name']}',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.no, style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    try {
      final res = await app.api!.manageUnit(
        app.selectedBusiness!.businessId,
        'delete',
        id: unit['id'] as int,
      );
      if (mounted) {
        _snack(res['message'] as String? ?? '🗑️', AppColors.chartOrange);
        _load();
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: widget.desktop
              ? 0
              : MediaQuery.of(context).viewPadding.bottom + 76,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEdit(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            l.addUnit,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.desktop ? 24 : 12,
              14,
              widget.desktop ? 24 : 12,
              6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      hintText: l.unitNameHint,
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
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
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: _load,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.desktop ? 24 : 12,
              vertical: 4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} ${l.unitsTab.toLowerCase()}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : filtered.isEmpty
                ? PremiumEmptyState(
                    icon: Icons.straighten_rounded,
                    title: l.isSw ? 'Hakuna vipimo bado' : 'No units yet',
                    subtitle: l.isSw
                        ? 'Ongeza vipimo (kilo, lita, kipande) vinavyotumika kuuza bidhaa zako.'
                        : 'Add the units (kg, litre, piece) your products are sold in.',
                    buttonLabel: l.addUnit,
                    onButtonTap: () => _showAddEdit(),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      widget.desktop ? 24 : 12,
                      4,
                      widget.desktop ? 24 : 12,
                      100,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _UnitTile(
                      unit: filtered[i],
                      onEdit: () => _showAddEdit(unit: filtered[i]),
                      onDelete: () => _delete(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

}

// Unit Tile
class _UnitTile extends StatelessWidget {
  final Map<String, dynamic> unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _UnitTile({
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = unit['short_name'] as String? ?? '';
    final isGlobal = unit['is_global'] as bool? ?? false;
    const color = AppColors.accent;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: isGlobal ? null : onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Center(
                  child: Text(
                    shortName.isNotEmpty
                        ? shortName.substring(0, shortName.length.clamp(0, 2))
                        : 'U',
                    style: const TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
                      unit['name'] as String? ?? '—',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (shortName.isNotEmpty)
                      Text(
                        'Jina fupi: $shortName',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (isGlobal)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: 'Chaguo la kawaida la mfumo',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  tooltip: L.of(context).tapToEdit,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  tooltip: L.of(context).delete,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff Tab — Add / manage business workers
// ─────────────────────────────────────────────────────────────────────────────
const _kStaffRoles = [
  'Admin',
  'Manager',
  'Cashier',
  'Stockist',
  'Accountant',
  'Viewer',
  'Supporter',
];

class _StaffTab extends StatefulWidget {
  final bool desktop;
  const _StaffTab({required this.desktop});
  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await app.api!.manageStaff(
        businessId: app.selectedBusiness!.businessId,
        action: 'list',
      );
      if (mounted && res['success'] == true) {
        setState(() {
          _staff = (res['staff'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  Future<void> _showAddEdit({Map<String, dynamic>? staff}) async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    if (biz == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffFormSheet(business: biz, staff: staff),
    );
    if (result == true) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> s) async {
    final app = context.read<AppProvider>();
    final user = app.user;
    final biz = app.selectedBusiness;
    if (app.api == null || user == null || biz == null) return;
    try {
      final res = await app.api!.manageStaff(
        businessId: biz.businessId,
        action: (s['is_active'] as bool) ? 'delete' : 'reactivate',
        requesterUserId: user.userId,
        userId: s['user_id'] as int,
      );
      if (mounted) {
        _snack(
          res['message'] as String? ?? '✅',
          res['success'] == true ? AppColors.accent : Colors.redAccent,
        );
        if (res['success'] == true) _load();
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    }
  }

  Future<void> _deletePermanent(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        icon: const Icon(
          Icons.warning_rounded,
          color: Colors.redAccent,
          size: 32,
        ),
        title: Text(
          'Futa Kabisa?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          'Una uhakika unataka kumfuta ${s['fullname']} KABISA? Hatua hii haiwezi kurudishwa.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Futa Kabisa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final app = context.read<AppProvider>();
    final user = app.user;
    final biz = app.selectedBusiness;
    if (app.api == null || user == null || biz == null) return;
    try {
      final res = await app.api!.manageStaff(
        businessId: biz.businessId,
        action: 'delete_permanent',
        requesterUserId: user.userId,
        userId: s['user_id'] as int,
      );
      if (mounted) {
        _snack(
          res['message'] as String? ?? '✅',
          res['success'] == true ? AppColors.accent : Colors.redAccent,
        );
        if (res['success'] == true) _load();
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    }
  }

  // ── Empty state: polished card + quick actions (existing actions only) ──
  Widget _buildStaffEmptyState() {
    final isSw = L.of(context).isSw;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        widget.desktop ? 32 : MediaQuery.of(context).viewPadding.bottom + 96,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Main empty card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.gradPrimary,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(80),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isSw ? 'Hakuna wafanyakazi bado' : 'No staff members yet',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSw
                          ? 'Ongeza wafanyakazi na uwapangie majukumu kwenye biashara yako.'
                          : 'Add staff and assign their roles within your business.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddEdit(),
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          isSw ? 'Ongeza Mfanyakazi' : 'Add Staff Member',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
              const SizedBox(height: 24),
              // ── Quick actions — only wired to functionality that exists ──
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isSw ? 'Mambo unayoweza kufanya' : 'Things you can do',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _quickAction(
                icon: Icons.person_add_alt_1_outlined,
                title: isSw ? 'Ongeza mfanyakazi' : 'Add a staff member',
                subtitle: isSw
                    ? 'Sajili wafanyakazi wapya'
                    : 'Register new staff',
                onTap: () => _showAddEdit(),
              ),
              const SizedBox(height: 8),
              // Hakuna skrini ya kuhariri ruhusa kwa pekee — kadi hii ni ya
              // kuonyesha tu (non-interactive) kwa mujibu wa muundo.
              _quickAction(
                icon: Icons.admin_panel_settings_outlined,
                title: isSw ? 'Pangia majukumu' : 'Assign roles',
                subtitle: isSw
                    ? 'Weka ruhusa za mfumo'
                    : 'Set system permissions',
              ),
              const SizedBox(height: 8),
              // Hakuna historia ya shughuli za wafanyakazi kwenye app —
              // non-interactive (haujaundwa feature bandia).
              _quickAction(
                icon: Icons.analytics_outlined,
                title: isSw ? 'Fuatilia shughuli' : 'Track activity',
                subtitle: isSw
                    ? 'Ona historia ya shughuli za wafanyakazi'
                    : 'View staff activity history',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final interactive = onTap != null;
    return Opacity(
      opacity: interactive ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLt.withAlpha(24),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryLt.withAlpha(60),
                      ),
                    ),
                    child: Icon(icon, size: 20, color: AppColors.primaryLt),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (interactive)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (_loading || _staff.isEmpty)
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: widget.desktop
                    ? 0
                    : MediaQuery.of(context).viewPadding.bottom + 76,
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _showAddEdit(),
                backgroundColor: AppColors.primary,
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                ),
                label: const Text(
                  'Ongeza Mfanyakazi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _staff.isEmpty
          ? _buildStaffEmptyState()
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                widget.desktop ? 24 : 12,
                14,
                widget.desktop ? 24 : 12,
                100,
              ),
              itemCount: _staff.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _StaffTile(
                staff: _staff[i],
                onEdit: () => _showAddEdit(staff: _staff[i]),
                onToggle: () => _toggleActive(_staff[i]),
                onDelete: () => _deletePermanent(_staff[i]),
              ),
            ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _StaffTile({
    required this.staff,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin':
        return AppColors.chartPurple;
      case 'Manager':
        return AppColors.chartBlue;
      case 'Cashier':
        return AppColors.accent;
      case 'Stockist':
        return AppColors.chartOrange;
      case 'Accountant':
        return AppColors.primaryLt;
      default:
        return AppColors.chartGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = staff['is_active'] as bool;
    final role = staff['role'] as String? ?? '';
    final color = active ? _roleColor(role) : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withAlpha(180)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (staff['fullname'] as String).isNotEmpty
                        ? (staff['fullname'] as String)[0].toUpperCase()
                        : '?',
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
                      staff['fullname'] as String? ?? '',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            staff['branch_name'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!active)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Amezimwa',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  label: Text(
                    'Hariri',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    active ? Icons.person_off_outlined : Icons.person_rounded,
                    size: 15,
                    color: active ? AppColors.chartOrange : AppColors.accent,
                  ),
                  label: Text(
                    active ? 'Zima' : 'Washa',
                    style: TextStyle(
                      color: active ? AppColors.chartOrange : AppColors.accent,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: (active ? AppColors.chartOrange : AppColors.accent)
                          .withAlpha(90),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 15,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Futa',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Staff Add/Edit Form Sheet ─────────────────────────────────────────────────
class _StaffFormSheet extends StatefulWidget {
  final Business business;
  final Map<String, dynamic>? staff;
  const _StaffFormSheet({required this.business, this.staff});

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _fullnameCtrl = TextEditingController(
    text: widget.staff?['fullname'] as String? ?? '',
  );
  late final _usernameCtrl = TextEditingController(
    text: widget.staff?['username'] as String? ?? '',
  );
  final _passwordCtrl = TextEditingController();
  late String _role = widget.staff?['role'] as String? ?? _kStaffRoles.first;
  late int? _branchId =
      widget.staff?['branch_id'] as int? ??
      (widget.business.branches.isNotEmpty
          ? widget.business.branches.first.branchId
          : null);
  bool _saving = false;
  bool _obscurePass = true;

  // ── Ukaguzi wa upatikanaji wa username (live, huku mtumiaji anaandika) ──
  Timer? _usernameDebounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable; // null = bado hajaandika/haujaguswa
  List<String> _usernameSuggestions = [];
  int _usernameCheckSeq = 0;

  bool get _isEdit => widget.staff != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) _usernameCtrl.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final value = _usernameCtrl.text.trim();
    _usernameDebounce?.cancel();
    if (value.isEmpty) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
        _usernameSuggestions = [];
      });
      return;
    }
    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () => _checkUsername(value));
  }

  Future<void> _checkUsername(String value) async {
    final seq = ++_usernameCheckSeq;
    final app = context.read<AppProvider>();
    if (app.api == null) return;
    try {
      final res = await app.api!.manageStaff(
        businessId: widget.business.businessId,
        action: 'check_username',
        username: value,
        fullname: _fullnameCtrl.text.trim(),
      );
      // Puuza jibu kama mtumiaji ameshaandika kitu kingine tangu ombi hili lilipoanza.
      if (!mounted || seq != _usernameCheckSeq) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = res['available'] as bool? ?? true;
        _usernameSuggestions = (res['suggestions'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
      });
    } catch (_) {
      if (!mounted || seq != _usernameCheckSeq) return;
      setState(() => _checkingUsername = false);
    }
  }

  void _applySuggestion(String s) {
    _usernameCtrl.text = s;
    _usernameCtrl.selection = TextSelection.collapsed(offset: s.length);
    _onUsernameChanged();
  }

  Widget? _usernameStatusIcon() {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }
    if (_usernameAvailable == null) return null;
    return Icon(
      _usernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: _usernameAvailable! ? AppColors.accent : AppColors.chartRed,
      size: 20,
    );
  }

  Widget _usernameStatusPanel() {
    if (_checkingUsername) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          'Inaangalia upatikanaji...',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
        ),
      );
    }
    if (_usernameAvailable == true) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          'Jina linapatikana',
          style: TextStyle(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      );
    }
    // Tayari linatumika — onyesha ujumbe + mapendekezo (kama yapo).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Jina hili tayari linatumika',
            style: TextStyle(color: AppColors.chartRed, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
        if (_usernameSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in _usernameSuggestions)
                InkWell(
                  onTap: () => _applySuggestion(s),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLt.withAlpha(24),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryLt.withAlpha(70)),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(color: AppColors.primaryLt, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isEdit && _usernameAvailable == false) {
      AppNotification.show(
        context,
        'Jina la mtumiaji tayari linatumika — chagua jingine',
        AppColors.chartRed,
        icon: Icons.error_rounded,
      );
      return;
    }
    if (_branchId == null) {
      AppNotification.show(
        context,
        'Chagua tawi',
        AppColors.chartRed,
        icon: Icons.error_rounded,
      );
      return;
    }
    final app = context.read<AppProvider>();
    final user = app.user;
    if (app.api == null || user == null) return;

    setState(() => _saving = true);
    try {
      final res = _isEdit
          ? await app.api!.manageStaff(
              businessId: widget.business.businessId,
              action: 'edit',
              requesterUserId: user.userId,
              userId: widget.staff!['user_id'] as int,
              role: _role,
              branchId: _branchId,
            )
          : await app.api!.manageStaff(
              businessId: widget.business.businessId,
              action: 'add',
              requesterUserId: user.userId,
              fullname: _fullnameCtrl.text.trim(),
              username: _usernameCtrl.text.trim(),
              password: _passwordCtrl.text,
              role: _role,
              branchId: _branchId,
            );
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotification.show(
          context,
          res['message'] as String? ?? '✅ Imefanikiwa',
          AppColors.accent,
          icon: Icons.check_circle_rounded,
        );
        Navigator.pop(context, true);
      } else if (res['reason'] == 'inactive_here' && res['user_id'] != null) {
        // Mfanyakazi huyu tayari yupo kwenye duka hili lakini ameondolewa —
        // mpe njia ya haraka ya kumrejesha badala ya ujumbe wa kufeli tu.
        final reactivate = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: Text('Mfanyakazi tayari yupo', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
            content: Text(
              res['message'] as String? ?? '',
              style: TextStyle(color: AppColors.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Mrejeshe'),
              ),
            ],
          ),
        );
        if (reactivate == true && mounted) {
          final r2 = await app.api!.manageStaff(
            businessId: widget.business.businessId,
            action: 'reactivate',
            requesterUserId: user.userId,
            userId: res['user_id'] as int,
          );
          if (!mounted) return;
          AppNotification.show(
            context,
            r2['message'] as String? ?? (r2['success'] == true ? '✅ Imefanikiwa' : 'Hitilafu'),
            r2['success'] == true ? AppColors.accent : AppColors.chartRed,
            icon: r2['success'] == true ? Icons.check_circle_rounded : Icons.error_rounded,
          );
          if (r2['success'] == true) Navigator.pop(context, true);
        }
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
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isEdit
                                  ? 'Hariri Mfanyakazi'
                                  : 'Ongeza Mfanyakazi',
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

                      _field(
                        _fullnameCtrl,
                        'Jina Kamili',
                        Icons.badge_outlined,
                        enabled: !_isEdit,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Jina linahitajika'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _usernameCtrl,
                        'Jina la Mtumiaji',
                        Icons.person_outline_rounded,
                        enabled: !_isEdit,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Username inahitajika'
                            : null,
                        suffixIcon: _isEdit ? null : _usernameStatusIcon(),
                      ),
                      if (!_isEdit && (_checkingUsername || _usernameAvailable != null)) ...[
                        const SizedBox(height: 6),
                        _usernameStatusPanel(),
                      ],
                      if (!_isEdit) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePass,
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Angalau herufi 6'
                              : null,
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nywila',
                            labelStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.textMuted,
                              size: 17,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: AppColors.textMuted,
                                size: 17,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
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
                      ],
                      const SizedBox(height: 14),

                      Text(
                        'Cheo',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
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
                          child: DropdownButton<String>(
                            value: _role,
                            isExpanded: true,
                            dropdownColor: AppColors.bgCard,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 14,
                            ),
                            items: _kStaffRoles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _role = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Tawi',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
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
                            value: _branchId,
                            isExpanded: true,
                            dropdownColor: AppColors.bgCard,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 14,
                            ),
                            items: widget.business.branches
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b.branchId,
                                    child: Text(b.branchName),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _branchId = v),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool enabled = true,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      validator: validator,
      style: TextStyle(color: AppColors.textWhite, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 17),
        suffixIcon: suffixIcon,
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
        disabledBorder: OutlineInputBorder(
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
}
