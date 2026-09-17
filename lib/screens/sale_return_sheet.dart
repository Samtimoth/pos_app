import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

    final reason = _reasonCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final res = await app.api!.createSaleReturn(
        saleId: widget.sale.saleId,
        items: payload,
        reason: reason,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _snack('${res['message'] ?? 'Marejesho yamehifadhiwa'}', AppColors.accent);
        final returnedLines = <_CreditNoteLine>[];
        for (final item in widget.items) {
          final itemId = int.tryParse('${item['item_id']}') ?? 0;
          final q = _qty[itemId] ?? 0;
          if (q <= 0) continue;
          final price = double.tryParse('${item['unit_price']}') ?? 0;
          returnedLines.add(_CreditNoteLine(
            name: '${item['product_name'] ?? ''}',
            qty: q,
            unitPrice: price,
            lineTotal: q * price,
          ));
        }
        final returnId = int.tryParse('${res['return_id']}') ?? 0;
        final refundAmount = double.tryParse('${res['refund_amount']}') ?? 0;
        final cashRefund = double.tryParse('${res['cash_refund']}') ?? 0;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _CreditNoteSheet(
            businessName: app.selectedBusiness?.receiptHeader.isNotEmpty == true
                ? app.selectedBusiness!.receiptHeader
                : (app.selectedBusiness?.businessName ?? 'Duka Kiganjani'),
            creditNoteNo: 'CN-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${returnId.toString().padLeft(5, '0')}',
            sale: widget.sale,
            reason: reason,
            lines: returnedLines,
            refundAmount: refundAmount,
            cashRefund: cashRefund,
          ),
        );
        if (mounted) Navigator.pop(context, true);
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

class _CreditNoteLine {
  final String name;
  final double qty;
  final double unitPrice;
  final double lineTotal;
  const _CreditNoteLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });
}

/// Preview + print sheet for the "hati ya marejesho" (credit note) generated
/// after a return is recorded — same pw.Document/Printing pattern the sales
/// receipt uses in pos_screen.dart, kept local since only this flow needs it.
class _CreditNoteSheet extends StatelessWidget {
  final String businessName;
  final String creditNoteNo;
  final Sale sale;
  final String reason;
  final List<_CreditNoteLine> lines;
  final double refundAmount;
  final double cashRefund;

  const _CreditNoteSheet({
    required this.businessName,
    required this.creditNoteNo,
    required this.sale,
    required this.reason,
    required this.lines,
    required this.refundAmount,
    required this.cashRefund,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    final balanceReduction = refundAmount - cashRefund;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 46, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 12, 10),
              child: Row(children: [
                Icon(Icons.receipt_long_rounded, color: AppColors.chartBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hati ya Marejesho', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(creditNoteNo, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                children: [
                  Text(businessName, style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Mauzo asili: ${sale.saleNo.isNotEmpty ? sale.saleNo : '#${sale.saleId}'}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(dateFmt.format(DateTime.now()), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  if (sale.customerName.isNotEmpty)
                    Text('Mteja: ${sale.customerName}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  if (reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Sababu: $reason', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: lines.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Expanded(
                            child: Text('${l.name}\n${_qtyStr(l.qty)} x TZS ${fmt.format(l.unitPrice)}',
                                style: TextStyle(color: AppColors.textWhite, fontSize: 12.5)),
                          ),
                          Text('TZS ${fmt.format(l.lineTotal)}',
                              style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ]),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _moneyRow('Jumla ya marejesho', refundAmount, bold: true),
                  if (balanceReduction > 0) _moneyRow('Imepunguza deni', balanceReduction),
                  if (cashRefund > 0) _moneyRow('Kurudishiwa taslimu', cashRefund, color: AppColors.chartOrange, bold: true),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _printPdf(fmt, dateFmt, balanceReduction),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.chartBlue, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Chapisha Hati', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _qtyStr(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

  Widget _moneyRow(String k, double v, {bool bold = false, Color? color}) {
    final fmt = NumberFormat('#,###', 'en_US');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: TextStyle(color: color ?? AppColors.textMuted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
        Text('TZS ${fmt.format(v)}', style: TextStyle(color: color ?? AppColors.textWhite, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  Future<void> _printPdf(NumberFormat fmt, DateFormat dateFmt, double balanceReduction) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('Hati ya Marejesho / Credit Note', style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 8),
            _pdfRow('Namba', creditNoteNo),
            _pdfRow('Tarehe', dateFmt.format(DateTime.now())),
            _pdfRow('Mauzo asili', sale.saleNo.isNotEmpty ? sale.saleNo : '#${sale.saleId}'),
            if (sale.customerName.isNotEmpty) _pdfRow('Mteja', sale.customerName),
            if (reason.isNotEmpty) _pdfRow('Sababu', reason),
            pw.Divider(),
            ...lines.map((l) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.Text('${l.name}\n${_qtyStr(l.qty)} x TZS ${fmt.format(l.unitPrice)}', style: const pw.TextStyle(fontSize: 9))),
                  pw.Text('TZS ${fmt.format(l.lineTotal)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            )),
            pw.Divider(),
            _pdfMoney('Jumla ya marejesho', refundAmount, fmt, bold: true),
            if (balanceReduction > 0) _pdfMoney('Imepunguza deni', balanceReduction, fmt),
            if (cashRefund > 0) _pdfMoney('Kurudishiwa taslimu', cashRefund, fmt, bold: true),
            pw.SizedBox(height: 12),
            pw.Center(child: pw.Text('Asante', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  pw.Widget _pdfRow(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(children: [
          pw.Text('$k: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Expanded(child: pw.Text(v, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
        ]),
      );

  pw.Widget _pdfMoney(String k, double v, NumberFormat fmt, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: bold ? 11 : 9)),
            pw.Text('TZS ${fmt.format(v)}', style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: bold ? 11 : 9)),
          ],
        ),
      );
}
