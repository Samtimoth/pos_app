import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/sale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Detail Bottom Sheet — items + payment history + actions
// ─────────────────────────────────────────────────────────────────────────────
class TransactionDetailSheet extends StatefulWidget {
  final Sale sale;
  final VoidCallback onActionDone;

  const TransactionDetailSheet({
    super.key,
    required this.sale,
    required this.onActionDone,
  });

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _items = [];
  List<SalePayment> _payments = [];
  bool _loadingItems = true;
  bool _loadingPayments = true;
  bool _processing = false;
  Sale _sale = const Sale(
    saleId: 0,
    saleNo: '',
    customerName: '',
    customerPhone: '',
    subtotalAmount: 0,
    discountAmount: 0,
    totalAmount: 0,
    paidAmount: 0,
    balanceAmount: 0,
    saleType: '',
    paymentStatus: '',
    paymentMethod: '',
    notes: '',
    createdAt: '',
    itemCount: 0,
  );

  final _fmt = NumberFormat('#,###', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');
  final _shortDate = DateFormat('dd MMM, HH:mm');

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _sale = widget.sale;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _loadAll();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final app = context.read<AppProvider>();
    if (app.api == null) {
      if (mounted) {
        setState(() {
          _loadingItems = false;
          _loadingPayments = false;
        });
      }
      return;
    }
    // Load items + payments in parallel
    await Future.wait([_loadItems(app), _loadPayments(app)]);
    if (mounted) _animCtrl.forward(from: 0);
  }

