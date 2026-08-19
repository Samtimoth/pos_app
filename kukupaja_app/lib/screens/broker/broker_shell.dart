import 'package:flutter/material.dart';

import '../../core/local_store.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/login_required.dart';
import '../auth/login_screen.dart';
import 'add_stock_page.dart';
import 'broker_dashboard.dart';
import 'broker_order_page.dart';
import 'broker_settings_page.dart';
import 'payout_page.dart';
import 'stock_page.dart';

class BrokerShell extends StatefulWidget {
  final Session? session;
  const BrokerShell({super.key, this.session});
  @override
  State<BrokerShell> createState() => _BrokerShellState();
}

class _BrokerShellState extends State<BrokerShell> {
  int index = 0;
  Session? session;

  @override
  void initState() {
    super.initState();
    session = widget.session;
    if (session != null) {
      PushNotificationService.registerToken(session!.token);
    }
  }

  Future<Session?> requireBrokerLogin() async {
    if (session != null) return session;
    final result = await Navigator.push<Session>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(expectedRole: 'broker', returnSession: true),
      ),
    );
    if (result != null && mounted) {
      setState(() => session = result);
      PushNotificationService.registerToken(result.token);
    }
    return result;
  }

  Future<void> _logout() async {
    await SessionStore.clear();
    if (mounted) setState(() => session = null);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      session == null
          ? _brokerGate('Ingia kuona dashboard yako')
          : BrokerDashboard(token: session!.token, name: session!.name),
      session == null
          ? _brokerGate('Ingia kuona stock yako')
          : StockPage(token: session!.token),
      session == null
          ? _brokerGate('Ingia kuona maombi ya oda')
          : BrokerOrderPage(token: session!.token),
      session == null
          ? _brokerGate('Ingia kuona malipo yako')
          : PayoutPage(token: session!.token),
      session == null
          ? _brokerGate('Ingia kuona mipangilio yako')
          : BrokerSettingsPage(
              session: session!,
              loadProfile: () => ApiService.me(session!.token),
              onLogout: _logout,
            ),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.receipt), label: 'Maombi'),
          NavigationDestination(icon: Icon(Icons.wallet), label: 'Malipo'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Mipangilio',
          ),
        ],
      ),
      floatingActionButton: index == 1
          ? FloatingActionButton.extended(
              onPressed: () async {
                final activeSession = await requireBrokerLogin();
                if (activeSession == null || !context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddStockPage(token: activeSession.token),
                  ),
                );
                if (context.mounted) setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('Weka Kuku'),
            )
          : null,
    );
  }

  Widget _brokerGate(String title) => Scaffold(
    appBar: AppBar(title: const Text('KukuPaja Broker')),
    body: LoginRequired(
      title: title,
      onPressed: () async {
        await requireBrokerLogin();
      },
    ),
  );
}
