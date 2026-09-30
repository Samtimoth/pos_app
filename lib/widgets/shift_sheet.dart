import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/shift_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';

/// Zamu (Shift/Register, Hatua 4): fungua zamu na fedha ya kuanzia, funga
/// zamu ukihesabu fedha taslimu ilivyo mkononi — mfumo unaonyesha
/// "inayotarajiwa" dhidi ya "uliyohesabu" (hii ndiyo reconciliation ya
/// Hatua 5, hakuna skrini tofauti inayohitajika kwa hilo).
class ShiftSheet extends StatefulWidget {
  const ShiftSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ShiftSheet(),
      );

  @override
  State<ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<ShiftSheet> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _dateFmt = DateFormat('dd MMM, HH:mm');
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;
  bool _changed = false;

  CrmApi? get _crm {
    final app = context.read<AppProvider>();
    final url = app.user?.serverUrl;
    return url == null ? null : CrmApi(url);
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final crm = _crm;
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final userId = app.user?.userId;
    if (crm == null || bizId == null) { setState(() => _loadingHistory = false); return; }
    try {
      final raw = await crm.listShifts(bizId, userId: userId);
      if (!mounted) return;
      setState(() { _history = raw; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openShift() async {
    final ctrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Fungua Zamu', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Weka kiasi cha fedha taslimu ulichonacho sasa mkononi kabla ya kuanza kuuza.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(hintText: 'Fedha ya Kuanzia', hintStyle: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(hintText: 'Maelezo (hiari)', hintStyle: TextStyle(color: AppColors.textMuted)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Fungua Zamu')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final crm = _crm;
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final userId = app.user?.userId;
    if (crm == null || bizId == null || userId == null) return;
    try {
      final r = await crm.openShift(
        businessId: bizId, branchId: app.selectedBranch?.branchId, userId: userId,
        openingCash: double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0,
        openingNotes: notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        _changed = true;
        await context.read<ShiftProvider>().refresh(crm, bizId, userId);
        _loadHistory();
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    }
  }

  Future<void> _closeShift(Map<String, dynamic> shift) async {
    final ctrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Funga Zamu', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hesabu fedha taslimu iliyoko mkononi sasa na uweke hapa.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(hintText: 'Fedha Taslimu Uliyohesabu', hintStyle: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(hintText: 'Maelezo (hiari)', hintStyle: TextStyle(color: AppColors.textMuted)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartOrange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Funga Zamu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final crm = _crm;
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    final userId = app.user?.userId;
    if (crm == null || bizId == null) return;
    try {
      final r = await crm.closeShift(
        businessId: bizId, shiftId: shift['shift_id'] as int,
        closingCash: double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0,
        closingNotes: notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        _changed = true;
        if (userId != null) await context.read<ShiftProvider>().refresh(crm, bizId, userId);
        _loadHistory();
        if (!mounted) return;
        final variance = double.tryParse('${r['variance']}') ?? 0;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Zamu Imefungwa', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _resultRow('Inayotarajiwa', double.tryParse('${r['expected_cash']}') ?? 0),
              _resultRow('Uliyohesabu', double.tryParse('${r['closing_cash']}') ?? 0),
              Divider(color: AppColors.border),
              _resultRow(variance == 0 ? 'Sawa kabisa' : (variance > 0 ? 'Ziada' : 'Pungufu'), variance.abs(),
                  color: variance == 0 ? AppColors.accent : (variance > 0 ? AppColors.chartBlue : AppColors.chartRed), bold: true),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sawa'))],
          ),
        );
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    }
  }

  Widget _resultRow(String label, double value, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: color ?? AppColors.textMuted, fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text('TZS ${_fmt.format(value)}', style: TextStyle(color: color ?? AppColors.textWhite, fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final shiftProv = context.watch<ShiftProvider>();
    final current = shiftProv.current;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.pop(context, _changed); },
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(width: 46, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 12, 10),
              child: Row(children: [
                Icon(Icons.point_of_sale_rounded, color: AppColors.chartBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text('Zamu (Shift)', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context, _changed), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                children: [
                  if (shiftProv.loading)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
                  else if (current == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Huna zamu iliyo wazi', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Fungua zamu na fedha uliyonayo mkononi kabla ya kuanza kuuza — itakusaidia kuhakiki fedha mwishoni.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openShift,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                            icon: const Icon(Icons.lock_open_rounded),
                            label: const Text('Fungua Zamu', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.accent.withAlpha(20), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accent.withAlpha(80))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Zamu Iko Wazi', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                        ]),
                        const SizedBox(height: 8),
                        Text('Ilifunguliwa: ${_dateFmt.format(DateTime.tryParse('${current['opened_at']}') ?? DateTime.now())}',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text('Fedha ya Kuanzia: TZS ${_fmt.format(double.tryParse('${current['opening_cash']}') ?? 0)}',
                            style: TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _closeShift(current),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartOrange, foregroundColor: Colors.white),
                            icon: const Icon(Icons.lock_outline_rounded),
                            label: const Text('Funga Zamu', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 18),
                  Text('Historia ya Zamu', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (_loadingHistory)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary)))
                  else if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Hakuna zamu za nyuma', style: TextStyle(color: AppColors.textMuted)),
                    )
                  else
                    Column(children: [for (final s in _history) _historyRow(s)]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> s) {
    final isOpen = s['status'] == 'open';
    final variance = s['variance'] == null ? null : (double.tryParse('${s['variance']}') ?? 0);
    final opened = DateTime.tryParse('${s['opened_at']}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(opened == null ? '' : _dateFmt.format(opened), style: TextStyle(color: AppColors.textWhite, fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text(isOpen ? 'Bado wazi' : 'Imefungwa', style: TextStyle(color: isOpen ? AppColors.accent : AppColors.textMuted, fontSize: 10.5)),
          ]),
        ),
        if (!isOpen && variance != null)
          Text(
            variance == 0 ? 'Sawa' : (variance > 0 ? '+${_fmt.format(variance)}' : _fmt.format(variance)),
            style: TextStyle(
              color: variance == 0 ? AppColors.accent : (variance > 0 ? AppColors.chartBlue : AppColors.chartRed),
              fontSize: 12.5, fontWeight: FontWeight.w800,
            ),
          ),
      ]),
    );
  }
}
