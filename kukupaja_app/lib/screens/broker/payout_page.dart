import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/stat_card.dart';

String _payoutStatusLabel(String status) => switch (status) {
  'paid' => 'Imelipwa',
  'failed' => 'Imeshindikana',
  _ => 'Inasubiri Malipo',
};

class PayoutPage extends StatefulWidget {
  final String token;
  const PayoutPage({super.key, required this.token});

  @override
  State<PayoutPage> createState() => _PayoutPageState();
}

class _PayoutPageState extends State<PayoutPage> {
  late Future<List<Map<String, dynamic>>> payoutsFuture;

  @override
  void initState() {
    super.initState();
    payoutsFuture = ApiService.brokerPayouts(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      payoutsFuture = ApiService.brokerPayouts(widget.token);
    });
    await payoutsFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Malipo Yangu')),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: payoutsFuture,
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
          final payouts = snapshot.data ?? [];
          final pending = payouts.where((p) => p['status'] == 'pending');
          final pendingTotal = pending.fold<num>(
            0,
            (sum, p) => sum + (num.tryParse('${p['supplier_amount']}') ?? 0),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatCard(
                'Inasubiri Malipo',
                money(pendingTotal),
                Icons.pending,
                Colors.orange,
              ),
              const SizedBox(height: 8),
              if (payouts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('Bado hakuna malipo')),
                ),
              ...payouts.map(
                (payout) => Card(
                  child: ListTile(
                    title: Text('${payout['order_number']}'),
                    subtitle: Text(
                      '${money(num.tryParse('${payout['supplier_amount']}') ?? 0)} • ${_payoutStatusLabel('${payout['status']}')}',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
