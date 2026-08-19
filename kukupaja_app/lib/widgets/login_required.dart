import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class LoginRequired extends StatelessWidget {
  final String title;
  final Future<void> Function() onPressed;
  const LoginRequired({super.key, required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 60, color: green),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: const Text('Ingia sasa')),
        ],
      ),
    ),
  );
}
