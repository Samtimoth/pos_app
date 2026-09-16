import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/first_run_tutorial.dart';
import '../l10n/app_l10n.dart';
import 'suppliers_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Manage Screen — Categories + Units
// ─────────────────────────────────────────────────────────────────────────────
class ManageScreen extends StatefulWidget {
  final bool desktop;
  final int initialTab;
  const ManageScreen({super.key, this.desktop = false, this.initialTab = 0});
  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Hatua 1: tabs zinaonekana kwa role ──
  // Categories/Units: canManageProducts · Staff: canManageStaff
  late final List<String> _visible;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().user;
    _visible = [
      if (user == null || user.canManageProducts) ...['categories', 'units', 'suppliers'],
      if (user == null || user.canManageStaff) 'staff',
    ];
    var initIdx = widget.initialTab;
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
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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

    final themePanel = _ThemePanel();

    if (widget.desktop) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            color: Colors.transparent,
            child: themePanel,
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
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
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 0, 0),
                        child: Row(
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
                              const SizedBox(width: 12),
                            Text(
                              l.manage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: buildTabBar(onGradient: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: themePanel,
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
// Theme Panel — Mandhari / Appearance settings card
// ─────────────────────────────────────────────────────────────────────────────
class _ThemePanel extends StatelessWidget {
  const _ThemePanel();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
          // Animated icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: ValueKey(isDark),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withAlpha(45)
                    : AppColors.accentDk.withAlpha(25),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: isDark ? AppColors.primaryLt : AppColors.accentDk,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mandhari',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    key: ValueKey(theme.preference + (isDark ? 'd' : 'l')),
                    theme.preference == 'auto'
                        ? (isDark
                              ? 'Kiotomatiki • Usiku sasa'
                              : 'Kiotomatiki • Mchana sasa')
                        : theme.preference == 'dark'
                        ? 'Usiku daima'
                        : 'Mchana daima',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          ]),
          const SizedBox(height: 10),
          // 3 option chips – full width row
          Row(
            children: [
              Expanded(child: _ThemeChip(
                pref: 'auto',
                icon: Icons.schedule_rounded,
                label: 'Auto',
              )),
              const SizedBox(width: 6),
              Expanded(child: _ThemeChip(
                pref: 'dark',
                icon: Icons.dark_mode_rounded,
                label: 'Usiku',
              )),
              const SizedBox(width: 6),
              Expanded(child: _ThemeChip(
                pref: 'light',
                icon: Icons.light_mode_rounded,
                label: 'Mchana',
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String pref;
  final IconData icon;
  final String label;
  const _ThemeChip({
    required this.pref,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isActive = theme.preference == pref;

    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().setPreference(pref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(210) : AppColors.bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isActive ? AppColors.primaryLt : AppColors.border,
            width: isActive ? 1.4 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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
                ? _empty(l.noCats, Icons.category_outlined)
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

  Widget _empty(String msg, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 56),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ],
    ),
  );
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
                ? _empty(l.noUnitsData, Icons.straighten_rounded)
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

  Widget _empty(String msg, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 56),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ],
    ),
  );
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

  @override
  Widget build(BuildContext context) {
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
          icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
          label: const Text(
            'Ongeza Mfanyakazi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _staff.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    color: AppColors.textMuted,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hakuna wafanyakazi bado',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            )
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

  bool get _isEdit => widget.staff != null;

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
                      ),
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
