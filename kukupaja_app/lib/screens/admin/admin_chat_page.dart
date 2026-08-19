import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class AdminChatPage extends StatefulWidget {
  final String token;
  final int otherUserId;
  final String otherUserName;
  const AdminChatPage({
    super.key,
    required this.token,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
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
      final result = await ApiService.messagesWith(
        widget.token,
        widget.otherUserId,
      );
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
      await ApiService.sendMessageTo(widget.token, widget.otherUserId, text);
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
      backgroundColor: green,
      foregroundColor: Colors.white,
      title: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: .2),
          child: Text(
            widget.otherUserName.isNotEmpty
                ? widget.otherUserName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          widget.otherUserName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    ),
    body: Column(
      children: [
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
                    child: Icon(Icons.forum_outlined, size: 32, color: green),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Bado hakuna mazungumzo',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Andika ujumbe hapa chini kuanza mazungumzo.',
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
                  Text(
                    _time(message['created_at']),
                    style: TextStyle(
                      color: mine ? Colors.white70 : Colors.grey,
                      fontSize: 10.5,
                    ),
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
