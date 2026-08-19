import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/stat_card.dart';
import '../customer/customer_shell.dart';

class BrokerDashboard extends StatefulWidget {
  final String token;
  final String name;
  const BrokerDashboard({super.key, required this.token, required this.name});

  @override
  State<BrokerDashboard> createState() => _BrokerDashboardState();
}

class _BrokerDashboardState extends State<BrokerDashboard> {
  late Future<Map<String, dynamic>> dashboardFuture;

  @override
  void initState() {
    super.initState();
    dashboardFuture = ApiService.brokerDashboard(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      dashboardFuture = ApiService.brokerDashboard(widget.token);
    });
    await dashboardFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: green,
      foregroundColor: Colors.white,
      title: const Text('Dashboard ya Broker'),
      leading: IconButton(
        tooltip: 'Rudi',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CustomerShell()),
            );
          }
        },
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                const SizedBox(height: 14),
                Text('${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Jaribu tena'),
                ),
              ],
            );
          }
          final data = snapshot.data ?? {};
          final pendingAssignments = data['pending_assignments'] ?? 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Karibu, ${widget.name}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  StatCard(
                    'Stock Yangu',
                    '${data['available_stock'] ?? 0} Kuku',
                    Icons.inventory,
                    green,
                  ),
                  StatCard(
                    'Reserved',
                    '${data['reserved_stock'] ?? 0} Kuku',
                    Icons.lock,
                    Colors.orange,
                  ),
                  StatCard(
                    'Waliouzwa',
                    '${data['sold_stock'] ?? 0} Kuku',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                  StatCard(
                    'Inasubiri Malipo',
                    money(num.tryParse('${data['pending_payout'] ?? 0}') ?? 0),
                    Icons.wallet,
                    Colors.red,
                  ),
                ],
              ),
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('$pendingAssignments')),
                  title: const Text('Maombi mapya ya Oda'),
                  subtitle: const Text('Admin anahitaji uthibitishe stock'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
