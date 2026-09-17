import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';
import 'suppliers_screen.dart';

/// Manunuzi (purchases): record stock bought from a supplier, track how much
/// of it is still owed, and record payments against that balance over time.
class PurchasesScreen extends StatefulWidget {
  final bool desktop;
  final int? supplierId; // pre-filter to one supplier's purchases
  const PurchasesScreen({super.key, this.desktop = false, this.supplierId});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String _status = ''; // '' | unpaid | partial | paid

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
    if (crm == null || bizId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await crm.listPurchases(bizId, supplierId: widget.supplierId,
          status: _status);
      if (!mounted) return;
      setState(() {
        _all = raw;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('$e', AppColors.chartRed);
      }
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
      builder: (_) => _PurchaseFormSheet(crm: crm, businessId: bizId, presetSupplierId: widget.supplierId),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> p) async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final crm = _crm;
    if (bizId == null || crm == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseDetailSheet(crm: crm, businessId: bizId, purchaseId: p['purchase_id'] as int),
    );
    if (changed == true) _load();
  }

  Color _statusColor(String s) => switch (s) {
        'paid' => AppColors.accent,
        'partial' => Colors.orangeAccent,
        _ => Colors.redAccent,
      };

  String _statusLabel(String s) => switch (s) {
        'paid' => 'Imelipwa',
        'partial' => 'Nusu',
        _ => 'Haijalipwa',
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
                _chip('Haijalipwa', 'unpaid'),
                _chip('Nusu', 'partial'),
                _chip('Imelipwa', 'paid'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _all.isEmpty
                    ? Center(child: Text('Hakuna manunuzi bado', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = _all[i];
                          final status = '${p['payment_status'] ?? 'unpaid'}';
                          final total = double.tryParse('${p['subtotal_amount']}') ?? 0;
                          final balance = double.tryParse('${p['balance_amount']}') ?? 0;
                          return Material(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openDetail(p),
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
                                      Text('${p['supplier_name'] ?? 'Bila msambazaji'}',
                                          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('${p['purchase_no']} · bidhaa ${p['item_count']}',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ]),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('TZS ${_fmt.format(total)}', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
                                    if (balance > 0)
                                      Text('Deni TZS ${_fmt.format(balance)}', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                                  ]),
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
        icon: const Icon(Icons.move_to_inbox_outlined, color: Colors.white),
        label: const Text('Ongeza Ununuzi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        onSelected: (_) {
          setState(() => _status = value);
          _load();
        },
        selectedColor: AppColors.accent.withAlpha(60),
        backgroundColor: AppColors.bgCard,
        labelStyle: TextStyle(color: sel ? AppColors.accent : AppColors.textMuted),
      ),
    );
  }
}

class _PurchaseLine {
  final Product product;
  double qty = 1;
  double cost;
  _PurchaseLine({required this.product}) : cost = product.buyPrice;
  double get lineTotal => qty * cost;
}

class _PurchaseFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final int? presetSupplierId;
  const _PurchaseFormSheet({required this.crm, required this.businessId, this.presetSupplierId});

  @override
  State<_PurchaseFormSheet> createState() => _PurchaseFormSheetState();
}

class _PurchaseFormSheetState extends State<_PurchaseFormSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _searchCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_PurchaseLine> _lines = [];
  List<Product> _searchResults = [];
  Supplier? _supplier;
  bool _searching = false;
  bool _saving = false;

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final picked = await Navigator.of(context).push<Supplier>(
      MaterialPageRoute(builder: (_) => const SuppliersScreen(pickMode: true)),
    );
    if (picked != null && mounted) setState(() => _supplier = picked);
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final app = context.read<AppProvider>();
      if (app.api == null) return;
      final raw = await app.api!.getProducts(widget.businessId,
          branchId: app.selectedBranch?.branchId, search: q.trim());
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
      if (idx >= 0) {
        _lines[idx].qty += 1;
      } else {
        _lines.add(_PurchaseLine(product: p));
      }
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      _snack('Ongeza angalau bidhaa moja', AppColors.chartOrange);
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await widget.crm.createPurchase(
        businessId: widget.businessId,
        supplierId: _supplier?.supplierId,
        items: _lines
            .map((l) => {'product_id': l.product.productId, 'quantity': l.qty, 'unit_cost': l.cost})
            .toList(),
        paidAmount: double.tryParse(_paidCtrl.text.replaceAll(',', '').trim()) ?? 0,
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
                Expanded(child: Text('Ongeza Ununuzi', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InkWell(
                    onTap: _pickSupplier,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(Icons.local_shipping_outlined, color: AppColors.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_supplier?.name ?? 'Chagua msambazaji (hiari)',
                              style: TextStyle(color: _supplier != null ? AppColors.textWhite : AppColors.textMuted, fontSize: 13)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
                            subtitle: Text('Stock: ${p.stock} ${p.unit}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
                      Text('TZS ${_fmt.format(_subtotal)}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _paidCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText: 'Kiasi ulicholipa sasa (hiari)',
                        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        hintText: 'Ukiacha wazi, deni lote litabaki',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        filled: true, fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      ),
                    ),
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
                  label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi Ununuzi', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(int i, _PurchaseLine line) {
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
            width: 60,
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
              initialValue: line.cost.toStringAsFixed(0),
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textWhite, fontSize: 12),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              onChanged: (v) => setState(() => line.cost = double.tryParse(v) ?? line.cost),
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

class _PurchaseDetailSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final int purchaseId;
  const _PurchaseDetailSheet({required this.crm, required this.businessId, required this.purchaseId});

  @override
  State<_PurchaseDetailSheet> createState() => _PurchaseDetailSheetState();
}

class _PurchaseDetailSheetState extends State<_PurchaseDetailSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  Map<String, dynamic>? _purchase;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.crm.getPurchase(widget.businessId, widget.purchaseId);
      if (!mounted) return;
      if (r['success'] == true) {
        setState(() {
          _purchase = Map<String, dynamic>.from(r['purchase'] as Map);
          _items = ((r['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _payments = ((r['payments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordPayment() async {
    final balance = double.tryParse('${_purchase?['balance_amount']}') ?? 0;
    if (balance <= 0) return;
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Lipa Msambazaji', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Deni lililobaki: TZS ${_fmt.format(balance)}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(hintText: 'Kiasi', hintStyle: TextStyle(color: AppColors.textMuted)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text.replaceAll(',', '').trim())),
            child: const Text('Lipa'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;
    try {
      final r = await widget.crm.recordPurchasePayment(businessId: widget.businessId, purchaseId: widget.purchaseId, amount: amount);
      if (!mounted) return;
      if (r['success'] == true) {
        _changed = true;
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r['message'] ?? 'Hitilafu'}'), backgroundColor: AppColors.chartRed, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.chartRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final balance = double.tryParse('${_purchase?['balance_amount']}') ?? 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
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
                            Text('${_purchase?['purchase_no'] ?? ''}', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('${_purchase?['supplier_name'] ?? 'Bila msambazaji'}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        ),
                        IconButton(onPressed: _printInvoice, icon: Icon(Icons.print_outlined, color: AppColors.textMuted)),
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
                                  Text('${it['quantity']} x TZS ${_fmt.format(double.tryParse('${it['unit_cost']}') ?? 0)}',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ]),
                              )),
                          const Divider(height: 24),
                          _moneyRow('Jumla', double.tryParse('${_purchase?['subtotal_amount']}') ?? 0, bold: true),
                          _moneyRow('Amelipwa', double.tryParse('${_purchase?['paid_amount']}') ?? 0),
                          if (balance > 0) _moneyRow('Deni lililobaki', balance, color: Colors.orangeAccent, bold: true),
                          if (_payments.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text('Historia ya Malipo', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            ..._payments.map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text('${p['created_at']}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    Text('TZS ${_fmt.format(double.tryParse('${p['amount']}') ?? 0)}', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ]),
                                )),
                          ],
                        ],
                      ),
                    ),
                    if (balance > 0)
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
                        child: SizedBox(
                          width: double.infinity, height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _recordPayment,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartBlue, foregroundColor: Colors.white),
                            icon: const Icon(Icons.payments_rounded),
                            label: const Text('Lipa Msambazaji', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _moneyRow(String k, double v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: color ?? AppColors.textMuted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
          Text('TZS ${_fmt.format(v)}', style: TextStyle(color: color ?? AppColors.textWhite, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
        ]),
      );

  /// Invoice rasmi ya msambazaji (Hatua 5) — hati ya kuchapisha yenye
  /// muundo wa kawaida wa invoice (bidhaa, bei, jumla, kilicholipwa, deni).
  Future<void> _printInvoice() async {
    final p = _purchase;
    if (p == null) return;
    final businessName = context.read<AppProvider>().selectedBusiness?.businessName ?? '';
    final subtotal = double.tryParse('${p['subtotal_amount']}') ?? 0;
    final paid = double.tryParse('${p['paid_amount']}') ?? 0;
    final balance = double.tryParse('${p['balance_amount']}') ?? 0;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Center(child: pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('INVOICE YA MANUNUZI', style: const pw.TextStyle(fontSize: 10))),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Msambazaji: ${p['supplier_name'] ?? 'Bila msambazaji'}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Namba: ${p['purchase_no'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.Text('Tarehe: ${p['created_at'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.3), 2: pw.FlexColumnWidth(1.6), 3: pw.FlexColumnWidth(1.6)},
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                _pdfCell('Bidhaa', bold: true), _pdfCell('Kiasi', bold: true),
                _pdfCell('Bei/kipimo', bold: true, align: pw.TextAlign.right), _pdfCell('Jumla', bold: true, align: pw.TextAlign.right),
              ]),
              for (final it in _items)
                pw.TableRow(children: [
                  _pdfCell('${it['product_name']}'),
                  _pdfCell('${it['quantity']}'),
                  _pdfCell(_fmt.format(double.tryParse('${it['unit_cost']}') ?? 0), align: pw.TextAlign.right),
                  _pdfCell(_fmt.format(double.tryParse('${it['line_total']}') ?? 0), align: pw.TextAlign.right),
                ]),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.SizedBox(width: 220, child: pw.Column(children: [
            _pdfMoneyRow('Jumla', subtotal, bold: true),
            _pdfMoneyRow('Kimelipwa', paid),
            if (balance > 0) _pdfMoneyRow('Deni', balance, bold: true),
          ]))),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  pw.Widget _pdfCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  pw.Widget _pdfMoneyRow(String k, double v, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(k, style: pw.TextStyle(fontSize: bold ? 11 : 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('TZS ${_fmt.format(v)}', style: pw.TextStyle(fontSize: bold ? 11 : 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );
}
