import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';
import 'customers_screen.dart';

/// Nukuu ya Bei (Quotation, Hatua 6): hati ya bei kwa mteja KABLA ya mauzo
/// halisi kutokea — haigusi stock wala fedha. Mauzo halisi bado yanafanywa
/// kupitia POS wakati mteja anapokubali kununua.
class QuotationsScreen extends StatefulWidget {
  final bool desktop;
  const QuotationsScreen({super.key, this.desktop = false});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String _status = '';

  CrmApi? get _crm {
    final app = context.read<AppProvider>();
    final url = app.user?.serverUrl;
    return url == null ? null : CrmApi(url);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final crm = _crm;
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    if (crm == null || bizId == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final raw = await crm.listQuotations(bizId, status: _status);
      if (!mounted) return;
      setState(() { _all = raw; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _snack('$e', AppColors.chartRed); }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openForm() async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final crm = _crm;
    if (bizId == null || crm == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuotationFormSheet(crm: crm, businessId: bizId, branchId: app.selectedBranch?.branchId),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> q) async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final crm = _crm;
    if (bizId == null || crm == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuotationDetailSheet(crm: crm, businessId: bizId, quotationId: q['quotation_id'] as int),
    );
    if (changed == true) _load();
  }

  Color _statusColor(String s) => switch (s) {
        'accepted' => AppColors.accent,
        'cancelled' => AppColors.textMuted,
        'expired' => Colors.orangeAccent,
        _ => AppColors.chartBlue,
      };

  String _statusLabel(String s) => switch (s) {
        'accepted' => 'Imekubaliwa',
        'cancelled' => 'Imefutwa',
        'expired' => 'Muda Umepita',
        _ => 'Imetumwa',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              children: [
                _chip('Zote', ''),
                _chip('Zilizotumwa', 'sent'),
                _chip('Zilizokubaliwa', 'accepted'),
                _chip('Muda Umepita', 'expired'),
                _chip('Zilizofutwa', 'cancelled'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _all.isEmpty
                    ? Center(child: Text('Hakuna nukuu bado', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final q = _all[i];
                          final status = '${q['status'] ?? 'sent'}';
                          final total = double.tryParse('${q['subtotal_amount']}') ?? 0;
                          return Material(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openDetail(q),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: _statusColor(status).withAlpha(28), borderRadius: BorderRadius.circular(8)),
                                    child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(('${q['customer_name'] ?? ''}').isEmpty ? 'Mteja wa kawaida' : '${q['customer_name']}',
                                          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('${q['quotation_no']} · bidhaa ${q['item_count']}',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ]),
                                  ),
                                  Text('TZS ${_fmt.format(total)}', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.description_outlined, color: Colors.white),
        label: const Text('Tengeneza Nukuu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: sel,
        onSelected: (_) { setState(() => _status = value); _load(); },
        selectedColor: AppColors.accent.withAlpha(60),
        backgroundColor: AppColors.bgCard,
        labelStyle: TextStyle(color: sel ? AppColors.accent : AppColors.textMuted),
      ),
    );
  }
}

class _QuoteLine {
  final Product product;
  double qty = 1;
  double price;
  _QuoteLine({required this.product}) : price = product.sellPrice;
  double get lineTotal => qty * price;
}

class _QuotationFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final int? branchId;
  const _QuotationFormSheet({required this.crm, required this.businessId, this.branchId});

  @override
  State<_QuotationFormSheet> createState() => _QuotationFormSheetState();
}

class _QuotationFormSheetState extends State<_QuotationFormSheet> {
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_QuoteLine> _lines = [];
  List<Product> _searchResults = [];
  Customer? _customer;
  DateTime? _validUntil;
  bool _searching = false;
  bool _saving = false;

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final picked = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => const CustomersScreen(pickMode: true)),
    );
    if (picked != null && mounted) setState(() => _customer = picked);
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _validUntil = picked);
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final app = context.read<AppProvider>();
      if (app.api == null) return;
      final raw = await app.api!.getProducts(widget.businessId, branchId: widget.branchId, search: q.trim());
      if (!mounted) return;
      setState(() => _searchResults = raw.map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addProduct(Product p) {
    setState(() {
      final idx = _lines.indexWhere((l) => l.product.productId == p.productId);
      if (idx >= 0) { _lines[idx].qty += 1; } else { _lines.add(_QuoteLine(product: p)); }
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) { _snack('Ongeza angalau bidhaa moja', AppColors.chartOrange); return; }
    setState(() => _saving = true);
    try {
      final res = await widget.crm.createQuotation(
        businessId: widget.businessId,
        branchId: widget.branchId,
        customerId: _customer?.customerId,
        customerName: _customer?.name ?? '',
        customerPhone: _customer?.phone ?? '',
        items: _lines.map((l) => {'product_id': l.product.productId, 'quantity': l.qty, 'unit_price': l.price}).toList(),
        validUntil: _validUntil == null ? null : DateFormat('yyyy-MM-dd').format(_validUntil!),
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['success'] == true) {
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
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(children: [
                Expanded(child: Text('Tengeneza Nukuu', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InkWell(
                    onTap: _pickCustomer,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(Icons.person_outline_rounded, color: AppColors.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_customer?.name ?? 'Chagua mteja (hiari)',
                              style: TextStyle(color: _customer != null ? AppColors.textWhite : AppColors.textMuted, fontSize: 13)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickValidUntil,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(Icons.event_outlined, color: AppColors.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_validUntil == null ? 'Muda wa nukuu (hiari)' : 'Inaisha: ${DateFormat('dd MMM yyyy').format(_validUntil!)}',
                              style: TextStyle(color: _validUntil != null ? AppColors.textWhite : AppColors.textMuted, fontSize: 13)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Tafuta bidhaa ya kuongeza...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                      filled: true, fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    ),
                    onChanged: _search,
                  ),
                  if (_searching)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        itemBuilder: (_, i) {
                          final p = _searchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(p.name, style: TextStyle(color: AppColors.textWhite, fontSize: 13)),
                            subtitle: Text('Bei: TZS ${NumberFormat('#,###').format(p.sellPrice)}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            trailing: Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                            onTap: () => _addProduct(p),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (_lines.isNotEmpty) ...[
                    Text('Bidhaa (${_lines.length})', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._lines.asMap().entries.map((e) => _lineRow(e.key, e.value)),
                    const Divider(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Jumla', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800)),
                      Text('TZS ${NumberFormat('#,###').format(_subtotal)}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      style: TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText: 'Maelezo (hiari)',
                        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        filled: true, fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_saving || _lines.isEmpty) ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi Nukuu', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(int i, _QuoteLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Text(line.product.name, style: TextStyle(color: AppColors.textWhite, fontSize: 12.5), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 55,
            child: TextFormField(
              initialValue: line.qty == line.qty.roundToDouble() ? line.qty.toInt().toString() : line.qty.toString(),
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textWhite, fontSize: 12),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              onChanged: (v) => setState(() => line.qty = double.tryParse(v) ?? line.qty),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: line.price.toStringAsFixed(0),
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textWhite, fontSize: 12),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              onChanged: (v) => setState(() => line.price = double.tryParse(v) ?? line.price),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _lines.removeAt(i)),
            icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ]),
      ),
    );
  }
}

class _QuotationDetailSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final int quotationId;
  const _QuotationDetailSheet({required this.crm, required this.businessId, required this.quotationId});

  @override
  State<_QuotationDetailSheet> createState() => _QuotationDetailSheetState();
}

class _QuotationDetailSheetState extends State<_QuotationDetailSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  Map<String, dynamic>? _quotation;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.crm.getQuotation(widget.businessId, widget.quotationId);
      if (!mounted) return;
      if (r['success'] == true) {
        setState(() {
          _quotation = Map<String, dynamic>.from(r['quotation'] as Map);
          _items = ((r['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() call) async {
    setState(() => _busy = true);
    try {
      final r = await call();
      if (!mounted) return;
      if (r['success'] == true) { _changed = true; _load(); } else { _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed); }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printQuotation() async {
    final q = _quotation;
    if (q == null) return;
    final app = context.read<AppProvider>();
    final businessName = app.selectedBusiness?.businessName ?? '';
    final subtotal = double.tryParse('${q['subtotal_amount']}') ?? 0;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Center(child: pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('NUKUU YA BEI / QUOTATION', style: const pw.TextStyle(fontSize: 10))),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Mteja: ${(q['customer_name'] ?? '').toString().isEmpty ? 'Mteja wa kawaida' : q['customer_name']}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Namba: ${q['quotation_no'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tarehe: ${q['created_at'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
              if (q['valid_until'] != null) pw.Text('Inaisha: ${q['valid_until']}', style: const pw.TextStyle(fontSize: 10)),
            ]),
          ]),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.3), 2: pw.FlexColumnWidth(1.6), 3: pw.FlexColumnWidth(1.6)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                _cell('Bidhaa', bold: true), _cell('Kiasi', bold: true),
                _cell('Bei/kipimo', bold: true, align: pw.TextAlign.right), _cell('Jumla', bold: true, align: pw.TextAlign.right),
              ]),
              for (final it in _items)
                pw.TableRow(children: [
                  _cell('${it['product_name']}'),
                  _cell('${it['quantity']}'),
                  _cell(_fmt.format(double.tryParse('${it['unit_price']}') ?? 0), align: pw.TextAlign.right),
                  _cell(_fmt.format(double.tryParse('${it['line_total']}') ?? 0), align: pw.TextAlign.right),
                ]),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Align(alignment: pw.Alignment.centerRight,
              child: pw.Text('Jumla: TZS ${_fmt.format(subtotal)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          if (('${q['notes'] ?? ''}').isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Maelezo: ${q['notes']}', style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  pw.Widget _cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final status = '${_quotation?['status'] ?? 'sent'}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.pop(context, _changed); },
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: _loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${_quotation?['quotation_no'] ?? ''}', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                            Text(('${_quotation?['customer_name'] ?? ''}').isEmpty ? 'Mteja wa kawaida' : '${_quotation?['customer_name']}',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        ),
                        IconButton(onPressed: _printQuotation, icon: Icon(Icons.print_outlined, color: AppColors.textMuted)),
                        IconButton(onPressed: () => Navigator.pop(context, _changed), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
                      ]),
                    ),
                    Divider(color: AppColors.border, height: 1),
                    Flexible(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        children: [
                          ..._items.map((it) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  Expanded(child: Text('${it['product_name']}', style: TextStyle(color: AppColors.textWhite, fontSize: 13))),
                                  Text('${it['quantity']} x TZS ${_fmt.format(double.tryParse('${it['unit_price']}') ?? 0)}',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ]),
                              )),
                          const Divider(height: 24),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Jumla', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800)),
                            Text('TZS ${_fmt.format(double.tryParse('${_quotation?['subtotal_amount']}') ?? 0)}',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
                          ]),
                        ],
                      ),
                    ),
                    if (status == 'sent')
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : () => _act(() => widget.crm.cancelQuotation(widget.businessId, widget.quotationId)),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Futa'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : () => _act(() => widget.crm.acceptQuotation(widget.businessId, widget.quotationId)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Mteja Amekubali', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
