import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

String _stockStatusLabel(String status) => switch (status) {
  'pending' => 'Inasubiri idhini',
  'approved' => 'Imeidhinishwa',
  'rejected' => 'Imekataliwa',
  'expired' => 'Imeisha muda',
  _ => status,
};

Color _stockStatusColor(String status) => switch (status) {
  'approved' => green,
  'rejected' => Colors.red,
  'expired' => Colors.grey,
  _ => Colors.orange,
};

class StockPage extends StatefulWidget {
  final String token;
  const StockPage({super.key, required this.token});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late Future<List<Map<String, dynamic>>> productsFuture;

  @override
  void initState() {
    super.initState();
    productsFuture = ApiService.brokerProducts(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      productsFuture = ApiService.brokerProducts(widget.token);
    });
    await productsFuture;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stock Yangu')),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: productsFuture,
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
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                const Center(child: Text('Bado hujaweka kuku')),
              ],
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: products
                .map(
                  (p) => StockTile(
                    name: '${p['name']}',
                    imageUrl: '${p['image_url'] ?? ''}',
                    details:
                        '${p['available_stock']} kuku • ${money(num.parse('${p['supplier_price']}'))}',
                    status: '${p['status']}',
                  ),
                )
                .toList(),
          );
        },
      ),
    ),
  );
}

class StockTile extends StatelessWidget {
  final String name, imageUrl, details, status;
  const StockTile({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.details,
    required this.status,
  });

  @override
  Widget build(BuildContext context) => Card(
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
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFFFF2C7),
                    child: const Center(child: Text('🐔')),
                  ),
                ),
        ),
      ),
      title: Text(name),
      subtitle: Text(details),
      isThreeLine: false,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _stockStatusColor(status).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _stockStatusLabel(status),
          style: TextStyle(
            color: _stockStatusColor(status),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}
