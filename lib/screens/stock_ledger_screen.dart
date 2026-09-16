import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';
import '../widgets/manager_pin_dialog.dart';

/// Every stock change in the business (written by DB triggers) — sales, void,
/// stock in, adjustments, edits. Filter by type; tap a row for details.
class StockLedgerScreen extends StatefulWidget {
  final bool desktop;
  const StockLedgerScreen({super.key, this.desktop = false});

  @override
  State<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends State<StockLedgerScreen> {
  final _fmt = NumberFormat('#,##0.#', 'en_US');
  List<StockMovement> _rows = [];
  bool _loading = true;
  String _type = 'all';
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    final url = app.user?.serverUrl;
    if (biz == null || url == null) return;
    setState(() => _loading = true);
    try {
      final raw = await CrmApi(url).recentMovements(biz.businessId, type: _type);
      if (mounted) setState(() => _rows = raw.map(StockMovement.fromJson).toList());
    } catch (e) {
      if (mounted) AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StockMovement> get _filtered {
    final s = _q.trim().toLowerCase();
    if (s.isEmpty) return _rows;
    return _rows.where((m) => m.productName.toLowerCase().contains(s) || m.saleNo.toLowerCase().contains(s)).toList();
  }

  static const _types = [
    ('all', 'Zote'), ('sale', 'Mauzo'), ('batch', 'Stock in'), ('adjustment', 'Marekebisho'),
    ('void', 'Zilizofutwa'), ('edit', 'Zilizohaririwa'), ('opening', 'Opening'),
  ];

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: AppColors.gradHeader, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 12),
              child: Row(children: [
                if (Navigator.of(context).canPop())
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))
                else
                  const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Historia ya Stock', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Kila badiliko la stock — nani, lini, kwa nini', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                  ]),
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SizedBox(
            height: 42,
            child: TextField(
              style: TextStyle(color: AppColors.textWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tafuta bidhaa au risiti',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                isDense: true, filled: true, fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            children: [
              for (final t in _types)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t.$2, style: TextStyle(color: _type == t.$1 ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: _type == t.$1 ? FontWeight.w700 : FontWeight.w500)),
                    selected: _type == t.$1, showCheckmark: false, selectedColor: AppColors.primary, backgroundColor: AppColors.bgCard,
                    side: BorderSide(color: _type == t.$1 ? AppColors.primary : AppColors.border),
                    visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) { setState(() => _type = t.$1); _load(); },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading && _rows.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : list.isEmpty
                  ? Center(child: Text('Hakuna rekodi', style: TextStyle(color: AppColors.textMuted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 30),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => MovementTile(m: list[i], fmt: _fmt, showProduct: true),
                      ),
                    ),
        ),
      ]),
    );
  }
}

/// One ledger line (shared by the ledger screen and the product stock card).
class MovementTile extends StatelessWidget {
  final StockMovement m;
  final NumberFormat fmt;
  final bool showProduct;
  const MovementTile({super.key, required this.m, required this.fmt, this.showProduct = false});

