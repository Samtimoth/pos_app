import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import 'admin_broker_detail_page.dart';

class AdminBrokersPage extends StatefulWidget {
  final String token;
  const AdminBrokersPage({super.key, required this.token});

  @override
  State<AdminBrokersPage> createState() => _AdminBrokersPageState();
}

class _AdminBrokersPageState extends State<AdminBrokersPage> {
  late Future<List<Map<String, dynamic>>> brokersFuture;
  int? busyId;

  @override
  void initState() {
    super.initState();
    brokersFuture = ApiService.adminBrokers(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      brokersFuture = ApiService.adminBrokers(widget.token);
    });
    await brokersFuture;
  }

  Future<void> _toggle(int brokerId) async {
    setState(() => busyId = brokerId);
    try {
      await ApiService.toggleBrokerVerified(widget.token, brokerId);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Brokers'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: brokersFuture,
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
          final brokers = snapshot.data ?? [];
          if (brokers.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.agriculture_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                const Center(child: Text('Hakuna broker aliyesajiliwa')),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: brokers.length,
            itemBuilder: (context, index) {
              final b = brokers[index];
              final verified = b['is_verified'] == true || '${b['is_verified']}' == '1';
              final busy = busyId == b['id'];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminBrokerDetailPage(
                          token: widget.token,
                          broker: b,
                        ),
                      ),
                    );
                    if (context.mounted) _reload();
                  },
                  leading: CircleAvatar(
                    backgroundColor: verified
                        ? const Color(0xFFFFE0B2)
                        : Colors.grey.shade200,
                    child: Text(
                      '${b['name']}'.isNotEmpty
                          ? '${b['name']}'[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: verified ? green : Colors.grey.shade600,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    '${b['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${b['phone']} • ${b['location'] ?? ''}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilterChip(
                          label: Text(verified ? 'Amethibitishwa' : 'Thibitisha'),
                          avatar: Icon(
                            verified ? Icons.verified : Icons.hourglass_empty,
                            size: 17,
                            color: verified ? green : Colors.orange,
                          ),
                          selected: verified,
                          onSelected: (_) => _toggle(b['id'] as int),
                          selectedColor: const Color(0xFFFFE0B2),
                          labelStyle: TextStyle(
                            color: verified ? green : Colors.orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
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
