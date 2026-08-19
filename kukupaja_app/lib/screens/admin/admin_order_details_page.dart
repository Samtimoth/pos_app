import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/order_status.dart';

class AdminOrderDetailsPage extends StatefulWidget {
  final String token;
  final int orderId;
  const AdminOrderDetailsPage({
    super.key,
    required this.token,
    required this.orderId,
  });

  @override
  State<AdminOrderDetailsPage> createState() => _AdminOrderDetailsPageState();
}

class _AdminOrderDetailsPageState extends State<AdminOrderDetailsPage> {
  late Future<Map<String, dynamic>> detailsFuture;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    detailsFuture = ApiService.orderDetails(widget.token, widget.orderId);
  }

  void _reload() {
    setState(() {
      detailsFuture = ApiService.orderDetails(widget.token, widget.orderId);
    });
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => busy = true);
    try {
      await action();
      if (success != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Maelezo ya Oda'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: detailsFuture,
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
        final order = (data['order'] as Map).cast<String, dynamic>();
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        final status = '${order['status']}';
        final color = orderStatusColor(status);
        final nextStatuses = nextOrderStatuses(status);
        final paymentStatus = '${order['payment_status']}';
        final reference = '${order['payment_reference'] ?? ''}';
        final payerName = '${order['payment_payer_name'] ?? ''}';
        final proofImage = '${order['payment_proof_image'] ?? ''}';

        return AbsorbPointer(
          absorbing: busy,
          child: Opacity(
            opacity: busy ? .6 : 1,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order['order_number']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        orderStatusLabel(status),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(displayDate(order['created_at'])),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(Icons.person_outline, 'Mteja', '${order['customer_name']}'),
                        const Divider(height: 20),
                        _row(
                          Icons.phone_outlined,
                          'Simu',
                          '${order['customer_phone']}',
                        ),
                        const Divider(height: 20),
                        _row(
                          Icons.location_on_outlined,
                          'Anwani',
                          '${order['delivery_address']}',
                        ),
                        const Divider(height: 20),
                        _row(
                          Icons.receipt_outlined,
                          'Jumla',
                          money(num.tryParse('${order['total_amount']}') ?? 0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Malipo',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(
                          Icons.payments_outlined,
                          'Njia',
                          '${order['payment_method_name'] ?? order['payment_method']}',
                        ),
                        if (payerName.isNotEmpty) ...[
                          const Divider(height: 20),
                          _row(Icons.badge_outlined, 'Jina la Malipo', payerName),
                        ],
                        if (reference.isNotEmpty) ...[
                          const Divider(height: 20),
                          _row(
                            Icons.confirmation_number_outlined,
                            'Namba ya muamala',
                            reference,
                          ),
                        ],
                        if (proofImage.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.network(proofImage),
                                  ),
                                ),
                              ),
                              child: Image.network(
                                proofImage,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (paymentStatus == 'paid'
                                            ? green
                                            : paymentStatus == 'refunded'
                                            ? Colors.red
                                            : Colors.orange)
                                        .withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                paymentStatus == 'paid'
                                    ? 'Imelipwa'
                                    : paymentStatus == 'refunded'
                                    ? 'Imerejeshwa'
                                    : 'Inasubiri',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: paymentStatus == 'paid'
                                      ? green
                                      : paymentStatus == 'refunded'
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (paymentStatus != 'paid')
                              TextButton(
                                onPressed: () => _run(
                                  () => ApiService.verifyPayment(
                                    widget.token,
                                    widget.orderId,
                                    'paid',
                                  ),
                                  success: 'Malipo yamethibitishwa',
                                ),
                                child: const Text('Thibitisha Malipo'),
                              ),
                            if (paymentStatus == 'paid')
                              TextButton(
                                onPressed: () => _run(
                                  () => ApiService.verifyPayment(
                                    widget.token,
                                    widget.orderId,
                                    'refunded',
                                  ),
                                  success: 'Malipo yamerejeshwa',
                                ),
                                child: const Text('Rejesha Malipo'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bidhaa',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final assigned = item['is_assigned'] == true || item['is_assigned'] == 1;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Text('🐔')),
                      title: Text('${item['name']}'),
                      subtitle: Text(
                        '${item['quantity']} × ${money(num.tryParse('${item['unit_price']}') ?? 0)} • Broker: ${item['broker_name']}',
                      ),
                      trailing: assigned
                          ? const Icon(Icons.check_circle, color: green)
                          : (status == 'confirmed' || status == 'assigned')
                          ? TextButton(
                              onPressed: () => _run(
                                () => ApiService.assignOrderItem(
                                  widget.token,
                                  item['id'] as int,
                                ),
                                success: 'Imetumwa kwa broker',
                              ),
                              child: const Text('Tuma'),
                            )
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: 20),
                if (nextStatuses.isNotEmpty) ...[
                  Text(
                    'Badilisha Hali ya Oda',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: nextStatuses.map((next) {
                      final isCancel = next == 'cancelled';
                      return isCancel
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              onPressed: () => _run(
                                () => ApiService.updateOrderStatus(
                                  widget.token,
                                  widget.orderId,
                                  next,
                                ),
                                success: 'Oda imefutwa',
                              ),
                              child: const Text('Futa Oda'),
                            )
                          : FilledButton(
                              onPressed: () => _run(
                                () => ApiService.updateOrderStatus(
                                  widget.token,
                                  widget.orderId,
                                  next,
                                ),
                                success: 'Hali ya oda imebadilishwa',
                              ),
                              child: Text(orderStatusLabel(next)),
                            );
                    }).toList(),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Oda hii imefungwa, haiwezi kubadilishwa zaidi.'),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _row(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: green, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  );
}