  @override
  Widget build(BuildContext context) {
    final color = switch (m.type) {
      'sale' => AppColors.primaryLt,
      'void' || 'return' || 'return_in' => AppColors.chartBlue,
      'batch' || 'opening' => AppColors.accent,
      'adjustment' => AppColors.chartOrange,
      'edit' => AppColors.chartPurple,
      _ => AppColors.textMuted,
    };
    final icon = switch (m.type) {
      'sale' => Icons.point_of_sale_rounded,
      'void' => Icons.undo_rounded,
      'batch' => Icons.add_box_rounded,
      'opening' => Icons.flag_rounded,
      'adjustment' => Icons.tune_rounded,
      'edit' => Icons.edit_rounded,
      _ => Icons.swap_vert_rounded,
    };
    final (kind, reason) = m.parsedReason;
    final kindLabel = StockAdjustType.all.where((t) => t.$1 == kind).map((t) => t.$2).firstOrNull;
    final sub = [
      if (m.saleNo.isNotEmpty) m.saleNo,
      ?kindLabel,
      if (reason.isNotEmpty && m.type != 'opening') reason,
      if (m.userName.isNotEmpty) m.userName,
      m.createdAt.length >= 16 ? m.createdAt.substring(0, 16) : m.createdAt,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(showProduct && m.productName.isNotEmpty ? m.productName : m.typeLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(showProduct ? '${m.typeLabel} · $sub' : sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${m.isIn ? '+' : ''}${fmt.format(m.qtyDelta)}',
              style: TextStyle(color: m.isIn ? AppColors.accent : AppColors.chartRed, fontWeight: FontWeight.w800, fontSize: 14,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          Text('= ${fmt.format(m.stockAfter)}', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stock card (per product) + adjust sheet
// ─────────────────────────────────────────────────────────────────────────────
class StockCardSheet extends StatefulWidget {
  final Product product;
  final VoidCallback? onChanged;
  const StockCardSheet({super.key, required this.product, this.onChanged});

  static Future<void> show(BuildContext context, Product p, {VoidCallback? onChanged}) =>
      showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => StockCardSheet(product: p, onChanged: onChanged),
      );

  @override
  State<StockCardSheet> createState() => _StockCardSheetState();
}

class _StockCardSheetState extends State<StockCardSheet> {
  final _fmt = NumberFormat('#,##0.#', 'en_US');
  List<StockMovement> _rows = [];
  bool _loading = true;
  late int _stock = widget.product.stock;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    final url = app.user?.serverUrl;
    if (biz == null || url == null) return;
    try {
      final raw = await CrmApi(url).stockCard(biz.businessId, widget.product.productId);
      if (mounted) setState(() => _rows = raw.map(StockMovement.fromJson).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adjust() async {
    final r = await StockAdjustSheet.show(context, widget.product, currentStock: _stock);
    if (r != null && mounted) {
      setState(() => _stock = (double.tryParse('${r['stock_after']}') ?? _stock.toDouble()).round());
      widget.onChanged?.call();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Stock sasa: $_stock ${widget.product.unit}  ·  historia ${_rows.length}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
            TextButton.icon(
              onPressed: _adjust,
              style: TextButton.styleFrom(backgroundColor: AppColors.chartOrange.withAlpha(30), foregroundColor: AppColors.chartOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Rekebisha', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
          ]),
        ),
        Divider(color: AppColors.border, height: 1),
        Flexible(
          child: _loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              : _rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        widget.product.productId < 0
                            ? 'Bidhaa hii bado haijasync — historia itaonekana baada ya sync.'
                            : 'Hakuna historia bado.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 16 + mq.padding.bottom),
                      itemCount: _rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => MovementTile(m: _rows[i], fmt: _fmt),
                    ),
        ),
      ]),
    );
  }
}

class StockAdjustSheet extends StatefulWidget {
  final Product product;
  final int currentStock;
  const StockAdjustSheet({super.key, required this.product, required this.currentStock});

  static Future<Map<String, dynamic>?> show(BuildContext context, Product p, {required int currentStock}) =>
      showModalBottomSheet<Map<String, dynamic>>(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => StockAdjustSheet(product: p, currentStock: currentStock),
      );

  @override
  State<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends State<StockAdjustSheet> {
  final _qty = TextEditingController();
  final _reason = TextEditingController();
  String _type = 'damaged';
  String _direction = 'minus';
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  double? get _preview {
    final q = double.tryParse(_qty.text.replaceAll(',', ''));
    if (q == null) return null;
    final cur = widget.currentStock.toDouble();
    return switch (_type) {
      'damaged' || 'lost' || 'expired' || 'return_supplier' => cur - q,
      'count' => q,
      'correction' => _direction == 'minus' ? cur - q : cur + q,
      _ => cur + q,
    };
  }

  Future<void> _save() async {
    final q = double.tryParse(_qty.text.replaceAll(',', ''));
    if (q == null || q < 0 || (q == 0 && _type != 'count')) {
      AppNotification.show(context, 'Weka kiasi sahihi', AppColors.chartOrange, icon: Icons.error_outline_rounded);
      return;
    }
    if (_reason.text.trim().isEmpty && ['damaged', 'lost', 'correction'].contains(_type)) {
      AppNotification.show(context, 'Andika sababu', AppColors.chartOrange, icon: Icons.error_outline_rounded);
      return;
    }
    final after = _preview ?? 0;
    if (after < 0) {
      AppNotification.show(context, 'Stock haiwezi kuwa chini ya 0', AppColors.chartRed, icon: Icons.error_rounded);
      return;
    }
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    final url = app.user?.serverUrl;
    if (biz == null || url == null) return;

    // ── Idhini ya meneja: write-offs za hasara zinahitaji PIN isipokuwa
    // mtumiaji mwenyewe ni meneja/mmiliki tayari (ona MANAGER_PIN_TIER server-side).
    final isWriteOff = _type == 'damaged' || _type == 'lost' ||
        (_type == 'correction' && _direction == 'minus');
    String? managerPin;
    if (isWriteOff && app.user?.isManagerTier != true) {
      final typeLabel = switch (_type) {
        'damaged' => 'imeharibika', 'lost' => 'imepotea', _ => 'marekebisho',
      };
      managerPin = await ManagerPinDialog.show(context,
          reasonLabel: 'Marekebisho ya hasara ($typeLabel) yanahitaji meneja aweke PIN yake.');
      if (managerPin == null) return; // cashier cancelled
    }

    setState(() => _saving = true);
    try {
      final r = await CrmApi(url).adjustStock(
        businessId: biz.businessId, productId: widget.product.productId,
        adjustType: _type, qty: q, reason: _reason.text.trim(), direction: _direction,
        managerPin: managerPin,
      );
      if (!mounted) return;
      if (r['success'] == true) {
        AppNotification.show(context, '${r['message']}', r['offline'] == true ? Colors.orange : AppColors.accent,
            icon: Icons.check_circle_rounded);
        Navigator.pop(context, r);
      } else {
        AppNotification.show(context, '${r['message'] ?? 'Hitilafu'}', AppColors.chartRed, icon: Icons.error_rounded);
      }
    } catch (e) {
      if (mounted) AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final preview = _preview;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.tune_rounded, color: AppColors.chartOrange),
                const SizedBox(width: 8),
                Expanded(child: Text('Rekebisha stock', style: TextStyle(color: AppColors.textWhite, fontSize: 17, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
              Text('${widget.product.name}  ·  sasa ${widget.currentStock} ${widget.product.unit}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              const SizedBox(height: 12),
              Text('SABABU', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in StockAdjustType.all)
                  ChoiceChip(
                    label: Text('${t.$3} ${t.$2}', style: TextStyle(color: _type == t.$1 ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: _type == t.$1 ? FontWeight.w700 : FontWeight.w500)),
                    selected: _type == t.$1, showCheckmark: false, selectedColor: AppColors.chartOrange, backgroundColor: AppColors.bgInput,
                    side: BorderSide(color: _type == t.$1 ? AppColors.chartOrange : AppColors.border),
                    visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => setState(() => _type = t.$1),
                  ),
              ]),
              if (_type == 'correction') ...[
                const SizedBox(height: 8),
                Row(children: [
                  for (final d in const [('plus', '+ Ongeza'), ('minus', '− Punguza')])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(d.$2, style: TextStyle(color: _direction == d.$1 ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                        selected: _direction == d.$1, showCheckmark: false, selectedColor: AppColors.primary, backgroundColor: AppColors.bgInput,
                        side: BorderSide(color: _direction == d.$1 ? AppColors.primary : AppColors.border),
                        visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (_) => setState(() => _direction = d.$1),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _qty, autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: _type == 'count' ? 'Stock iliyohesabiwa' : 'Kiasi',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      suffixText: widget.product.unit, suffixStyle: TextStyle(color: AppColors.textMuted),
                      filled: true, fillColor: AppColors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.chartOrange, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.bgInput, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    Text('Itakuwa', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    Text(preview == null ? '—' : NumberFormat('#,##0.#').format(preview),
                        style: TextStyle(color: (preview ?? 0) < 0 ? AppColors.chartRed : AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                style: TextStyle(color: AppColors.textWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Maelezo (mf. chupa 3 zilivunjika wakati wa kupanga)',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  isDense: true, filled: true, fillColor: AppColors.bgInput,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartOrange, foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                  label: const Text('Hifadhi marekebisho', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 6),
              Text('Kila marekebisho yanaandikwa kwenye historia ya stock na nani aliyefanya.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}
