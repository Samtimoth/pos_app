import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatCard(
    this.title,
    this.value,
    this.icon,
    this.color, {
    super.key,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(title),
          ],
        ),
      ),
    ),
  );
}
