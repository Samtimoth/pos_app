import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';
import 'suppliers_screen.dart';

/// PO rasmi (Hatua 5): hatua ya KUAGIZA, tofauti na Purchases (kupokea +
/// kuandikisha kwa pamoja). Draft/Sent hazigusi stock wala deni — 'Pokea'
/// ndipo inapotengeneza rekodi ya kawaida ya Purchase (stock inaongezeka).
class PurchaseOrdersScreen extends StatefulWidget {
  final bool desktop;
  const PurchaseOrdersScreen({super.key, this.desktop = false});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
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
    if (crm == null || bizId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await crm.listPurchaseOrders(bizId, status: _status);
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
      builder: (_) => _PoFormSheet(crm: crm, businessId: bizId),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> po) async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final crm = _crm;
    if (bizId == null || crm == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PoDetailSheet(crm: crm, businessId: bizId, poId: po['po_id'] as int),
    );
    if (changed == true) _load();
  }

  Color _statusColor(String s) => switch (s) {
        'received' => AppColors.accent,
        'sent' => AppColors.chartBlue,
        'cancelled' => AppColors.textMuted,
        _ => Colors.orangeAccent,
      };

  String _statusLabel(String s) => switch (s) {
        'received' => 'Imepokewa',
        'sent' => 'Imetumwa',
        'cancelled' => 'Imefutwa',
        _ => 'Rasimu',
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
                _chip('Rasimu', 'draft'),
                _chip('Zilizotumwa', 'sent'),
                _chip('Zilizopokewa', 'received'),
                _chip('Zilizofutwa', 'cancelled'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _all.isEmpty
                    ? Center(child: Text('Hakuna maagizo (PO) bado', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = _all[i];
                          final status = '${p['status'] ?? 'draft'}';
                          final total = double.tryParse('${p['subtotal_amount']}') ?? 0;
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
                                      Text('${p['po_no']} · bidhaa ${p['item_count']}',
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
        icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
        label: const Text('Agiza Bidhaa (PO)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

class _PoLine {
  final Product product;
  double qty = 1;
  double cost;
  _PoLine({required this.product}) : cost = product.buyPrice;
  double get lineTotal => qty * cost;
}

class _PoFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  const _PoFormSheet({required this.crm, required this.businessId});

  @override
  State<_PoFormSheet> createState() => _PoFormSheetState();
}

class _PoFormSheetState extends State<_PoFormSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_PoLine> _lines = [];
  List<Product> _searchResults = [];
  Supplier? _supplier;
  bool _searching = false;
  bool _saving = false;

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final app = context.read<AppProvider>();
      if (app.api == null) return;
      final raw = await app.api!.getProducts(widget.businessId, search: q.trim());
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
      if (idx >= 0) { _lines[idx].qty += 1; } else { _lines.add(_PoLine(product: p)); }
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) { _snack('Ongeza angalau bidhaa moja', AppColors.chartOrange); return; }
    setState(() => _saving = true);
    try {
      final res = await widget.crm.createPurchaseOrder(
        businessId: widget.businessId,
        supplierId: _supplier?.supplierId,
        items: _lines.map((l) => {'product_id': l.product.productId, 'quantity': l.qty, 'unit_cost': l.cost}).toList(),
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
                Expanded(child: Text('Agiza Bidhaa (PO)', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.chartBlue.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.chartBlue),
                      const SizedBox(width: 8),
                      Expanded(child: Text('PO haiongezi stock wala deni — inakuwa hai tu ukiipokea baadaye.',
                          style: TextStyle(color: AppColors.chartBlue, fontSize: 11))),
                    ]),
                  ),
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
                      hintText: 'Tafuta bidhaa ya kuagiza...',
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
                      Text('Jumla ya PO', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800)),
                      Text('TZS ${_fmt.format(_subtotal)}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
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
                  label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi PO', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(int i, _PoLine line) {
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

class _PoDetailSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final int poId;
  const _PoDetailSheet({required this.crm, required this.businessId, required this.poId});

  @override
  State<_PoDetailSheet> createState() => _PoDetailSheetState();
}

class _PoDetailSheetState extends State<_PoDetailSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  Map<String, dynamic>? _po;
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
      final r = await widget.crm.getPurchaseOrder(widget.businessId, widget.poId);
      if (!mounted) return;
      if (r['success'] == true) {
        setState(() {
          _po = Map<String, dynamic>.from(r['purchase_order'] as Map);
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

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await widget.crm.sendPurchaseOrder(widget.businessId, widget.poId);
      if (!mounted) return;
      if (r['success'] == true) { _changed = true; _load(); } else { _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed); }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Futa PO?', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Text('Hatua hii haiwezi kutenduliwa.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Futa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await widget.crm.cancelPurchaseOrder(widget.businessId, widget.poId);
      if (!mounted) return;
      if (r['success'] == true) { _changed = true; _load(); } else { _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed); }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    final subtotal = double.tryParse('${_po?['subtotal_amount']}') ?? 0;
    final ctrl = TextEditingController();
    final paid = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pokea PO', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bidhaa zilizoagizwa zitaongezwa kwenye stock. Jumla: TZS ${_fmt.format(subtotal)}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(hintText: 'Kiasi ulicholipa sasa (hiari)', hintStyle: TextStyle(color: AppColors.textMuted)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0),
            child: const Text('Pokea'),
          ),
        ],
      ),
    );
    if (paid == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await widget.crm.receivePurchaseOrder(businessId: widget.businessId, poId: widget.poId, paidAmount: paid);
      if (!mounted) return;
      if (r['success'] == true) {
        _changed = true;
        _snack('✅ PO imepokewa — stock imeongezwa', AppColors.accent);
        _load();
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final status = '${_po?['status'] ?? 'draft'}';
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
                            Text('${_po?['po_no'] ?? ''}', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('${_po?['supplier_name'] ?? 'Bila msambazaji'}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        ),
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
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Jumla ya PO', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800)),
                            Text('TZS ${_fmt.format(double.tryParse('${_po?['subtotal_amount']}') ?? 0)}',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
                          ]),
                          if (status == 'received')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('✅ Imepokewa — angalia kwenye Manunuzi kwa maelezo ya malipo.',
                                  style: TextStyle(color: AppColors.accent, fontSize: 12)),
                            ),
                          if (status == 'cancelled')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Imefutwa.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    if (status == 'draft' || status == 'sent')
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
                        child: Row(children: [
                          if (status == 'draft')
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _send,
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Tuma'),
                              ),
                            ),
                          if (status == 'draft') const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _cancel,
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Futa'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _receive,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                              icon: const Icon(Icons.move_to_inbox_rounded, size: 16),
                              label: const Text('Pokea', style: TextStyle(fontWeight: FontWeight.bold)),
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