  Future<void> _loadItems(AppProvider app) async {
    try {
      final res = await app.api!.getSaleDetail(widget.sale.saleId);
      if (mounted && res['success'] == true) {
        setState(() {
          _items = (res['items'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingItems = false);
  }

  Future<void> _loadPayments(AppProvider app) async {
    try {
      final raw = await app.api!.getSalePayments(widget.sale.saleId);
      if (mounted) {
        setState(() {
          _payments = raw
              .map((e) => SalePayment.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPayments = false);
  }

  Future<void> _printReceipt() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    final businessName = (biz?.receiptHeader.isNotEmpty ?? false)
        ? biz!.receiptHeader
        : (biz?.businessName ?? 'Duka Kiganjani');
    final footer = (biz?.receiptFooter.isNotEmpty ?? false)
        ? biz!.receiptFooter
        : 'Asante kwa kununua kwetu!';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                businessName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Official Sales Receipt',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 8),
            _pdfRow(
              'Receipt No',
              _sale.saleNo.isNotEmpty ? _sale.saleNo : '#${_sale.saleId}',
            ),
            _pdfRow(
              'Date',
              _dateFmt.format(
                DateTime.tryParse(_sale.createdAt) ?? DateTime.now(),
              ),
            ),
            _pdfRow(
              'Customer',
              _sale.customerName.isNotEmpty
                  ? _sale.customerName
                  : 'Walk-in Customer',
            ),
            if (_sale.customerPhone.isNotEmpty)
              _pdfRow('Phone', _sale.customerPhone),
            _pdfRow('Payment Type', _typeLabel(_sale.saleType, L.of(context))),
            pw.Divider(),
            ..._items.map((i) {
              final qty = (i['quantity'] as num? ?? 0).toDouble();
              final price = (i['unit_price'] as num? ?? 0).toDouble();
              final total = (i['line_total'] as num? ?? 0).toDouble();
              final name = i['product_name'] as String? ?? '—';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '$name\n${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1)} x TZS ${_fmt.format(price)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Text(
                      'TZS ${_fmt.format(total)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
            pw.Divider(),
            _pdfMoney('Total', _sale.totalAmount, bold: true),
            _pdfMoney('Paid', _sale.paidAmount),
            if (_sale.balanceAmount > 0)
              _pdfMoney('Outstanding Balance', _sale.balanceAmount, bold: true),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                footer,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  pw.Widget _pdfRow(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      children: [
        pw.Text(
          '$k: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        ),
        pw.Expanded(
          child: pw.Text(
            v,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );

  pw.Widget _pdfMoney(String k, double v, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          k,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 10,
          ),
        ),
        pw.Text(
          'TZS ${_fmt.format(v)}',
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _doAction(String action, {double? amount}) async {
    final app = context.read<AppProvider>();
    if (app.api == null) return;
    setState(() => _processing = true);
    try {
      final res = await app.api!.saleAction(
        _sale.saleId,
        action,
        amount: amount,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _snack(res['message'] as String? ?? '✅ Imefanikiwa', AppColors.accent);
        Navigator.pop(context);
        widget.onActionDone();
      } else {
        _snack(
          res['message'] as String? ?? L.of(context).error,
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showRecordPaymentDialog() async {
    final l = L.of(context);
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.recordPayment,
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${l.customer}: ${_sale.customerName.isNotEmpty ? _sale.customerName : "—"}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.chartRed.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.chartRed.withAlpha(70)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.balanceLabel,
                    style: TextStyle(color: AppColors.chartRed, fontSize: 13),
                  ),
                  Text(
                    'TZS ${_fmt.format(_sale.balanceAmount)}',
                    style: TextStyle(
                      color: AppColors.chartRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            TextField(
              controller: amtCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: l.enterPayAmt,
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.money_rounded, color: AppColors.accent),
                labelText: 'Kiasi (TZS)',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                ),
                filled: true,
                fillColor: AppColors.bg,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              style: TextStyle(color: AppColors.textWhite, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: l.isSw
                    ? 'Maelezo ya malipo (optional)'
                    : 'Payment note (optional)',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                prefixIcon: Icon(
                  Icons.note_alt_outlined,
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                filled: true,
                fillColor: AppColors.bg,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: Icon(Icons.check_rounded, color: AppColors.bgDark, size: 18),
            label: Text(
              l.save,
              style: TextStyle(
                color: AppColors.bgDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    // Read values BEFORE disposing controllers
    final amtText = amtCtrl.text;
    amtCtrl.dispose();
    noteCtrl.dispose();
    if (ok == true && mounted) {
      final amt = double.tryParse(amtText.replaceAll(',', ''));
      if (amt == null || amt <= 0) {
        _snack(l.enterPayAmt, Colors.orange);
        return;
      }
      await _doAction('record_payment', amount: amt);
    }
  }

  Future<void> _showVoidConfirm() async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l.voidSale,
              style: TextStyle(color: AppColors.textWhite, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          l.voidConfirmMsg,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.no, style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l.yes, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _doAction('void_sale');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final mq = MediaQuery.of(context);
    final sc = _statusColor(_sale);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Hero header ────────────────────────────────────────────────────
            _buildHeroHeader(l, sc),

            // ── Balance progress (if has debt) ─────────────────────────────────
            if (_sale.hasBalance && !_sale.isVoided) _buildBalanceBar(l),

            Divider(color: AppColors.border, height: 1),

            // ── Scrollable body ────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ListView(
                      controller: scroll,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        mq.padding.bottom + 20,
                      ),
                      children: [
                        // Info row
                        _infoCard(l),
                        const SizedBox(height: 14),

                        // Items
                        _sectionHeader(
                          l.saleItemsLabel,
                          Icons.inventory_2_rounded,
                        ),
                        const SizedBox(height: 8),
                        _itemsCard(l),
                        const SizedBox(height: 14),

                        // Amounts
                        _sectionHeader(l.summary, Icons.calculate_outlined),
                        const SizedBox(height: 8),
                        _amountsCard(l),
                        const SizedBox(height: 14),

                        // Payment history
                        if (!_sale.isVoided) ...[
                          _sectionHeader(
                            l.isSw ? 'Historia ya Malipo' : 'Payment History',
                            Icons.history_rounded,
                          ),
                          const SizedBox(height: 8),
                          _paymentHistoryCard(l),
                          const SizedBox(height: 14),
                        ],

                        // Actions
                        if (!_sale.isVoided) ...[
                          _sectionHeader('Vitendo', Icons.touch_app_rounded),
                          const SizedBox(height: 10),
                          _buildActionButtons(l),
                        ] else
                          _voidedBanner(l),

                        // Extra space so content isn't hidden behind FAB
                        if (_sale.hasBalance && !_sale.isVoided)
                          const SizedBox(height: 72),
                      ],
                    ),
                  ),

                  // Processing overlay
                  if (_processing)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Sticky "Weka Malipo" button ─────────────────────────────────────
            if (_sale.hasBalance && !_sale.isVoided)
              _buildStickyPayButton(l, mq),
          ],
        ),
      ),
    );
  }

  // ── Hero header ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(L l, Color sc) {
    final initials = _sale.customerName.isNotEmpty
        ? _sale.customerName
              .trim()
              .split(' ')
              .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
              .take(2)
              .join()
        : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [sc.withAlpha(180), sc.withAlpha(100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: sc.withAlpha(120), width: 1.5),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sale.customerName.isNotEmpty
                      ? _sale.customerName
                      : 'Mteja #${_sale.saleId}',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge(
                      _typeLabel(_sale.saleType, l),
                      _typeColor(_sale.saleType),
                      _typeIcon(_sale.saleType),
                    ),
                    _badge(
                      _statusLabel(_sale, l),
                      sc,
                      _sale.isPaid
                          ? Icons.check_circle_rounded
                          : _sale.isVoided
                          ? Icons.block_rounded
                          : Icons.pending_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_sale.isVoided && !_loadingItems)
            IconButton(
              onPressed: _printReceipt,
              tooltip: l.isSw ? 'Chapisha Risiti' : 'Print Receipt',
              icon: Icon(Icons.print_rounded, color: AppColors.primaryLt),
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Balance progress bar ─────────────────────────────────────────────────────
  Widget _buildBalanceBar(L l) {
    final paid = _sale.paidAmount;
    final total = _sale.totalAmount;
    final pct = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final unpaid = _sale.balanceAmount;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pct),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, _) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.chartRed.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.chartRed.withAlpha(60)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.isSw ? 'Salio linalobaki' : 'Outstanding balance',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'TZS ${_fmt.format(unpaid)}',
                      style: TextStyle(
                        color: AppColors.chartRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l.isSw ? 'Kimelipwa' : 'Paid so far',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'TZS ${_fmt.format(paid)}',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (ctx, box) => Stack(
                children: [
                  Container(
                    height: 8,
                    width: box.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: box.maxWidth * v,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradLime,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(0)}% ${l.isSw ? "imelipwa" : "paid"}',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${((1 - pct) * 100).toStringAsFixed(0)}% ${l.isSw ? "imesalia" : "remaining"}',
                  style: TextStyle(color: AppColors.chartRed, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Info card ────────────────────────────────────────────────────────────────
  Widget _infoCard(L l) {
    DateTime? dt;
    try {
      dt = DateTime.parse(_sale.createdAt);
    } catch (_) {}
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.receipt_long_rounded,
            l.isSw ? 'Namba' : 'Receipt No',
            _sale.saleNo.isNotEmpty ? _sale.saleNo : '#${_sale.saleId}',
          ),
          if (dt != null) ...[
            Divider(color: AppColors.border.withAlpha(80), height: 14),
            _infoRow(
              Icons.access_time_rounded,
              l.isSw ? 'Tarehe' : 'Date',
              _dateFmt.format(dt),
            ),
          ],
          if (_sale.customerPhone.isNotEmpty) ...[
            Divider(color: AppColors.border.withAlpha(80), height: 14),
            _infoRow(
              Icons.phone_rounded,
              l.isSw ? 'Simu' : 'Phone',
              _sale.customerPhone,
            ),
          ],
          if (_sale.notes.isNotEmpty) ...[
            Divider(color: AppColors.border.withAlpha(80), height: 14),
            _infoRow(
              Icons.notes_rounded,
              l.isSw ? 'Maelezo' : 'Notes',
              _sale.notes,
            ),
          ],
        ],
      ),
    );
  }

  // ── Items card ───────────────────────────────────────────────────────────────
  Widget _itemsCard(L l) {
    if (_loadingItems) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryLt,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(l.noItems, style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: _items.asMap().entries.map((e) {
          return _itemRow(e.value, e.key == _items.length - 1);
        }).toList(),
      ),
    );
  }

  // ── Payment history card ─────────────────────────────────────────────────────
  Widget _paymentHistoryCard(L l) {
    if (_loadingPayments) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      // If sale is already paid, don't show a confusing empty history
      if (_sale.isPaid) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withAlpha(60)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                l.isSw
                    ? 'Muamala huu umelipwa kikamilifu.'
                    : 'This transaction is fully paid.',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              l.isSw
                  ? 'Hakuna historia ya malipo bado.'
                  : 'No payment history yet.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: _payments.asMap().entries.map((e) {
          final pay = e.value;
          final isLast = e.key == _payments.length - 1;
          DateTime? dt;
          try {
            dt = DateTime.parse(pay.createdAt);
          } catch (_) {}
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Timeline dot + line
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withAlpha(80),
                              width: 2,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 28,
                            color: AppColors.border,
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TZS ${_fmt.format(pay.amount)}',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (pay.note.isNotEmpty)
                            Text(
                              pay.note,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      dt != null ? _shortDate.format(dt) : pay.createdAt,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(color: AppColors.border.withAlpha(60), height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Amounts card ─────────────────────────────────────────────────────────────
  Widget _amountsCard(L l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (_sale.discountAmount > 0) ...[
            _amtRow(
              l.isSw ? 'Jumla (kabla ya punguzo)' : 'Subtotal',
              _sale.subtotalAmount,
              AppColors.textMuted,
            ),
            _amtRow(
              l.isSw ? 'Punguzo' : 'Discount',
              -_sale.discountAmount,
              AppColors.chartOrange,
            ),
            Divider(color: AppColors.border, height: 16),
          ],
          _amtRow(l.total, _sale.totalAmount, AppColors.textWhite, large: true),
          const SizedBox(height: 6),
          _amtRow(l.amountPaidLabel, _sale.paidAmount, AppColors.accent),
          if (_sale.balanceAmount > 0)
            _amtRow(
              l.balanceLabel,
              _sale.balanceAmount,
              AppColors.chartRed,
              bold: true,
            ),
        ],
      ),
    );
  }

  // ── Sticky pay button ─────────────────────────────────────────────────────────
  Widget _buildStickyPayButton(L l, MediaQueryData mq) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, mq.padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _processing ? null : _showRecordPaymentDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          icon: _processing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.bgDark,
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.payments_rounded, color: AppColors.bgDark, size: 20),
          label: Text(
            l.isSw ? 'Weka Malipo Mapya' : 'Record New Payment',
            style: TextStyle(
              color: AppColors.bgDark,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────────
  Widget _buildActionButtons(L l) {
    final btns = <Widget>[];

    if (_sale.isCashNotCollected) {
      btns.add(
        _actionBtn(
          label: l.collectCash,
          icon: Icons.point_of_sale_rounded,
          color: AppColors.primaryLt,
          onTap: () => _doAction('collect_cash'),
        ),
      );
    }

    if (_sale.isBankTransfer && _sale.isPending) {
      btns.add(
        _actionBtn(
          label: l.confirmTransfer,
          icon: Icons.account_balance_rounded,
          color: AppColors.chartBlue,
          onTap: () => _doAction('confirm_bank_transfer'),
        ),
      );
    }

    btns.add(
      _actionBtn(
        label: l.voidSale,
        icon: Icons.delete_outline_rounded,
        color: Colors.redAccent,
        onTap: _showVoidConfirm,
      ),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: btns);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _itemRow(Map<String, dynamic> item, bool isLast) {
    final qty = (item['quantity'] as num? ?? 0).toDouble();
    final price = (item['unit_price'] as num? ?? 0).toDouble();
    final total = (item['line_total'] as num? ?? 0).toDouble();
    final unit = (item['unit'] as String?) ?? '';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.primaryLt,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['product_name'] as String? ?? '—',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'TZS ${_fmt.format(price)} × ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1)} $unit',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'TZS ${_fmt.format(total)}',
                style: TextStyle(
                  color: AppColors.primaryLt,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: AppColors.border.withAlpha(80), height: 1),
      ],
    );
  }

  Widget _amtRow(
    String label,
    double val,
    Color color, {
    bool large = false,
    bool bold = false,
  }) {
    final neg = val < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: large ? 15 : 13,
              fontWeight: bold || large ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            '${neg ? '-' : ''}TZS ${_fmt.format(val.abs())}',
            style: TextStyle(
              color: color,
              fontSize: large ? 16 : 13,
              fontWeight: bold || large ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 8),
      Text(
        '$label: ',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(color: AppColors.textWhite, fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _badge(String label, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    onPressed: _processing ? null : onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withAlpha(120)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: color.withAlpha(12),
    ),
    icon: Icon(icon, size: 18),
    label: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
  );

  Widget _voidedBanner(L l) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.chartGray.withAlpha(25),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.chartGray.withAlpha(80)),
    ),
    child: Row(
      children: [
        const Icon(Icons.block_rounded, color: AppColors.chartGray, size: 22),
        const SizedBox(width: 10),
        Text(
          l.saleVoided,
          style: const TextStyle(
            color: AppColors.chartGray,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ── Type / status helpers ─────────────────────────────────────────────────────
  Color _typeColor(String type) {
    switch (type) {
      case 'cash':
        return AppColors.accent;
      case 'loan':
        return AppColors.chartRed;
      case 'partial':
        return AppColors.chartOrange;
      case 'cash_not_collected':
        return AppColors.chartOrange;
      case 'bank_transfer':
        return AppColors.chartBlue;
      case 'voided':
        return AppColors.chartGray;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_rounded;
      case 'loan':
        return Icons.credit_card_rounded;
      case 'partial':
        return Icons.timelapse_rounded;
      case 'cash_not_collected':
        return Icons.pending_rounded;
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      case 'voided':
        return Icons.block_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _typeLabel(String type, L l) {
    switch (type) {
      case 'cash':
        return l.filterCash;
      case 'loan':
        return l.filterLoan;
      case 'partial':
        return l.filterPartial;
      case 'cash_not_collected':
        return l.cashNotCollected;
      case 'bank_transfer':
        return l.bankTransfer;
      case 'voided':
        return l.saleVoided;
      default:
        return type;
    }
  }

  Color _statusColor(Sale s) {
    if (s.isVoided) return AppColors.chartGray;
    if (s.isPaid) return AppColors.accent;
    if (s.isPending) return AppColors.chartOrange;
    if (s.isPartial) return AppColors.chartOrange;
    return AppColors.chartRed;
  }

  String _statusLabel(Sale s, L l) {
    if (s.isVoided) return l.saleVoided;
    if (s.isPaid) return l.salePaid;
    if (s.isPending) return l.salePending;
    if (s.isPartial) return l.salePartial;
    return l.saleUnpaid;
  }
}
