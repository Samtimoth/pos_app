import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/local_store.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../utils/order_status.dart';
import '../../widgets/stat_card.dart';
import '../customer/customer_shell.dart';
import 'admin_ads_page.dart';
import 'admin_brokers_page.dart';
import 'admin_listings_page.dart';
import 'admin_messages_page.dart';
import 'admin_order_details_page.dart';
import 'admin_orders_page.dart';
import 'admin_profile_page.dart';
import 'payment_methods_page.dart';
import 'payment_verification_page.dart';

class AdminShell extends StatefulWidget {
  final Session session;
  const AdminShell({super.key, required this.session});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminNotification {
  final String kind;
  final String title;
  final String subtitle;
  final VoidCallback onView;
  _AdminNotification({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onView,
  });
}

class _AdminShellState extends State<AdminShell> {
  late Future<Map<String, dynamic>> dashboardFuture;
  late Future<List<Map<String, dynamic>>> ordersFuture;
  final searchController = TextEditingController();
  String searchQuery = '';
  Timer? _pollTimer;
  final Set<int> _seenOrderIds = {};
  final Set<int> _seenProductIds = {};
  final Set<int> _seenBrokerIds = {};
  final Set<int> _seenAssignmentIds = {};
  bool _seenInitialized = false;
  final List<_AdminNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _seedSeenActivity();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _pollForNewActivity(),
    );
    PushNotificationService.registerToken(widget.session.token);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _seedSeenActivity() async {
    try {
      final results = await Future.wait([
        ordersFuture,
        ApiService.adminProducts(widget.session.token),
        ApiService.adminBrokers(widget.session.token),
        ApiService.adminAssignments(widget.session.token),
      ]);
      _seenOrderIds.addAll(results[0].map((o) => o['id'] as int));
      _seenProductIds.addAll(results[1].map((p) => p['id'] as int));
      _seenBrokerIds.addAll(results[2].map((b) => b['id'] as int));
      _seenAssignmentIds.addAll(results[3].map((a) => a['id'] as int));
      _seenInitialized = true;
    } catch (_) {
      // If seeding fails, the next poll simply keeps waiting to try again.
    }
  }

