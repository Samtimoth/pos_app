import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Maombi ya Kurudisha Bidhaa — mfanyakazi asiye na ruhusa ya sales.void
/// (cashier) hawezi kurudisha bidhaa moja kwa moja; ombi lake linakaa hapa
/// mpaka meneja/admin aidhinishe (ndipo stock/deni vinabadilika kweli,
/// angalia sale_returns.php's approve_request).
class ReturnRequestsScreen extends StatefulWidget {
  const ReturnRequestsScreen({super.key});

  @override
  State<ReturnRequestsScreen> createState() => _ReturnRequestsScreenState();
}

class _ReturnRequestsScreenState extends State<ReturnRequestsScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    if (app.api == null || bizId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await app.api!.listPendingReturnRequests(bizId);
      if (!mounted) return;
      setState(() { _requests = raw; _loading = false; });
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

  Future<void> _approve(Map<String, dynamic> req) async {
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    if (app.api == null || bizId == null) return;
    setState(() => _busyId = req['request_id'] as int);
    try {
      final r = await app.api!.approveReturnRequest(businessId: bizId, requestId: req['request_id'] as int);
      if (!mounted) return;
      if (r['success'] == true) {
        _snack('${r['message'] ?? '✅ Imeidhinishwa'}', AppColors.accent);
        _load();
      } else {
        _snack('${r['message'] ?? 'Hitilafu'}', AppColors.chartRed);
      }
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Kataa ombi la kurudisha?', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kataa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppProvider>();
    final bizId = app.selectedBusiness?.businessId;
    if (app.api == null || bizId == null) return;
    setState(() => _busyId = req['request_id'] as int);
    try {
      final r = await app.api!.rejectReturnRequest(businessId: bizId, requestId: req['request_id'] as int);
      if (!mounted) return;
      _snack(r['message'] as String? ?? (r['success'] == true ? '✅ Imefanikiwa' : 'Hitilafu'),
          r['success'] == true ? AppColors.accent : AppColors.chartRed);
      if (r['success'] == true) _load();
    } catch (e) {
      if (mounted) _snack('$e', AppColors.chartRed);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Maombi ya Kurudisha', style: TextStyle(color: AppColors.textWhite)),
        iconTheme: IconThemeData(color: AppColors.textWhite),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _requests.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 120),
                        child: Center(
                          child: Text('Hakuna maombi ya kurudisha yanayosubiri',
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _requests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = _requests[i];
                      final items = (r['items'] as List?) ?? [];
                      final busy = _busyId == r['request_id'];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('Mauzo #${r['sale_id']}',
                                  style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                            ),
                            Text('TZS ${_fmt.format((r['refund_amount'] as num?)?.toDouble() ?? 0)}',
                                style: TextStyle(color: AppColors.chartOrange, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 4),
                          Text('Aliyeomba: ${r['requested_by_name'] ?? '—'}',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          if ((r['reason'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Sababu: ${r['reason']}',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ),
                          const SizedBox(height: 8),
                          ...items.map((it) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '• ${it['product_name']} x${it['quantity']}',
                                  style: TextStyle(color: AppColors.textWhite, fontSize: 12.5),
                                ),
                              )),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => _reject(r),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Kataa'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: busy ? null : () => _approve(r),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Idhinisha', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ]),
                        ]),
                      );
                    },
                  ),
      ),
    );
  }
}
