import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Zaidi" (More) — orodha ya vitu vya ziada visivyofaa kukaa moja kwa moja
/// kwenye bottom nav ya simu (nafasi ni chache pale). Muundo: safu za
/// icon+jina+chevron, moja kwa moja kama app nyingine za kifedha/biashara.
class MoreListItem {
  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const MoreListItem({
    required this.icon,
    required this.color,
    required this.label,
    this.subtitle,
    required this.onTap,
  });
}

class MoreScreen extends StatelessWidget {
  final bool desktop;
  final List<MoreListItem> items;
  const MoreScreen({super.key, this.desktop = false, required this.items});

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      padding: EdgeInsets.fromLTRB(16, desktop ? 20 : 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final it = items[i];
        return Material(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: it.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: it.color.withAlpha(28), borderRadius: BorderRadius.circular(12)),
                  child: Icon(it.icon, color: it.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.label, style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14.5)),
                    if (it.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(it.subtitle!, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      ),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ]),
            ),
          ),
        );
      },
    );
    if (!desktop) return list;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Row(children: [
            Text('Zaidi', style: TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(child: list),
      ],
    );
  }
}
