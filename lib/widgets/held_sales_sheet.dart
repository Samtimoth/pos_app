import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/held_sales_provider.dart';
import '../theme/app_theme.dart';

/// List of carts "parked" for later (see [HeldSalesProvider]). Tap a row to
/// pick it for resuming (caller does the actual `take()` + cart restore);
/// the trash icon discards one without resuming it.
class HeldSalesSheet extends StatelessWidget {
  const HeldSalesSheet({super.key});

  static Future<HeldSale?> show(BuildContext context) => showModalBottomSheet<HeldSale>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const HeldSalesSheet(),
      );

  String _agoLabel(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'sasa hivi';
    if (d.inMinutes < 60) return '${d.inMinutes} dk zilizopita';
    if (d.inHours < 24) return '${d.inHours} saa zilizopita';
    return DateFormat('dd MMM, HH:mm').format(t);
  }

  Future<void> _confirmDiscard(BuildContext context, HeldSale h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Futa mauzo yaliyowekwa kando?', style: TextStyle(color: AppColors.textWhite, fontSize: 16)),
        content: Text('${h.label} — bidhaa ${h.count} hazitapatikana tena.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Futa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<HeldSalesProvider>().discard(h.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');
    final held = context.watch<HeldSalesProvider>();
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: AppColors.chartPurple.withAlpha(30), borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.pause_circle_outline_rounded, color: AppColors.chartPurple, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Mauzo Yaliyowekwa Kando', style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${held.count} yanasubiri', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
            ),
            Divider(color: AppColors.border, height: 1),
            Flexible(
              child: held.items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text('Hakuna mauzo yaliyowekwa kando kwa sasa.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                      itemCount: held.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final h = held.items[i];
                        return Material(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(context, h),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(h.label.isNotEmpty ? h.label : 'Mteja wa kawaida',
                                        style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('${h.count} bidhaa · TZS ${fmt.format(h.total)} · ${_agoLabel(h.heldAt)}',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  ]),
                                ),
                                IconButton(
                                  onPressed: () => _confirmDiscard(context, h),
                                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
