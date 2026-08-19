import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';
import '../utils/cat_style.dart';
import 'product_form_sheet.dart';
import 'product_detail_sheet.dart';
import 'add_product_page.dart';
import 'add_batch_sheet.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(initialProduct: product, onSaved: _load),
    );
  }

  void _openAddBatch(Product product) {
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
      return matchSearch && matchFilter;
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
        _desktopHero(l),
        _buildToolbar(desktop: true, l: l),
        _buildStatsRow(desktop: true, l: l),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: _filtered.isEmpty
                      ? _emptyState(l)
                      : _buildProductGrid(l),
                ),
        ),
      ],
    );
  }

  Widget _desktopHero(L l) {
    final totalValue = _all.fold<double>(
      0,
      (s, p) => s + (p.sellPrice * p.stock),
    );
    final totalStock = _all.fold<int>(0, (s, p) => s + p.stock);
    final low = _all.where((p) => p.stock > 0 && p.stock <= 5).length;
    final out = _all.where((p) => p.stock <= 0).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: _FadeSlide(
        animation: _fadeAnim,
        offset: const Offset(0, -0.06),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryLt.withAlpha(38),
                AppColors.accent.withAlpha(20),
                AppColors.bgCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primaryLt.withAlpha(55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.accent.withAlpha(80)),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.productList,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.isSw
                          ? 'Simamia stock, bei, na hali ya bidhaa zako.'
                          : 'Manage stock, prices and product health.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _heroMetric('${_all.length}', l.products, AppColors.primaryLt),
              const SizedBox(width: 10),
              _heroMetric(
                '$totalStock',
                l.isSw ? 'Jumla Qty' : 'Total Qty',
                AppColors.chartBlue,
              ),
              const SizedBox(width: 10),
              _heroMetric(
                'TZS ${_fmt.format(totalValue)}',
                l.isSw ? 'Thamani' : 'Value',
                AppColors.accent,
              ),
              const SizedBox(width: 10),
              _heroMetric('$low / $out', l.kpiLowStock, AppColors.chartOrange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroMetric(String value, String label, Color color) => Container(
    constraints: const BoxConstraints(minWidth: 120),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.bg.withAlpha(125),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _buildProductGrid(L l) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final maxExtent = isWide ? 390.0 : 350.0;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisExtent: 296,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: _filtered.length,
          itemBuilder: (context, i) {
            final p = _filtered[i];
            return _ProFadeItem(
              index: i.clamp(0, 12),
              child: _DesktopProductCard(
                product: p,
                fmt: _fmt,
                stockColor: _stockColor(p),
                stockLabel: _stockLabel(p),
                onView: () => _openDetailProduct(p),
                onEdit: () => _openEditProduct(p),
                onDelete: () => _confirmDeleteProduct(p),
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final l = L.of(context);
    final mq = MediaQuery.of(context);
    final lowCount = _all
        .where(
          (p) =>
              p.stock <= 0 ||
              (p.stock > 0 && (p.stock <= p.minStock || p.stock <= 5)),
        )
        .length;
    const bottomNavHeight = 72.0;
    const bottomNavPadding = 10.0;
    const fabNavGap = 28.0;
    final fabBottom =
        mq.viewPadding.bottom + bottomNavHeight + bottomNavPadding + fabNavGap;

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bg, AppColors.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _mobileHeader(l, lowCount),
            _mobileInventoryHero(l),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border.withAlpha(180)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _buildToolbar(desktop: false, l: l),
            ),
            _buildAlertBanner(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.primary,
                            child: _filtered.isEmpty
                                ? ListView(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      30,
                                      16,
                                      fabBottom + 78,
                                    ),
                                    children: [_emptyState(l)],
                                  )
                                : ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      fabBottom + 82,
                                    ),
                                    itemCount: _filtered.length,
                                    itemBuilder: (ctx, i) => _ProFadeItem(
                                      index: i.clamp(0, 12),
                                      child: _MobileProductCard(
                                        product: _filtered[i],
                                        fmt: _fmt,
                                        stockColor: _stockColor(_filtered[i]),
                                        onView: () =>
                                            _openDetailProduct(_filtered[i]),
                                        onEdit: () =>
                                            _openEditProduct(_filtered[i]),
                                        onDelete: () =>
                                            _confirmDeleteProduct(_filtered[i]),
                                        onBatch: () =>
                                            _openAddBatch(_filtered[i]),
                                      ),
                                    ),
                                  ),
                          ),
                  ),
                  if (widget.showMobileFab)
                    Positioned(
                      right: 16,
                      bottom: fabBottom,
                      child: FloatingActionButton.extended(
                        heroTag: 'add_product_fab',
                        onPressed: _openAddProduct,
                        backgroundColor: AppColors.accent,
                        elevation: 8,
                        icon: Icon(
                          Icons.add_rounded,
                          color: AppColors.bgDark,
                          size: 22,
                        ),
                        label: Text(
                          l.isSw ? 'Ongeza Bidhaa' : l.addProductTitle,
                          style: TextStyle(
                            color: AppColors.bgDark,
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
      ),
    );
  }

  Widget _mobileHeader(L l, int lowCount) {
    final showBack = widget.onBack != null && !widget.showMobileFab;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(showBack ? 8 : 22, 12, 16, 18),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.products,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l.isSw
                          ? 'Simamia bidhaa na stock'
                          : 'Manage products and stock',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (lowCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$lowCount',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                tooltip: l.searchProd,
                onPressed: () => _searchFocus.requestFocus(),
                icon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              IconButton(
                tooltip: l.refresh,
                onPressed: _load,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileInventoryHero(L l) {
    final low = _all
        .where(
          (p) =>
              p.stock <= 0 ||
              (p.stock > 0 && (p.stock <= p.minStock || p.stock <= 5)),
        )
        .length;
    final totalValue = _all.fold<double>(
      0,
      (s, p) => s + (p.sellPrice * p.stock),
    );
    return _FadeSlide(
      animation: _fadeAnim,
      offset: const Offset(0, -0.10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withAlpha(150)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _MobileSummaryTile(
                icon: Icons.shopping_bag_outlined,
                label: l.isSw ? 'Jumla ya Bidhaa' : 'Total Products',
                value: '${_all.length}',
                suffix: l.isSw ? 'bidhaa' : 'items',
                color: AppColors.primary,
              ),
            ),
            _SummaryDivider(),
            Expanded(
              child: _MobileSummaryTile(
                icon: Icons.monetization_on_outlined,
                label: l.isSw ? 'Thamani ya Stock' : 'Stock Value',
                value: 'TZS ${_fmt.format(totalValue)}',
                suffix: l.isSw ? 'jumla' : 'total',
                color: AppColors.primary,
              ),
            ),
            _SummaryDivider(),
            Expanded(
              child: _MobileSummaryTile(
                icon: Icons.warning_amber_rounded,
                label: l.isSw ? 'Stock Ndogo' : 'Low Stock',
                value: '$low',
                suffix: l.isSw ? 'bidhaa' : 'items',
                color: AppColors.chartRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared ─────────────────────────────────────────────────────────────────
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

  Widget _buildStatsRow({required bool desktop, required L l}) {
    final total = _all.length;
    final totalStock = _all.fold<int>(0, (s, p) => s + p.stock);
    final totalValue = _all.fold<double>(
      0,
      (s, p) => s + (p.buyPrice * p.stock),
    );
    final inStock = _all.where((p) => p.stock > 5).length;
    final low = _all.where((p) => p.stock > 0 && p.stock <= 5).length;
    final out = _all.where((p) => p.stock <= 0).length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 24 : 12, vertical: 8),
      child: Row(
        children: [
          _statChip(
            '$total',
            l.products,
            AppColors.chartPurple,
            Icons.inventory_2_rounded,
          ),
          const SizedBox(width: 8),
          _statChip(
            '$totalStock',
            l.isSw ? 'Jumla Qty' : 'Total Qty',
            AppColors.chartBlue,
            Icons.layers_rounded,
          ),
          const SizedBox(width: 8),
          _statChip(
            'TZS ${_fmt.format(totalValue)}',
            l.isSw ? 'Gharama Hisa' : 'Inventory Cost',
            AppColors.primaryLt,
            Icons.attach_money_rounded,
          ),
          const SizedBox(width: 8),
          _statChip(
            '$inStock',
            l.filterInStock,
            AppColors.accent,
            Icons.check_circle_rounded,
          ),
          if (low > 0) ...[
            const SizedBox(width: 8),
            _statChip(
              '$low',
              l.kpiLowStock,
              AppColors.chartOrange,
              Icons.warning_amber_rounded,
            ),
          ],
          if (out > 0) ...[
            const SizedBox(width: 8),
            _statChip(
              '$out',
              l.kpiOutStock,
              AppColors.chartRed,
              Icons.remove_shopping_cart_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color.withAlpha(180), fontSize: 11),
            ),
          ],
        ),
      );

  // ── Alert banner ────────────────────────────────────────────────────────────
  Widget _buildAlertBanner() {
    if (_loading || _all.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final outList = _all.where((p) => p.stock <= 0).toList();
    final expList = _all
        .where((p) => p.expiryStatus == ExpiryStatus.expired)
        .toList();
    final lowList = _all
        .where((p) => p.stock > 0 && p.stock <= p.minStock && p.stock <= 5)
        .toList();
    final soonList = _all
        .where((p) => p.expiryStatus == ExpiryStatus.expiringSoon)
        .toList();
    final hasIssue = outList.isNotEmpty || expList.isNotEmpty;
    final hasWarn = !hasIssue && (lowList.isNotEmpty || soonList.isNotEmpty);
    if (!hasIssue && !hasWarn) {
      return const SizedBox.shrink();
    }

    final color = hasIssue ? AppColors.chartRed : AppColors.chartOrange;
    final icon = hasIssue ? Icons.error_rounded : Icons.warning_amber_rounded;
    final parts = <String>[];
    if (outList.isNotEmpty) {
      parts.add(
        '${outList.length} ${l.isSw ? "zimeisha stock" : "out of stock"}',
      );
    }
    if (expList.isNotEmpty) {
      parts.add('${expList.length} ${l.isSw ? "zimeisha muda" : "expired"}');
    }
    if (lowList.isNotEmpty) {
      parts.add('${lowList.length} ${l.isSw ? "stock ndogo" : "low stock"}');
    }
    if (soonList.isNotEmpty) {
      parts.add(
        '${soonList.length} ${l.isSw ? "zinaisha hivi karibuni" : "expiring soon"}',
      );
    }

    return GestureDetector(
      onTap: () => setState(() {
        _filter = outList.isNotEmpty ? 'out' : 'low';
        _applyFilter();
      }),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(
          children: [
            PulseWidget(
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.isSw ? 'Tatizo la Bidhaa' : 'Product Issues',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    parts.join(' • '),
                    style: TextStyle(color: color.withAlpha(180), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l.isSw ? 'Angalia' : 'View',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
class _MobileProductCard extends StatelessWidget {
  final Product product;
  final NumberFormat fmt;
  final Color stockColor;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBatch;

  const _MobileProductCard({
    required this.product,
    required this.fmt,
    required this.stockColor,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onBatch,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = CatStyle.color(product.category);
    final outOfStock = product.stock <= 0;
    final l = L.of(context);
    final badgeText = outOfStock
        ? (l.isSw ? 'Imeisha' : 'Out')
        : (product.stock <= product.minStock || product.stock <= 5)
        ? (l.isSw ? 'Low Stock' : 'Low Stock')
        : 'Stock ${product.stock}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withAlpha(130)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImageBox(product: product, color: catColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: outOfStock
                                        ? AppColors.textMuted
                                        : AppColors.textWhite,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  product.category.isNotEmpty
                                      ? product.category
                                      : l.noCategory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: stockColor.withAlpha(22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: stockColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'TZS ${fmt.format(product.sellPrice)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ProductActionButton(
                            icon: Icons.visibility_outlined,
                            color: AppColors.textWhite,
                            tooltip: l.isSw ? 'Angalia' : 'View',
                            onTap: onView,
                          ),
                          const SizedBox(width: 9),
                          _ProductActionButton(
                            icon: Icons.edit_outlined,
                            color: AppColors.textWhite,
                            tooltip: l.isSw ? 'Hariri' : 'Edit',
                            onTap: onEdit,
                          ),
                          const SizedBox(width: 9),
                          _ProductActionButton(
                            icon: Icons.inventory_2_outlined,
                            color: AppColors.textWhite,
                            tooltip: l.isSw ? 'Ongeza stock' : 'Add stock',
                            onTap: onBatch,
                          ),
                          const SizedBox(width: 9),
                          _ProductActionButton(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.chartRed,
                            tooltip: l.isSw ? 'Futa' : 'Delete',
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ],
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

class _ProductImageBox extends StatelessWidget {
  final Product product;
  final Color color;

  const _ProductImageBox({required this.product, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = product.stock <= 0
        ? Icons.remove_shopping_cart_rounded
        : CatStyle.icon(product.category);
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withAlpha(90)),
      ),
      clipBehavior: Clip.antiAlias,
      child: product.image.isNotEmpty
          ? Image.network(
              product.image,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) =>
                  Icon(icon, color: color, size: 34),
            )
          : Icon(icon, color: color, size: 34),
    );
  }
}

class _ProductActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ProductActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color == AppColors.chartRed
              ? AppColors.chartRed.withAlpha(10)
              : AppColors.bg.withAlpha(120),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: color == AppColors.chartRed
                ? AppColors.chartRed.withAlpha(42)
                : AppColors.border.withAlpha(130),
          ),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Product Card — Inventory Grid Card with hover effects
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
                // ── Info row 2: Buy Price + Profit ─────────────────────────────
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

class _MobileSummaryTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String suffix;
  final Color color;

  const _MobileSummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withAlpha(16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 25),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textLight, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              suffix,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 52,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: AppColors.border.withAlpha(120),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fade + stagger animation helpers
// ─────────────────────────────────────────────────────────────────────────────
class _FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Offset offset;
  const _FadeSlide({
    required this.animation,
    required this.child,
    this.offset = const Offset(0, 0.06),
  });

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: offset,
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

class _ProFadeItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _ProFadeItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = index.clamp(0, 10) * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
