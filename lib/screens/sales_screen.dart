import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';
import 'transaction_detail_sheet.dart';

class SalesScreen extends StatefulWidget {
  final bool desktop;
  final VoidCallback? onBack;
  const SalesScreen({super.key, this.desktop = false, this.onBack});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  List<Sale> _sales = [];
  bool _loading = true;
  String _filterType = 'all';
  DateTime? _filterDate;
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _loadSales();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    if (app.api == null || biz == null) return;
    setState(() => _loading = true);
    try {
      final raw = await app.api!.getSales(
        biz.businessId,
        branchId: app.selectedBranch?.branchId,
      );
      setState(() {
        _sales = raw
            .map((e) => Sale.fromJson(e as Map<String, dynamic>))
            .toList();
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
        ),
      );

  void _openDetail(Sale sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          TransactionDetailSheet(sale: sale, onActionDone: _loadSales),
    );
  }

  List<Sale> get _filtered {
    return _sales.where((s) {
      final matchType = _filterType == 'all' || s.saleType == _filterType;
      final matchSearch =
          _search.isEmpty ||
          s.customerName.toLowerCase().contains(_search.toLowerCase()) ||
          s.saleNo.toLowerCase().contains(_search.toLowerCase()) ||
          s.saleId.toString().contains(_search);
      final matchDate =
          _filterDate == null || _sameDay(s.createdAt, _filterDate!);
      return matchType && matchSearch && matchDate;
    }).toList();
  }

  bool _sameDay(String rawDate, DateTime target) {
    try {
      final dt = DateTime.parse(rawDate);
      return dt.year == target.year &&
          dt.month == target.month &&
          dt.day == target.day;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryLt,
            surface: AppColors.bgCard,
            onSurface: AppColors.textWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _filterDate = picked);
  }

  Color _statusColor(Sale s) {
    if (s.isVoided) return AppColors.chartGray;
    if (s.isPaid) return AppColors.accent;
    if (s.isPending) return AppColors.chartOrange;
    if (s.isPartial) return AppColors.chartOrange;
    if (s.isUnpaid) return AppColors.chartRed;
    return AppColors.chartGray;
  }

