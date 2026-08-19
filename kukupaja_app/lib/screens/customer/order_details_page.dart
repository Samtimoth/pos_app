import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/order_status.dart';

class OrderDetailsPage extends StatelessWidget {
  final String token;
  final Map<String, dynamic> order;
  const OrderDetailsPage({super.key, required this.token, required this.order});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${order['order_number']}')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: ApiService.orderDetails(token, int.parse('${order['id']}')),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        }
        final data = snapshot.data!;
        final current = (data['order'] as Map).cast<String, dynamic>();
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        final status = '${current['status']}';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [green, Color(0xFFF57A22)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Hali ya oda', 'Order status'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    orderStatusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: orderProgress(status)),
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      color: yellow,
                      backgroundColor: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              tr('Hatua za oda', 'Order progress'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _OrderTimeline(status: status),
            const SizedBox(height: 18),
            Text(
              tr('Bidhaa ulizoagiza', 'Order items'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE0B2),
                    child: Icon(Icons.egg_alt_outlined, color: green),
                  ),
                  title: Text(
                    '${item['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${tr('Idadi', 'Quantity')}: ${item['quantity']}  ×  ${money(num.tryParse('${item['unit_price']}') ?? 0)}',
                  ),
                  trailing: Text(
                    money(
                      (num.tryParse('${item['unit_price']}') ?? 0) *
                          (num.tryParse('${item['quantity']}') ?? 0),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      Icons.location_on_outlined,
                      tr('Anwani', 'Address'),
                      '${current['delivery_address']}',
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      Icons.payments_outlined,
                      tr('Malipo', 'Payment'),
                      '${current['payment_method']}' == 'cash'
                          ? tr('Lipa unapopokea', 'Cash on delivery')
                          : '${current['payment_method']}',
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      Icons.receipt_outlined,
                      tr('Jumla', 'Total'),
                      money(num.tryParse('${current['total_amount']}') ?? 0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: green),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  );
}

class _OrderTimeline extends StatelessWidget {
  final String status;
  const _OrderTimeline({required this.status});
  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled' || status == 'refunded') {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.close, color: Colors.white),
        ),
        title: Text(
          orderStatusLabel(status),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    const steps = [
      'pending',
      'confirmed',
      'preparing',
      'in_transit',
      'completed',
    ];
    final progress = orderProgress(status);
    return Column(
      children: List.generate(steps.length, (index) {
        final done = progress >= orderProgress(steps[index]);
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + index * 120),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(-12 * (1 - value), 0),
              child: child,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? green : Colors.grey.shade300,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          done ? Icons.check : Icons.circle,
                          key: ValueKey(done),
                          size: done ? 16 : 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (index < steps.length - 1)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 2,
                      height: 34,
                      color: done ? green : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  orderStatusLabel(steps[index]),
                  style: TextStyle(
                    fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                    color: done ? null : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
