import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/first_run_tutorial.dart';
import '../l10n/app_l10n.dart';
import '../utils/cat_style.dart';
import 'product_form_sheet.dart';
import 'product_detail_sheet.dart';
import 'add_product_page.dart';
import 'add_batch_sheet.dart';
import 'stock_ledger_screen.dart';

class ProductsScreen extends StatefulWidget {
  final bool desktop;
  final bool showMobileFab;
  final VoidCallback? onBack;
  const ProductsScreen({
    super.key,
    this.desktop = false,
    this.showMobileFab = false,
    this.onBack,
  });
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  List<Product> _all = [];
  List<Product> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _filter = 'all'; // all | in_stock | low | out
  String _catFilter = ''; // '' = all categories (mobile chips)
  String _sort =
      'name'; // name | price_asc | price_desc | stock_asc | stock_desc
  final _fmt = NumberFormat('#,###', 'en_US');
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  late final AnimationController _pageAnimCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pageAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _pageAnimCtrl,
      curve: Curves.easeOutCubic,
    );
    _load();
  }

  @override
  void dispose() {
    _pageAnimCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    if (app.api == null || biz == null) return;
    setState(() => _loading = true);
    try {
      final raw = await app.api!.getProducts(
        biz.businessId,
        branchId: app.selectedBranch?.branchId,
      );
      final prods = raw
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _all = prods;
        _applyFilter();
      });
      _pageAnimCtrl.forward(from: 0);
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
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddProduct() {
    // ── Role check (Hatua 1) ──
    if (context.read<AppProvider>().user?.canManageProducts != true) {
      AppNotification.show(context,
          L.of(context).isSw ? 'Huna ruhusa ya kuongeza bidhaa' : 'You cannot add products',
          AppColors.chartRed);
      return;
    }
    if (widget.desktop) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddProductSheet(onSaved: _load),
      );
    } else {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (ctx, a1, a2) => AddProductPage(onProductsAdded: _load),
          transitionsBuilder: (ctx, anim, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 380),
        ),
      );
    }
  }

  void _openDetailProduct(Product product) {
    ProductDetailSheet.show(context, product, onRefresh: _load);
  }

  void _openEditProduct(Product product) {
    // ── Role check (Hatua 1) ──
    if (context.read<AppProvider>().user?.canManageProducts != true) {
      AppNotification.show(context,
          L.of(context).isSw ? 'Huna ruhusa ya kuhariri bidhaa' : 'You cannot edit products',
          AppColors.chartRed);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(initialProduct: product, onSaved: _load),
    );
  }

  void _openAddBatch(Product product) {
    // ── Role check (Hatua 1) ──
    if (context.read<AppProvider>().user?.canManageProducts != true) {
      AppNotification.show(context,
          L.of(context).isSw ? 'Huna ruhusa ya kuongeza stock' : 'You cannot add stock',
          AppColors.chartRed);
      return;
    }
    AddBatchSheet.show(context, product, onSaved: _load);
  }

  void _openExcelImport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExcelImportSheet(onImported: _load),
    );
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final l = L.of(context);
    // ── Role check (Hatua 1) ──
    if (context.read<AppProvider>().user?.canDeleteProducts != true) {
      if (!mounted) return;
      AppNotification.show(context,
          l.isSw ? 'Admin/Owner pekee ndiye anaweza kufuta bidhaa' : 'Only Admin/Owner can delete products',
          AppColors.chartRed);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.isSw ? 'Futa Bidhaa' : 'Delete Product',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.chartRed.withAlpha(22),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.chartRed.withAlpha(70)),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.chartRed,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.isSw
                  ? 'Una uhakika unataka kufuta\n"${product.name}"?'
                  : 'Are you sure you want to delete\n"${product.name}"?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.isSw
                  ? 'Hatua hii haiwezi kurudishwa.'
                  : 'This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.chartRed,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    l.cancel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.chartRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        l.delete,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteProduct(product);
  }

  Future<void> _deleteProduct(Product product) async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    try {
      final res = await app.api!.deleteProduct(
        productId: product.productId,
        businessId: app.selectedBusiness!.businessId,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotification.show(
          context,
          L.of(context).isSw
              ? '"${product.name}" imefutwa.'
              : '"${product.name}" deleted.',
          AppColors.chartRed,
          icon: Icons.delete_rounded,
        );
        _load();
      } else {
        AppNotification.show(
          context,
          res['message'] as String? ??
              (L.of(context).isSw ? 'Kosa limejitokeza' : 'An error occurred'),
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
    }
  }

  void _applyFilter() {
    _filtered = _all.where((p) {
      final matchSearch =
          _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.category.toLowerCase().contains(_search.toLowerCase()) ||
          p.barcode.contains(_search);
      final matchFilter = switch (_filter) {
        'in_stock' => p.stock > 5,
        'low' => p.stock > 0 && p.stock <= 5,
        'out' => p.stock <= 0,
        _ => true,
      };
      final matchCat = _catFilter.isEmpty || p.category == _catFilter;
      return matchSearch && matchFilter && matchCat;
    }).toList();
    _applySort();
  }

  void _applySort() {
    switch (_sort) {
      case 'name':
        _filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'price_asc':
        _filtered.sort((a, b) => a.sellPrice.compareTo(b.sellPrice));
        break;
      case 'price_desc':
        _filtered.sort((a, b) => b.sellPrice.compareTo(a.sellPrice));
        break;
      case 'stock_asc':
        _filtered.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'stock_desc':
        _filtered.sort((a, b) => b.stock.compareTo(a.stock));
        break;
    }
  }

  Color _stockColor(Product p) {
    if (p.stock <= 0) return AppColors.chartRed;
    if (p.stock <= p.minStock || p.stock <= 5) return AppColors.chartOrange;
    return AppColors.accent;
  }

  String _stockLabel(Product p) {
    final l = L.of(context);
    if (p.stock <= 0) return l.isSw ? 'Imeisha' : 'Out of Stock';
    if (p.stock <= p.minStock || p.stock <= 5) {
      return l.isSw ? 'Stock Ndogo' : 'Low Stock';
    }
    return l.isSw ? 'Ipo Stock' : 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return widget.desktop ? _buildDesktop() : _buildMobile();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    final l = L.of(context);
    return Column(
      children: [
        _desktopStatsBar(l),
        _buildToolbar(desktop: true, l: l),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: _filtered.isEmpty
                      ? _emptyState(l)
                      : _buildProductTable(l),
                ),
        ),
      ],
    );
  }

  /// One slim row of stats (replaces the tall hero + duplicate chip row).
  Widget _desktopStatsBar(L l) {
    final totalQty = _all.fold<int>(0, (a, p) => a + p.stock);
    final value = _all.fold<double>(0, (a, p) => a + p.sellPrice * p.stock);
    final cost = _all.fold<double>(0, (a, p) => a + p.buyPrice * p.stock);
    final low = _all.where((p) => p.stock > 0 && (p.stock <= p.minStock || p.stock <= 5)).length;
    final out = _all.where((p) => p.stock <= 0).length;
    Widget stat(String v, String k, Color c, {VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(v, style: TextStyle(color: c, fontSize: 17, fontWeight: FontWeight.w800)),
                Text(k, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        );
    Widget sep() => Container(width: 1, height: 30, color: AppColors.border);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.inventory_2_rounded, color: AppColors.primaryLt, size: 22),
            const SizedBox(width: 10),
            Text(l.products,
                style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            stat('${_all.length}', l.kpiProducts, AppColors.textWhite),
            sep(),
            stat(_fmt.format(totalQty), 'Jumla qty', AppColors.chartBlue),
            sep(),
            stat('TZS ${_fmt.format(value)}', 'Thamani (kuuza)', AppColors.accent),
            sep(),
            stat('TZS ${_fmt.format(cost)}', 'Gharama ya hisa', AppColors.primaryLt),
            sep(),
            stat('$low', 'Stock ndogo', low > 0 ? AppColors.chartOrange : AppColors.textMuted,
                onTap: () => setState(() { _filter = 'low'; _applyFilter(); })),
            sep(),
            stat('$out', 'Zimeisha', out > 0 ? AppColors.chartRed : AppColors.textMuted,
                onTap: () => setState(() { _filter = 'out'; _applyFilter(); })),
          ],
        ),
      ),
    );
  }

  /// Dense, sortable table – the natural desktop view for an inventory list.
  Widget _buildProductTable(L l) {
    final headStyle = TextStyle(
        color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6);
    Widget h(String t, {int flex = 2, TextAlign align = TextAlign.left}) => Expanded(
          flex: flex,
          child: Text(t.toUpperCase(), textAlign: align, style: headStyle),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              color: AppColors.bgInput,
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  h('Bidhaa', flex: 4),
                  h('Kategoria', flex: 2),
                  h('Stock', flex: 2, align: TextAlign.right),
                  h('Kununua', flex: 2, align: TextAlign.right),
                  h('Kuuza', flex: 2, align: TextAlign.right),
                  h('Faida', flex: 2, align: TextAlign.right),
                  h('Hali', flex: 2, align: TextAlign.center),
                  const SizedBox(width: 132),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) => _ProductTableRow(
                  product: _filtered[i],
                  fmt: _fmt,
                  stockColor: _stockColor(_filtered[i]),
                  stockLabel: _stockLabel(_filtered[i]),
                  onView: () => _openDetailProduct(_filtered[i]),
                  onEdit: () => _openEditProduct(_filtered[i]),
                  onBatch: () => _openAddBatch(_filtered[i]),
                  onDelete: () => _confirmDeleteProduct(_filtered[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile() {
    final l = L.of(context);
    final mq = MediaQuery.of(context);
    final out = _all.where((p) => p.stock <= 0).length;
    final low = _all.where((p) => p.stock > 0 && (p.stock <= p.minStock || p.stock <= 5)).length;
    final cats = <String>{for (final p in _all) if (p.category.isNotEmpty) p.category}.toList()..sort();
    final fabBottom = mq.viewPadding.bottom + 72 + 10 + 24;
    final filtersActive = _filter != 'all' || _sort != 'name';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── slim header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.gradHeader,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Row(
                  children: [
                    if (widget.onBack != null && !widget.showMobileFab)
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.products,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_all.length} ${l.kpiProducts}'
                            '${low > 0 ? '  ·  $low ${l.isSw ? "stock ndogo" : "low"}' : ''}'
                            '${out > 0 ? '  ·  $out ${l.isSw ? "zimeisha" : "out"}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StockLedgerScreen()),
                      ),
                      icon: const Icon(Icons.history_rounded, color: Colors.white),
                      tooltip: l.isSw ? 'Historia ya stock' : 'Stock history',
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      tooltip: l.refresh,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── search + filter ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: TutorialTarget(
                      id: 'products_search',
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: l.isSw ? 'Tafuta jina au barcode' : 'Search name or barcode',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _search = '';
                                      _applyFilter();
                                    });
                                  },
                                ),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.bgCard,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                        onChanged: (v) => setState(() {
                          _search = v;
                          _applyFilter();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: filtersActive ? AppColors.primary : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openFilterSheet,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: filtersActive ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: filtersActive ? Colors.white : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── category chips ─────────────────────────────────────────────
          if (cats.length > 1)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                children: [
                  _catChip(l.isSw ? 'Zote' : 'All', ''),
                  for (final c in cats) _catChip(c, c),
                ],
              ),
            )
          else
            const SizedBox(height: 6),
          // ── low-stock strip (one line) ─────────────────────────────────
          if (out + low > 0 && _filter == 'all')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _filter = out > 0 ? 'out' : 'low';
                  _applyFilter();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (out > 0 ? AppColors.chartRed : AppColors.chartOrange).withAlpha(22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: out > 0 ? AppColors.chartRed : AppColors.chartOrange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (out > 0) '$out ${l.isSw ? "zimeisha" : "out of stock"}',
                            if (low > 0) '$low ${l.isSw ? "stock ndogo" : "low stock"}',
                          ].join(' · '),
                          style: TextStyle(
                            color: out > 0 ? AppColors.chartRed : AppColors.chartOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: out > 0 ? AppColors.chartRed : AppColors.chartOrange),
                    ],
                  ),
                ),
              ),
            ),
          // ── list ───────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: _filtered.isEmpty
                              ? ListView(
                                  padding: EdgeInsets.fromLTRB(16, 30, 16, fabBottom + 78),
                                  children: [_emptyState(l)],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(12, 8, 12, fabBottom + 70),
                                  itemCount: _filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                                  itemBuilder: (ctx, i) {
                                    final p = _filtered[i];
                                    final row = _MobileProductRow(
                                      product: p,
                                      fmt: _fmt,
                                      stockColor: _stockColor(p),
                                      onTap: () => _openDetailProduct(p),
                                      onMore: () => _openProductActions(p),
                                    );
                                    return i == 0
                                        ? TutorialTarget(id: 'products_list', child: row)
                                        : row;
                                  },
                                ),
                        ),
                ),
                if (widget.showMobileFab)
                  Positioned(
                    right: 16,
                    bottom: fabBottom,
                    child: TutorialTarget(
                      id: 'products_add',
                      child: FloatingActionButton.extended(
                        heroTag: 'add_product_fab',
                        onPressed: _openAddProduct,
                        backgroundColor: AppColors.accent,
                        elevation: 6,
                        icon: Icon(Icons.add_rounded, color: AppColors.bgDark, size: 22),
                        label: Text(
                          l.isSw ? 'Ongeza' : 'Add',
                          style: TextStyle(color: AppColors.bgDark, fontWeight: FontWeight.bold),
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

  Widget _catChip(String label, String value) {
    final sel = _catFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : AppColors.textMuted,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: sel,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
        onSelected: (_) => setState(() {
          _catFilter = value;
          _applyFilter();
        }),
      ),
    );
  }

  /// Filter + sort in one bottom sheet (replaces the two cramped dropdowns).
  void _openFilterSheet() {
    final l = L.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget chip(String label, bool sel, VoidCallback onTap) => ChoiceChip(
                label: Text(label,
                    style: TextStyle(
                        color: sel ? Colors.white : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                selected: sel,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.bgInput,
                side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
                onSelected: (_) {
                  onTap();
                  setSheet(() {});
                  setState(_applyFilter);
                },
              );
          Widget title(String t) => Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Text(t.toUpperCase(),
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
              );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  title(l.isSw ? 'Onyesha' : 'Show'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    chip(l.filterAll, _filter == 'all', () => _filter = 'all'),
                    chip(l.filterInStock, _filter == 'in_stock', () => _filter = 'in_stock'),
                    chip(l.filterLow, _filter == 'low', () => _filter = 'low'),
                    chip(l.filterOut, _filter == 'out', () => _filter = 'out'),
                  ]),
                  title(l.isSw ? 'Panga kwa' : 'Sort by'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    chip(l.isSw ? 'Jina A-Z' : 'Name A-Z', _sort == 'name', () => _sort = 'name'),
                    chip(l.isSw ? 'Bei ↑' : 'Price ↑', _sort == 'price_asc', () => _sort = 'price_asc'),
                    chip(l.isSw ? 'Bei ↓' : 'Price ↓', _sort == 'price_desc', () => _sort = 'price_desc'),
                    chip(l.isSw ? 'Stock ↓' : 'Stock ↓', _sort == 'stock_desc', () => _sort = 'stock_desc'),
                    chip(l.isSw ? 'Stock kidogo kwanza' : 'Low stock first', _sort == 'stock_asc', () => _sort = 'stock_asc'),
                  ]),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l.isSw ? 'Onyesha ${_filtered.length}' : 'Show ${_filtered.length}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// View / edit / add stock / delete for one product.
  void _openProductActions(Product p) {
    final l = L.of(context);
    final user = context.read<AppProvider>().user; // ── role (Hatua 1) ──
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        Widget item(IconData icon, String label, Color color, VoidCallback onTap) => ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: color.withAlpha(28), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(label,
                  style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  Text('TZS ${_fmt.format(p.sellPrice)}',
                      style: TextStyle(color: AppColors.primaryLt, fontWeight: FontWeight.w700)),
                ]),
              ),
              item(Icons.visibility_rounded, l.isSw ? 'Tazama maelezo' : 'View details',
                  AppColors.primaryLt, () => _openDetailProduct(p)),
              if (user?.canManageProducts == true)
                item(Icons.edit_rounded, l.isSw ? 'Hariri bidhaa' : 'Edit product',
                    AppColors.chartPurple, () => _openEditProduct(p)),
              if (user?.canManageProducts == true)
                item(Icons.add_box_rounded, l.isSw ? 'Ongeza stock (batch)' : 'Add stock (batch)',
                    AppColors.accent, () => _openAddBatch(p)),
              if (user?.canManageProducts == true)
                item(Icons.history_rounded, l.isSw ? 'Historia / rekebisha stock' : 'Stock history / adjust',
                    AppColors.chartOrange, () => StockCardSheet.show(context, p, onChanged: _load)),
              if (user?.canDeleteProducts == true)
                item(Icons.delete_outline_rounded, l.isSw ? 'Futa bidhaa' : 'Delete product',
                    AppColors.chartRed, () => _confirmDeleteProduct(p)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar({required bool desktop, required L l}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        desktop ? 24 : 12,
        14,
        desktop ? 24 : 12,
        10,
      ),
      decoration: BoxDecoration(
        color: desktop ? Colors.transparent : AppColors.bgCard,
        border: desktop
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TutorialTarget(
              id: 'products_search',
              child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: TextStyle(color: AppColors.textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: l.searchProd,
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                _search = v;
                setState(_applyFilter);
              },
            ),
            ),
          ),
          const SizedBox(width: 8),
          _dropdownBox(
            value: _filter,
            icon: Icons.filter_list_rounded,
            items: [
              DropdownMenuItem(value: 'all', child: Text(l.filterAll)),
              DropdownMenuItem(value: 'in_stock', child: Text(l.filterInStock)),
              DropdownMenuItem(value: 'low', child: Text(l.filterLow)),
              DropdownMenuItem(value: 'out', child: Text(l.filterOut)),
            ],
            onChanged: (v) {
              setState(() {
                _filter = v!;
                _applyFilter();
              });
            },
          ),
          const SizedBox(width: 8),
          _dropdownBox(
            value: _sort,
            icon: Icons.sort_rounded,
            items: [
              DropdownMenuItem(
                value: 'name',
                child: Text(l.isSw ? 'Jina A-Z' : 'Name A-Z'),
              ),
              DropdownMenuItem(
                value: 'price_asc',
                child: Text(l.isSw ? 'Bei ↑' : 'Price ↑'),
              ),
              DropdownMenuItem(
                value: 'price_desc',
                child: Text(l.isSw ? 'Bei ↓' : 'Price ↓'),
              ),
              DropdownMenuItem(
                value: 'stock_desc',
                child: Text(l.isSw ? 'Stock ↓' : 'Stock ↓'),
              ),
              DropdownMenuItem(
                value: 'stock_asc',
                child: Text(l.isSw ? 'Stock kidogo' : 'Low stock first'),
              ),
            ],
            onChanged: (v) {
              setState(() {
                _sort = v!;
                _applySort();
              });
            },
          ),
          if (desktop) ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(10),
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
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openExcelImport,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryLt,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.table_chart_rounded, size: 16),
              label: Text(
                l.importExcel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _openAddProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bgDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                l.addProductTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdownBox<T>({
    required T value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        dropdownColor: AppColors.bgCard,
        style: TextStyle(color: AppColors.textWhite, fontSize: 13),
        icon: Icon(icon, color: AppColors.textMuted, size: 18),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _emptyState(L l) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppColors.primaryLt.withAlpha(18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryLt.withAlpha(50)),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primaryLt,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.noProducts,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.isSw
                ? 'Tumia kitufe cha + kuongeza bidhaa mpya.'
                : 'Use the + button to add a new product.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.tryAgain),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryLt,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile product list card
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopProductCard extends StatefulWidget {
  final Product product;
  final NumberFormat fmt;
  final Color stockColor;
  final String stockLabel;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DesktopProductCard({
    required this.product,
    required this.fmt,
    required this.stockColor,
    required this.stockLabel,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DesktopProductCard> createState() => _DesktopProductCardState();
}

class _DesktopProductCardState extends State<_DesktopProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final catColor = CatStyle.color(p.category);
    final canSeeCosts = context.read<AppProvider>().user?.canSeeCosts ?? false;
    final profit = p.sellPrice - p.buyPrice;
    final outOfStock = p.stock <= 0;
    final l = L.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hovered
              ? Color.lerp(AppColors.bgCard, AppColors.bg, 0.25)!
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? widget.stockColor.withAlpha(110)
                : widget.stockColor.withAlpha(55),
            width: _hovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(_hovered ? 55 : 35),
              blurRadius: _hovered ? 28 : 18,
              offset: Offset(0, _hovered ? 14 : 9),
            ),
            if (_hovered)
              BoxShadow(
                color: widget.stockColor.withAlpha(18),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: InkWell(
          onTap: widget.onView,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: icon + name + category + stock badge ───────────────
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: outOfStock
                            ? AppColors.chartGray.withAlpha(18)
                            : catColor.withAlpha(24),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: outOfStock
                              ? AppColors.chartGray.withAlpha(35)
                              : catColor.withAlpha(70),
                        ),
                      ),
                      child: Icon(
                        outOfStock
                            ? Icons.remove_shopping_cart_rounded
                            : CatStyle.icon(p.category),
                        color: outOfStock ? AppColors.chartGray : catColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: outOfStock
                                  ? AppColors.textMuted
                                  : AppColors.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  p.category.isNotEmpty
                                      ? p.category
                                      : l.noCategory,
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
                        ],
                      ),
                    ),
                    // Stock status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.stockColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.stockColor.withAlpha(70),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: widget.stockColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.stockLabel,
                            style: TextStyle(
                              color: widget.stockColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                // ── Info row 1: Stock + Sell Price ─────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _InfoBox(
                        label: '${l.stock} (${p.unit})',
                        value: '${p.stock}',
                        icon: Icons.inventory_2_outlined,
                        color: widget.stockColor,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _InfoBox(
                        label: l.sellPrice,
                        value: 'TZS ${widget.fmt.format(p.sellPrice)}',
                        icon: Icons.sell_rounded,
                        color: AppColors.primaryLt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                // ── Info row 2: Buy Price + Profit (wanao ruhusa pekee) ───────
                if (canSeeCosts)
                  Row(
                    children: [
                      Expanded(
                        child: _InfoBox(
                          label: l.buyPrice,
                          value: 'TZS ${widget.fmt.format(p.buyPrice)}',
                          icon: Icons.shopping_bag_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _InfoBox(
                          label: l.profit,
                          value: 'TZS ${widget.fmt.format(profit)}',
                          icon: profit >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: profit >= 0
                              ? AppColors.accent
                              : AppColors.chartRed,
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                // ── Action buttons ─────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _CardBtn(
                        label: l.isSw ? 'Angalia' : 'View',
                        icon: Icons.visibility_rounded,
                        color: AppColors.primaryLt,
                        outlined: true,
                        onTap: widget.onView,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _CardBtn(
                        label: l.isSw ? 'Hariri' : 'Edit',
                        icon: Icons.edit_rounded,
                        color: AppColors.accent,
                        outlined: false,
                        onTap: widget.onEdit,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _CardBtn(
                        label: l.isSw ? 'Futa' : 'Del',
                        icon: Icons.delete_rounded,
                        color: AppColors.chartRed,
                        outlined: false,
                        onTap: widget.onDelete,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(90)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 9),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 36),
        ),
        icon: Icon(icon, size: 13),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(210),
        foregroundColor: color == AppColors.chartRed
            ? Colors.white
            : AppColors.bgDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 9),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
      ),
      icon: Icon(icon, size: 13),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withAlpha(45)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 9),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MobileProductRow extends StatelessWidget {
  final Product product;
  final NumberFormat fmt;
  final Color stockColor;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _MobileProductRow({
    required this.product,
    required this.fmt,
    required this.stockColor,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final out = product.stock <= 0;
    final catColor = CatStyle.color(product.category);
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: out ? AppColors.chartRed.withAlpha(70) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: catColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: product.image.isNotEmpty
                    ? Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(CatStyle.icon(product.category), color: catColor, size: 22),
                      )
                    : Icon(CatStyle.icon(product.category), color: catColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: stockColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            out
                                ? l.outOfStock
                                : '${product.stock} ${product.unit}',
                            style: TextStyle(
                              color: stockColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (product.category.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              product.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmt.format(product.sellPrice),
                style: TextStyle(
                  color: AppColors.primaryLt,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              IconButton(
                onPressed: onMore,
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: l.isSw ? 'Zaidi' : 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// One dense row of the desktop inventory table.
class _ProductTableRow extends StatefulWidget {
  final Product product;
  final NumberFormat fmt;
  final Color stockColor;
  final String stockLabel;
  final VoidCallback onView, onEdit, onBatch, onDelete;
  const _ProductTableRow({
    required this.product,
    required this.fmt,
    required this.stockColor,
    required this.stockLabel,
    required this.onView,
    required this.onEdit,
    required this.onBatch,
    required this.onDelete,
  });

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final catColor = CatStyle.color(p.category);
    final canSeeCosts = context.read<AppProvider>().user?.canSeeCosts ?? false;
    final profit = p.sellPrice - p.buyPrice;
    final out = p.stock <= 0;
    Widget cell(String t, {int flex = 2, TextAlign align = TextAlign.left, Color? color, bool bold = false}) =>
        Expanded(
          flex: flex,
          child: Text(t,
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? AppColors.textWhite,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        );
    Widget act(IconData icon, Color c, String tip, VoidCallback onTap) => Tooltip(
          message: tip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 18, color: c),
            ),
          ),
        );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onView,
        child: Container(
          color: _hover ? AppColors.primary.withAlpha(18) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: catColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: p.image.isNotEmpty
                    ? Image.network(p.image, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(CatStyle.icon(p.category), color: catColor, size: 18))
                    : Icon(CatStyle.icon(p.category), color: catColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textWhite, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    if (p.barcode.isNotEmpty)
                      Text(p.barcode, style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                  ],
                ),
              ),
              cell(p.category.isEmpty ? '—' : p.category, color: AppColors.textMuted),
              cell('${p.stock} ${p.unit}', align: TextAlign.right,
                  color: out ? AppColors.chartRed : AppColors.textWhite, bold: true),
              cell(canSeeCosts ? widget.fmt.format(p.buyPrice) : '—', align: TextAlign.right, color: AppColors.textMuted),
              cell(widget.fmt.format(p.sellPrice), align: TextAlign.right, color: AppColors.primaryLt, bold: true),
              cell(!canSeeCosts ? '—' : '${profit >= 0 ? '+' : ''}${widget.fmt.format(profit)}', align: TextAlign.right,
                  color: canSeeCosts ? (profit >= 0 ? AppColors.accent : AppColors.chartRed) : AppColors.textMuted),
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.stockColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.stockLabel,
                        style: TextStyle(color: widget.stockColor, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              SizedBox(
                width: 132,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    act(Icons.visibility_rounded, AppColors.textMuted, 'Angalia', widget.onView),
                    act(Icons.edit_rounded, AppColors.primaryLt, 'Hariri', widget.onEdit),
                    act(Icons.add_box_rounded, AppColors.accent, 'Ongeza stock', widget.onBatch),
                    act(Icons.delete_outline_rounded, AppColors.chartRed, 'Futa', widget.onDelete),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
