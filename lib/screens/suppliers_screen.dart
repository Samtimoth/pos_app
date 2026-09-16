import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/supplier.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';

/// Wasambazaji (suppliers): list, search, add/edit, delete.
/// [pickMode] returns the chosen supplier via Navigator.pop (used by
/// add_batch_sheet.dart instead of a free-text field).
class SuppliersScreen extends StatefulWidget {
  final bool desktop;
  final bool pickMode;
  const SuppliersScreen({super.key, this.desktop = false, this.pickMode = false});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _searchCtrl = TextEditingController();
  List<Supplier> _all = [];
  bool _loading = true;
  String _q = '';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      final raw = await crm.listSuppliers(bizId);
      if (!mounted) return;
      setState(() {
        _all = raw.map((e) => Supplier.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('$e', AppColors.chartRed);
      }
    }
  }

  List<Supplier> get _filtered {
    if (_q.trim().isEmpty) return _all;
    final s = _q.trim().toLowerCase();
    return _all.where((sup) =>
        sup.name.toLowerCase().contains(s) || sup.phone.contains(s)).toList();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openForm({Supplier? edit}) async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final crm = _crm;
    if (bizId == null || crm == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierFormSheet(crm: crm, businessId: bizId, edit: edit),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Futa msambazaji?', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Text('${s.name} ataondolewa kwenye orodha.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Futa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final crm = _crm;
    if (bizId == null || crm == null) return;
    final r = await crm.deleteSupplier(bizId, s.supplierId);
    if (!mounted) return;
    if (r['success'] == true) {
      _snack('${r['message'] ?? 'Imefutwa'}', AppColors.accent);
      _load();
    } else {
      _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.pickMode ? Colors.transparent : AppColors.bg,
      appBar: widget.pickMode
          ? AppBar(
              backgroundColor: AppColors.bgCard,
              title: Text('Chagua Msambazaji', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
              iconTheme: IconThemeData(color: AppColors.textWhite),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                hintText: 'Tafuta msambazaji au simu...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.bgInput,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Text('Hakuna wasambazaji bado', style: TextStyle(color: AppColors.textMuted)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = _filtered[i];
                          return Material(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: widget.pickMode ? () => Navigator.pop(context, s) : () => _openForm(edit: s),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(color: AppColors.chartBlue.withAlpha(28), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.local_shipping_outlined, color: AppColors.chartBlue, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(s.name, style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Builder(builder: (_) {
                                        final parts = [
                                          if (s.phone.isNotEmpty) s.phone,
                                          if (s.batchesCount > 0)
                                            'Manunuzi ${s.batchesCount} · TZS ${_fmt.format(s.totalSpent)}',
                                        ];
                                        return Text(
                                          parts.isEmpty ? 'Hakuna maelezo' : parts.join(' · '),
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        );
                                      }),
                                    ]),
                                  ),
                                  if (!widget.pickMode)
                                    IconButton(
                                      onPressed: () => _confirmDelete(s),
                                      icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                                    ),
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
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text('Ongeza Msambazaji', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SupplierFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final Supplier? edit;
  const _SupplierFormSheet({required this.crm, required this.businessId, this.edit});

  @override
  State<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<_SupplierFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.edit?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.edit?.phone ?? '');
  late final _emailCtrl = TextEditingController(text: widget.edit?.email ?? '');
  late final _addressCtrl = TextEditingController(text: widget.edit?.address ?? '');
  late final _notesCtrl = TextEditingController(text: widget.edit?.notes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jina la msambazaji linahitajika'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await widget.crm.saveSupplier(
        businessId: widget.businessId,
        supplierId: widget.edit?.supplierId,
        name: name,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r['message'] ?? 'Hitilafu'}'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
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
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(children: [
                Expanded(
                  child: Text(widget.edit == null ? 'Ongeza Msambazaji' : 'Hariri Msambazaji',
                      style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _field(_nameCtrl, 'Jina la Msambazaji *', Icons.storefront_outlined),
                  const SizedBox(height: 12),
                  _field(_phoneCtrl, 'Namba ya Simu', Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(_emailCtrl, 'Barua Pepe (hiari)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field(_addressCtrl, 'Anuani (hiari)', Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  _field(_notesCtrl, 'Maelezo (hiari)', Icons.notes_outlined),
                ]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textWhite, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
      ),
    );
  }
}
