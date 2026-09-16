import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_l10n.dart';
import '../models/expense.dart';
import '../providers/app_provider.dart';
import '../services/report_export.dart';
import '../theme/app_theme.dart';
import '../widgets/first_run_tutorial.dart';
import 'expense_form_sheet.dart';

/// Ripoti: P&L · Mauzo · Matumizi — for a chosen date range, with Excel export.
class ReportsScreen extends StatefulWidget {
  final bool desktop;
  const ReportsScreen({super.key, this.desktop = false});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _Range { today, week, month, lastMonth, quarter, year, custom }

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  final _fmt = NumberFormat('#,###', 'en_US');
  final _fmtD = NumberFormat('#,##0.#', 'en_US');

  _Range _range = _Range.month;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  Map<String, dynamic>? _report;
  Map<String, dynamic>? _cashflow;
  bool _loading = true;
  bool _offline = false;
  bool _exporting = false;
  String? _error;

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_from);
  String get _toStr => DateFormat('yyyy-MM-dd').format(_to);

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstRunTutorial.showIfNeeded(
        context,
        storageKey: 'reports',
        steps: const [
          TutorialStep(
            icon: Icons.date_range_rounded,
            title: 'Chagua kipindi',
            body: 'Leo, wiki, mwezi… au tarehe zako mwenyewe. Ripoti zote zinafuata kipindi hiki.',
            targetId: 'reports_range',
          ),
          TutorialStep(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Faida na Hasara',
            body: 'Mauzo − gharama ya bidhaa − matumizi = faida halisi. Bonyeza Excel kutoa ripoti.',
            targetId: 'reports_export',
          ),
          TutorialStep(
            icon: Icons.receipt_long_rounded,
            title: 'Matumizi',
            body: 'Kwenye tab ya Matumizi ongeza kodi, umeme, mishahara… ili faida ionyeshe ukweli.',
            targetId: 'reports_tabs',
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    if (app.api == null || biz == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        app.api!.getReport(
          biz.businessId,
          branchId: app.selectedBranch?.branchId,
          dateFrom: _fromStr,
          dateTo: _toStr,
        ),
        app.api!.getCashFlow(
          biz.businessId,
          branchId: app.selectedBranch?.branchId,
          dateFrom: _fromStr,
          dateTo: _toStr,
        ),
      ]);
      if (!mounted) return;
      final r = results[0];
      final cf = results[1];
      if (r['success'] == true) {
        setState(() {
          _report = r;
          _cashflow = cf['success'] == true ? cf : null;
          _offline = r['offline'] == true;
        });
      } else {
        setState(() => _error = '${r['message'] ?? 'Hitilafu'}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setRange(_Range r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (r) {
      case _Range.today:
        _from = today;
        _to = today;
      case _Range.week:
        _from = today.subtract(Duration(days: today.weekday - 1));
        _to = today;
      case _Range.month:
        _from = DateTime(now.year, now.month, 1);
        _to = today;
      case _Range.lastMonth:
        _from = DateTime(now.year, now.month - 1, 1);
        _to = DateTime(now.year, now.month, 0);
      case _Range.quarter:
        _from = DateTime(now.year, now.month - 2, 1);
        _to = today;
      case _Range.year:
        _from = DateTime(now.year, 1, 1);
        _to = today;
      case _Range.custom:
        break;
    }
    setState(() => _range = r);
    if (r != _Range.custom) _load();
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primaryLt),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    _from = picked.start;
    _to = picked.end;
    setState(() => _range = _Range.custom);
    _load();
  }

  Future<void> _export() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    if (_report == null || biz == null) return;
    setState(() => _exporting = true);
    try {
      await ReportExport.exportPnl(
        report: _report!,
        businessName: biz.receiptHeader.isNotEmpty ? biz.receiptHeader : biz.businessName,
        currency: biz.currency,
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

  Future<void> _addExpense([Expense? existing]) async {
    final saved = await ExpenseFormSheet.show(context, existing: existing);
    if (saved == true) _load();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  double _n(dynamic v) => double.tryParse('$v') ?? 0;
  Map<String, dynamic> _m(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List<Map<String, dynamic>> _l(dynamic v) =>
      (v as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  String _money(dynamic v) => 'TZS ${_fmt.format(_n(v))}';

  String _rangeLabel(_Range r) => switch (r) {
        _Range.today => 'Leo',
        _Range.week => 'Wiki hii',
        _Range.month => 'Mwezi huu',
        _Range.lastMonth => 'Mwezi uliopita',
        _Range.quarter => 'Miezi 3',
        _Range.year => 'Mwaka huu',
        _Range.custom => _range == _Range.custom
            ? '${DateFormat('dd/MM').format(_from)} – ${DateFormat('dd/MM').format(_to)}'
            : 'Tarehe…',
      };

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _header(l),
          Expanded(
            child: _loading && _report == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null && _report == null
                    ? _errorView()
                    : TabBarView(
                        controller: _tab,
                        children: [_pnlTab(), _salesTab(), _expensesTab(), _cashflowTab()],
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.desktop ? null : AnimatedBuilder(
        animation: _tab,
        builder: (_, _) => _tab.index == 2
            ? FloatingActionButton.extended(
                heroTag: 'add_expense_fab',
                onPressed: () => _addExpense(),
                backgroundColor: AppColors.accent,
                icon: Icon(Icons.add_rounded, color: AppColors.bgDark),
                label: Text('Ongeza matumizi',
                    style: TextStyle(color: AppColors.bgDark, fontWeight: FontWeight.bold)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _header(L l) => Container(
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
          child: Column(
            children: [
              if (!widget.desktop)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      )
                    else
                      const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ripoti',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text(
                            '${DateFormat('dd MMM').format(_from)} – ${DateFormat('dd MMM yyyy').format(_to)}'
                            '${_offline ? '  ·  offline' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      )
                    else
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      ),
                    TutorialTarget(
                      id: 'reports_export',
                      child: IconButton(
                        tooltip: 'Export Excel',
                        onPressed: _exporting || _report == null ? null : _export,
                        icon: _exporting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.table_view_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              // range chips (+ actions on desktop)
              Row(
                children: [
                  Expanded(
                    child: TutorialTarget(
                id: 'reports_range',
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(widget.desktop ? 24 : 16, widget.desktop ? 12 : 6, 16, 4),
                    children: [
                      for (final r in _Range.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              _rangeLabel(r),
                              style: TextStyle(
                                color: _range == r ? AppColors.primary : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selected: _range == r,
                            showCheckmark: false,
                            selectedColor: Colors.white,
                            backgroundColor: Colors.white.withAlpha(22),
                            side: BorderSide(color: Colors.white.withAlpha(_range == r ? 0 : 60)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) => r == _Range.custom ? _pickCustom() : _setRange(r),
                          ),
                        ),
                    ],
                  ),
                ),
                    ),
                  ),
                  if (widget.desktop) ...[
                    if (_offline)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, right: 4),
                        child: Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 18),
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      )
                    else
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      ),
                    TutorialTarget(
                      id: 'reports_export',
                      child: TextButton.icon(
                        onPressed: _exporting || _report == null ? null : _export,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.table_view_rounded, size: 18),
                        label: const Text('Excel', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ],
              ),
              // tabs
              Align(
                alignment: Alignment.centerLeft,
                child: TutorialTarget(
                id: 'reports_tabs',
                child: Container(
                  margin: EdgeInsets.fromLTRB(widget.desktop ? 24 : 16, 6, widget.desktop ? 24 : 16, 12),
                  constraints: BoxConstraints(maxWidth: widget.desktop ? 520 : double.infinity),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(3),
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    isScrollable: true,
                    tabs: const [
                      Tab(height: 40, text: 'Faida (P&L)'),
                      Tab(height: 40, text: 'Mauzo'),
                      Tab(height: 40, text: 'Matumizi'),
                      Tab(height: 40, text: 'Mtiririko wa Pesa'),
                    ],
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
      );

  /// Desktop: two columns side by side; phone: one scrolling column.
  Widget _columns(List<Widget> left, List<Widget> right, {required double bottomPad}) {
    if (!widget.desktop) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
        children: [...left, const SizedBox(height: 14), ...right],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: Column(children: left)),
            const SizedBox(width: 16),
            Expanded(flex: 6, child: Column(children: right)),
          ],
        ),
      ],
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_error ?? '', textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Jaribu tena')),
            ],
          ),
        ),
      );

  // ── P&L tab ───────────────────────────────────────────────────────────────
  Widget _pnlTab() {
    final pnl = _m(_report?['pnl']);
    final sales = _m(_report?['sales']);
    final net = _n(pnl['net_profit']);
    final gross = _n(pnl['gross_profit']);
    final monthly = _l(pnl['monthly']);
    final maxPad = MediaQuery.paddingOf(context).bottom;

    final left = <Widget>[
          // net profit hero
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: net >= 0
                    ? [AppColors.primaryDk, AppColors.primaryMid]
                    : [const Color(0xFF7F1D1D), const Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(net >= 0 ? 'FAIDA HALISI' : 'HASARA',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(_money(net.abs()),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Row(children: [
                  _pill('${_fmtD.format(_n(pnl['net_margin_pct']))}% ya mauzo'),
                  const SizedBox(width: 8),
                  _pill('${sales['count'] ?? 0} mauzo'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // statement
          _card(
            title: 'Taarifa ya Faida na Hasara',
            child: Column(children: [
              _line('Mauzo (jumla)', pnl['revenue'], strong: true),
              _line('   Pesa iliyopokelewa', sales['collected'], muted: true),
              _line('   Madeni ya wateja', sales['outstanding'], muted: true,
                  color: _n(sales['outstanding']) > 0 ? AppColors.chartOrange : null),
              _line('− Gharama ya bidhaa (COGS)', pnl['cogs'], negative: true),
              Divider(color: AppColors.border, height: 18),
              _line('= Faida ghafi', gross, strong: true,
                  trailing: '${_fmtD.format(_n(pnl['gross_margin_pct']))}%'),
              _line('− Matumizi', pnl['expenses'], negative: true),
              Divider(color: AppColors.border, height: 18),
              _line('= Faida halisi', net, strong: true,
                  color: net >= 0 ? AppColors.accent : AppColors.chartRed,
                  trailing: '${_fmtD.format(_n(pnl['net_margin_pct']))}%'),
            ]),
          ),
    ];
    final right = <Widget>[
          if (monthly.length > 1)
            _card(
              title: 'Mwenendo — miezi ${monthly.length}',
              subtitle: 'Mauzo vs faida halisi',
              child: SizedBox(height: widget.desktop ? 260 : 200, child: _monthlyChart(monthly)),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exporting || _report == null ? null : _export,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.table_view_rounded),
              label: const Text('Toa P&L kwenye Excel',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Excel ina sheets 3: P&L, Mauzo (kwa siku, aina ya malipo, bidhaa) na Matumizi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _columns(left, right, bottomPad: 100 + maxPad),
    );
  }

  Widget _monthlyChart(List<Map<String, dynamic>> monthly) {
    double maxY = 0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < monthly.length; i++) {
      final rv = _n(monthly[i]['revenue']);
      final np = _n(monthly[i]['net_profit']);
      if (rv > maxY) maxY = rv;
      groups.add(BarChartGroupData(x: i, barsSpace: 2, barRods: [
        BarChartRodData(
            toY: rv, width: 7, color: AppColors.primaryLt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
        BarChartRodData(
            toY: np < 0 ? 0 : np, width: 7,
            color: np < 0 ? AppColors.chartRed : AppColors.accent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      ]));
    }
    return BarChart(BarChartData(
      barGroups: groups,
      maxY: maxY > 0 ? maxY * 1.15 : 100,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 25,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: maxY > 0 ? maxY / 4 : 25,
            getTitlesWidget: (v, _) => Text(_short(v),
                style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
              final m = '${monthly[i]['month']}';
              final mon = int.tryParse(m.split('-').last) ?? 0;
              const names = ['', 'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(mon >= 1 && mon <= 12 ? names[mon] : m,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
            '${ri == 0 ? "Mauzo" : "Faida"}: ${_fmt.format(rod.toY)}',
            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ));
  }

  // ── Sales tab ─────────────────────────────────────────────────────────────
  Widget _salesTab() {
    final s = _m(_report?['sales']);
    final byDay = _l(s['by_day']);
    final byType = _l(s['by_type']);
    final byCat = _l(s['by_category']);
    final top = _l(s['top_products']);
    final maxPad = MediaQuery.paddingOf(context).bottom;
    final rev = _n(s['revenue']);

    final left = <Widget>[
          Row(children: [
            _kpi('Mauzo', _money(s['revenue']), '${s['count'] ?? 0} miamala', AppColors.primaryLt),
            const SizedBox(width: 10),
            _kpi('Imepokelewa', _money(s['collected']),
                'madeni ${_fmt.format(_n(s['outstanding']))}', AppColors.accent),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _kpi('Bidhaa zilizouzwa', _fmtD.format(_n(s['units_sold'])), 'vipande', AppColors.chartBlue),
            const SizedBox(width: 10),
            _kpi('Zilizofutwa', '${s['voided_count'] ?? 0}',
                _money(s['voided_amount']), AppColors.chartRed),
          ]),
          const SizedBox(height: 14),
          if (byDay.isNotEmpty)
            _card(
              title: 'Mauzo kwa siku',
              child: SizedBox(height: widget.desktop ? 240 : 180, child: _dailyChart(byDay)),
            ),
          const SizedBox(height: 14),
          if (byType.isNotEmpty)
            _card(
              title: 'Aina ya malipo',
              child: Column(children: [
                for (final t in byType)
                  _bar('${_typeName('${t['type']}')}  ·  ${t['count']}', _n(t['amount']), rev,
                      AppColors.primaryLt),
              ]),
            ),
          const SizedBox(height: 14),
          if (byCat.isNotEmpty)
            _card(
              title: 'Kwa kategoria',
              child: Column(children: [
                for (final c in byCat.take(8))
                  _bar('${c['category']}', _n(c['revenue']), rev, AppColors.chartPurple),
              ]),
            ),
    ];
    final right = <Widget>[
          if (top.isNotEmpty)
            _card(
              title: 'Bidhaa zinazouzwa zaidi',
              subtitle: 'Idadi · mauzo · faida',
              child: Column(children: [
                for (var i = 0; i < top.length && i < (widget.desktop ? 25 : 15); i++) _productRow(i + 1, top[i]),
              ]),
            ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _columns(left, right, bottomPad: 100 + maxPad),
    );
  }

  Widget _dailyChart(List<Map<String, dynamic>> byDay) {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < byDay.length; i++) {
      final v = _n(byDay[i]['revenue']);
      if (v > maxY) maxY = v;
      spots.add(FlSpot(i.toDouble(), v));
    }
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY > 0 ? maxY * 1.15 : 100,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 25,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: maxY > 0 ? maxY / 4 : 25,
            getTitlesWidget: (v, _) =>
                Text(_short(v), style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: (byDay.length / 6).ceilToDouble().clamp(1, 31),
            getTitlesWidget: (v, meta) {
              final i = v.toInt();
              if (i < 0 || i >= byDay.length) return const SizedBox.shrink();
              // fl_chart always adds the last value; skip it if it would
              // collide with the previous regular tick
              final step = meta.appliedInterval.round();
              if (i == byDay.length - 1 && byDay.length > 2 && i % step != 0 && i % step < step / 2) {
                return const SizedBox.shrink();
              }
              final d = '${byDay[i]['date']}';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(d.length >= 10 ? '${d.substring(8, 10)}/${d.substring(5, 7)}' : d,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: AppColors.accent,
          barWidth: 2.5,
          dotData: FlDotData(show: byDay.length <= 14),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [AppColors.accent.withAlpha(90), AppColors.accent.withAlpha(0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    '${byDay[s.x.toInt()]['date']}\nTZS ${_fmt.format(s.y)}',
                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ))
              .toList(),
        ),
      ),
    ));
  }

  Widget _productRow(int rank, Map<String, dynamic> p) {
    final profit = _n(p['profit']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 22,
          child: Text('$rank',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w600, fontSize: 13)),
            Text('${_fmtD.format(_n(p['qty']))} · ${p['category'] ?? ''}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt.format(_n(p['revenue'])),
              style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
          Text('${profit >= 0 ? '+' : ''}${_fmt.format(profit)}',
              style: TextStyle(
                  color: profit >= 0 ? AppColors.accent : AppColors.chartRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  // ── Expenses tab ──────────────────────────────────────────────────────────
  Widget _expensesTab() {
    final e = _m(_report?['expenses']);
    final byCat = _l(e['by_category']);
    final items = _l(e['items']);
    final total = _n(e['total']);
    final maxPad = MediaQuery.paddingOf(context).bottom;
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;

    final left = <Widget>[
          Row(children: [
            _kpi('Matumizi jumla', _money(total), '${items.length} rekodi', AppColors.chartOrange),
            const SizedBox(width: 10),
            _kpi('Kategoria', '${byCat.length}',
                byCat.isEmpty ? '—' : 'kubwa: ${byCat.first['category']}', AppColors.chartPurple),
          ]),
          const SizedBox(height: 14),
          if (byCat.isNotEmpty)
            _card(
              title: 'Kwa kategoria',
              child: Column(children: [
                for (final c in byCat) _bar('${c['category']}', _n(c['amount']), total, AppColors.chartOrange),
              ]),
            ),
          if (widget.desktop) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addExpense(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chartOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ongeza matumizi', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
    ];
    final right = <Widget>[
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 10),
                Text('Hakuna matumizi kwenye kipindi hiki',
                    style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text('Bonyeza "Ongeza matumizi" — kodi, umeme, mishahara…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            )
          else
            _card(
              title: 'Rekodi za matumizi',
              child: Column(children: [
                for (final it in items)
                  _expenseRow(Expense.fromJson({...it, 'business_id': biz?.businessId ?? 0})),
              ]),
            ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _columns(left, right, bottomPad: 110 + maxPad),
    );
  }

  Widget _expenseRow(Expense x) {
    final d = DateTime.tryParse(x.expenseDate);
    return InkWell(
      onTap: () => _addExpense(x),
      onLongPress: () => _confirmDeleteExpense(x),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.chartOrange.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(d == null ? '' : '${d.day}',
                  style: TextStyle(color: AppColors.chartOrange, fontWeight: FontWeight.w800, fontSize: 14, height: 1)),
              Text(d == null ? '' : DateFormat('MMM').format(d),
                  style: TextStyle(color: AppColors.chartOrange, fontSize: 9, height: 1.2)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.category,
                  style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
              if (x.description.isNotEmpty)
                Text(x.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
          Text('-${_fmt.format(x.amount)}',
              style: TextStyle(color: AppColors.chartOrange, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Expense x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Futa matumizi?', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Text('${x.category} · TZS ${_fmt.format(x.amount)}',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ghairi')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Futa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppProvider>();
    final res = await app.api!.deleteExpense(
        businessId: app.selectedBusiness!.businessId, expenseId: x.expenseId);
    if (!mounted) return;
    AppNotification.show(context, '${res['message'] ?? 'Imefutwa'}',
        res['success'] == true ? AppColors.accent : AppColors.chartRed,
        icon: Icons.delete_rounded);
    _load();
  }

  // ── Cash flow tab ────────────────────────────────────────────────────────
  static const _cfMethodLabels = {
    'cash': 'Taslimu', 'mpesa': 'M-Pesa', 'mobile': 'Simu', 'bank': 'Benki',
    'card': 'Kadi', 'credit': 'Mkopo', 'other': 'Nyingine',
  };
  String _cfMethodLabel(String m) => _cfMethodLabels[m.toLowerCase()] ?? m;

  Widget _cashflowTab() {
    final cf = _cashflow;
    final maxPad = MediaQuery.paddingOf(context).bottom;
    if (cf == null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(children: [
              Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 10),
              Text('Mtiririko wa pesa haupatikani kwa sasa',
                  style: TextStyle(color: AppColors.textMuted)),
            ]),
          ),
        ]),
      );
    }
    final inD = _m(cf['in']);
    final outD = _m(cf['out']);
    final netD = _m(cf['net']);
    final inByMethod = _l(inD['by_method']);
    final outByMethod = _l(outD['by_method']);
    final netByMethod = _l(netD['by_method']);
    final inTotal = _n(inD['total']);
    final outTotal = _n(outD['total']);
    final netTotal = _n(netD['total']);

    final left = <Widget>[
          Row(children: [
            _kpi('Pesa Ndani', _money(inTotal), '${inByMethod.length} aina', AppColors.accent),
            const SizedBox(width: 10),
            _kpi('Pesa Nje', _money(outTotal), 'manunuzi + matumizi', AppColors.chartOrange),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _kpi('Mtiririko Halisi', '${netTotal >= 0 ? '' : '-'}${_money(netTotal.abs())}',
                netTotal >= 0 ? 'chanya' : 'hasi',
                netTotal >= 0 ? AppColors.accent : AppColors.chartRed),
          ]),
          const SizedBox(height: 14),
          if (inByMethod.isNotEmpty)
            _card(
              title: 'Pesa Ndani — kwa aina ya malipo',
              child: Column(children: [
                for (final r in inByMethod)
                  _bar('${_cfMethodLabel('${r['method']}')} (${r['count']})', _n(r['amount']), inTotal, AppColors.accent),
              ]),
            ),
          if (outByMethod.isNotEmpty) ...[
            const SizedBox(height: 14),
            _card(
              title: 'Pesa Nje — kwa aina ya malipo',
              child: Column(children: [
                for (final r in outByMethod)
                  _bar(_cfMethodLabel('${r['method']}'), _n(r['amount']), outTotal, AppColors.chartOrange),
              ]),
            ),
          ],
    ];
    final right = <Widget>[
          if (netByMethod.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 10),
                Text('Hakuna miamala kwenye kipindi hiki',
                    style: TextStyle(color: AppColors.textMuted)),
              ]),
            )
          else
            _card(
              title: 'Mtiririko halisi — kwa aina',
              subtitle: 'Ndani ukiondoa Nje, kila aina ya malipo',
              child: Column(children: [
                for (final r in netByMethod)
                  _line(_cfMethodLabel('${r['method']}'), r['net'],
                      strong: true,
                      negative: _n(r['net']) < 0,
                      color: _n(r['net']) >= 0 ? AppColors.accent : AppColors.chartRed),
              ]),
            ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _columns(left, right, bottomPad: 100 + maxPad),
    );
  }

  // ── small widgets ─────────────────────────────────────────────────────────
  Widget _kpi(String label, String value, String sub, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
          ]),
        ),
      );

  Widget _card({required String title, String? subtitle, required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800, fontSize: 14)),
          if (subtitle != null)
            Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _line(String label, dynamic value,
          {bool strong = false, bool muted = false, bool negative = false, Color? color, String? trailing}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: muted ? AppColors.textMuted : AppColors.textWhite,
                  fontSize: strong ? 14 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                )),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(trailing, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          Text(
            '${negative ? '(' : ''}${_fmt.format(_n(value).abs())}${negative ? ')' : ''}',
            style: TextStyle(
              color: color ?? (muted ? AppColors.textMuted : AppColors.textWhite),
              fontSize: strong ? 15 : 13,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ]),
      );

  Widget _bar(String label, double value, double total, Color color) {
    final f = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textWhite, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Text('${_fmt.format(value)}  ',
              style: TextStyle(color: AppColors.textWhite, fontSize: 12.5, fontWeight: FontWeight.w700)),
          Text('${(f * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: f,
            minHeight: 6,
            backgroundColor: AppColors.bgInput,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  String _typeName(String t) => switch (t.toLowerCase().replaceAll(' ', '_')) {
        'cash' => 'Taslimu',
        'loan' => 'Mkopo',
        'partial' || 'slow_payment' => 'Polepole',
        'cash_not_collected' => 'Bado kulipwa',
        'bank_transfer' => 'Benki',
        'voided' => 'Zilizofutwa',
        _ => t,
      };
}
