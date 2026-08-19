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

class AdminListingsPage extends StatefulWidget {
  final String token;
  const AdminListingsPage({super.key, required this.token});

  @override
  State<AdminListingsPage> createState() => _AdminListingsPageState();
}

class _AdminListingsPageState extends State<AdminListingsPage> {
  late Future<List<Map<String, dynamic>>> productsFuture;
  String filter = 'pending';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    productsFuture = ApiService.adminProducts(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      productsFuture = ApiService.adminProducts(widget.token);
    });
    await productsFuture;
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
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> product) async {
    final controller = TextEditingController(
      text: '${product['supplier_price']}',
    );
    final price = await showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Idhinisha Bidhaa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bei ya mfugaji: ${money(num.tryParse('${product['supplier_price']}') ?? 0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bei ya Mteja (TZS)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, num.tryParse(controller.text)),
            child: const Text('Idhinisha'),
          ),
        ],
      ),
    );
    if (price == null || price <= 0) return;
    await _run(
      () => ApiService.approveProduct(
        widget.token,
        product['id'] as int,
        price,
      ),
      success: 'Bidhaa imeidhinishwa',
    );
  }

  Future<void> _reject(Map<String, dynamic> product) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kataa Bidhaa'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Sababu ya kukataa',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kataa'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _run(
      () => ApiService.rejectProduct(widget.token, product['id'] as int, reason),
      success: 'Bidhaa imekataliwa',
    );
  }

  Future<void> _expire(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ondoa Sokoni'),
        content: Text('Una uhakika unataka kuondoa "${product['name']}" sokoni?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ondoa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ApiService.expireProduct(widget.token, product['id'] as int),
      success: 'Listing imeondolewa sokoni',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Listings'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    body: Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Inasubiri',
                  value: 'pending',
                  selected: filter,
                  onTap: (v) => setState(() => filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Imeidhinishwa',
                  value: 'approved',
                  selected: filter,
                  onTap: (v) => setState(() => filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Imekataliwa',
                  value: 'rejected',
                  selected: filter,
                  onTap: (v) => setState(() => filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Imeisha',
                  value: 'expired',
                  selected: filter,
                  onTap: (v) => setState(() => filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Zote',
                  value: 'all',
                  selected: filter,
                  onTap: (v) => setState(() => filter = v),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: AbsorbPointer(
              absorbing: busy,
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
                  final all = snapshot.data ?? [];
                  final products = filter == 'all'
                      ? all
                      : all.where((p) => p['status'] == filter).toList();
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
                        const Center(child: Text('Hakuna bidhaa hapa')),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final status = '${p['status']}';
                      final imageUrl = '${p['image_url'] ?? ''}';
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: imageUrl.isEmpty
                                          ? Container(
                                              color: const Color(0xFFFFF2C7),
                                              child: const Center(
                                                child: Text('🐔'),
                                              ),
                                            )
                                          : Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                    color: const Color(
                                                      0xFFFFF2C7,
                                                    ),
                                                    child: const Center(
                                                      child: Text('🐔'),
                                                    ),
                                                  ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${p['name']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _listingStatusColor(
                                                  status,
                                                ).withValues(alpha: .12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _listingStatusLabel(status),
                                                style: TextStyle(
                                                  color: _listingStatusColor(
                                                    status,
                                                  ),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Broker: ${p['broker_name']} • ${p['category']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${p['available_stock']} kuku • Mfugaji: ${money(num.tryParse('${p['supplier_price']}') ?? 0)}'
                                          '${p['status'] == 'approved' ? ' • Mteja: ${money(num.tryParse('${p['customer_price']}') ?? 0)}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (status == 'rejected' &&
                                            '${p['rejection_reason'] ?? ''}'
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Sababu: ${p['rejection_reason']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (status == 'pending' || status == 'approved') ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (status == 'pending') ...[
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                        ),
                                        onPressed: () => _reject(p),
                                        child: const Text('Kataa'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: () => _approve(p),
                                        child: const Text('Idhinisha'),
                                      ),
                                    ] else
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade700,
                                        ),
                                        onPressed: () => _expire(p),
                                        child: const Text('Ondoa Sokoni'),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(value),
      selectedColor: green,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