  void _openOrder(int orderId) {
    _dismissNotifications();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminOrderDetailsPage(token: widget.session.token, orderId: orderId),
      ),
    ).then((_) => _reload());
  }

  void _openListings() {
    _dismissNotifications();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminListingsPage(token: widget.session.token),
      ),
    ).then((_) => _reload());
  }

  void _openBrokers() {
    _dismissNotifications();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminBrokersPage(token: widget.session.token),
      ),
    ).then((_) => _reload());
  }

  Future<void> _pollForNewActivity() async {
    if (!_seenInitialized || !mounted) return;
    try {
      final results = await Future.wait([
        ApiService.orders(widget.session.token),
        ApiService.adminProducts(widget.session.token),
        ApiService.adminBrokers(widget.session.token),
        ApiService.adminAssignments(widget.session.token),
      ]);
      final orders = results[0];
      final products = results[1];
      final brokers = results[2];
      final assignments = results[3];

      final freshOrders = orders
          .where((o) => !_seenOrderIds.contains(o['id'] as int))
          .toList();
      final freshListings = products
          .where(
            (p) =>
                p['status'] == 'pending' &&
                !_seenProductIds.contains(p['id'] as int),
          )
          .toList();
      final freshBrokers = brokers
          .where((b) => !_seenBrokerIds.contains(b['id'] as int))
          .toList();
      final freshAssignments = assignments
          .where((a) => !_seenAssignmentIds.contains(a['id'] as int))
          .toList();

      if (freshOrders.isEmpty &&
          freshListings.isEmpty &&
          freshBrokers.isEmpty &&
          freshAssignments.isEmpty) {
        return;
      }
      if (!mounted) return;

      _seenOrderIds.addAll(orders.map((o) => o['id'] as int));
      _seenProductIds.addAll(products.map((p) => p['id'] as int));
      _seenBrokerIds.addAll(brokers.map((b) => b['id'] as int));
      _seenAssignmentIds.addAll(assignments.map((a) => a['id'] as int));

      final fresh = <_AdminNotification>[
        ...freshOrders.map(
          (o) => _AdminNotification(
            kind: 'order',
            title: 'Oda Mpya!',
            subtitle: '${o['order_number'] ?? ''} • ${o['customer_name'] ?? ''}',
            onView: () => _openOrder(o['id'] as int),
          ),
        ),
        ...freshListings.map(
          (p) => _AdminNotification(
            kind: 'listing',
            title: 'Stock Mpya Imewekwa!',
            subtitle: '${p['name'] ?? ''} • ${p['broker_name'] ?? ''}',
            onView: _openListings,
          ),
        ),
        ...freshBrokers.map(
          (b) => _AdminNotification(
            kind: 'broker',
            title: 'Broker Mpya Amejisajili!',
            subtitle: '${b['name'] ?? ''} • ${b['phone'] ?? ''}',
            onView: _openBrokers,
          ),
        ),
        ...freshAssignments.map(
          (a) => _AdminNotification(
            kind: 'assignment',
            title: a['status'] == 'accepted'
                ? 'Broker Amekubali Kufanya Biashara!'
                : 'Broker Amekataa Kufanya Biashara!',
            subtitle:
                '${a['broker_name'] ?? ''} • ${a['product_name'] ?? ''} • ${a['order_number'] ?? ''}',
            onView: () => _openOrder(a['order_id'] as int),
          ),
        ),
      ];

      setState(() {
        _notifications.insertAll(0, fresh);
        ordersFuture = Future.value(orders);
      });
      HapticFeedback.mediumImpact();
    } catch (_) {
      // Silent — a failed background poll shouldn't disrupt the dashboard.
    }
  }

  void _dismissNotifications() => setState(_notifications.clear);

  void _refresh() {
    dashboardFuture = ApiService.adminDashboard(widget.session.token);
    ordersFuture = ApiService.orders(widget.session.token);
  }

  Future<void> _reload() async {
    setState(_refresh);
    await Future.wait([dashboardFuture, ordersFuture]);
  }

  Future<void> _logout() async {
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomerShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            session: widget.session,
            onLogout: _logout,
            onOpenProfile: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminProfilePage(
                  session: widget.session,
                  loadProfile: () => ApiService.me(widget.session.token),
                  onLogout: _logout,
                ),
              ),
            ),
            notificationCount: _notifications.length,
            onOpenNotifications: _notifications.isEmpty
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminOrdersPage(token: widget.session.token),
                    ),
                  ).then((_) => _reload())
                : _notifications.first.onView,
          ),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                elevation: 4,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  controller: searchController,
                  onChanged: (v) => setState(() => searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Tafuta oda kwa namba au jina la mteja',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              searchController.clear();
                              searchQuery = '';
                            }),
                          ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _ActivityBanner(
                notifications: _notifications,
                onDismiss: _dismissNotifications,
                onView: _notifications.first.onView,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                        const SizedBox(height: 14),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => setState(_refresh),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Jaribu tena'),
                        ),
                      ],
                    ),
                  );
                }
                final data = snapshot.data ?? {};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        StatCard(
                          'Mauzo ya Leo',
                          money(num.tryParse('${data['sales_today'] ?? 0}') ?? 0),
                          Icons.trending_up,
                          green,
                        ),
                        StatCard(
                          'Oda Mpya',
                          '${data['new_orders'] ?? 0}',
                          Icons.receipt_long,
                          Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminOrdersPage(token: widget.session.token),
                            ),
                          ).then((_) => _reload()),
                        ),
                        StatCard(
                          'Listings Zinazosubiri',
                          '${data['pending_listings'] ?? 0}',
                          Icons.fact_check,
                          Colors.orange,
                          onTap: _openListings,
                        ),
                        StatCard(
                          'Brokers Active',
                          '${data['active_brokers'] ?? 0}',
                          Icons.agriculture,
                          Colors.purple,
                          onTap: _openBrokers,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Vitendo vya Haraka',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: .95,
                      children: [
                        _StaggerIn(
                          index: 0,
                          child: _QuickAction(
                            icon: Icons.receipt_long_outlined,
                            label: 'Oda',
                            subtitle: 'Simamia oda zote',
                            color: const Color(0xFF1565C0),
                            background: const Color(0xFFE3F2FD),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminOrdersPage(token: widget.session.token),
                              ),
                            ).then((_) => _reload()),
                          ),
                        ),
                        _StaggerIn(
                          index: 1,
                          child: _QuickAction(
                            icon: Icons.fact_check_outlined,
                            label: 'Listings',
                            subtitle: 'Idhinisha bidhaa',
                            color: const Color(0xFF6A1B9A),
                            background: const Color(0xFFF3E5F5),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminListingsPage(
                                  token: widget.session.token,
                                ),
                              ),
                            ).then((_) => _reload()),
                          ),
                        ),
                        _StaggerIn(
                          index: 2,
                          child: _QuickAction(
                            icon: Icons.agriculture_outlined,
                            label: 'Brokers',
                            subtitle: 'Angalia brokers',
                            color: const Color(0xFFC24010),
                            background: const Color(0xFFFBE7E0),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminBrokersPage(
                                  token: widget.session.token,
                                ),
                              ),
                            ).then((_) => _reload()),
                          ),
                        ),
                        _StaggerIn(
                          index: 3,
                          child: _QuickAction(
                            icon: Icons.verified_outlined,
                            label: 'Thibitisha Malipo',
                            subtitle: 'Hakiki malipo',
                            color: const Color(0xFF9A6700),
                            background: const Color(0xFFFFF3CD),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentVerificationPage(
                                  token: widget.session.token,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _StaggerIn(
                          index: 4,
                          child: _QuickAction(
                            icon: Icons.campaign_outlined,
                            label: 'Matangazo',
                            subtitle: 'Tengeneza tangazo',
                            color: const Color(0xFFAD1457),
                            background: const Color(0xFFFCE4EC),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminAdsPage(token: widget.session.token),
                              ),
                            ).then((_) => _reload()),
                          ),
                        ),
                        _StaggerIn(
                          index: 5,
                          child: _QuickAction(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Njia za Malipo',
                            subtitle: 'Simamia njia',
                            color: green,
                            background: const Color(0xFFFFE0B2),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentMethodsPage(
                                  token: widget.session.token,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _StaggerIn(
                          index: 6,
                          child: _QuickAction(
                            icon: Icons.forum_outlined,
                            label: 'Mawasiliano',
                            subtitle: 'Ongea na wateja',
                            color: const Color(0xFF9A6700),
                            background: const Color(0xFFFFF2C7),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminMessagesPage(
                                  token: widget.session.token,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Oda za Karibuni',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Onyesha upya',
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: ordersFuture,
                      builder: (context, orderSnapshot) {
                        if (orderSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final allOrders = orderSnapshot.data ?? [];
                        final query = searchQuery.trim().toLowerCase();
                        final orders = query.isEmpty
                            ? allOrders
                            : allOrders.where((o) {
                                final orderNumber =
                                    '${o['order_number'] ?? ''}'.toLowerCase();
                                final customerName =
                                    '${o['customer_name'] ?? ''}'.toLowerCase();
                                final customerPhone =
                                    '${o['customer_phone'] ?? ''}'.toLowerCase();
                                return orderNumber.contains(query) ||
                                    customerName.contains(query) ||
                                    customerPhone.contains(query);
                              }).toList();
                        if (orders.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  query.isEmpty
                                      ? 'Hakuna oda mpya'
                                      : 'Hakuna oda inayolingana',
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: orders.take(8).map((order) {
                            final status = '${order['status']}';
                            final color = orderStatusColor(status);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withValues(alpha: .12),
                                    child: Icon(Icons.receipt_long, color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${order['order_number'] ?? 'Oda'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${order['customer_name'] ?? ''}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          orderStatusLabel(status),
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        money(
                                          num.tryParse(
                                                '${order['total_amount'] ?? 0}',
                                              ) ??
                                              0,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final Session session;
  final VoidCallback onLogout;
  final VoidCallback onOpenProfile;
  final int notificationCount;
  final VoidCallback onOpenNotifications;
  const _Header({
    required this.session,
    required this.onLogout,
    required this.onOpenProfile,
    required this.notificationCount,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 14,
      20,
      40,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF7A1F04), green, Color(0xFFF57A22)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      boxShadow: [
        BoxShadow(
          color: Color(0x33004325),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/kukupaja_icon.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'KukuPaja',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Material(
              color: Colors.white.withValues(alpha: .15),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Arifa',
                onPressed: onOpenNotifications,
                icon: Badge(
                  isLabelVisible: notificationCount > 0,
                  label: Text('$notificationCount'),
                  backgroundColor: Colors.red,
                  child: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: Colors.white.withValues(alpha: .15),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Toka',
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white, size: 19),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpenProfile,
          child: Row(
            children: [
              Hero(
                tag: 'admin-avatar',
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: yellow,
                  child: Text(
                    session.name.isNotEmpty
                        ? session.name[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Habari, ${session.name.split(' ').first} \u{1F44B}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Msimamizi (Admin) • KukuPaja',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: color),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 360 + index * 70),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 14),
        child: child,
      ),
    ),
    child: child,
  );
}

class _ActivityBanner extends StatelessWidget {
  final List<_AdminNotification> notifications;
  final VoidCallback onDismiss;
  final VoidCallback onView;
  const _ActivityBanner({
    required this.notifications,
    required this.onDismiss,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final latest = notifications.first;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(scale: value.clamp(0, 1), child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onView,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC107), Color(0xFFFFD95A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33A67C00),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.notifications_active, color: green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notifications.length > 1
                            ? '${notifications.length} Arifa Mpya!'
                            : latest.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF5A2310),
                        ),
                      ),
                      Text(
                        latest.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF5A2310)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: Color(0xFF5A2310)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
