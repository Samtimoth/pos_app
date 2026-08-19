import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class SupportPage extends StatefulWidget {
  final String token;
  const SupportPage({super.key, required this.token});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  Timer? refreshTimer;
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final result = await ApiService.messages(widget.token);
      if (!mounted) return;
      final hasNewMessage = result.length != messages.length;
      setState(() {
        messages = result;
        loading = false;
        error = null;
      });
      if (hasNewMessage || !silent) _scrollToBottom();
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;
    FocusScope.of(context).unfocus();
    setState(() => sending = true);
    try {
      await ApiService.sendMessage(widget.token, text);
      messageController.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String _time(dynamic value) {
    final text = '${value ?? ''}';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Color(0xFFFFE0B2),
          child: Icon(Icons.support_agent, color: green),
        ),
        title: Text(
          'Admin KukuPaja',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Msaada rasmi ndani ya app'),
      ),
    ),
    body: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: yellow.withValues(alpha: .16),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 17, color: green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ujumbe wako unafika moja kwa moja kwa admin.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _conversation()),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Andika ujumbe wako...',
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : _send,
                  padding: const EdgeInsets.all(15),
                  icon: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _conversation() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Jaribu tena'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: messages.isEmpty ? 1 : messages.length,
        itemBuilder: (context, index) {
          if (messages.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFFFFE0B2),
                    child: Icon(Icons.waving_hand, size: 32, color: green),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Karibu kwenye msaada wa KukuPaja',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Andika ujumbe hapa chini, admin atakujibu ndani ya app.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          final message = messages[index];
          final mine =
              message['is_mine'] == true || '${message['is_mine']}' == '1';
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 310),
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.fromLTRB(13, 10, 10, 7),
              decoration: BoxDecoration(
                color: mine
                    ? green
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(mine ? 17 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 17),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${message['message'] ?? ''}',
                    style: TextStyle(
                      color: mine ? Colors.white : null,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _time(message['created_at']),
                        style: TextStyle(
                          color: mine ? Colors.white70 : Colors.grey,
                          fontSize: 10.5,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          '${message['is_read']}' == '1' ||
                                  message['is_read'] == true
                              ? Icons.done_all
                              : Icons.done,
                          size: 15,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
