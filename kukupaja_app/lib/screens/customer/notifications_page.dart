import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Taarifa', 'Notifications'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF3CD),
              child: Icon(Icons.campaign, color: green),
            ),
            title: Text(tr('Broiler wamefika', 'Broilers are available')),
            subtitle: Text(
              tr(
                'Angalia stock mpya kwenye Home.',
                'Check the new stock on Home.',
              ),
            ),
            trailing: const Text('Mpya', style: TextStyle(color: green)),
          ),
        ),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFE0B2),
              child: Icon(Icons.verified, color: green),
            ),
            title: Text(tr('Biashara salama', 'Safe shopping')),
            subtitle: Text(
              tr(
                'Oda na mawasiliano yote hupitia kwa admin.',
                'All orders and communication go through admin.',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
