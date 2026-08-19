import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'admin/admin_web_portal.dart';
import 'broker/broker_shell.dart';
import 'customer/customer_shell.dart';

/// Lets a user pick which part of the app to enter. Not currently linked
/// from anywhere in the navigation flow (the splash screen goes straight
/// to the customer storefront) — kept in case it's wired up later.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [green, Color(0xFFB8390A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 54,
                    backgroundColor: yellow,
                    child: Text('🐔', style: TextStyle(fontSize: 58)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'KukuPaja',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Tunauza ladha ya kuku',
                    style: TextStyle(color: yellow, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Soko la kuku, moja kwa moja.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 38),
                  _roleButton(
                    context,
                    'Ingia kama Mteja',
                    Icons.shopping_bag,
                    const CustomerShell(),
                  ),
                  _roleButton(
                    context,
                    'Ingia kama Broker',
                    Icons.agriculture,
                    const BrokerShell(),
                  ),
                  _roleButton(
                    context,
                    'Ingia kama Admin',
                    Icons.admin_panel_settings,
                    const AdminWebPortal(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(
    BuildContext context,
    String label,
    IconData icon,
    Widget page,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 340,
        height: 56,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: label.contains('Mteja') ? yellow : Colors.white,
            foregroundColor: green,
          ),
          onPressed: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          icon: Icon(icon),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
