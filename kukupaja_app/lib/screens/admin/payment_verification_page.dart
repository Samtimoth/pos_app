import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class PaymentVerificationPage extends StatefulWidget {
  final String token;
  const PaymentVerificationPage({super.key, required this.token});

  @override
  State<PaymentVerificationPage> createState() =>
      _PaymentVerificationPageState();
}

class _PaymentVerificationPageState extends State<PaymentVerificationPage> {
  late Future<List<Map<String, dynamic>>> verificationsFuture;

  @override
  void initState() {
    super.initState();
    verificationsFuture = ApiService.adminPaymentVerifications(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      verificationsFuture = ApiService.adminPaymentVerifications(
        widget.token,
      );
    });
    await verificationsFuture;
  }

  Future<void> _verify(Map<String, dynamic> order, String status) async {
    try {
      await ApiService.verifyPayment(widget.token, order['id'] as int, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'paid'
                ? 'Malipo yamethibitishwa'
                : 'Imewekwa kusubiri tena',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Uthibitisho wa Malipo'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: verificationsFuture,
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
                  Icons.verified_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text('Hakuna malipo yanayosubiri uthibitisho'),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final proofImage = '${order['payment_proof_image'] ?? ''}';
              final reference = '${order['payment_reference'] ?? ''}';
              final payerName = '${order['payment_payer_name'] ?? ''}';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            money(
                              num.tryParse('${order['total_amount']}') ?? 0,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order['customer_name']} • 📞 ${order['customer_phone']}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withValues(
                            alpha: .5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Njia: ${order['payment_method_name'] ?? order['payment_method']}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (payerName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Jina la malipo: $payerName'),
                              ),
                            if (reference.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Namba ya muamala: $reference'),
                              ),
                            if (proofImage.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
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
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const SizedBox(
                                          height: 60,
                                          child: Center(
                                            child: Text('Picha haipatikani'),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _verify(order, 'paid'),
                              icon: const Icon(Icons.check),
                              label: const Text('Thibitisha Malipo'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _verify(order, 'pending'),
                              child: const Text('Bado Hajalipa'),
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
}
