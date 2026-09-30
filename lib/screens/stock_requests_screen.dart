import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';

/// Maombi ya Stock — mnyororo kamili: Ombi → Idhini → Ununuzi → Kupokea → Stock.
/// Muundo (header/theme/bottom-nav) ni ule ule wa Simamia/Wateja/Ripoti —
/// hii ni "tab" ya dashibodi (_nav), si ukurasa uliopigwa (push) tofauti.
class StockRequestsScreen extends StatefulWidget {
  final bool desktop;
  /// Ukifunguliwa kupitia arifa (notification tap) — inafungua maelezo ya
  /// ombi hili moja kwa moja baada ya orodha kupakiwa.
  final int? initialRequestId;
  const StockRequestsScreen({super.key, this.desktop = false, this.initialRequestId});

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

  int? _pendingFocusId;

  @override
  void initState() {
    super.initState();
    _pendingFocusId = widget.initialRequestId;
    _load();
  }

  @override
  void didUpdateWidget(covariant StockRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRequestId != null && widget.initialRequestId != oldWidget.initialRequestId) {
      _pendingFocusId = widget.initialRequestId;
      _load();
    }
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
      final focusId = _pendingFocusId;
      if (focusId != null) {
        _pendingFocusId = null;
        final match = raw.firstWhere((r) => r['request_id'] == focusId, orElse: () => {});
        if (match.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _openDetail(match); });
        }
      }
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
        crm: crm, businessId: bizId, requestId: req['request_id'] as int,
        currentUserId: app.user?.userId ?? 0,
        canApprove: app.user?.canApproveStock ?? false,
        canPurchase: app.user?.canConfirmPurchase ?? false,
        canReceive: app.user?.canReceiveStock ?? false,
      ),
    );
    if (changed == true) _load();
  }

  Color _statusColor(String s) => switch (s) {
        'received' => AppColors.accent,
        'partially_received' => AppColors.chartBlue,
        'purchased' => AppColors.chartPurple,
        'approved' => AppColors.chartBlue,
        'partially_approved' => AppColors.chartOrange,
        'rejected' => AppColors.chartRed,
        'cancelled' => AppColors.textMuted,
        _ => Colors.orangeAccent,
      };

  String _statusLabel(String s) => switch (s) {
        'received' => 'Imepokewa',
        'partially_received' => 'Imepokewa Kiasi',
        'purchased' => 'Imenunuliwa',
        'approved' => 'Imeidhinishwa',
        'partially_approved' => 'Imeidhinishwa Kiasi',
        'rejected' => 'Imekataliwa',
        'cancelled' => 'Imefutwa',
        _ => 'Inasubiri',
      };

  Widget _buildBody(bool canRequest) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            children: [
              _chip('Zote', ''),
              _chip('Inasubiri', 'pending'),
              _chip('Imeidhinishwa', 'approved'),
              _chip('Imenunuliwa', 'purchased'),
              _chip('Imepokewa', 'received'),
              _chip('Imekataliwa', 'rejected'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _all.isEmpty
                  ? Center(child: Text('Hakuna maombi ya stock bado', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, widget.desktop ? 24 : 90),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRequest = context.watch<AppProvider>().user?.canRequestStock ?? false;

    if (widget.desktop) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Row(children: [
                Text('Maombi ya Stock', style: TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (canRequest)
                  ElevatedButton.icon(
                    onPressed: _openForm,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                    label: const Text('Omba Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
            Expanded(child: _buildBody(canRequest)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: AppColors.gradHeader, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (Navigator.of(context).canPop())
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Text('Maombi ya Stock',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
                      ),
                      const _StockReqThemeButton(),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Text('Omba, idhinisha, nunua na pokea stock',
                          style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(canRequest)),
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

// ── Compact theme toggle — sawa na _CompactThemeButton ya manage_screen.dart ──
class _StockReqThemeButton extends StatelessWidget {
  const _StockReqThemeButton();

  static const _order = ['auto', 'dark', 'light'];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;
    final icon = switch (theme.preference) {
      'dark' => Icons.dark_mode_rounded,
      'light' => Icons.light_mode_rounded,
      _ => isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
    };
    return IconButton(
      onPressed: () {
        final tp = context.read<ThemeProvider>();
        tp.setPreference(_order[(_order.indexOf(tp.preference) + 1) % _order.length]);
      },
      icon: Icon(icon, color: Colors.white, size: 20),
      tooltip: 'Mandhari',
    );
  }
}

// ── Request form (chagua bidhaa + kiasi) ───────────────────────────────────
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
                      Expanded(child: Text('Ombi hili halibadilishi stock — linahitaji idhini, ununuzi, kisha upokeaji ndipo stock inaongezeka.',
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

// ── Request detail: timeline + hatua zinazofuata (idhini/ununuzi/upokeaji) ──
class _RequestDetailSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final int requestId;
  final int currentUserId;
  final bool canApprove;
  final bool canPurchase;
  final bool canReceive;
  const _RequestDetailSheet({
    required this.crm, required this.businessId, required this.requestId, required this.currentUserId,
    required this.canApprove, required this.canPurchase, required this.canReceive,
  });

  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  Map<String, dynamic>? _req;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.crm.getStockRequest(widget.businessId, widget.requestId);
      if (mounted) setState(() { _req = r; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _snack('$e', AppColors.chartRed); }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

  Future<void> _approveReject(bool approve) async {
    final req = _req;
    if (req == null) return;
    if (!approve) {
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
      if (ok != true) return;
      setState(() => _busy = true);
      try {
        final r = await widget.crm.rejectStockRequest(widget.businessId, widget.requestId);
        if (!mounted) return;
        if (r['success'] == true) { _changed = true; await _load(); } else { _snack('${r['message']}', AppColors.chartRed); }
      } catch (e) {
        if (mounted) _snack('$e', AppColors.chartRed);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final qtyCtrl = TextEditingController(text: _fmt.format(_d(req['requested_qty'])));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Idhinisha Ombi', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            labelText: 'Kiasi cha kuidhinisha (kilichoombwa: ${_fmt.format(_d(req['requested_qty']))})',
            labelStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Idhinisha')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final approvedQty = double.tryParse(qtyCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (approvedQty <= 0) { _snack('Weka kiasi sahihi', AppColors.chartOrange); return; }
    setState(() => _busy = true);
    try {
      final r = await widget.crm.approveStockRequest(widget.businessId, widget.requestId, approvedQty: approvedQty);
      if (!mounted) return;
      if (r['success'] == true) { _changed = true; await _load(); } else { _snack('${r['message']}', AppColors.chartRed); }
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
        title: Text('Futa ombi hili?', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hapana', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Futa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await widget.crm.cancelStockRequest(widget.businessId, widget.requestId);
      if (!mounted) return;
      if (r['success'] == true) { _changed = true; Navigator.pop(context, true); } else { _snack('${r['message']}', AppColors.chartRed); }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPurchase() async {
    final req = _req;
    if (req == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseFormSheet(crm: widget.crm, businessId: widget.businessId, request: req),
    );
    if (changed == true) { _changed = true; _load(); }
  }

  Future<void> _openReceive() async {
    final req = _req;
    if (req == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiveFormSheet(crm: widget.crm, businessId: widget.businessId, request: req),
    );
    if (changed == true) { _changed = true; _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.pop(context, _changed); },
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: _loading || _req == null
              ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              : _buildContent(mq),
        ),
      ),
    );
  }

  Widget _buildContent(MediaQueryData mq) {
    final req = _req!;
    final status = '${req['status'] ?? 'pending'}';
    final canModify = status == 'pending' || status == 'approved' || status == 'partially_approved';
    final isOwner = (req['requested_by'] as int?) == widget.currentUserId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
          child: Row(children: [
            Expanded(child: Text('${req['product_name'] ?? ''}',
                style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(context, _changed), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
          ]),
        ),
        Divider(color: AppColors.border, height: 1),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            children: [
              _timeline(req),
              const SizedBox(height: 16),
              if ((req['note'] ?? '').toString().isNotEmpty)
                _row('Maelezo ya ombi', '${req['note']}'),
              if (canModify && (isOwner || widget.canApprove))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _cancel,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                    label: const Text('Futa Ombi', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
            ],
          ),
        ),
        if (status == 'pending' && widget.canApprove)
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _approveReject(false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Kataa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _approveReject(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Idhinisha', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        if ((status == 'approved' || status == 'partially_approved') && widget.canPurchase)
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _openPurchase,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartPurple, foregroundColor: Colors.white),
                icon: const Icon(Icons.shopping_cart_checkout_rounded),
                label: const Text('Rekodi Ununuzi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        if ((status == 'purchased' || status == 'partially_received') && widget.canReceive)
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _openReceive,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                icon: const Icon(Icons.move_to_inbox_rounded),
                label: const Text('Pokea Stock', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _timeline(Map<String, dynamic> req) {
    final status = '${req['status'] ?? 'pending'}';
    final requestedQty = _d(req['requested_qty']);
    final approvedQty = req['approved_qty'] != null ? _d(req['approved_qty']) : null;
    final purchasedQty = req['purchased_qty'] != null ? _d(req['purchased_qty']) : null;
    final receivedQty = req['received_qty'] != null ? _d(req['received_qty']) : null;
    final batches = (req['batches'] as List? ?? []).cast<Map>();
    final rejected = status == 'rejected';
    final cancelled = status == 'cancelled';

    Widget step({required bool done, required bool active, required IconData icon, required String title, String? subtitle, bool isLast = false}) {
      final color = done ? AppColors.accent : (active ? AppColors.chartOrange : AppColors.textMuted);
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: done ? AppColors.accent.withAlpha(30) : AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(done ? Icons.check_rounded : icon, size: 15, color: color),
            ),
            if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: done || active ? AppColors.textWhite : AppColors.textMuted, fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                ],
              ]),
            ),
          ),
        ]),
      );
    }

    if (rejected) {
      return Column(children: [
        step(done: true, active: false, icon: Icons.send_rounded, title: 'Imeombwa na ${req['requested_by_name'] ?? '—'}',
            subtitle: '${req['requested_at'] ?? ''} · $requestedQty'),
        step(done: true, active: false, icon: Icons.cancel_rounded, title: 'Imekataliwa na ${req['approved_by_name'] ?? '—'}',
            subtitle: (req['approve_note'] ?? '').toString().isNotEmpty ? '${req['approve_note']}' : null, isLast: true),
      ]);
    }
    if (cancelled) {
      return Column(children: [
        step(done: true, active: false, icon: Icons.send_rounded, title: 'Imeombwa na ${req['requested_by_name'] ?? '—'}',
            subtitle: '${req['requested_at'] ?? ''} · $requestedQty'),
        step(done: true, active: false, icon: Icons.block_rounded, title: 'Ombi Limefutwa', isLast: true),
      ]);
    }

    final approvedDone = approvedQty != null;
    final purchasedDone = purchasedQty != null;
    final receivedDone = receivedQty != null && receivedQty > 0;
    final fullyReceived = status == 'received';

    return Column(children: [
      step(done: true, active: status == 'pending', icon: Icons.send_rounded,
          title: 'Imeombwa na ${req['requested_by_name'] ?? '—'}',
          subtitle: '${req['requested_at'] ?? ''} · Kiasi: ${_fmt.format(requestedQty)}'),
      step(done: approvedDone, active: !approvedDone, icon: Icons.fact_check_rounded,
          title: approvedDone ? 'Imeidhinishwa na ${req['approved_by_name'] ?? '—'}' : 'Inasubiri idhini',
          subtitle: approvedDone ? '${req['approved_at'] ?? ''} · Imeidhinishwa: ${_fmt.format(approvedQty)} / ${_fmt.format(requestedQty)}' : null),
      step(done: purchasedDone, active: approvedDone && !purchasedDone, icon: Icons.shopping_cart_rounded,
          title: purchasedDone ? 'Imenunuliwa na ${req['purchased_by_name'] ?? '—'}' : 'Inasubiri ununuzi',
          subtitle: purchasedDone
              ? '${req['purchased_at'] ?? ''} · ${_fmt.format(purchasedQty)} @ TZS ${_fmt.format(_d(req['purchase_unit_cost']))}'
                '${(req['supplier_name'] ?? '').toString().isNotEmpty ? ' · ${req['supplier_name']}' : ''}'
              : null),
      step(done: receivedDone, active: purchasedDone && !receivedDone, icon: Icons.move_to_inbox_rounded,
          title: receivedDone ? 'Imepokewa na ${req['received_by_name'] ?? '—'}' : 'Inasubiri kupokewa',
          subtitle: receivedDone
              ? '${_fmt.format(receivedQty)} / ${_fmt.format(purchasedQty ?? 0)} · batches ${batches.length}'
              : null),
      step(done: fullyReceived, active: false, icon: Icons.inventory_2_rounded,
          title: fullyReceived ? 'Imeongezwa Kwenye Stock' : 'Kuongezwa Kwenye Stock', isLast: true),
    ]);
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );
}

// ── Hatua ya "Ununuzi": msambazaji + bei + kumbukumbu ──────────────────────
class _PurchaseFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final Map<String, dynamic> request;
  const _PurchaseFormSheet({required this.crm, required this.businessId, required this.request});

  @override
  State<_PurchaseFormSheet> createState() => _PurchaseFormSheetState();
}

class _PurchaseFormSheetState extends State<_PurchaseFormSheet> {
  late final _qtyCtrl = TextEditingController(
    text: (widget.request['approved_qty'] ?? widget.request['requested_qty'] ?? '').toString());
  final _costCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<Map<String, dynamic>> _suppliers = [];
  int? _supplierId;
  bool _saving = false;
  bool _loadingSuppliers = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final raw = await widget.crm.listSuppliers(widget.businessId);
      if (mounted) setState(() { _suppliers = raw; _loadingSuppliers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;
    if (qty <= 0) { _snack('Weka kiasi kilichonunuliwa', AppColors.chartOrange); return; }
    setState(() => _saving = true);
    try {
      final r = await widget.crm.purchaseStockRequest(
        businessId: widget.businessId,
        requestId: widget.request['request_id'] as int,
        purchasedQty: qty,
        purchaseUnitCost: cost,
        supplierId: _supplierId,
        purchaseRef: _refCtrl.text.trim(),
        purchaseNote: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: true, fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      );

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
                Expanded(child: Text('Rekodi Ununuzi', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
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
                    decoration: BoxDecoration(color: AppColors.chartPurple.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.chartPurple),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Hii ni idhini ya ununuzi tu — stock bado haiongezeki mpaka ipokewe.',
                          style: TextStyle(color: AppColors.chartPurple, fontSize: 11))),
                    ]),
                  ),
                  if (!_loadingSuppliers && _suppliers.isNotEmpty) ...[
                    DropdownButtonFormField<int?>(
                      initialValue: _supplierId,
                      decoration: _dec('Msambazaji (hiari)'),
                      dropdownColor: AppColors.bgCard,
                      style: TextStyle(color: AppColors.textWhite, fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Hakuna —')),
                        for (final s in _suppliers)
                          DropdownMenuItem(value: s['supplier_id'] as int, child: Text('${s['name']}')),
                      ],
                      onChanged: (v) => setState(() => _supplierId = v),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(controller: _qtyCtrl, keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textWhite), decoration: _dec('Kiasi kilichonunuliwa')),
                  const SizedBox(height: 14),
                  TextField(controller: _costCtrl, keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textWhite), decoration: _dec('Bei ya ununuzi (kila kipande)')),
                  const SizedBox(height: 14),
                  TextField(controller: _refCtrl,
                      style: TextStyle(color: AppColors.textWhite), decoration: _dec('Namba ya risiti/ankara (hiari)')),
                  const SizedBox(height: 14),
                  TextField(controller: _noteCtrl,
                      style: TextStyle(color: AppColors.textWhite), decoration: _dec('Maelezo (hiari)')),
                ]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartPurple, foregroundColor: Colors.white),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.shopping_cart_checkout_rounded),
                  label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi Ununuzi', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hatua ya "Kupokea": batches nyingi, kila moja na lot/expiry yake ────────
class _ReceiveBatchRow {
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final expiryCtrl = TextEditingController();
  final lotCtrl = TextEditingController();
  void dispose() { qtyCtrl.dispose(); priceCtrl.dispose(); expiryCtrl.dispose(); lotCtrl.dispose(); }
}

class _ReceiveFormSheet extends StatefulWidget {
  final CrmApi crm;
  final int businessId;
  final Map<String, dynamic> request;
  const _ReceiveFormSheet({required this.crm, required this.businessId, required this.request});

  @override
  State<_ReceiveFormSheet> createState() => _ReceiveFormSheetState();
}

class _ReceiveFormSheetState extends State<_ReceiveFormSheet> {
  final List<_ReceiveBatchRow> _rows = [_ReceiveBatchRow()];
  bool _saving = false;

  double get _purchasedQty {
    final v = widget.request['purchased_qty'];
    return v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  }

  double get _alreadyReceived {
    final v = widget.request['received_qty'];
    return v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  }

  double get _remaining => _purchasedQty - _alreadyReceived;

  double get _batchTotal => _rows.fold(0.0, (s, r) => s + (double.tryParse(r.qtyCtrl.text.trim()) ?? 0));

  @override
  void dispose() {
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    final batches = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final q = double.tryParse(r.qtyCtrl.text.trim()) ?? 0;
      if (q <= 0) continue;
      batches.add({
        'quantity': q,
        'buy_price': double.tryParse(r.priceCtrl.text.trim()) ?? 0,
        'expiry_date': r.expiryCtrl.text.trim().isEmpty ? null : r.expiryCtrl.text.trim(),
        'batch_number': r.lotCtrl.text.trim(),
      });
    }
    if (batches.isEmpty) { _snack('Weka kiasi kwa angalau batch moja', AppColors.chartOrange); return; }
    if (_batchTotal > _remaining + 0.0001) {
      _snack('Jumla (${_batchTotal.toStringAsFixed(0)}) inazidi kiasi kilichobaki (${_remaining.toStringAsFixed(0)})', AppColors.chartOrange);
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await widget.crm.receiveStockRequest(
        businessId: widget.businessId,
        requestId: widget.request['request_id'] as int,
        batches: batches,
      );
      if (!mounted) return;
      if (r['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
        isDense: true,
        filled: true, fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                child: Row(children: [
                  Expanded(child: Text('Pokea Stock', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
                ]),
              ),
              Divider(color: AppColors.border, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.accent.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Kimenunuliwa: ${_purchasedQty.toStringAsFixed(0)}', style: TextStyle(color: AppColors.textWhite, fontSize: 12)),
                    Text('Kimebaki: ${_remaining.toStringAsFixed(0)}', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      Row(children: [
                        Text('Batch ${i + 1}', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (_rows.length > 1)
                          InkWell(
                            onTap: () => setSheetState(() { _rows[i].dispose(); _rows.removeAt(i); }),
                            child: Icon(Icons.close_rounded, size: 16, color: AppColors.chartRed),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _rows[i].qtyCtrl, keyboardType: TextInputType.number,
                            style: TextStyle(color: AppColors.textWhite, fontSize: 13), decoration: _dec('Kiasi'),
                            onChanged: (_) => setSheetState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _rows[i].priceCtrl, keyboardType: TextInputType.number,
                            style: TextStyle(color: AppColors.textWhite, fontSize: 13), decoration: _dec('Bei/kipande'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _rows[i].lotCtrl,
                            style: TextStyle(color: AppColors.textWhite, fontSize: 13), decoration: _dec('Lot/Batch No (hiari)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _rows[i].expiryCtrl,
                            style: TextStyle(color: AppColors.textWhite, fontSize: 13), decoration: _dec('Muda kuisha (hiari)'))),
                      ]),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setSheetState(() => _rows.add(_ReceiveBatchRow())),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Ongeza Batch Nyingine'),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + mq.padding.bottom),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                    icon: _saving
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark))
                        : const Icon(Icons.move_to_inbox_rounded),
                    label: Text(_saving ? 'Inahifadhi...' : 'Pokea (Jumla: ${_batchTotal.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
