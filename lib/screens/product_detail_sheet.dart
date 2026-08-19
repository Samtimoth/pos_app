import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart'; // exports ProductUnit
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';
import '../utils/cat_style.dart';
import 'product_form_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Product Detail Sheet
// Tap any product tile → opens this card-style sheet.
// An "Edit Product" button at the bottom opens AddProductSheet.
// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailSheet extends StatelessWidget {
  final Product product;
  final VoidCallback onRefresh;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.onRefresh,
  });

  static void show(
    BuildContext context,
    Product product, {
    required VoidCallback onRefresh,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(product: product, onRefresh: onRefresh),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _stockColor() {
    if (product.stock <= 0) return AppColors.chartRed;
    if (product.stock <= product.minStock) return AppColors.chartOrange;
    return AppColors.accent;
  }

  Widget _chip(String label, Color color, {bool pulse = false}) {
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
    return pulse ? PulseWidget(child: w) : w;
  }

  Widget _sectionCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.gradPrimary),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );

  // ── Hero area (image + name + category) ───────────────────────────────────
  Widget _heroArea(BuildContext context) {
    final catColor = CatStyle.color(product.category);
    final catIcon  = CatStyle.icon(product.category);
    final hasImage = product.image.isNotEmpty;
    final fmt      = NumberFormat('#,###', 'en_US');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [catColor.withAlpha(45), AppColors.bg.withAlpha(230)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: catColor.withAlpha(60)),
        boxShadow: [
          BoxShadow(color: catColor.withAlpha(25), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product image / icon
          Container(
            width: 82, height: 82,
            decoration: BoxDecoration(
              color: catColor.withAlpha(22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: catColor.withAlpha(90), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Image.network(
                    product.image,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) =>
                        Icon(catIcon, color: catColor, size: 38),
                  )
                : Icon(catIcon, color: catColor, size: 38),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              product.name,
              style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  product.category.isNotEmpty ? product.category : '—',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _chip(product.unit, AppColors.chartBlue),
              if (product.expiryStatus == ExpiryStatus.expired)
                _chip('EXPIRED', AppColors.chartRed, pulse: true)
              else if (product.expiryStatus == ExpiryStatus.expiringSoon)
                _chip('Expiring Soon', AppColors.chartOrange),
            ]),
          ])),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
        const SizedBox(height: 14),
        // Sell price hero strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.gradPrimary),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primaryLt.withAlpha(45),
                  blurRadius: 14,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(children: [
            Text(
              'TZS ${fmt.format(product.sellPrice)}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26),
            ),
            Text(
              L.of(context).sellPrice,
              style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Price card (buy / profit) ──────────────────────────────────────────────
  Widget _priceCard(BuildContext context) {
    final l      = L.of(context);
    final fmt    = NumberFormat('#,###', 'en_US');
    final profit = product.sellPrice - product.buyPrice;
    final margin = product.sellPrice > 0 ? (profit / product.sellPrice * 100) : 0.0;
    final isGood = profit >= 0;
    final pc     = isGood ? AppColors.accent : AppColors.chartRed;

    return _sectionCard(
      icon: Icons.payments_rounded,
      label: l.isSw ? 'Bei' : 'Pricing',
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(child: _metricCol(
            icon: Icons.arrow_downward_rounded,
            color: AppColors.chartOrange,
            value: 'TZS ${fmt.format(product.buyPrice)}',
            label: l.buyPrice,
          )),
          Container(width: 1, color: AppColors.border),
          Expanded(child: _metricCol(
            icon: isGood ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: pc,
            value: 'TZS ${fmt.format(profit.abs())}',
            subValue: '${margin.toStringAsFixed(1)}%',
            label: l.profit,
          )),
        ]),
      ),
    );
  }

  Widget _metricCol({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    String? subValue,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center),
          if (subValue != null) ...[
            Text(subValue,
                style:
                    TextStyle(color: color.withAlpha(190), fontSize: 12)),
          ],
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      );

  // ── Stock card ─────────────────────────────────────────────────────────────
  Widget _stockCard(BuildContext context) {
    final l  = L.of(context);
    final sc = _stockColor();
    // Scale: 0 = empty, 1 = at minStock, show green once above 3x minStock
    final target = (product.minStock * 3.0).clamp(1.0, double.infinity);
    final pct    = (product.stock / target).clamp(0.0, 1.0);

    final statusLabel = product.stock <= 0
        ? l.kpiOutStock
        : product.stock <= product.minStock
            ? l.kpiLowStock
            : l.filterInStock;

    return _sectionCard(
      icon: Icons.inventory_2_rounded,
      label: l.isSw ? 'Hifadhi (Stock)' : 'Stock',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            '${product.stock} ${product.unit}',
            style: TextStyle(
                color: sc, fontWeight: FontWeight.bold, fontSize: 26),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sc.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sc.withAlpha(80)),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: sc, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        // Progress bar
        LayoutBuilder(builder: (ctx, box) => Stack(children: [
          Container(
            height: 8,
            width: box.maxWidth,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            height: 8,
            width: box.maxWidth * pct,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: pct > 0.5
                    ? AppColors.gradLime
                    : pct > 0.2
                        ? [AppColors.chartOrange,
                            AppColors.chartOrange.withAlpha(170)]
                        : [AppColors.chartRed,
                            AppColors.chartRed.withAlpha(170)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ])),
        const SizedBox(height: 6),
        Text(
          '${l.isSw ? "Min stock" : "Min stock"}: ${product.minStock} ${product.unit}',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ]),
    );
  }

  // ── Units card (selling units table) ─────────────────────────────────────
  Widget _unitsCard(BuildContext context) {
    final l   = L.of(context);
    final fmt = NumberFormat('#,###', 'en_US');
    const blue = Color(0xFF3B82F6);

    return _sectionCard(
      icon: Icons.layers_rounded,
      label: l.isSw ? 'Unit za Mauzo' : 'Selling Units',
      child: Column(children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: blue.withAlpha(14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Text(l.isSw ? 'Unit' : 'Unit',
                style: TextStyle(color: blue, fontSize: 10, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text(l.isSw ? 'Inabeba' : 'Equals',
                style: TextStyle(color: blue, fontSize: 10, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text('Bei / Unit',
                textAlign: TextAlign.right,
                style: TextStyle(color: blue, fontSize: 10, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('Max Qty',
                textAlign: TextAlign.right,
                style: TextStyle(color: blue, fontSize: 10, fontWeight: FontWeight.bold))),
          ]),
        ),
        const SizedBox(height: 6),
        // Unit rows
        ...product.units.map((unit) {
          final maxQty  = unit.maxQty(product.stock);
          final canSell = maxQty > 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: canSell
                    ? AppColors.bg.withAlpha(180)
                    : AppColors.chartGray.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: canSell
                        ? AppColors.border
                        : AppColors.chartGray.withAlpha(40)),
              ),
              child: Row(children: [
                Expanded(flex: 3, child: Row(children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: canSell ? blue : AppColors.chartGray,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(unit.unitName,
                      style: TextStyle(
                          color: canSell ? AppColors.textWhite : AppColors.textMuted,
                          fontWeight: FontWeight.w600, fontSize: 12))),
                ])),
                Expanded(flex: 2, child: Text(
                  unit.conversionLabel(product.unit),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                )),
                Expanded(flex: 3, child: Text(
                  'TZS ${fmt.format(unit.sellingPrice)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.primaryLt,
                      fontWeight: FontWeight.bold, fontSize: 12),
                )),
                Expanded(flex: 2, child: Text(
                  canSell ? '$maxQty' : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: canSell ? AppColors.accent : AppColors.chartRed,
                      fontWeight: FontWeight.w600, fontSize: 12),
                )),
              ]),
            ),
          );
        }),
        // Base unit row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withAlpha(40)),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Row(children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                product.unit.isNotEmpty ? product.unit : 'Base',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold, fontSize: 12),
              )),
            ])),
            Expanded(flex: 2, child: Text('1 ${product.unit}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
            Expanded(flex: 3, child: Text(
              'TZS ${fmt.format(product.sellPrice)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.primaryLt,
                  fontWeight: FontWeight.bold, fontSize: 12),
            )),
            Expanded(flex: 2, child: Text(
              '${product.stock}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600, fontSize: 12),
            )),
          ]),
        ),
      ]),
    );
  }

  // ── Info card (barcode, ID, expiry) ────────────────────────────────────────
  Widget _infoCard(BuildContext context) {
    final l = L.of(context);

    final rows = <_InfoEntry>[];
    rows.add(_InfoEntry(
      label: 'Product ID',
      value: '#${product.productId}',
      icon: Icons.tag_rounded,
    ));
    if (product.barcode.isNotEmpty) {
      rows.add(_InfoEntry(
        label: l.barcode_,
        value: product.barcode,
        icon: Icons.qr_code_rounded,
      ));
    }
    if (product.expiryDate != null && product.expiryDate!.isNotEmpty) {
      rows.add(_InfoEntry(
        label: l.expiryOptional,
        value: product.expiryDisplayDate,
        icon: Icons.calendar_month_rounded,
        valueColor: product.expiryStatus == ExpiryStatus.expired
            ? AppColors.chartRed
            : product.expiryStatus == ExpiryStatus.expiringSoon
                ? AppColors.chartOrange
                : AppColors.accent,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      icon: Icons.info_outline_rounded,
      label: l.isSw ? 'Taarifa Zaidi' : 'More Info',
      child: Column(
        children: rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryLt.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(r.icon, color: AppColors.primaryLt, size: 13),
            ),
            const SizedBox(width: 10),
            Text(r.label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const Spacer(),
            Text(r.value,
                style: TextStyle(
                    color: r.valueColor ?? AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
        )).toList(),
      ),
    );
  }

  // ── Edit button ────────────────────────────────────────────────────────────
  Widget _editButton(BuildContext context, MediaQueryData mq) {
    final l = L.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + mq.padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddProductSheet(
                onSaved: onRefresh,
                initialProduct: product,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
          label: Text(
            l.isSw ? 'Hariri Bidhaa' : 'Edit Product',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: CustomScrollView(
          controller: scroll,
          slivers: [
            // Handle
            SliverToBoxAdapter(child: Column(children: [
              Container(
                width: 44, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              _heroArea(context),
            ])),

            SliverToBoxAdapter(
                child: StaggeredItem(index: 0, child: _priceCard(context))),
            SliverToBoxAdapter(
                child: StaggeredItem(index: 1, child: _stockCard(context))),
            if (product.units.isNotEmpty)
              SliverToBoxAdapter(
                  child: StaggeredItem(index: 2, child: _unitsCard(context))),
            SliverToBoxAdapter(
                child: StaggeredItem(index: 3, child: _infoCard(context))),
            SliverToBoxAdapter(child: _editButton(context, mq)),
          ],
        ),
      ),
    );
  }
}

class _InfoEntry {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _InfoEntry({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });
}
