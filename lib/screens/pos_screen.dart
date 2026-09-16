import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/customer.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';
import '../utils/cat_style.dart';
import '../widgets/discount_field.dart';
import '../widgets/first_run_tutorial.dart';
import '../widgets/manager_pin_dialog.dart';
import '../widgets/split_payment_field.dart';
import 'customers_screen.dart';

class PosScreen extends StatefulWidget {
  final bool desktop;
  final ValueChanged<int>? onNavChange;
  const PosScreen({super.key, this.desktop = false, this.onNavChange});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _selectedCat = 'Zote';
  List<String> _categories = ['Zote'];
  final _fmt = NumberFormat('#,###', 'en_US');
  final _searchCtrl = TextEditingController();
  // Desktop: USB barcode scanner / manual barcode entry → auto-add to cart
  final _barcodeDesktopCtrl = TextEditingController();

  // Mobile barcode scan
  bool get _canScan => kIsWeb || Platform.isAndroid || Platform.isIOS;

  // Desktop: called when USB scanner or keyboard submits a barcode
  void _handleDesktopBarcode(String raw) {
    final code = raw.trim();
    _barcodeDesktopCtrl.clear();
    if (code.isEmpty) return;

    final l = L.of(context);
    // Try exact barcode match first, then partial
    final matches = _allProducts
        .where((p) => p.barcode.isNotEmpty && p.barcode == code)
        .toList();

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.isSw
                ? 'Barcode "$code" haikupatikana'
                : 'Barcode "$code" not found',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final product = matches.first;
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.isSw
                ? '${product.name}: haina stock'
                : '${product.name}: out of stock',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    context.read<CartProvider>().addProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.isSw
              ? '✓ ${product.name} imeongezwa kwenye cart'
              : '✓ ${product.name} added to cart',
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _openBarcodeScanner() {
    if (!_canScan) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PosBarcodeSheet(onScanned: _addByBarcode),
    );
  }

