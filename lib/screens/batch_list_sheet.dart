import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';
import '../utils/cat_style.dart';
import 'add_batch_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Batch List Sheet
// Shows all batches for a product with FIFO tracking and profit analytics
// ─────────────────────────────────────────────────────────────────────────────

class BatchListSheet extends StatefulWidget {
  final Product      product;
  final VoidCallback onRefresh;

  const BatchListSheet({
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
      builder: (_) => BatchListSheet(product: product, onRefresh: onRefresh),
    );
  }

  @override
  State<BatchListSheet> createState() => _BatchListSheetState();
}

class _BatchListSheetState extends State<BatchListSheet> {
  List<ProductBatch> _batches = [];
  bool _loading = true;
  final _fmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await app.api!.getProductBatches(
        widget.product.productId,
        app.selectedBusiness!.businessId,
      );
      final list = raw
          .map((e) => ProductBatch.fromJson(e as Map<String, dynamic>))
          .toList();
      // FIFO order: oldest first
      list.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
      setState(() => _batches = list);
    } catch (_) {
      // Graceful — API may not exist yet
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAddBatch() {
    AddBatchSheet.show(context, widget.product, onSaved: () {
      _load();
      widget.onRefresh();
    });
  }

  /// Index of the current active batch (FIFO: oldest with remaining > 0)
  int get _currentBatchIndex =>
      _batches.indexWhere((b) => b.isActive);

  @override
  Widget build(BuildContext context) {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Stack(children: [
          // ── Content ────────────────────────────────────────────────────────
          CustomScrollView(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(child: Column(children: [
                // Handle
                Container(
                  width: 44, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
                _Header(product: widget.product, batchCount: _batches.length,
                    loading: _loading, l: l),
                if (!_loading && _batches.isNotEmpty)
                  _SummaryCard(batches: _batches, product: widget.product,
                      fmt: _fmt, l: l),
                const SizedBox(height: 6),
              ])),

              if (_loading)
                SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min,
                      children: [
                    const CircularProgressIndicator(color: Color(0xFF3B82F6)),
                    const SizedBox(height: 16),
                    Text(l.isSw ? 'Inapakia batch...' : 'Loading batches...',
                        style: TextStyle(color: AppColors.textMuted)),
                  ])),
                )
              else if (_batches.isEmpty)
                SliverFillRemaining(child: _EmptyBatch(l: l))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: StaggeredItem(
                        index: i,
                        child: _BatchCard(
                          batch: _batches[i],
                          product: widget.product,
                          isCurrent: i == _currentBatchIndex,
                          isNext: _currentBatchIndex >= 0 &&
                              i == _currentBatchIndex + 1 &&
                              _batches[i].isActive,
                          fmt: _fmt,
                          l: l,
                        ),
                      ),
                    ),
                    childCount: _batches.length,
                  ),
                ),

              SliverToBoxAdapter(
                  child: SizedBox(height: mq.padding.bottom + 88)),
            ],
          ),

          // ── FAB ─────────────────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: mq.padding.bottom + 16,
            child: FloatingActionButton.extended(
              onPressed: _openAddBatch,
              backgroundColor: const Color(0xFF3B82F6),
              elevation: 8,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                l.isSw ? 'Batch Mpya' : 'Add Batch',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Product product;
  final int     batchCount;
  final bool    loading;
  final L       l;
  const _Header({
    required this.product, required this.batchCount,
    required this.loading, required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = CatStyle.color(product.category);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3B82F6).withAlpha(28), AppColors.bg],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withAlpha(55)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.layers_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(product.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textWhite,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 3),
          Row(children: [
            Container(width: 7, height: 7,
                decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(
              loading
                  ? (l.isSw ? 'Inapakia...' : 'Loading...')
                  : l.isSw
                      ? '$batchCount batch zimepatikana'
                      : '$batchCount batch(es) found',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ]),
        ])),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Summary card — totals across all batches
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final List<ProductBatch> batches;
  final Product            product;
  final NumberFormat       fmt;
  final L                  l;
  const _SummaryCard({
    required this.batches, required this.product,
    required this.fmt, required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final activeBatches = batches.where((b) => b.isActive).length;
    final totalQty      = batches.fold<int>(0, (s, b) => s + b.quantity);
    final totalRemain   = batches.fold<int>(0, (s, b) => s + b.remaining);
    final totalSold     = totalQty - totalRemain;
    final realizedProfit = batches.fold<double>(
        0, (s, b) => s + b.totalProfit(product.sellPrice));
    final weightedAvgBuy = totalQty > 0
        ? batches.fold<double>(0, (s, b) => s + b.buyPrice * b.quantity) /
              totalQty
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // Counts
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            _StatCell(
              value: '$activeBatches',
              label: l.isSw ? 'Batch Hai' : 'Active',
              color: const Color(0xFF3B82F6),
              icon: Icons.layers_rounded,
            ),
            _vBar(),
            _StatCell(
              value: '$totalSold ${product.unit}',
              label: l.isSw ? 'Imeuza' : 'Sold',
              color: AppColors.chartOrange,
              icon: Icons.sell_rounded,
            ),
            _vBar(),
            _StatCell(
              value: '$totalRemain ${product.unit}',
              label: l.isSw ? 'Imebaki' : 'Remaining',
              color: AppColors.accent,
              icon: Icons.inventory_2_outlined,
            ),
          ]),
        ),
        Container(height: 1, color: AppColors.border),
        // Financials
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Row(children: [
            _FinCell(
              label: l.isSw ? 'Bei Wastani (FIFO)' : 'Weighted Avg Buy',
              value: 'TZS ${fmt.format(weightedAvgBuy)}',
              color: AppColors.chartOrange,
              icon: Icons.functions_rounded,
            ),
            _vBar(),
            _FinCell(
              label: l.isSw ? 'Faida Iliyopatikana' : 'Realized Profit',
              value: 'TZS ${fmt.format(realizedProfit.abs())}',
              color: realizedProfit >= 0 ? AppColors.accent : AppColors.chartRed,
              icon: realizedProfit >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _vBar() => Container(
      width: 1, height: 44, color: AppColors.border);
}

class _StatCell extends StatelessWidget {
  final String   value;
  final String   label;
  final Color    color;
  final IconData icon;
  const _StatCell({required this.value, required this.label,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold,
          fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ]),
  );
}

class _FinCell extends StatelessWidget {
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;
  const _FinCell({required this.label, required this.value,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold,
            fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// Individual Batch Card
// ─────────────────────────────────────────────────────────────────────────────
class _BatchCard extends StatelessWidget {
  final ProductBatch batch;
  final Product      product;
  final bool         isCurrent; // FIFO: this is the batch being sold from now
  final bool         isNext;    // Next batch to be sold after current
  final NumberFormat fmt;
  final L            l;

  const _BatchCard({
    required this.batch,
    required this.product,
    required this.isCurrent,
    required this.isNext,
    required this.fmt,
    required this.l,
  });

  Color get _accentColor {
    if (batch.isExhausted) return AppColors.chartGray;
    if (isCurrent) return const Color(0xFF3B82F6);
    if (isNext) return AppColors.primaryLt;
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final profit      = product.sellPrice - batch.buyPrice;
    final totalProfit = batch.totalProfit(product.sellPrice);
    final pct         = batch.quantity > 0
        ? (batch.remaining / batch.quantity).clamp(0.0, 1.0)
        : 0.0;

    final statusLabel = batch.isExhausted
        ? (l.isSw ? 'Imeisha' : 'Exhausted')
        : isCurrent
            ? (l.isSw ? 'INAUZWA SASA' : 'SELLING NOW')
            : isNext
                ? (l.isSw ? 'Inafuata' : 'Up Next')
                : (l.isSw ? 'Inasubiri' : 'Queued');

    final barColor = pct > 0.5
        ? AppColors.accent
        : pct > 0.2
            ? AppColors.chartOrange
            : AppColors.chartRed;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accentColor.withAlpha(isCurrent ? 120 : 60),
          width: isCurrent ? 1.5 : 1.0,
        ),
        boxShadow: isCurrent
            ? [BoxShadow(
                color: const Color(0xFF3B82F6).withAlpha(28),
                blurRadius: 16, offset: const Offset(0, 6))]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card header ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _accentColor.withAlpha(isCurrent ? 16 : 8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          ),
          child: Row(children: [
            // Batch number badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _accentColor.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentColor.withAlpha(70)),
              ),
              child: Text(
                batch.batchNumber.isNotEmpty ? batch.batchNumber : 'BATCH',
                style: TextStyle(color: _accentColor,
                    fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 11),
                  const SizedBox(width: 3),
                  Text(statusLabel, style: const TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.bold)),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel, style: TextStyle(
                    color: _accentColor, fontSize: 9,
                    fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            if (batch.dateAdded.isNotEmpty)
              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(batch.displayDate,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ]),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Progress bar ───────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}% ${l.isSw ? "imebaki" : "remaining"}',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                    Text(
                      '${batch.remaining} / ${batch.quantity} ${product.unit}',
                      style: TextStyle(color: barColor,
                          fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      minHeight: 7,
                    ),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Qty pills ──────────────────────────────────────────────────
            Row(children: [
              _QtyPill(
                value: '${batch.quantity}',
                label: l.isSw ? 'Iliingia' : 'Received',
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              _QtyPill(
                value: '${batch.soldQty}',
                label: l.isSw ? 'Imeuza' : 'Sold',
                color: AppColors.chartOrange,
              ),
              const SizedBox(width: 8),
              _QtyPill(
                value: '${batch.remaining}',
                label: l.isSw ? 'Imebaki' : 'Left',
                color: batch.remaining > 0
                    ? AppColors.accent
                    : AppColors.chartRed,
              ),
            ]),
            const SizedBox(height: 12),

            // ── Price / profit ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                _PriceStat(
                  label: l.buyPrice,
                  value: 'TZS ${fmt.format(batch.buyPrice)}',
                  color: AppColors.chartOrange,
                  icon: Icons.arrow_downward_rounded,
                ),
                Container(width: 1, height: 38, color: AppColors.border),
                _PriceStat(
                  label: '${l.profit} / ${product.unit}',
                  value: 'TZS ${fmt.format(profit.abs())}',
                  color: profit >= 0 ? AppColors.accent : AppColors.chartRed,
                  icon: profit >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                ),
                Container(width: 1, height: 38, color: AppColors.border),
                _PriceStat(
                  label: l.isSw ? 'Faida Jumla' : 'Total Earned',
                  value: 'TZS ${fmt.format(totalProfit.abs())}',
                  color: totalProfit >= 0
                      ? AppColors.accent
                      : AppColors.chartRed,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ]),
            ),

            // ── Expiry ─────────────────────────────────────────────────────
            if (batch.expiryDate != null &&
                (batch.expiryDate?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.calendar_month_rounded,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text(
                  '${l.isSw ? "Tarehe mwisho" : "Expires"}: '
                  '${_fmt(batch.expiryDate!)}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ]),
            ],

            // ── Notes ──────────────────────────────────────────────────────
            if (batch.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.notes_rounded,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(batch.notes,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11,
                          fontStyle: FontStyle.italic),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2,'0')}/'
             '${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyBatch extends StatelessWidget {
  final L l;
  const _EmptyBatch({required this.l});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withAlpha(18),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF3B82F6).withAlpha(50)),
          ),
          child: const Icon(Icons.layers_outlined,
              color: Color(0xFF3B82F6), size: 36),
        ),
        const SizedBox(height: 18),
        Text(l.isSw ? 'Hakuna Batch Bado' : 'No Batches Yet',
            style: TextStyle(color: AppColors.textWhite,
                fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        Text(
          l.isSw
              ? 'Bonyeza "Batch Mpya" kuongeza batch.\n'
                'Kila batch inaweza kuwa na bei tofauti ya ununuzi.'
              : 'Tap "Add Batch" to track stock batches.\n'
                'Each batch can have a different buy price.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted,
              fontSize: 13, height: 1.5),
        ),
      ]),
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _QtyPill extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _QtyPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
      ]),
    ),
  );
}

class _PriceStat extends StatelessWidget {
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;
  const _PriceStat({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(height: 3),
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 1),
      Text(label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 9),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}
