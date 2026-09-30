import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../providers/app_provider.dart';
import '../services/report_export.dart';
import '../theme/app_theme.dart';
import '../widgets/first_run_tutorial.dart';
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
  String _period = 'all';   // all | today | week | month  (mobile chips)
  String _status = 'all';   // all | paid | debt | pending | voided | offline
  bool _exporting = false;
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###', 'en_US');
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
      final matchPeriod = _inPeriod(s.createdAt);
      final matchStatus = switch (_status) {
        'paid' => s.isPaid,
        'debt' => (s.isUnpaid || s.isPartial) && !s.isVoided,
        'pending' => s.isPending,
        'voided' => s.isVoided,
        'offline' => !s.isSynced,
        _ => true,
      };
      return matchType && matchSearch && matchDate && matchPeriod && matchStatus;
    }).toList();
  }

  bool _inPeriod(String rawDate) {
    if (_period == 'all') return true;
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    return switch (_period) {
      'today' => d == today,
      'week' => !d.isBefore(today.subtract(Duration(days: today.weekday - 1))),
      'month' => d.year == now.year && d.month == now.month,
      _ => true,
    };
  }

  Future<void> _exportExcel() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    if (biz == null || _filtered.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await ReportExport.exportSalesList(
        sales: _filtered,
        businessName: biz.receiptHeader.isNotEmpty ? biz.receiptHeader : biz.businessName,
        label: _period == 'all' ? 'zote' : _period,
      );
      if (mounted) {
        AppNotification.show(context, 'Excel imetengenezwa', AppColors.accent,
            icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(context, 'Export imeshindwa: $e', AppColors.chartRed,
            icon: Icons.error_rounded);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
                      if (!s.isSynced) _SyncBadge(sale: s),
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
            TutorialTarget(
              id: 'sales_toolbar',
              child: _mobileFilters(l),
            ),
            TutorialTarget(
              id: 'sales_summary',
              child: _SalesHeroSummary(
                filtered: filtered,
                fmt: _fmt,
                compact: _compact,
                desktop: false,
              ),
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
                                  4,
                                  12,
                                  100,
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
                                  // ── Sale row (compact) ─────────────────────────
                                  final sale = item as Sale;
                                  final row = Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _SaleRow(
                                      sale: sale,
                                      fmt: _fmt,
                                      statusColor: _statusColor(sale),
                                      statusLabel: _statusLabel(sale, l),
                                      typeLabel: _typeLabel(sale.saleType, l),
                                      onTap: () => _openDetail(sale),
                                    ),
                                  );
                                  // first sale is the tutorial anchor
                                  final firstSaleIdx = grouped.indexWhere((e) => e is Sale);
                                  return i == firstSaleIdx
                                      ? TutorialTarget(id: 'sales_list', child: row)
                                      : row;
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
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.sales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$count ${l.allSales.toLowerCase()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Export Excel',
              onPressed: _exporting || filteredIsEmpty ? null : _exportExcel,
              icon: _exporting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.table_view_rounded, color: Colors.white),
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

  bool get filteredIsEmpty => _filtered.isEmpty;

  /// Search + period chips + status chips (phone).
  Widget _mobileFilters(L l) {
    Widget chip(String label, bool sel, VoidCallback onTap, {Color? color}) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
              color: sel ? Colors.white : AppColors.textMuted,
              fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            )),
        selected: sel,
        showCheckmark: false,
        selectedColor: color ?? AppColors.primary,
        backgroundColor: AppColors.bgCard,
        side: BorderSide(color: sel ? (color ?? AppColors.primary) : AppColors.border),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        onSelected: (_) => onTap(),
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SizedBox(
            height: 42,
            child: TextField(
              style: TextStyle(color: AppColors.textWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: l.isSw ? 'Tafuta mteja au namba ya risiti' : 'Search customer or receipt no.',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            children: [
              chip('Zote', _period == 'all' && _filterDate == null, () => setState(() { _period = 'all'; _filterDate = null; })),
              chip('Leo', _period == 'today', () => setState(() { _period = 'today'; _filterDate = null; })),
              chip('Wiki hii', _period == 'week', () => setState(() { _period = 'week'; _filterDate = null; })),
              chip('Mwezi huu', _period == 'month', () => setState(() { _period = 'month'; _filterDate = null; })),
              chip(
                _filterDate == null ? 'Tarehe…' : DateFormat('dd MMM').format(_filterDate!),
                _filterDate != null,
                () async {
                  await _pickFilterDate();
                  if (_filterDate != null) setState(() => _period = 'all');
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            children: [
              chip('Hali: zote', _status == 'all', () => setState(() => _status = 'all')),
              chip('Zimelipwa', _status == 'paid', () => setState(() => _status = 'paid'), color: AppColors.accentDk),
              chip('Madeni', _status == 'debt', () => setState(() => _status = 'debt'), color: AppColors.chartRed),
              chip('Zinasubiri', _status == 'pending', () => setState(() => _status = 'pending'), color: AppColors.chartOrange),
              chip('Zilizofutwa', _status == 'voided', () => setState(() => _status = 'voided'), color: AppColors.chartGray),
              chip('Offline', _status == 'offline', () => setState(() => _status = 'offline'), color: Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

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

    if (!desktop) {
      // Phone: one compact stats strip – the screen title is already above.
      Widget stat(IconData icon, String label, String value, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      );
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            stat(Icons.payments_rounded, l.income, 'TZS ${compact(paid)}', AppColors.accent),
            Container(width: 1, height: 28, color: AppColors.border),
            const SizedBox(width: 10),
            stat(Icons.warning_amber_rounded, l.debts, 'TZS ${compact(debt)}',
                debt > 0 ? AppColors.chartRed : AppColors.textMuted),
            Container(width: 1, height: 28, color: AppColors.border),
            const SizedBox(width: 10),
            stat(Icons.pending_actions_rounded, l.salePending, '$pending',
                pending > 0 ? AppColors.chartOrange : AppColors.textMuted),
          ],
        ),
      );
    }

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
/// "Offline – inasubiri sync" / "Imekataliwa" chip for sales made offline.
class _SyncBadge extends StatelessWidget {
  final Sale sale;
  const _SyncBadge({required this.sale});

  @override
  Widget build(BuildContext context) {
    final failed = sale.isSyncFailed;
    final color = failed ? Colors.redAccent : Colors.orange;
    final label = failed
        ? 'Imekataliwa: ${sale.syncError.isNotEmpty ? sale.syncError : "angalia sync"}'
        : 'Offline · inasubiri sync';
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(failed ? Icons.error_outline_rounded : Icons.cloud_off_rounded,
            size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}


/// Compact one-line sale row for phones: avatar · name + meta · amount/status.
class _SaleRow extends StatelessWidget {
  final Sale sale;
  final NumberFormat fmt;
  final Color statusColor;
  final String statusLabel;
  final String typeLabel;
  final VoidCallback? onTap;

  const _SaleRow({
    required this.sale,
    required this.fmt,
    required this.statusColor,
    required this.statusLabel,
    required this.typeLabel,
    this.onTap,
  });

  String get _initials {
    final words = sale.customerName.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    DateTime? dt;
    try {
      dt = DateTime.parse(sale.createdAt);
    } catch (_) {}
    final time = dt != null ? DateFormat('HH:mm').format(dt) : '';
    final name = sale.customerName.isNotEmpty ? sale.customerName : '—';
    final voided = sale.isVoided;

    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !sale.isSynced ? Colors.orange.withAlpha(120) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor.withAlpha(90)),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: voided ? AppColors.textMuted : AppColors.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        decoration: voided ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (time.isNotEmpty) time,
                        '${sale.itemCount} ${L.of(context).items}',
                        typeLabel,
                        if (!sale.isSynced)
                          sale.isSyncFailed ? '⚠ sync' : '☁ offline',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: !sale.isSynced ? Colors.orange : AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(sale.totalAmount),
                    style: TextStyle(
                      color: voided ? AppColors.textMuted : AppColors.textWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      decoration: voided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
