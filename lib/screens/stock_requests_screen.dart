import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';

/// Maombi ya Stock: mfanyakazi (cashier) anaomba bidhaa aliyoiona inapungua,
/// admin/meneja anaidhinisha, kisha aliyeomba anapokea ikiwasili — hapo
/// ndipo stock halisi inapoongezwa (batch/FEFO, angalia stock_requests.php).
/// Tofauti na Stock Transfers (kati ya matawi mawili) — hii ni ndani ya
/// tawi moja: "tupatie zaidi ya bidhaa hii".
class StockRequestsScreen extends StatefulWidget {
  final bool desktop;
  const StockRequestsScreen({super.key, this.desktop = false});

  @override
  State<StockRequestsScreen> createState() => _StockRequestsScreenState();
}

class _StockRequestsScreenState extends State<StockRequestsScreen> {
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
      final raw = await crm.listStockRequests(bizId,
          branchId: app.selectedBranch?.branchId, status: _status);
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
      builder: (_) => _RequestFormSheet(
        crm: crm, businessId: bizId, branchId: app.selectedBranch?.branchId,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> req) async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final crm = _crm;
    if (bizId == null || crm == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailSheet(
        crm: crm, businessId: bizId, request: req,
        canApprove: app.user?.canApproveStock ?? false,
        canReceive: app.user?.canRequestStock ?? false,
      ),
    );
    if (changed == true) _load();
  }

  Color _statusColor(String s) => switch (s) {
        'received' => AppColors.accent,
        'approved' => AppColors.chartBlue,
        'rejected' => AppColors.chartRed,
        _ => Colors.orangeAccent,
      };

  String _statusLabel(String s) => switch (s) {
        'received' => 'Imepokewa',
        'approved' => 'Imeidhinishwa',
        'rejected' => 'Imekataliwa',
        _ => 'Inasubiri',
      };

  @override
  Widget build(BuildContext context) {
    final canRequest = context.watch<AppProvider>().user?.canRequestStock ?? false;
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
                _chip('Inasubiri', 'pending'),
                _chip('Zilizoidhinishwa', 'approved'),
                _chip('Zilizopokewa', 'received'),
                _chip('Zilizokataliwa', 'rejected'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _all.isEmpty
                    ? Center(child: Text('Hakuna maombi ya stock bado', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = _all[i];
                          final status = '${r['status'] ?? 'pending'}';
                          final qty = double.tryParse('${r['requested_qty']}') ?? 0;
                          return Material(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openDetail(r),
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
                                      Text('${r['product_name'] ?? ''}',
                                          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('Aliyeomba: ${r['requested_by_name'] ?? '—'}',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ]),
                                  ),
                                  Text(_fmt.format(qty), style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 15)),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: canRequest
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white),
              label: const Text('Omba Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
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

// ── Request form (cashier: chagua bidhaa + kiasi) ──────────────────────────
class _RequestFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final int? branchId;
  const _RequestFormSheet({required this.crm, required this.businessId, this.branchId});

  @override
  State<_RequestFormSheet> createState() => _RequestFormSheetState();
}

class _RequestFormSheetState extends State<_RequestFormSheet> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  List<Product> _searchResults = [];
  Product? _product;
  bool _searching = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
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

  void _pick(Product p) {
    setState(() {
      _product = p;
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  Future<void> _save() async {
    final p = _product;
    if (p == null) { _snack('Chagua bidhaa kwanza', AppColors.chartOrange); return; }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) { _snack('Weka kiasi sahihi', AppColors.chartOrange); return; }
    setState(() => _saving = true);
    try {
      final res = await widget.crm.createStockRequest(
        businessId: widget.businessId,
        branchId: widget.branchId,
        productId: p.productId,
        requestedQty: qty,
        note: _noteCtrl.text.trim(),
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
                Expanded(child: Text('Omba Stock', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
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
                      Expanded(child: Text('Ombi hili halibadilishi stock — admin akiidhinisha na wewe ukipokea ndipo stock inaongezeka.',
                          style: TextStyle(color: AppColors.chartBlue, fontSize: 11))),
                    ]),
                  ),
                  if (_product == null) ...[
                    TextField(
                      controller: _searchCtrl,
                      style: TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        hintText: 'Tafuta bidhaa...',
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
                        constraints: const BoxConstraints(maxHeight: 220),
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
                              subtitle: Text('Stock ya sasa: ${p.stock} ${p.unit}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                              onTap: () => _pick(p),
                            );
                          },
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_product!.name, style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('Stock ya sasa: ${_product!.stock} ${_product!.unit}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ]),
                        ),
                        TextButton(onPressed: () => setState(() => _product = null), child: const Text('Badilisha')),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textWhite),
                      decoration: InputDecoration(
                        labelText: 'Kiasi unachoomba',
                        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        filled: true, fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteCtrl,
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
                  onPressed: (_saving || _product == null) ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_saving ? 'Inatuma...' : 'Tuma Ombi', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request detail (approve/reject/receive) ────────────────────────────────
class _RequestDetailSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final Map<String, dynamic> request;
  final bool canApprove;
  final bool canReceive;
  const _RequestDetailSheet({
    required this.crm, required this.businessId, required this.request,
    required this.canApprove, required this.canReceive,
  });

  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  bool _busy = false;
  bool _changed = false;
  late final Map<String, dynamic> _req = widget.request;

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final r = await widget.crm.approveStockRequest(widget.businessId, _req['request_id'] as int);
      if (!mounted) return;
      if (r['success'] == true) {
        _changed = true;
        _snack('✅ Ombi limeidhinishwa', AppColors.accent);
        Navigator.pop(context, true);
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Kataa ombi?', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kataa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await widget.crm.rejectStockRequest(widget.businessId, _req['request_id'] as int);
      if (!mounted) return;
      if (r['success'] == true) {
        _changed = true;
        Navigator.pop(context, true);
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    final qtyCtrl = TextEditingController(text: '${_req['requested_qty'] ?? ''}');
    final priceCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pokea Stock', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(labelText: 'Kiasi kilichowasili', labelStyle: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(labelText: 'Bei ya ununuzi (kila kipande)', labelStyle: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: expiryCtrl,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(labelText: 'Muda wa kuisha (hiari, YYYY-MM-DD)', labelStyle: TextStyle(color: AppColors.textMuted)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pokea')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    if (qty <= 0) { _snack('Weka kiasi sahihi', AppColors.chartOrange); return; }
    setState(() => _busy = true);
    try {
      final r = await widget.crm.receiveStockRequest(
        businessId: widget.businessId,
        requestId: _req['request_id'] as int,
        receivedQty: qty,
        receivedBuyPrice: price,
        receivedExpiryDate: expiryCtrl.text.trim().isEmpty ? null : expiryCtrl.text.trim(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        _changed = true;
        _snack('✅ Stock imepokewa na kuongezwa', AppColors.accent);
        Navigator.pop(context, true);
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
    final status = '${_req['status'] ?? 'pending'}';
    final qty = double.tryParse('${_req['requested_qty']}') ?? 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.pop(context, _changed); },
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
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
                    child: Text('${_req['product_name'] ?? ''}',
                        style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context, _changed), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
                ]),
              ),
              Divider(color: AppColors.border, height: 1),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  children: [
                    _row('Kiasi kilichoombwa', _fmt.format(qty)),
                    _row('Aliyeomba', '${_req['requested_by_name'] ?? '—'}'),
                    if ((_req['note'] ?? '').toString().isNotEmpty) _row('Maelezo', '${_req['note']}'),
                    if (status != 'pending') _row('Aliyeamua', '${_req['approved_by_name'] ?? '—'}'),
                    if (status == 'received') ...[
                      _row('Kiasi kilichopokewa', _fmt.format(double.tryParse('${_req['received_qty']}') ?? 0)),
                      _row('Bei ya ununuzi', 'TZS ${_fmt.format(double.tryParse('${_req['received_buy_price']}') ?? 0)}'),
                    ],
                    const SizedBox(height: 8),
                    if (status == 'pending')
                      Text(widget.canApprove
                          ? 'Ombi bado linasubiri idhini yako.'
                          : 'Ombi bado linasubiri idhini ya meneja/admin.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    if (status == 'approved')
                      Text('✅ Limeidhinishwa — linasubiri kupokewa stock ikiwasili.',
                          style: TextStyle(color: AppColors.accent, fontSize: 12)),
                    if (status == 'received')
                      Text('✅ Imekamilika — stock imeshaongezwa.',
                          style: TextStyle(color: AppColors.accent, fontSize: 12)),
                    if (status == 'rejected')
                      Text('Ombi hili lilikataliwa.', style: TextStyle(color: AppColors.chartRed, fontSize: 12)),
                  ],
                ),
              ),
              if (status == 'pending' && widget.canApprove)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _reject,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Kataa'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _approve,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Idhinisha', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              if (status == 'approved' && widget.canReceive)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _receive,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                      icon: const Icon(Icons.move_to_inbox_rounded),
                      label: const Text('Pokea Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );
}
