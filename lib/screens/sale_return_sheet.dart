import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sale.dart';
import '../providers/app_provider.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Marejesho ya bidhaa (partial/full return) for one sale. Lets the cashier
/// pick which items and how many to return; stock goes back automatically
/// and the sale's total/balance shrink accordingly. Unlike "Futa mauzo"
/// (void), the original sale is kept — only the returned lines are undone.
class SaleReturnSheet extends StatefulWidget {
  final Sale sale;
  final List<Map<String, dynamic>> items;

  const SaleReturnSheet({super.key, required this.sale, required this.items});

  /// Returns true if a return was recorded (caller should refresh).
  static Future<bool?> show(
    BuildContext context, {
    required Sale sale,
    required List<Map<String, dynamic>> items,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SaleReturnSheet(sale: sale, items: items),
      );

  @override
  State<SaleReturnSheet> createState() => _SaleReturnSheetState();
}

class _SaleReturnSheetState extends State<SaleReturnSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _reasonCtrl = TextEditingController();
  final Map<int, double> _qty = {}; // item_id -> quantity to return
  Map<int, double> _alreadyReturned = {}; // product_id -> qty
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAlreadyReturned();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAlreadyReturned() async {
    final app = context.read<AppProvider>();
    try {
      final raw = await app.api?.getSaleReturns(widget.sale.saleId) ?? [];
      final map = <int, double>{};
      for (final r in raw) {
        final items = (r as Map)['items'] as List? ?? [];
        for (final it in items) {
          final m = Map<String, dynamic>.from(it as Map);
          final pid = int.tryParse('${m['product_id']}') ?? 0;
          final q = double.tryParse('${m['quantity']}') ?? 0;
          map[pid] = (map[pid] ?? 0) + q;
        }
      }
      if (mounted) setState(() => _alreadyReturned = map);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _maxFor(Map<String, dynamic> item) {
    final pid = int.tryParse('${item['product_id']}') ?? 0;
    final original = double.tryParse('${item['quantity']}') ?? 0;
    final already = _alreadyReturned[pid] ?? 0;
    return (original - already).clamp(0, original);
  }

  double get _refundTotal {
    var total = 0.0;
    for (final item in widget.items) {
      final itemId = int.tryParse('${item['item_id']}') ?? 0;
      final q = _qty[itemId] ?? 0;
      final price = double.tryParse('${item['unit_price']}') ?? 0;
      total += q * price;
    }
    return total;
  }

  bool get _hasSelection => _qty.values.any((q) => q > 0);

  void _setQty(int itemId, double v, double max) {
    setState(() => _qty[itemId] = v.clamp(0, max));
  }

  Future<void> _submit() async {
    if (!_hasSelection) return;
    if (!ConnectivityService.instance.isOnline) {
      _snack('Marejesho yanahitaji mtandao — jaribu tena ukiwa online.', AppColors.chartOrange);
      return;
    }
    final app = context.read<AppProvider>();
    if (app.api == null) return;

    final payload = <Map<String, dynamic>>[];
    for (final item in widget.items) {
      final itemId = int.tryParse('${item['item_id']}') ?? 0;
      final q = _qty[itemId] ?? 0;
      if (q <= 0) continue;
      payload.add({
        'item_id': itemId,
        'product_id': item['product_id'],
        'quantity': q,
      });
    }

    setState(() => _saving = true);
    try {
      final res = await app.api!.createSaleReturn(
        saleId: widget.sale.saleId,
        items: payload,
        reason: _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _snack('${res['message'] ?? 'Marejesho yamehifadhiwa'}', AppColors.accent);
        Navigator.pop(context, true);
      } else {
        _snack('${res['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final returnable = widget.items.where((it) => _maxFor(it) > 0).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.chartBlue.withAlpha(30),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.assignment_return_rounded, color: AppColors.chartBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Rudisha bidhaa',
                        style: TextStyle(color: AppColors.textWhite, fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(widget.sale.saleNo.isNotEmpty ? widget.sale.saleNo : '#${widget.sale.saleId}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                  : returnable.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text('Bidhaa zote za mauzo haya tayari zimerudishwa.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          itemCount: returnable.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _returnRow(returnable[i]),
                        ),
            ),
            if (!_loading && returnable.isNotEmpty) ...[
              Divider(color: AppColors.border, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: TextField(
                  controller: _reasonCtrl,
                  style: TextStyle(color: AppColors.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Sababu (mf. mteja alibadilisha mawazo, kasoro ya bidhaa)',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    isDense: true, filled: true, fillColor: AppColors.bgInput,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + mq.padding.bottom),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Jumla ya kurudisha', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      Text('TZS ${_fmt.format(_refundTotal)}',
                          style: TextStyle(color: AppColors.chartBlue, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_hasSelection && !_saving) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.chartBlue, foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_saving ? 'Inahifadhi...' : 'Thibitisha',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _returnRow(Map<String, dynamic> item) {
    final itemId = int.tryParse('${item['item_id']}') ?? 0;
    final name = '${item['product_name'] ?? ''}';
    final unit = '${item['unit'] ?? ''}';
    final price = double.tryParse('${item['unit_price']}') ?? 0;
    final max = _maxFor(item);
    final qty = (_qty[itemId] ?? 0).clamp(0, max).toDouble();
    final selected = qty > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.chartBlue : AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('Uliuza ${_fmt.format(max)} $unit  ·  TZS ${_fmt.format(price)} kwa $unit',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        _QtyStepper(
          value: qty,
          max: max,
          onChanged: (v) => _setQty(itemId, v, max),
        ),
      ]),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  const _QtyStepper({required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isWhole = max == max.roundToDouble();
    String fmt(double v) => isWhole ? v.toInt().toString() : v.toStringAsFixed(1);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _btn(Icons.remove_rounded, value > 0, () => onChanged(value - (isWhole ? 1 : 0.5))),
      SizedBox(
        width: 34,
        child: Text(fmt(value), textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800, fontSize: 14)),
      ),
      _btn(Icons.add_rounded, value < max, () => onChanged(value + (isWhole ? 1 : 0.5))),
    ]);
  }

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) => SizedBox(
        width: 30, height: 30,
        child: Material(
          color: enabled ? AppColors.chartBlue.withAlpha(28) : AppColors.border.withAlpha(40),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? onTap : null,
            child: Icon(icon, size: 16, color: enabled ? AppColors.chartBlue : AppColors.textMuted),
          ),
        ),
      );
}
