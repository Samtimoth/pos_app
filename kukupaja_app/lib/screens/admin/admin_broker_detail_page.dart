import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

String _listingStatusLabel(String status) => switch (status) {
  'pending' => 'Inasubiri idhini',
  'approved' => 'Imeidhinishwa',
  'rejected' => 'Imekataliwa',
  'expired' => 'Imeisha muda',
  _ => status,
};

Color _listingStatusColor(String status) => switch (status) {
  'approved' => green,
  'rejected' => Colors.red,
  'expired' => Colors.grey,
  _ => Colors.orange,
};

class AdminBrokerDetailPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> broker;
  const AdminBrokerDetailPage({
    super.key,
    required this.token,
    required this.broker,
  });

  @override
  State<AdminBrokerDetailPage> createState() => _AdminBrokerDetailPageState();
}

class _AdminBrokerDetailPageState extends State<AdminBrokerDetailPage> {
  late Future<List<Map<String, dynamic>>> productsFuture;
  bool busy = false;
  late bool verified;

  @override
  void initState() {
    super.initState();
    verified =
        widget.broker['is_verified'] == true ||
        '${widget.broker['is_verified']}' == '1';
    productsFuture = _loadBrokerProducts();
  }

  Future<List<Map<String, dynamic>>> _loadBrokerProducts() async {
    final all = await ApiService.adminProducts(widget.token);
    return all.where((p) => p['broker_id'] == widget.broker['id']).toList();
  }

  Future<void> _reload() async {
    setState(() => productsFuture = _loadBrokerProducts());
    await productsFuture;
  }

  Future<void> _toggleVerified() async {
    setState(() => busy = true);
    try {
      await ApiService.toggleBrokerVerified(
        widget.token,
        widget.broker['id'] as int,
      );
      if (mounted) setState(() => verified = !verified);
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
      title: Text('${widget.broker['name']}'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: verified
                            ? const Color(0xFFFFE0B2)
                            : Colors.grey.shade200,
                        child: Text(
                          '${widget.broker['name']}'.isNotEmpty
                              ? '${widget.broker['name']}'[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: verified ? green : Colors.grey.shade600,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.broker['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${widget.broker['phone']} • ${widget.broker['location'] ?? ''}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: busy
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _toggleVerified,
                            icon: Icon(
                              verified
                                  ? Icons.verified
                                  : Icons.hourglass_empty,
                              color: verified ? green : Colors.orange,
                            ),
                            label: Text(
                              verified
                                  ? 'Amethibitishwa (bonyeza kuondoa)'
                                  : 'Thibitisha Broker',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: verified ? green : Colors.orange,
                              side: BorderSide(
                                color: verified ? green : Colors.orange,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Bidhaa za Broker',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('${snapshot.error}')),
                );
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Broker huyu hajaweka bidhaa bado'),
                  ),
                );
              }
              return Column(
                children: products.map((p) {
                  final status = '${p['status']}';
                  final imageUrl = '${p['image_url'] ?? ''}';
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: imageUrl.isEmpty
                              ? Container(
                                  color: const Color(0xFFFFF2C7),
                                  child: const Center(child: Text('🐔')),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFFFFF2C7),
                                    child: const Center(child: Text('🐔')),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        '${p['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${p['available_stock']} kuku • Mfugaji: ${money(num.tryParse('${p['supplier_price']}') ?? 0)}'
                        '${status == 'approved' ? ' • Mteja: ${money(num.tryParse('${p['customer_price']}') ?? 0)}' : ''}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _listingStatusColor(
                            status,
                          ).withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _listingStatusLabel(status),
                          style: TextStyle(
                            color: _listingStatusColor(status),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );
}
