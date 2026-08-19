import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import 'admin_chat_page.dart';

class AdminMessagesPage extends StatefulWidget {
  final String token;
  const AdminMessagesPage({super.key, required this.token});

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  late Future<List<Map<String, dynamic>>> contactsFuture;

  @override
  void initState() {
    super.initState();
    contactsFuture = ApiService.adminMessageContacts(widget.token);
  }

  Future<void> _reload() async {
    setState(
      () => contactsFuture = ApiService.adminMessageContacts(widget.token),
    );
    await contactsFuture;
  }

  String _time(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mawasiliano'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: contactsFuture,
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
          final contacts = snapshot.data ?? [];
          if (contacts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                const Center(child: Text('Hakuna mazungumzo bado')),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final c = contacts[index];
              final unread = int.tryParse('${c['unread'] ?? 0}') ?? 0;
              final isBroker = c['role'] == 'broker';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: isBroker
                      ? const Color(0xFFFBE7E0)
                      : const Color(0xFFE8EAF6),
                  child: Text(
                    '${c['name']}'.isNotEmpty
                        ? '${c['name']}'[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isBroker
                          ? const Color(0xFFC24010)
                          : const Color(0xFF303F9F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  '${c['name']}',
                  style: TextStyle(
                    fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${c['last_message'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread > 0 ? Colors.black87 : Colors.grey.shade600,
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _time(c['last_at']),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 6),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminChatPage(
                        token: widget.token,
                        otherUserId: c['id'] as int,
                        otherUserName: '${c['name']}',
                      ),
                    ),
                  );
                  if (context.mounted) _reload();
                },
              );
            },
          );
        },
      ),
    ),
  );
}
