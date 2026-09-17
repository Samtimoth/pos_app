import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/business.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';

/// Uhamisho wa stock kati ya matawi (Hatua 5): kila tawi lina bidhaa/stock
/// yake tofauti sasa — hii inahamisha kiasi kutoka tawi moja kwenda lingine,
/// ikitambua bidhaa ya tawi lengwa kwa product_code/barcode (au kuiunda
/// ikiwa haipo bado huko).
class StockTransfersScreen extends StatefulWidget {
  final bool desktop;
  const StockTransfersScreen({super.key, this.desktop = false});

  @override
  State<StockTransfersScreen> createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen> {
  final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

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
      final raw = await crm.listStockTransfers(bizId);
      if (!mounted) return;
      setState(() { _all = raw; _loading = false; });
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
    final biz = app.selectedBusiness;
    final crm = _crm;
    if (biz == null || crm == null) return;
    if (biz.branches.length < 2) {
      _snack('Biashara ina tawi moja pekee — hakuna cha kuhamisha kati ya matawi', AppColors.chartOrange);
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferFormSheet(crm: crm, businessId: biz.businessId, branches: biz.branches),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _all.isEmpty
              ? Center(child: Text('Hakuna uhamisho wa stock bado', style: TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                  itemCount: _all.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = _all[i];
                    final date = DateTime.tryParse('${t['created_at']}');
                    return Material(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: AppColors.chartPurple.withAlpha(28), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.sync_alt_rounded, color: AppColors.chartPurple, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${t['from_branch_name'] ?? '?'} → ${t['to_branch_name'] ?? '?'}',
                                  style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('${t['transfer_no']} · bidhaa ${t['item_count']} · ${date == null ? '' : _dateFmt.format(date)}',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.sync_alt_rounded, color: Colors.white),
        label: const Text('Hamisha Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _TransferLine {
  final Product product;
  double qty = 1;
  _TransferLine({required this.product});
}

class _TransferFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final List<Branch> branches;
  const _TransferFormSheet({required this.crm, required this.businessId, required this.branches});

  @override
  State<_TransferFormSheet> createState() => _TransferFormSheetState();
}

class _TransferFormSheetState extends State<_TransferFormSheet> {
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_TransferLine> _lines = [];
  List<Product> _searchResults = [];
  late Branch _from;
  late Branch _to;
  bool _searching = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _from = widget.branches[0];
    _to = widget.branches.firstWhere((b) => b.branchId != _from.branchId, orElse: () => widget.branches[1]);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final app = context.read<AppProvider>();
      if (app.api == null) return;
      final raw = await app.api!.getProducts(widget.businessId, branchId: _from.branchId, search: q.trim());
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
      if (idx >= 0) { _lines[idx].qty += 1; } else { _lines.add(_TransferLine(product: p)); }
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    if (_from.branchId == _to.branchId) { _snack('Chagua matawi mawili tofauti', AppColors.chartOrange); return; }
    if (_lines.isEmpty) { _snack('Ongeza angalau bidhaa moja', AppColors.chartOrange); return; }
    setState(() => _saving = true);
    try {
      final res = await widget.crm.createStockTransfer(
        businessId: widget.businessId,
        fromBranchId: _from.branchId,
        toBranchId: _to.branchId,
        items: _lines.map((l) => {'product_id': l.product.productId, 'quantity': l.qty}).toList(),
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
                Expanded(child: Text('Hamisha Stock', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: _branchPicker('Kutoka', _from, (b) => setState(() { _from = b; _lines.clear(); }))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted)),
                    Expanded(child: _branchPicker('Kwenda', _to, (b) => setState(() => _to = b))),
                  ]),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Tafuta bidhaa ya kuhamisha (kutoka ${_from.branchName})...',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                  label: Text(_saving ? 'Inahamisha...' : 'Hamisha Stock', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchPicker(String label, Branch selected, ValueChanged<Branch> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Branch>(
          isExpanded: true,
          value: selected,
          dropdownColor: AppColors.bgCard,
          icon: Icon(Icons.expand_more_rounded, color: AppColors.textMuted, size: 18),
          items: widget.branches
              .map((b) => DropdownMenuItem(value: b, child: Text(b.branchName, style: TextStyle(color: AppColors.textWhite, fontSize: 13))))
              .toList(),
          onChanged: (b) { if (b != null) onChanged(b); },
          selectedItemBuilder: (_) => widget.branches
              .map((b) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
                    Text(b.branchName, style: TextStyle(color: AppColors.textWhite, fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  Widget _lineRow(int i, _TransferLine line) {
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
            width: 70,
            child: TextFormField(
              initialValue: line.qty == line.qty.roundToDouble() ? line.qty.toInt().toString() : line.qty.toString(),
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textWhite, fontSize: 12),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              onChanged: (v) => setState(() => line.qty = double.tryParse(v) ?? line.qty),
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
