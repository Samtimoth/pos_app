import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Thin banner shown under the app bar: offline state, pending / failed
/// sync operations, and a "Sync sasa" action. Hidden when everything is
/// online and in sync.
class SyncStatusBar extends StatelessWidget {
  /// Pad for the system status bar (use when the bar is the first thing on
  /// screen, e.g. mobile body).
  final bool safeTop;
  const SyncStatusBar({super.key, this.safeTop = false});

  /// True when the bar is currently rendered (offline, or work pending).
  /// Lets the parent drop the status-bar padding of the page below it.
  static bool isVisible(BuildContext context) {
    final conn = context.watch<ConnectivityService>();
    final sync = context.watch<SyncService>();
    return !conn.isOnline || sync.hasWork || sync.syncing;
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityService>();
    final sync = context.watch<SyncService>();

    final offline = !conn.isOnline;
    if (!offline && !sync.hasWork && !sync.syncing) {
      return const SizedBox.shrink();
    }

    final Color color;
    final IconData icon;
    final String text;
    if (sync.syncing) {
      color = AppColors.primaryLt;
      icon = Icons.sync_rounded;
      text = 'Inatuma data kwenye server… (${sync.pending})';
    } else if (offline) {
      color = Colors.orange;
      icon = Icons.cloud_off_rounded;
      text = sync.pending > 0
          ? 'Offline · ${sync.pending} zinasubiri kutumwa'
          : 'Offline · unaweza kuendelea kuuza';
    } else if (sync.failed > 0) {
      color = Colors.redAccent;
      icon = Icons.error_outline_rounded;
      text = '${sync.failed} zimekataliwa na server — bonyeza kuona';
    } else {
      color = AppColors.chartOrange;
      icon = Icons.cloud_upload_outlined;
      text = '${sync.pending} zinasubiri kutumwa';
    }

    final bar = Material(
      color: color.withAlpha(28),
      child: InkWell(
        onTap: () => showSyncQueueSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              if (sync.syncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!offline && sync.hasWork && !sync.syncing)
                TextButton(
                  onPressed: () => sync.failed > 0
                      ? sync.retryFailed()
                      : sync.syncNow(),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Sync sasa',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
    if (!safeTop) return bar;
    return ColoredBox(
      color: color.withAlpha(28),
      child: SafeArea(bottom: false, child: bar),
    );
  }
}

/// Small pill for the desktop top bar / profile: online dot + pending count.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityService>();
    final sync = context.watch<SyncService>();
    final online = conn.isOnline;
    final color = !online
        ? Colors.orange
        : (sync.failed > 0 ? Colors.redAccent : AppColors.accent);
    final label = !online
        ? 'Offline'
        : sync.syncing
            ? 'Syncing…'
            : sync.hasWork
                ? '${sync.pending + sync.failed} pending'
                : 'Online';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showSyncQueueSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

Future<void> showSyncQueueSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SyncQueueSheet(),
    );

class _SyncQueueSheet extends StatefulWidget {
  const _SyncQueueSheet();
  @override
  State<_SyncQueueSheet> createState() => _SyncQueueSheetState();
}

class _SyncQueueSheetState extends State<_SyncQueueSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    SyncService.instance.addListener(_load);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await SyncService.instance.queueItems();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityService>();
    final sync = context.watch<SyncService>();
    final fmt = DateFormat('dd/MM HH:mm');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
            child: Row(children: [
              Icon(conn.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: conn.isOnline ? AppColors.accent : Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hali ya Sync',
                      style: TextStyle(color: AppColors.textWhite,
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  Text(
                    conn.isOnline
                        ? (sync.lastSync == null
                            ? 'Online'
                            : 'Online · sync ya mwisho ${fmt.format(sync.lastSync!)}')
                        : 'Offline — data itatumwa ukiwasha mtandao',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ]),
              ),
              if (conn.isOnline && sync.hasWork)
                sync.syncing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: 'Sync sasa',
                        onPressed: () => sync.failed > 0
                            ? sync.retryFailed()
                            : sync.syncNow(),
                        icon: Icon(Icons.sync_rounded, color: AppColors.primaryLt),
                      ),
            ]),
          ),
          Divider(color: AppColors.border, height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 48, color: AppColors.accent),
                          const SizedBox(height: 10),
                          Text('Kila kitu kimesync',
                              style: TextStyle(color: AppColors.textWhite,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      )
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _row(_items[i], fmt),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> op, DateFormat fmt) {
    final failed = op['status'] == 'failed';
    final color = failed ? Colors.redAccent : AppColors.chartOrange;
    final when = DateTime.fromMillisecondsSinceEpoch(op['created_at'] as int);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        Icon(failed ? Icons.error_outline_rounded : Icons.schedule_rounded,
            color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(op['label'] as String,
                style: TextStyle(color: AppColors.textWhite,
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              failed
                  ? 'Imekataliwa: ${op['last_error'] ?? ''}'
                  : 'Inasubiri · ${fmt.format(when)}',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: failed ? color : AppColors.textMuted,
                  fontSize: 11),
            ),
          ]),
        ),
        if (failed)
          IconButton(
            tooltip: 'Futa',
            icon: Icon(Icons.delete_outline_rounded,
                color: AppColors.textMuted, size: 20),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.bgCard,
                  title: Text('Futa operation hii?',
                      style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
                  content: Text(
                    'Haitatumwa kwenye server. Kama ni mauzo, stock ya server haitapungua.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Ghairi')),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: const Text('Futa',
                            style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (ok == true) await SyncService.instance.discard(op['id'] as int);
            },
          ),
      ]),
    );
  }
}