  /// Look a barcode up in the FULL product list (ignores search/category
  /// filters) and add it to the cart. Returns a message for the scanner toast
  /// and whether it succeeded.
  ({bool ok, String msg}) _addByBarcode(String raw) {
    final code = raw.trim();
    final l = L.of(context);
    final matches = _allProducts.where((p) => p.barcode == code).toList();
    if (matches.isEmpty) {
      return (ok: false, msg: l.isSw ? 'Barcode haijulikani: $code' : 'Unknown barcode: $code');
    }
    final p = matches.first;
    if (p.stock <= 0) {
      return (ok: false, msg: '${p.name} — ${l.outOfStock}');
    }
    final cart = context.read<CartProvider>();
    final before = cart.count;
    cart.addProduct(p);
    if (cart.count == before) {
      return (ok: false, msg: l.isSw ? '${p.name}: stock imefika kikomo' : '${p.name}: stock limit reached');
    }
    final inCart = cart.items
        .where((i) => i.productId == p.productId)
        .fold(0, (a, i) => a + i.qty);
    return (ok: true, msg: '${p.name}  ×$inCart');
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeDesktopCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
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
      final cats = <String>{'Zote'};
      for (var p in prods) {
        if (p.category.isNotEmpty) cats.add(p.category);
      }
      setState(() {
        _allProducts = prods;
        _filtered = prods;
        _categories = cats.toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    setState(() {
      _filtered = _allProducts.where((p) {
        final matchCat = _selectedCat == 'Zote' || p.category == _selectedCat;
        final matchSearch =
            _search.isEmpty ||
            p.name.toLowerCase().contains(_search.toLowerCase()) ||
            p.barcode.contains(_search);
        return matchCat && matchSearch;
      }).toList();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return widget.desktop ? _buildDesktop() : _buildMobile();
  }

  // ══════════════════════════════════════════════════════════════════
  // DESKTOP: split panel — products left, cart right
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    return Row(
      children: [
        // ── Left: Product browser ──────────────────────────────────────
        Expanded(
          flex: 6,
          child: _ProductBrowser(
            categories: _categories,
            filtered: _filtered,
            loading: _loading,
            selectedCat: _selectedCat,
            searchCtrl: _searchCtrl,
            fmt: _fmt,
            onSearch: (v) {
              _search = v;
              _filter();
            },
            onCatSelect: (c) {
              setState(() => _selectedCat = c);
              _filter();
            },
            onRefresh: _loadProducts,
            desktop: true,
            onScanTap: _canScan ? _openBarcodeScanner : null,
            barcodeCtrl: _barcodeDesktopCtrl,
            onBarcodeSubmit: _handleDesktopBarcode,
          ),
        ),
        // ── Divider ───────────────────────────────────────────────────
        Container(width: 1, color: AppColors.border),
        // ── Right: Cart panel ─────────────────────────────────────────
        SizedBox(
          width: 360,
          child: _CartPanel(fmt: _fmt, onNavChange: widget.onNavChange),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MOBILE: products + FAB cart button
  // ══════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PremiumPageEntrance(
        child: _MobileProductBrowser(
          categories: _categories,
          filtered: _filtered,
          loading: _loading,
          selectedCat: _selectedCat,
          searchCtrl: _searchCtrl,
          fmt: _fmt,
          onSearch: (v) {
            _search = v;
            _filter();
          },
          onCatSelect: (c) {
            setState(() => _selectedCat = c);
            _filter();
          },
          onRefresh: _loadProducts,
          onScanTap: _canScan ? _openBarcodeScanner : null,
        ),
      ),
      floatingActionButton: cart.count > 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: FloatingActionButton.extended(
                heroTag: 'pos_mobile_cart_fab',
                onPressed: () => _showMobileCart(context),
                backgroundColor: AppColors.primary,
                elevation: 12,
                icon: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  '${cart.count}  •  TZS ${_fmt.format(cart.total)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showMobileCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CartSheet(fmt: _fmt),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POS Pro Hero Summary
// ─────────────────────────────────────────────────────────────────────────────
class _PosHeroSummary extends StatelessWidget {
  final int products;
  final bool desktop;
  final VoidCallback? onScanTap;
  final VoidCallback onRefresh;

  const _PosHeroSummary({
    required this.products,
    required this.desktop,
    required this.onScanTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cart = context.watch<CartProvider>();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(
          desktop ? 20 : 12,
          desktop ? 14 : 12,
          12,
          4,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradHeader,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withAlpha(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.isSw ? 'Kuuza Haraka' : 'Quick Sale',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cart.count} ${l.items} • TZS ${NumberFormat('#,###', 'en_US').format(cart.total)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MiniPosPill(
                        icon: Icons.inventory_2_rounded,
                        label: '$products ${l.kpiProducts}',
                      ),
                      _MiniPosPill(
                        icon: Icons.shopping_cart_rounded,
                        label: '${cart.count} ${l.cart}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onScanTap != null) ...[
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.qr_code_scanner_rounded,
                onTap: onScanTap!,
              ),
            ],
            const SizedBox(width: 8),
            _RoundAction(icon: Icons.refresh_rounded, onTap: onRefresh),
          ],
        ),
      ),
    );
  }
}

class _MiniPosPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniPosPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withAlpha(24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accentBright, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(28)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _ProStaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _ProStaggeredItem({required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 10) * 45);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - v)),
          child: Transform.scale(scale: 0.96 + (0.04 * v), child: child),
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Browser (shared between desktop and mobile)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductBrowser extends StatelessWidget {
  final List<String> categories;
  final List<Product> filtered;
  final bool loading;
  final String selectedCat;
  final TextEditingController searchCtrl;
  final NumberFormat fmt;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCatSelect;
  final VoidCallback onRefresh;
  final bool desktop;
  final VoidCallback? onScanTap;
  // Desktop: USB / keyboard barcode entry
  final TextEditingController? barcodeCtrl;
  final ValueChanged<String>? onBarcodeSubmit;

  const _ProductBrowser({
    required this.categories,
    required this.filtered,
    required this.loading,
    required this.selectedCat,
    required this.searchCtrl,
    required this.fmt,
    required this.onSearch,
    required this.onCatSelect,
    required this.onRefresh,
    required this.desktop,
    this.onScanTap,
    this.barcodeCtrl,
    this.onBarcodeSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final crossAxis = desktop ? 3 : 2;
    return Column(
      children: [
        // Hero summary (mobile only – the desktop cart panel shows totals)
        if (!desktop)
          _PosHeroSummary(
            products: filtered.length,
            desktop: desktop,
            onScanTap: onScanTap,
            onRefresh: onRefresh,
          ),
        // Search bar (+ USB/keyboard barcode field on desktop)
        Padding(
          padding: EdgeInsets.fromLTRB(desktop ? 20 : 12, desktop ? 16 : 14, desktop ? 20 : 12, 6),
          child: Row(
            children: [
              if (desktop && barcodeCtrl != null && onBarcodeSubmit != null) ...[
                Expanded(
                  child: _DesktopBarcodeBar(
                    controller: barcodeCtrl!,
                    onSubmit: onBarcodeSubmit!,
                    l: l,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  style: TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    hintText: l.searchProduct,
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
                  ),
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: 8),
              // Barcode scan button (mobile only)
              if (onScanTap != null)
                Tooltip(
                  message: 'Scan Barcode',
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradPrimary,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: onScanTap,
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              if (onScanTap != null) const SizedBox(width: 8),
              Tooltip(
                message: 'Refresh bidhaa',
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: onRefresh,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Category chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: desktop ? 20 : 12),
            itemCount: categories.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final sel = cat == selectedCat;
              return ChoiceChip(
                label: Text(
                  cat,
                  style: TextStyle(
                    color: sel ? Colors.white : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: sel,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                side: BorderSide(
                  color: sel ? AppColors.primary : AppColors.border,
                ),
                onSelected: (_) => onCatSelect(cat),
              );
            },
          ),
        ),
        // Stats row
        if (filtered.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: desktop ? 20 : 12,
              vertical: 6,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} ${l.kpiProducts}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 4),
        // Products grid
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textMuted,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.noProducts,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l.refresh),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 20 : 12,
                    0,
                    desktop ? 20 : 12,
                    desktop ? 16 : 130,
                  ),
                  gridDelegate: desktop
                      // as many ~170px cards as fit → ~6 per row on a laptop
                      ? const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        )
                      : SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxis,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.85,
                        ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ProStaggeredItem(
                    index: i,
                    child: _ProductCard(product: filtered[i], fmt: fmt, compact: desktop),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop barcode bar — prominent card with focus animation
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopBarcodeBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final L l;

  const _DesktopBarcodeBar({
    required this.controller,
    required this.onSubmit,
    required this.l,
  });

  @override
  State<_DesktopBarcodeBar> createState() => _DesktopBarcodeBarState();
}

class _DesktopBarcodeBarState extends State<_DesktopBarcodeBar> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    // USB scanners "type" into the focused field – keep it ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onFocusChange() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      style: TextStyle(color: AppColors.textWhite, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: widget.l.isSw
            ? 'Scan barcode (USB) au andika + Enter'
            : 'Scan barcode (USB) or type + Enter',
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(
          Icons.qr_code_scanner_rounded,
          color: _focused ? AppColors.primaryLt : AppColors.textMuted,
          size: 20,
        ),
        suffixIcon: _focused
            ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _focused ? AppColors.primary.withAlpha(30) : AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary.withAlpha(120)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onSubmitted: (v) {
        widget.onSubmit(v);
        _focus.requestFocus();
      },
    );
  }
}

void _showUnitPicker(BuildContext context, Product product) {
  final fmt = NumberFormat('#,###', 'en_US');
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withAlpha(70)),
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        L.of(context).isSw
                            ? 'Chagua unit ya kuuza'
                            : 'Select selling unit',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Unit options
          ...product.units.map((unit) {
            final maxQty = unit.maxQty(product.stock);
            final canSell = maxQty > 0;
            return ListTile(
              enabled: canSell,
              onTap: canSell
                  ? () {
                      Navigator.pop(context);
                      context.read<CartProvider>().addProductWithUnit(
                        product,
                        unit,
                      );
                    }
                  : null,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: canSell
                      ? AppColors.primary.withAlpha(22)
                      : AppColors.chartGray.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canSell
                        ? AppColors.primary.withAlpha(70)
                        : AppColors.chartGray.withAlpha(30),
                  ),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: canSell ? AppColors.primary : AppColors.chartGray,
                  size: 18,
                ),
              ),
              title: Text(
                unit.unitName,
                style: TextStyle(
                  color: canSell ? AppColors.textWhite : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '= ${unit.conversionLabel(product.unit)}  •  '
                '${canSell
                    ? L.of(context).isSw
                          ? "Stock: $maxQty"
                          : "In stock: $maxQty"
                    : (L.of(context).isSw ? "Imeisha" : "Out of stock")}',
                style: TextStyle(
                  color: canSell ? AppColors.textMuted : AppColors.chartRed,
                  fontSize: 11,
                ),
              ),
              trailing: canSell
                  ? Text(
                      'TZS ${fmt.format(unit.sellingPrice)}',
                      style: const TextStyle(
                        color: AppColors.primaryLt,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            );
          }),
          // Also offer base unit
          ListTile(
            enabled: product.stock > 0,
            onTap: product.stock > 0
                ? () {
                    Navigator.pop(context);
                    context.read<CartProvider>().addProduct(product);
                  }
                : null,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withAlpha(60)),
              ),
              child: const Icon(
                Icons.circle_outlined,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            title: Text(
              product.unit.isNotEmpty ? product.unit : 'Base unit',
              style: TextStyle(
                color: product.stock > 0
                    ? AppColors.textWhite
                    : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '= 1 ${product.unit}  •  ${product.stock} ${L.of(context).isSw ? "zinapatikana" : "in stock"}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            trailing: Text(
              'TZS ${fmt.format(product.sellPrice)}',
              style: const TextStyle(
                color: AppColors.primaryLt,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Card
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final NumberFormat fmt;
  /// Tighter spacing / smaller type for the 3-column phone grid.
  final bool compact;
  const _ProductCard({required this.product, required this.fmt, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    // Sum qty across ALL units of this product in cart
    final qtyInCart = cart.items
        .where((i) => i.productId == product.productId)
        .fold(0, (sum, i) => sum + i.qty);
    final outOfStock = product.stock <= 0;
    final catColor = outOfStock
        ? AppColors.chartGray
        : CatStyle.color(product.category);
    final catIcon = outOfStock
        ? Icons.remove_shopping_cart_rounded
        : CatStyle.icon(product.category);

    return GestureDetector(
      onTap: outOfStock
          ? null
          : () {
              if (product.units.isNotEmpty) {
                _showUnitPicker(context, product);
              } else {
                context.read<CartProvider>().addProduct(product);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(compact ? 20 : 35),
              blurRadius: compact ? 6 : 12,
              offset: Offset(0, compact ? 3 : 6),
            ),
          ],
          border: Border.all(
            color: qtyInCart > 0
                ? AppColors.primary
                : outOfStock
                ? AppColors.chartGray.withAlpha(60)
                : AppColors.border,
            width: qtyInCart > 0 ? 1.8 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(compact ? 8 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category icon ───────────────────────────────────────────
                  Container(
                    width: compact ? 32 : 46,
                    height: compact ? 32 : 46,
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(outOfStock ? 15 : 28),
                      borderRadius: BorderRadius.circular(compact ? 10 : 14),
                      border: Border.all(
                        color: catColor.withAlpha(outOfStock ? 30 : 70),
                      ),
                    ),
                    child: Icon(catIcon, color: catColor, size: compact ? 16 : 22),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  // ── Name ─────────────────────────────────────────────────────
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: outOfStock
                          ? AppColors.textMuted
                          : AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 11.5 : 13,
                      height: 1.15,
                    ),
                  ),
                  const Spacer(),
                  // ── Price ─────────────────────────────────────────────────────
                  Text(
                    compact
                        ? fmt.format(product.sellPrice)
                        : 'TZS ${fmt.format(product.sellPrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: outOfStock
                          ? AppColors.textMuted
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 12.5 : 14,
                    ),
                  ),
                  SizedBox(height: compact ? 1 : 3),
                  // ── Stock ─────────────────────────────────────────────────────
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_outlined,
                        size: 11,
                        color: outOfStock
                            ? AppColors.chartRed
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                        '${product.stock} ${product.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: outOfStock
                              ? AppColors.chartRed
                              : AppColors.textMuted,
                          fontSize: compact ? 10 : 11,
                          fontWeight: outOfStock
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Cart qty badge ───────────────────────────────────────────────
            if (qtyInCart > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(80),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '$qtyInCart',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // ── Out of stock label ───────────────────────────────────────────
            if (outOfStock)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.chartRed.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    L.of(context).outOfStock,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared checkout helpers
// ─────────────────────────────────────────────────────────────────────────────
class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
      color: AppColors.bg,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onMinus,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
          child: const Padding(
            padding: EdgeInsets.all(7),
            child: Icon(
              Icons.remove_rounded,
              size: 15,
              color: Colors.redAccent,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$qty',
            style: TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        InkWell(
          onTap: onPlus,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(9),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}

class _TotalCard extends StatelessWidget {
  final NumberFormat fmt;
  final double total;
  final double discount;
  const _TotalCard({required this.fmt, required this.total, this.discount = 0});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final grandTotal = (total - discount).clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withAlpha(50), AppColors.bg],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (discount > 0) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Jumla ndogo', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('TZS ${fmt.format(total)}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 3),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Punguzo', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('- TZS ${fmt.format(discount)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 6),
          ],
          Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l.total,
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Text(
            'TZS ${fmt.format(grandTotal)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }
}

class _CustomerModeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CustomerModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            selected: value == 'walkin',
            icon: Icons.shopping_bag_outlined,
            label: l.isSw ? 'Wa kawaida' : 'Walk-in',
            onTap: () => onChanged('walkin'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            selected: value == 'potential',
            icon: Icons.star_border_rounded,
            label: l.isSw ? 'Potential' : 'Potential',
            onTap: () => onChanged('potential'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            selected: value == 'registered',
            icon: Icons.verified_user_outlined,
            label: l.isSw ? 'Mkopo/SMS' : 'Credit/SMS',
            onTap: () => onChanged('registered'),
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ModeChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


/// "Chagua mteja" button — opens the customer list in pick mode and fills
/// the name/phone fields of the checkout form.
class _PickCustomerButton extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final ValueChanged<Customer> onPicked;
  const _PickCustomerButton({required this.nameCtrl, required this.phoneCtrl, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Tooltip(
      message: l.isSw ? 'Chagua mteja aliyesajiliwa' : 'Pick a saved customer',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: AppColors.primary.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final c = await Navigator.of(context).push<Customer>(
                MaterialPageRoute(builder: (_) => const CustomersScreen(pickMode: true)),
              );
              if (c == null) return;
              nameCtrl.text = c.name;
              if (c.phone.isNotEmpty) phoneCtrl.text = c.phone;
              onPicked(c);
            },
            child: Icon(Icons.person_search_rounded, color: AppColors.primaryLt, size: 22),
          ),
        ),
      ),
    );
  }
}

class _PosInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  const _PosInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: TextStyle(color: AppColors.textWhite, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Cart Panel (persistent right panel)
// ─────────────────────────────────────────────────────────────────────────────
class _CartPanel extends StatefulWidget {
  final NumberFormat fmt;
  final ValueChanged<int>? onNavChange;
  const _CartPanel({required this.fmt, this.onNavChange});
  @override
  State<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<_CartPanel> {
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();

  // walkin = mteja wa kawaida, potential = anaweza kurudi, registered = mteja kamili/mkopo/SMS
  String _customerMode = 'walkin';
  String _payType = 'cash';
  bool _processing = false;
  SplitPaymentResult _splitPay = SplitPaymentResult.off;
  double _discount = 0;

  // Set when "Chagua mteja" is used; only trusted at checkout if the phone
  // field still matches what was picked (guards against a stale id if the
  // cashier picks someone then types a different number for someone else).
  int? _pickedCustomerId;
  String? _pickedCustomerPhone;

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  bool get _needsCustomerDetails =>
      _customerMode != 'walkin' ||
      _payType == 'loan' ||
      _payType == 'slow_payment' ||
      _payType == 'cash_not_collected';

  String _customerPayload() {
    final name = _customerCtrl.text.trim().isEmpty
        ? 'Walk-in Customer'
        : _customerCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final loc = _locationCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (!_needsCustomerDetails) return name;

    final parts = <String>[
      name,
      'TYPE:${_customerMode.toUpperCase()}',
      if (phone.isNotEmpty) 'PHONE:$phone',
      if (loc.isNotEmpty) 'LOCATION:$loc',
      if (note.isNotEmpty) 'NOTE:$note',
    ];
    return parts.join(' | ');
  }

  double? _amountPaid() {
    if (_payType == 'cash') return null;
    return double.tryParse(_paidCtrl.text.replaceAll(',', '').trim());
  }

  Future<void> _checkout() async {
    final l = L.of(context);
    final app = context.read<AppProvider>();
    final cart = context.read<CartProvider>();

    if (cart.count <= 0) return;

    if (_needsCustomerDetails) {
      if (_customerCtrl.text.trim().isEmpty) {
        _snack(
          l.isSw ? 'Weka jina la mteja' : 'Enter customer name',
          Colors.orange,
        );
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        _snack(
          l.isSw
              ? 'Weka namba ya simu kwa mteja wa mkopo/potential/SMS'
              : 'Enter phone number for credit/potential/SMS customer',
          Colors.orange,
        );
        return;
      }
    }

    if (_payType == 'cash' && _splitPay.enabled && !_splitPay.valid) {
      _snack(
        l.isSw
            ? 'Jumla ya njia za malipo haiendani na jumla ya mauzo'
            : 'Split payment total does not match the sale total',
        Colors.orange,
      );
      return;
    }

    if (app.api == null || app.selectedBusiness == null) return;

    // ── Punguzo kubwa (>10% ya jumla) linahitaji PIN ya meneja isipokuwa
    // mtumaji mwenyewe ni meneja/mmiliki tayari (ona helpers/manager_pin.php).
    String? discountPin;
    if (_discount > 0 && cart.total > 0 && (_discount / cart.total) * 100 > 10 &&
        app.user?.isManagerTier != true) {
      discountPin = await ManagerPinDialog.show(context,
          reasonLabel: 'Punguzo hili linazidi 10% ya jumla — meneja aweke PIN yake.');
      if (discountPin == null) return; // cashier cancelled
    }

    final grandTotal = (cart.total - _discount).clamp(0, cart.total);

    setState(() => _processing = true);
    try {
      final phone = _phoneCtrl.text.trim();
      final confirmedCustomerId =
          (_pickedCustomerId != null && _pickedCustomerPhone == phone) ? _pickedCustomerId : null;
      final res = await app.api!.createSale(
        businessId: app.selectedBusiness!.businessId,
        branchId: app.selectedBranch?.branchId ?? 0,
        customerName: _customerPayload(),
        transactionType: _payType,
        items: cart.toApiItems(),
        amountPaid: _amountPaid(),
        customerPhone: phone,
        customerId: confirmedCustomerId,
        payments: (_payType == 'cash' && _splitPay.enabled) ? _splitPay.payments : null,
        overallDiscount: _discount > 0 ? _discount : null,
        managerPin: discountPin,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final receipt = _PosReceiptData.fromCart(
          response: res,
          businessName: app.selectedBusiness!.receiptHeader.isNotEmpty
              ? app.selectedBusiness!.receiptHeader
              : app.selectedBusiness!.businessName,
          footerMessage: app.selectedBusiness!.receiptFooter,
          customerName: _customerCtrl.text.trim().isEmpty
              ? 'Walk-in Customer'
              : _customerCtrl.text.trim(),
          customerPhone: _phoneCtrl.text.trim(),
          customerType: _customerMode,
          paymentType: _payType,
          total: grandTotal.toDouble(),
          amountPaid: _amountPaid() ?? grandTotal.toDouble(),
          changeAmount: (res['change_amount'] as num?)?.toDouble() ??
              (_splitPay.enabled ? _splitPay.changeAmount : null),
          discount: (res['discount_amount'] as num?)?.toDouble() ?? _discount,
          items: cart.items
              .map(
                (i) => _PosReceiptItem(
                  name: i.productName,
                  qty: i.qty,
                  unitPrice: i.unitPrice,
                  subtotal: i.subtotal,
                ),
              )
              .toList(),
        );

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _PosReceiptSheet(receipt: receipt, fmt: widget.fmt),
        );

        if (!mounted) return;
        cart.clear();
        _customerCtrl.clear();
        _phoneCtrl.clear();
        _locationCtrl.clear();
        _noteCtrl.clear();
        _paidCtrl.clear();
        setState(() {
          _customerMode = 'walkin';
          _payType = 'cash';
          _pickedCustomerId = null;
          _pickedCustomerPhone = null;
          _splitPay = SplitPaymentResult.off;
          _discount = 0;
        });
        _snack(
          res['offline'] == true
              ? (res['message'] as String? ?? L.of(context).saleSuccess)
              : L.of(context).saleSuccess,
          res['offline'] == true ? Colors.orange : AppColors.accent,
        );
        widget.onNavChange?.call(2);
      } else {
        _snack(
          res['message'] as String? ?? L.of(context).error,
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cart = context.watch<CartProvider>();
    return Container(
      color: AppColors.bgCard,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradPrimary,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.cart,
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${cart.count} ${l.items} • TZS ${widget.fmt.format(cart.total)}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cart.count > 0)
                  IconButton(
                    tooltip: l.clearCart,
                    onPressed: () => context.read<CartProvider>().clear(),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          color: AppColors.border,
                          size: 60,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.cartEmpty,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.cartEmptySub,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: cart.items.length,
                    separatorBuilder: (ctx, i) =>
                        Divider(color: AppColors.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textWhite,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'TZS ${widget.fmt.format(item.unitPrice)}${item.unitName.isNotEmpty ? " / ${item.unitName}" : " / kila moja"}',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _QtyStepper(
                              qty: item.qty,
                              onMinus: () => context
                                  .read<CartProvider>()
                                  .decreaseQty(item.cartKey),
                              onPlus: () => context
                                  .read<CartProvider>()
                                  .increaseQty(item.cartKey),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: Text(
                                'TZS ${widget.fmt.format(item.subtotal)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          if (cart.count > 0) ...[
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  children: [
                    _TotalCard(fmt: widget.fmt, total: cart.total, discount: _discount),
                    DiscountField(
                      subtotal: cart.total,
                      onChanged: (r) => setState(() => _discount = r.amount),
                    ),
                    const SizedBox(height: 12),
                    _CustomerModeSelector(
                      value: _customerMode,
                      onChanged: (v) => setState(() => _customerMode = v),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PosInput(
                            controller: _customerCtrl,
                            hint: _needsCustomerDetails
                                ? l.customer
                                : (l.isSw
                                      ? 'Jina la mteja (optional)'
                                      : 'Customer name (optional)'),
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PickCustomerButton(
                          nameCtrl: _customerCtrl,
                          phoneCtrl: _phoneCtrl,
                          onPicked: (c) => setState(() {
                            if (_customerMode == 'walkin') _customerMode = 'registered';
                            _pickedCustomerId = c.customerId != 0 ? c.customerId : null;
                            _pickedCustomerPhone = c.phone;
                          }),
                        ),
                      ],
                    ),
                    if (_needsCustomerDetails) ...[
                      const SizedBox(height: 10),
                      _PosInput(
                        controller: _phoneCtrl,
                        hint: l.isSw
                            ? 'Namba ya simu kwa SMS'
                            : 'Phone number for SMS',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 10),
                      _PosInput(
                        controller: _locationCtrl,
                        hint: l.isSw
                            ? 'Mahali / anuani (optional)'
                            : 'Location / address (optional)',
                        icon: Icons.location_on_outlined,
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _payType,
                      dropdownColor: AppColors.bgCard,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: l.payType,
                        labelStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.payment_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(value: 'cash', child: Text(l.cash)),
                        DropdownMenuItem(value: 'loan', child: Text(l.loan)),
                        DropdownMenuItem(
                          value: 'slow_payment',
                          child: Text(l.slowPay),
                        ),
                        DropdownMenuItem(
                          value: 'cash_not_collected',
                          child: Text(l.cashNotCollected),
                        ),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text(l.bankTransfer),
                        ),
                      ],
                      onChanged: (v) => setState(() => _payType = v!),
                    ),
                    if (_payType == 'cash')
                      SplitPaymentField(
                        total: (cart.total - _discount).clamp(0, cart.total),
                        onChanged: (r) => setState(() => _splitPay = r),
                      ),
                    if (_payType != 'cash') ...[
                      const SizedBox(height: 10),
                      _PosInput(
                        controller: _paidCtrl,
                        hint: l.isSw
                            ? 'Kiasi alicholipa sasa (optional)'
                            : 'Amount paid now (optional)',
                        icon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    if (_needsCustomerDetails) ...[
                      const SizedBox(height: 10),
                      _PosInput(
                        controller: _noteCtrl,
                        hint: l.isSw
                            ? 'Maelezo ya mteja/mkopo/SMS (optional)'
                            : 'Customer/credit/SMS notes (optional)',
                        icon: Icons.note_alt_outlined,
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _processing ? null : _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _processing
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: AppColors.bgDark,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.check_circle_outline_rounded,
                                color: AppColors.bgDark,
                              ),
                        label: Text(
                          _processing ? l.saving : l.saveSale,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.bgDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Cart Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  final NumberFormat fmt;
  const _CartSheet({required this.fmt});
  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();

  String _customerMode = 'walkin';
  String _payType = 'cash';
  bool _processing = false;
  SplitPaymentResult _splitPay = SplitPaymentResult.off;
  double _discount = 0;

  int? _pickedCustomerId;
  String? _pickedCustomerPhone;

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  bool get _needsCustomerDetails =>
      _customerMode != 'walkin' ||
      _payType == 'loan' ||
      _payType == 'slow_payment' ||
      _payType == 'cash_not_collected';

  String _customerPayload() {
    final name = _customerCtrl.text.trim().isEmpty
        ? 'Walk-in Customer'
        : _customerCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final loc = _locationCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (!_needsCustomerDetails) return name;

    return <String>[
      name,
      'TYPE:${_customerMode.toUpperCase()}',
      if (phone.isNotEmpty) 'PHONE:$phone',
      if (loc.isNotEmpty) 'LOCATION:$loc',
      if (note.isNotEmpty) 'NOTE:$note',
    ].join(' | ');
  }

  double? _amountPaid() {
    if (_payType == 'cash') return null;
    return double.tryParse(_paidCtrl.text.replaceAll(',', '').trim());
  }

  Future<void> _checkout() async {
    final l = L.of(context);
    final app = context.read<AppProvider>();
    final cart = context.read<CartProvider>();

    if (cart.count <= 0) return;

    if (_needsCustomerDetails) {
      if (_customerCtrl.text.trim().isEmpty) {
        _snack(
          l.isSw ? 'Weka jina la mteja' : 'Enter customer name',
          Colors.orange,
        );
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        _snack(
          l.isSw
              ? 'Weka namba ya simu kwa mteja wa mkopo/potential/SMS'
              : 'Enter phone number for credit/potential/SMS customer',
          Colors.orange,
        );
        return;
      }
    }

    if (_payType == 'cash' && _splitPay.enabled && !_splitPay.valid) {
      _snack(
        l.isSw
            ? 'Jumla ya njia za malipo haiendani na jumla ya mauzo'
            : 'Split payment total does not match the sale total',
        Colors.orange,
      );
      return;
    }

    if (app.api == null || app.selectedBusiness == null) return;

    // ── Punguzo kubwa (>10% ya jumla) linahitaji PIN ya meneja isipokuwa
    // mtumaji mwenyewe ni meneja/mmiliki tayari (ona helpers/manager_pin.php).
    String? discountPin;
    if (_discount > 0 && cart.total > 0 && (_discount / cart.total) * 100 > 10 &&
        app.user?.isManagerTier != true) {
      discountPin = await ManagerPinDialog.show(context,
          reasonLabel: 'Punguzo hili linazidi 10% ya jumla — meneja aweke PIN yake.');
      if (discountPin == null) return; // cashier cancelled
    }

    final grandTotal = (cart.total - _discount).clamp(0, cart.total);

    setState(() => _processing = true);
    try {
      final phone = _phoneCtrl.text.trim();
      final confirmedCustomerId =
          (_pickedCustomerId != null && _pickedCustomerPhone == phone) ? _pickedCustomerId : null;
      final res = await app.api!.createSale(
        businessId: app.selectedBusiness!.businessId,
        branchId: app.selectedBranch?.branchId ?? 0,
        customerName: _customerPayload(),
        transactionType: _payType,
        items: cart.toApiItems(),
        amountPaid: _amountPaid(),
        customerPhone: phone,
        customerId: confirmedCustomerId,
        payments: (_payType == 'cash' && _splitPay.enabled) ? _splitPay.payments : null,
        overallDiscount: _discount > 0 ? _discount : null,
        managerPin: discountPin,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final receipt = _PosReceiptData.fromCart(
          response: res,
          businessName: app.selectedBusiness!.receiptHeader.isNotEmpty
              ? app.selectedBusiness!.receiptHeader
              : app.selectedBusiness!.businessName,
          footerMessage: app.selectedBusiness!.receiptFooter,
          customerName: _customerCtrl.text.trim().isEmpty
              ? 'Walk-in Customer'
              : _customerCtrl.text.trim(),
          customerPhone: _phoneCtrl.text.trim(),
          customerType: _customerMode,
          paymentType: _payType,
          total: grandTotal.toDouble(),
          amountPaid: _amountPaid() ?? grandTotal.toDouble(),
          changeAmount: (res['change_amount'] as num?)?.toDouble() ??
              (_splitPay.enabled ? _splitPay.changeAmount : null),
          discount: (res['discount_amount'] as num?)?.toDouble() ?? _discount,
          items: cart.items
              .map(
                (i) => _PosReceiptItem(
                  name: i.productName,
                  qty: i.qty,
                  unitPrice: i.unitPrice,
                  subtotal: i.subtotal,
                ),
              )
              .toList(),
        );

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _PosReceiptSheet(receipt: receipt, fmt: widget.fmt),
        );

        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final offline = res['offline'] == true;
        final successMsg = offline
            ? (res['message'] as String? ?? L.of(context).saleSuccess)
            : L.of(context).saleSuccess;
        cart.clear();
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: offline ? Colors.orange : AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _snack(
          res['message'] as String? ?? L.of(context).error,
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cart = context.watch<CartProvider>();
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final maxItemsH = mq.size.height * 0.34;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.94),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── handle + header ───────────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.isSw ? 'Kamilisha Mauzo' : 'Complete Sale',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${cart.count} ${l.items}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // ── items (bounded, scrolls on its own) ───────────────────────
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxItemsH),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cart.items.length,
                separatorBuilder: (_, _) =>
                    Divider(color: AppColors.border, height: 1),
                itemBuilder: (ctx, i) {
                  final item = cart.items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                '@ ${widget.fmt.format(item.unitPrice)}${item.unitName.isNotEmpty ? " / ${item.unitName}" : ""}',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _QtyStepper(
                          qty: item.qty,
                          onMinus: () => context
                              .read<CartProvider>()
                              .decreaseQty(item.cartKey),
                          onPlus: () => context
                              .read<CartProvider>()
                              .increaseQty(item.cartKey),
                        ),
                        SizedBox(
                          width: 74,
                          child: Text(
                            widget.fmt.format(item.subtotal),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(color: AppColors.border, height: 1),
            // ── payment form (fits; scrolls only when the keyboard is up) ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DiscountField(
                      subtotal: cart.total,
                      onChanged: (r) => setState(() => _discount = r.amount),
                    ),
                    if (_discount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'Jumla baada ya punguzo: TZS ${widget.fmt.format((cart.total - _discount).clamp(0, cart.total))}',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    _sectionLabel(l.payType),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _payChip('cash', _plain(l.cash), Icons.payments_rounded),
                          _payChip('loan', _plain(l.loan), Icons.credit_score_rounded),
                          _payChip('slow_payment', l.isSw ? 'Polepole' : 'Installment', Icons.hourglass_bottom_rounded),
                          _payChip('cash_not_collected', l.isSw ? 'Bado kulipwa' : 'Not collected', Icons.pending_rounded),
                          _payChip('bank_transfer', l.isSw ? 'Benki' : 'Bank', Icons.account_balance_rounded),
                        ],
                      ),
                    ),
                    if (_payType == 'cash')
                      SplitPaymentField(
                        total: (cart.total - _discount).clamp(0, cart.total),
                        onChanged: (r) => setState(() => _splitPay = r),
                      ),
                    const SizedBox(height: 10),
                    _sectionLabel(l.isSw ? 'Mteja' : 'Customer'),
                    const SizedBox(height: 6),
                    _CustomerModeSelector(
                      value: _customerMode,
                      onChanged: (v) => setState(() => _customerMode = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _PosInput(
                            controller: _customerCtrl,
                            hint: _needsCustomerDetails
                                ? l.customer
                                : (l.isSw ? 'Jina (optional)' : 'Name (optional)'),
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PickCustomerButton(
                          nameCtrl: _customerCtrl,
                          phoneCtrl: _phoneCtrl,
                          onPicked: (c) => setState(() {
                            if (_customerMode == 'walkin') _customerMode = 'registered';
                            _pickedCustomerId = c.customerId != 0 ? c.customerId : null;
                            _pickedCustomerPhone = c.phone;
                          }),
                        ),
                        if (_needsCustomerDetails) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _PosInput(
                              controller: _phoneCtrl,
                              hint: l.isSw ? 'Simu' : 'Phone',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_payType != 'cash' || _needsCustomerDetails) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_payType != 'cash')
                            Expanded(
                              child: _PosInput(
                                controller: _paidCtrl,
                                hint: l.isSw ? 'Amelipa sasa' : 'Paid now',
                                icon: Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          if (_payType != 'cash' && _needsCustomerDetails)
                            const SizedBox(width: 8),
                          if (_needsCustomerDetails)
                            Expanded(
                              child: _PosInput(
                                controller: _noteCtrl,
                                hint: l.isSw ? 'Maelezo / mahali' : 'Note / location',
                                icon: Icons.note_alt_outlined,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // ── pay button (pinned) ───────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bgDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _processing
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.bgDark,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${l.isSw ? 'Hifadhi Mauzo' : 'Save Sale'}  •  TZS ${widget.fmt.format(cart.total)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Labels in L carry a leading emoji; the chip already has an icon.
  static String _plain(String s) =>
      s.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '').trim();

  Widget _sectionLabel(String t) => Text(
        t.toUpperCase(),
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      );

  Widget _payChip(String value, String label, IconData icon) {
    final sel = _payType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 15, color: sel ? Colors.white : AppColors.textMuted),
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
        backgroundColor: AppColors.bgInput,
        side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onSelected: (_) => setState(() => _payType = value),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POS Barcode Scanner Sheet (mobile only)
// ─────────────────────────────────────────────────────────────────────────────
class _PosBarcodeSheet extends StatefulWidget {
  /// Called for every scan; returns a toast message + success flag.
  final ({bool ok, String msg}) Function(String barcode) onScanned;
  const _PosBarcodeSheet({required this.onScanned});
  @override
  State<_PosBarcodeSheet> createState() => _PosBarcodeSheetState();
}

class _PosBarcodeSheetState extends State<_PosBarcodeSheet> {
  late MobileScannerController _ctrl;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _toast;
  bool _toastOk = true;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: const [
        BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA,
        BarcodeFormat.upcE, BarcodeFormat.code128, BarcodeFormat.code39,
        BarcodeFormat.qrCode, BarcodeFormat.codabar,
      ],
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Continuous mode: the sheet stays open so the cashier can scan item
  /// after item. The same code is accepted again only after 1.5 s so one
  /// steady frame does not add the product ten times.
  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    final now = DateTime.now();
    if (raw == _lastCode &&
        now.difference(_lastAt) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastCode = raw;
    _lastAt = now;
    final r = widget.onScanned(raw);
    if (r.ok) {
      _added++;
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }
    if (!mounted) return;
    setState(() {
      _toast = r.msg;
      _toastOk = r.ok;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _toast == r.msg) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primaryLt,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.scanBarcode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _added == 0
                            ? (l.isSw ? 'Scan bidhaa moja baada ya nyingine' : 'Scan items one after another')
                            : (l.isSw ? '$_added zimeongezwa kwenye mkoba' : '$_added added to cart'),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l.isSw ? 'Maliza' : 'Done',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: MobileScanner(
                    controller: _ctrl,
                    onDetect: _onDetect,
                    errorBuilder: (ctx, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.no_photography_rounded, color: Colors.white54, size: 42),
                            const SizedBox(height: 12),
                            Text(
                              l.isSw
                                  ? 'Kamera haipatikani.\nRuhusu kamera kwenye settings za simu, au andika barcode kwenye kisanduku cha kutafuta.'
                                  : 'Camera unavailable.\nAllow camera access in phone settings, or type the barcode in the search box.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(error.errorCode.name,
                                style: const TextStyle(color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _PosScanOverlay(),
                  child: const SizedBox.expand(),
                ),
                if (_toast != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: (_toastOk ? AppColors.accent : AppColors.chartRed).withAlpha(235),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(_toastOk ? Icons.add_shopping_cart_rounded : Icons.error_outline_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_toast!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.pointCamera,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
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
}

class _PosScanOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width * 0.7;
    final h = w * 0.55;
    final l = cx - w / 2;
    final t = cy - h / 2;
    final r = cx + w / 2;
    final b = cy + h / 2;

    final dark = Paint()..color = Colors.black.withAlpha(140);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, t), dark);
    canvas.drawRect(Rect.fromLTWH(0, b, size.width, size.height - b), dark);
    canvas.drawRect(Rect.fromLTWH(0, t, l, h), dark);
    canvas.drawRect(Rect.fromLTWH(r, t, size.width - r, h), dark);

    const cLen = 22.0;
    final corner = Paint()
      ..color = AppColors.primaryLt
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void mark(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * cLen, y), corner);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * cLen), corner);
    }

    mark(l, t, 1, 1);
    mark(r, t, -1, 1);
    mark(l, b, 1, -1);
    mark(r, b, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional POS Receipt Preview
// Note: This is UI-ready. For real Bluetooth/PDF printing, connect the print
// button to your preferred printing service/package.
// ─────────────────────────────────────────────────────────────────────────────
class _PosReceiptItem {
  final String name;
  final int qty;
  final double unitPrice;
  final double subtotal;
  const _PosReceiptItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
  });
}

class _PosReceiptData {
  final String receiptNo;
  final DateTime date;
  final String businessName;
  final String footerMessage;
  final String customerName;
  final String customerPhone;
  final String customerType;
  final String paymentType;
  final double total;
  final double amountPaid;
  final double? changeOverride;
  final double discount;
  final List<_PosReceiptItem> items;

  const _PosReceiptData({
    required this.receiptNo,
    required this.date,
    required this.businessName,
    required this.footerMessage,
    required this.customerName,
    required this.customerPhone,
    required this.customerType,
    required this.paymentType,
    required this.total,
    required this.amountPaid,
    this.changeOverride,
    this.discount = 0,
    required this.items,
  });

  double get balance => total - amountPaid > 0 ? total - amountPaid : 0;
  double get change =>
      changeOverride ?? (amountPaid - total > 0 ? amountPaid - total : 0);

  factory _PosReceiptData.fromCart({
    required Map<String, dynamic> response,
    required String businessName,
    required String footerMessage,
    required String customerName,
    required String customerPhone,
    required String customerType,
    required String paymentType,
    required double total,
    required double amountPaid,
    double? changeAmount,
    double discount = 0,
    required List<_PosReceiptItem> items,
  }) {
    final data = response['data'];
    final no =
        response['receipt_no'] ??
        response['sale_no'] ??
        response['sale_id'] ??
        (data is Map
            ? (data['receipt_no'] ?? data['sale_no'] ?? data['sale_id'])
            : null) ??
        DateTime.now().millisecondsSinceEpoch;
    return _PosReceiptData(
      receiptNo: '$no',
      date: DateTime.now(),
      businessName: businessName.trim().isNotEmpty
          ? businessName.trim()
          : 'Duka Kiganjani',
      footerMessage: footerMessage.trim().isNotEmpty
          ? footerMessage.trim()
          : 'Asante kwa kununua kwetu!',
      customerName: customerName,
      customerPhone: customerPhone,
      customerType: customerType,
      paymentType: paymentType,
      total: total,
      amountPaid: amountPaid,
      changeOverride: changeAmount != null && changeAmount > 0 ? changeAmount : null,
      discount: discount,
      items: items,
    );
  }
}

class _PosReceiptSheet extends StatelessWidget {
  final _PosReceiptData receipt;
  final NumberFormat fmt;
  const _PosReceiptSheet({required this.receipt, required this.fmt});

  String _label(String v) {
    switch (v) {
      case 'walkin':
        return 'Mteja wa kawaida';
      case 'potential':
        return 'Potential customer';
      case 'registered':
        return 'Mkopo / SMS customer';
      case 'cash':
        return 'Cash';
      case 'loan':
        return 'Mkopo';
      case 'slow_payment':
        return 'Slow payment';
      case 'cash_not_collected':
        return 'Cash but not collected';
      case 'bank_transfer':
        return 'Bank transfer';
      default:
        return v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradLime,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.bgDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Receipt / Risiti',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              receipt.businessName.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const Center(child: Text('Official Sales Receipt')),
                          const SizedBox(height: 12),
                          _r('Receipt No', receipt.receiptNo),
                          _r('Date', dateFmt.format(receipt.date)),
                          _r('Customer', receipt.customerName),
                          if (receipt.customerPhone.isNotEmpty)
                            _r('Phone', receipt.customerPhone),
                          _r('Customer Type', _label(receipt.customerType)),
                          _r('Payment Type', _label(receipt.paymentType)),
                          const Divider(height: 24),
                          ...receipt.items.map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${i.name}\n${i.qty} × TZS ${fmt.format(i.unitPrice)}',
                                    ),
                                  ),
                                  Text(
                                    'TZS ${fmt.format(i.subtotal)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          if (receipt.discount > 0)
                            _money('Discount', receipt.discount, color: Colors.orange),
                          _money('Total', receipt.total, bold: true),
                          _money('Paid', receipt.amountPaid),
                          if (receipt.balance > 0)
                            _money(
                              'Outstanding Balance',
                              receipt.balance,
                              color: Colors.red,
                              bold: true,
                            ),
                          if (receipt.change > 0)
                            _money(
                              'Change',
                              receipt.change,
                              color: Colors.green,
                              bold: true,
                            ),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              receipt.footerMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Done'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryLt,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _printReceipt(fmt),
                          icon: Icon(
                            Icons.print_rounded,
                            color: AppColors.bgDark,
                          ),
                          label: Text(
                            'Print Receipt',
                            style: TextStyle(
                              color: AppColors.bgDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _r(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text('$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(v, textAlign: TextAlign.right)),
      ],
    ),
  );

  Widget _money(String k, double v, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              k,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              'TZS ${fmt.format(v)}',
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );

  Future<void> _printReceipt(NumberFormat fmt) async {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                receipt.businessName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Official Sales Receipt',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 8),
            _pdfRow('Receipt No', receipt.receiptNo),
            _pdfRow('Date', dateFmt.format(receipt.date)),
            _pdfRow('Customer', receipt.customerName),
            if (receipt.customerPhone.isNotEmpty)
              _pdfRow('Phone', receipt.customerPhone),
            _pdfRow('Customer Type', _label(receipt.customerType)),
            _pdfRow('Payment Type', _label(receipt.paymentType)),
            pw.Divider(),
            ...receipt.items.map(
              (i) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${i.name}\n${i.qty} x TZS ${fmt.format(i.unitPrice)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Text(
                      'TZS ${fmt.format(i.subtotal)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.Divider(),
            if (receipt.discount > 0)
              _pdfMoney('Discount', receipt.discount, fmt),
            _pdfMoney('Total', receipt.total, fmt, bold: true),
            _pdfMoney('Paid', receipt.amountPaid, fmt),
            if (receipt.balance > 0)
              _pdfMoney(
                'Outstanding Balance',
                receipt.balance,
                fmt,
                bold: true,
              ),
            if (receipt.change > 0)
              _pdfMoney('Change', receipt.change, fmt, bold: true),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                receipt.footerMessage,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  pw.Widget _pdfRow(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      children: [
        pw.Text(
          '$k: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        ),
        pw.Expanded(
          child: pw.Text(
            v,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );

  pw.Widget _pdfMoney(
    String k,
    double v,
    NumberFormat fmt, {
    bool bold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          k,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 10,
          ),
        ),
        pw.Text(
          'TZS ${fmt.format(v)}',
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// MOBILE product browser — slivers: compact hero scrolls away, search +
// categories stay pinned, 3-column compact grid fills the screen.
// ─────────────────────────────────────────────────────────────────────────────
class _MobileProductBrowser extends StatelessWidget {
  final List<String> categories;
  final List<Product> filtered;
  final bool loading;
  final String selectedCat;
  final TextEditingController searchCtrl;
  final NumberFormat fmt;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCatSelect;
  final VoidCallback onRefresh;
  final VoidCallback? onScanTap;

  const _MobileProductBrowser({
    required this.categories,
    required this.filtered,
    required this.loading,
    required this.selectedCat,
    required this.searchCtrl,
    required this.fmt,
    required this.onSearch,
    required this.onCatSelect,
    required this.onRefresh,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // 3 columns on phones, 4 on wide phones / small tablets
    final cols = width >= 520 ? 4 : 3;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Compact hero (scrolls away) ─────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: TutorialTarget(
                id: 'pos_hero',
                child: _MobilePosHero(
                  products: filtered.length,
                  onScanTap: onScanTap,
                  onRefresh: onRefresh,
                ),
              ),
            ),
          ),
          // ── Search + categories (pinned) ───────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              height: 100,
              child: Container(
                color: AppColors.bg,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Expanded(
                            child: TutorialTarget(
                              id: 'pos_search',
                              child: TextField(
                              controller: searchCtrl,
                              style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: l.searchProduct,
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: searchCtrl,
                                  builder: (_, v, _) => v.text.isEmpty
                                      ? const SizedBox.shrink()
                                      : IconButton(
                                          icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                                          onPressed: () {
                                            searchCtrl.clear();
                                            onSearch('');
                                          },
                                        ),
                                ),
                                isDense: true,
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
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: onSearch,
                            ),
                            ),
                          ),
                          if (onScanTap != null) ...[
                            const SizedBox(width: 8),
                            TutorialTarget(
                              id: 'pos_scan',
                              child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Material(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: onScanTap,
                                  child: const Icon(Icons.qr_code_scanner_rounded,
                                      color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TutorialTarget(
                      id: 'pos_categories',
                      child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (ctx, i) {
                          final cat = categories[i];
                          final sel = cat == selectedCat;
                          return ChoiceChip(
                            label: Text(
                              cat,
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
                            onSelected: (_) => onCatSelect(cat),
                          );
                        },
                      ),
                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Grid ────────────────────────────────────────────────────────
          if (loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 56),
                    const SizedBox(height: 12),
                    Text(l.noProducts, style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l.refresh),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 110),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ProStaggeredItem(
                    index: i,
                    child: _ProductCard(product: filtered[i], fmt: fmt, compact: true),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Slim gradient strip: title, live cart summary, scan/refresh.
class _MobilePosHero extends StatelessWidget {
  final int products;
  final VoidCallback? onScanTap;
  final VoidCallback onRefresh;
  const _MobilePosHero({
    required this.products,
    required this.onScanTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cart = context.watch<CartProvider>();
    final fmt = NumberFormat('#,###', 'en_US');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.isSw ? 'Kuuza Haraka' : 'Quick Sale',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  cart.count == 0
                      ? '$products ${l.kpiProducts}'
                      : '${cart.count} ${l.items} • TZS ${fmt.format(cart.total)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cart.count == 0 ? Colors.white70 : AppColors.accentBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _RoundAction(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const _PinnedHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate old) =>
      old.height != height || old.child != child;
}
