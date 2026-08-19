import 'package:flutter/material.dart';

import '../../services/api_service.dart';

String _formatDeadline(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}');
  if (date == null) return '${value ?? ''}';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class BrokerOrderPage extends StatefulWidget {
  final String token;
  const BrokerOrderPage({super.key, required this.token});

  @override
  State<BrokerOrderPage> createState() => _BrokerOrderPageState();
}

class _BrokerOrderPageState extends State<BrokerOrderPage> {
  late Future<List<Map<String, dynamic>>> ordersFuture;

  @override
  void initState() {
    super.initState();
    ordersFuture = ApiService.orders(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      ordersFuture = ApiService.orders(widget.token);
    });
    await ordersFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ombi la Oda')),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(child: Text('${snapshot.error}')),
              ],
            );
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                const Center(child: Text('Hakuna ombi la oda kwa sasa')),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final pending = order['assignment_status'] == 'pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF2C7),
                          child: Text('🐔'),
                        ),
                        title: Text('${order['product_name']}'),
                        subtitle: Text(
                          '${order['assigned_quantity']} kuku • Oda ${order['order_number']}\nDeadline: ${_formatDeadline(order['deadline'])}\nHali: ${order['assignment_status']}',
                        ),
                      ),
                      if (pending)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _respond(
                                  context,
                                  int.parse('${order['assignment_id']}'),
                                  true,
                                ),
                                child: const Text('Kubali'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _respond(
                                  context,
                                  int.parse('${order['assignment_id']}'),
                                  false,
                                ),
                                child: const Text('Kataa'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );

  Future<void> _respond(
    BuildContext context,
    int assignmentId,
    bool accept,
  ) async {
    try {
      await ApiService.respondAssignment(widget.token, assignmentId, accept);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Oda imekubaliwa' : 'Oda imekataliwa')),
      );
      await _reload();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}
