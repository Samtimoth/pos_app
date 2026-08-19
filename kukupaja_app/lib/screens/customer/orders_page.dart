import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/order_status.dart';
import '../../widgets/login_required.dart';
import 'order_details_page.dart';

class OrdersPage extends StatefulWidget {
  final String? token;
  final Future<String?> Function() onRequireLogin;
  const OrdersPage({
    super.key,
    required this.token,
    required this.onRequireLogin,
  });

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Future<List<Map<String, dynamic>>>? _orders;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) _orders = ApiService.orders(widget.token!);
  }

  Future<void> _refresh() async {
    if (widget.token == null) return;
    final future = ApiService.orders(widget.token!);
    setState(() {
      _orders = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Oda Zangu', 'My Orders')),
      actions: [
        if (widget.token != null)
          IconButton(
            tooltip: tr('Onyesha upya', 'Refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
    body: widget.token == null
        ? LoginRequired(
            title: tr('Ingia kuona oda zako', 'Sign in to view your orders'),
            onPressed: () async {
              await widget.onRequireLogin();
            },
          )
        : _ordersList(),
  );

  Widget _ordersList() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _orders,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      final orders = snapshot.data ?? [];
      if (orders.isEmpty) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 130),
              Icon(
                Icons.receipt_long_outlined,
                size: 76,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  tr('Bado hujaweka oda yoyote', 'You have no orders yet'),
                ),
              ),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = '${order['status']}';
            final color = orderStatusColor(status);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OrderDetailsPage(token: widget.token!, order: order),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${order['order_number']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _StatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(displayDate(order['created_at'])),
                          const Spacer(),
                          Text(
                            money(
                              num.tryParse('${order['total_amount']}') ?? 0,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          tween: Tween(begin: 0, end: orderProgress(status)),
                          builder: (context, value, child) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 7,
                                color: color,
                                backgroundColor: color.withValues(alpha: .14),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        orderStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
