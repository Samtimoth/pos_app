import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/order_status.dart';
import 'admin_order_details_page.dart';

class AdminOrdersPage extends StatefulWidget {
  final String token;
  const AdminOrdersPage({super.key, required this.token});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
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
    appBar: AppBar(
      title: const Text('Oda'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
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
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Hakuna oda bado')),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = '${order['status']}';
              final color = orderStatusColor(status);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminOrderDetailsPage(
                          token: widget.token,
                          orderId: order['id'] as int,
                        ),
                      ),
                    );
                    if (context.mounted) _reload();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${order['order_number']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                orderStatusLabel(status),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${order['customer_name']} • ${order['customer_phone']}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              displayDate(order['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              money(
                                num.tryParse('${order['total_amount']}') ?? 0,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