  String _statusLabel(Sale s, L l) {
    if (s.isVoided) return l.saleVoided;
    if (s.isPaid) return l.salePaid;
    if (s.isPending) return l.salePending;
    if (s.isPartial) return l.salePartial;
    if (s.isUnpaid) return l.saleUnpaid;
    return s.paymentStatus;
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

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  // ── Date grouping ──────────────────────────────────────────────────────────
  String _dateGroup(String rawDate, L l) {
    try {
      final dt = DateTime.parse(rawDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(d).inDays;
      if (diff == 0) return l.isSw ? 'Leo' : 'Today';
      if (diff == 1) return l.isSw ? 'Jana' : 'Yesterday';
      if (diff < 7) return l.isSw ? 'Wiki hii' : 'This week';
      if (diff < 30) return l.isSw ? 'Mwezi huu' : 'This month';
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) {
      return l.isSw ? 'Tarehe nyingine' : 'Other dates';
    }
  }

  /// Build a grouped list: [section_header, sale, sale, section_header, sale, ...]
  List<dynamic> _groupedItems(List<Sale> sales, L l) {
    final groups = <String, List<Sale>>{};
    final order = <String>[];
    for (final s in sales) {
      final g = _dateGroup(s.createdAt, l);
      if (!groups.containsKey(g)) {
        groups[g] = [];
        order.add(g);
      }
      groups[g]!.add(s);
    }
    final items = <dynamic>[];
    for (final g in order) {
      items.add(g); // section header (String)
      items.addAll(groups[g]!);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return widget.desktop ? _buildDesktop() : _buildMobile();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP: data table
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    final l = L.of(context);
    final filtered = _filtered;
    return Column(
      children: [
        _buildToolbar(desktop: true, l: l),
        _SalesHeroSummary(
          filtered: filtered,
          fmt: _fmt,
          compact: _compact,
          desktop: true,
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : filtered.isEmpty
              ? _emptyState(l)
              : _buildTable(filtered, l),
        ),
      ],
    );
  }

  Widget _buildTable(List<Sale> sales, L l) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          headingRowColor: WidgetStateProperty.all(AppColors.bg),
          headingTextStyle: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          dataTextStyle: TextStyle(color: AppColors.textWhite, fontSize: 13),
          columns: [
            const DataColumn(label: Text('#')),
            DataColumn(label: Text(l.customer.toUpperCase().split(' ').first)),
            DataColumn(label: Text(l.payType.toUpperCase().split(' ').first)),
            DataColumn(label: Text(l.totalLabel.toUpperCase()), numeric: true),
            const DataColumn(label: Text('STATUS')),
            DataColumn(label: Text(l.debt.toUpperCase()), numeric: true),
            const DataColumn(label: Text('DATE')),
          ],
          rows: sales.map((s) {
            DateTime? dt;
            try {
              dt = DateTime.parse(s.createdAt);
            } catch (_) {}
            final color = _statusColor(s);
            return DataRow(
              onSelectChanged: (_) => _openDetail(s),
              cells: [
                DataCell(
                  Text(
                    '#${s.saleId}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s.customerName.isNotEmpty ? s.customerName : '—',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (s.saleNo.isNotEmpty)
                        Text(
                          s.saleNo,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                DataCell(_typeBadge(s.saleType, l)),
                DataCell(
                  Text(
                    'TZS ${_fmt.format(s.totalAmount)}',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(_statusBadge(color, _statusLabel(s, l))),
                DataCell(
                  s.balanceAmount > 0
                      ? Text(
                          'TZS ${_fmt.format(s.balanceAmount)}',
                          style: const TextStyle(
                            color: AppColors.chartRed,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text('—', style: TextStyle(color: AppColors.textMuted)),
                ),
                DataCell(
                  Text(
                    dt != null ? DateFormat('dd MMM, HH:mm').format(dt) : '—',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _typeBadge(String type, L l) {
    final colors = <String, Color>{
      'cash': AppColors.accent,
      'loan': AppColors.chartRed,
      'partial': AppColors.chartOrange,
      'cash_not_collected': AppColors.chartOrange,
      'bank_transfer': AppColors.chartBlue,
      'voided': AppColors.chartGray,
    };
    final color = colors[type] ?? AppColors.chartGray;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        _typeLabel(type, l),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusBadge(Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE: date-grouped card list
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final l = L.of(context);
    final filtered = _filtered;
    final grouped = _groupedItems(filtered, l);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PremiumPageEntrance(
        child: Column(
          children: [
            _mobileHeader(l, filtered.length),
            _buildToolbar(desktop: false, l: l),
            _SalesHeroSummary(
              filtered: filtered,
              fmt: _fmt,
              compact: _compact,
              desktop: false,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: RefreshIndicator(
                        onRefresh: _loadSales,
                        color: AppColors.primary,
                        child: filtered.isEmpty
                            ? ListView(children: [_emptyState(l)])
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  130,
                                ),
                                itemCount: grouped.length,
                                itemBuilder: (ctx, i) {
                                  final item = grouped[i];
                                  if (item is String) {
                                    // ── Date group header ───────────────────────
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        16,
                                        4,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            item,
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  // ── Sale card ──────────────────────────────────
                                  final sale = item as Sale;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _SaleCard(
                                      sale: sale,
                                      fmt: _fmt,
                                      dateFmt: _dateFmt,
                                      statusColor: _statusColor(sale),
                                      statusLabel: _statusLabel(sale, l),
                                      typeLabel: _typeLabel(sale.saleType, l),
                                      onTap: () => _openDetail(sale),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileHeader(L l, int count) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: AppColors.gradHeader,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
        child: Row(
          children: [
            IconButton(
              onPressed:
                  widget.onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.salesHistory,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$count ${l.allSales.toLowerCase()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadSales,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Shared widgets ──────────────────────────────────────────────────────────
  Widget _buildToolbar({required bool desktop, required L l}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        desktop ? 24 : 12,
        12,
        desktop ? 24 : 12,
        10,
      ),
      decoration: BoxDecoration(
        color: desktop ? Colors.transparent : AppColors.bgCard,
        border: desktop
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: AppColors.textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: l.search,
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterType,
                dropdownColor: AppColors.bgCard,
                style: TextStyle(color: AppColors.textWhite, fontSize: 13),
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(l.filterAll)),
                  DropdownMenuItem(value: 'cash', child: Text(l.filterCash)),
                  DropdownMenuItem(value: 'loan', child: Text(l.filterLoan)),
                  DropdownMenuItem(
                    value: 'partial',
                    child: Text(l.filterPartial),
                  ),
                  DropdownMenuItem(
                    value: 'cash_not_collected',
                    child: Text(l.filterCashNC),
                  ),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text(l.filterBankTrf),
                  ),
                  DropdownMenuItem(
                    value: 'voided',
                    child: Text(l.filterVoided),
                  ),
                ],
                onChanged: (v) => setState(() => _filterType = v!),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _filterDate != null ? 10 : 0,
            ),
            decoration: BoxDecoration(
              color: _filterDate != null
                  ? AppColors.primaryLt.withAlpha(25)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _filterDate != null
                    ? AppColors.primaryLt.withAlpha(90)
                    : AppColors.border,
              ),
            ),
            child: _filterDate != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_rounded,
                        color: AppColors.primaryLt,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _pickFilterDate,
                        child: Text(
                          DateFormat('dd MMM').format(_filterDate!),
                          style: TextStyle(
                            color: AppColors.primaryLt,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _filterDate = null),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.primaryLt,
                          size: 16,
                        ),
                      ),
                    ],
                  )
                : IconButton(
                    onPressed: _pickFilterDate,
                    icon: Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: l.isSw ? 'Chuja kwa siku' : 'Filter by day',
                  ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: IconButton(
              onPressed: _loadSales,
              icon: Icon(
                Icons.refresh_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Refresh',
            ),
          ),
          if (desktop) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withAlpha(70)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.isSw ? 'Historia tu' : 'History only',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(L l) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLt.withAlpha(18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryLt.withAlpha(50)),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primaryLt,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l.noSales,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.isSw
                ? 'Hakuna muamala unaofanana na utafutaji wako.'
                : 'No transactions match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _loadSales,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.tryAgain),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero summary banner
// ─────────────────────────────────────────────────────────────────────────────
class _SalesHeroSummary extends StatelessWidget {
  final List<Sale> filtered;
  final NumberFormat fmt;
  final String Function(double) compact;
  final bool desktop;

  const _SalesHeroSummary({
    required this.filtered,
    required this.fmt,
    required this.compact,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final paid = filtered
        .where((s) => s.isPaid)
        .fold(0.0, (a, s) => a + s.totalAmount);
    final debt = filtered
        .where((s) => !s.isPaid && !s.isVoided)
        .fold(0.0, (a, s) => a + s.balanceAmount);
    final pending = filtered
        .where((s) => s.isPending || s.isPartial || s.isUnpaid)
        .length;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(
          desktop ? 24 : 12,
          12,
          desktop ? 24 : 12,
          2,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradHeader,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(28)),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.salesHistory,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${filtered.length} ${l.allSales} • TZS ${compact(paid)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MiniPill(
                        icon: Icons.payments_rounded,
                        label: '${l.income}: TZS ${compact(paid)}',
                        color: AppColors.accent,
                      ),
                      if (debt > 0)
                        _MiniPill(
                          icon: Icons.warning_amber_rounded,
                          label: '${l.debts}: TZS ${compact(debt)}',
                          color: AppColors.chartRed,
                        ),
                      if (pending > 0)
                        _MiniPill(
                          icon: Icons.pending_actions_rounded,
                          label: '$pending ${l.salePending}',
                          color: AppColors.chartOrange,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(90)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Sale Card — clean professional design
// ─────────────────────────────────────────────────────────────────────────────
class _SaleCard extends StatelessWidget {
  final Sale sale;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final Color statusColor;
  final String statusLabel;
  final String typeLabel;
  final VoidCallback? onTap;

  const _SaleCard({
    required this.sale,
    required this.fmt,
    required this.dateFmt,
    required this.statusColor,
    required this.statusLabel,
    required this.typeLabel,
    this.onTap,
  });

  String get _initials {
    final name = sale.customerName.trim();
    if (name.isEmpty) return '?';
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    DateTime? dt;
    try {
      dt = DateTime.parse(sale.createdAt);
    } catch (_) {}

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sale.hasBalance
                  ? AppColors.chartRed.withAlpha(55)
                  : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar circle ──────────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withAlpha(160),
                      statusColor.withAlpha(90),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Main content ───────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sale.customerName.isNotEmpty
                                ? sale.customerName
                                : L.of(context).isSw
                                ? 'Mteja Asiyejulikana'
                                : 'Unknown Customer',
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(28),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withAlpha(90),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${sale.saleNo.isNotEmpty ? sale.saleNo : "#${sale.saleId}"}  ·  '
                          '${sale.itemCount} ${L.of(context).items}  ·  $typeLabel',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if (dt != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('HH:mm').format(dt),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    // ── Amounts row ──────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L.of(context).totalLabel,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'TZS ${fmt.format(sale.totalAmount)}',
                                style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (sale.hasBalance) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.chartRed.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.chartRed.withAlpha(70),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  L.of(context).debt,
                                  style: const TextStyle(
                                    color: AppColors.chartRed,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  'TZS ${fmt.format(sale.balanceAmount)}',
                                  style: const TextStyle(
                                    color: AppColors.chartRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
