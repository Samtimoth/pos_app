import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class PaymentMethodsPage extends StatefulWidget {
  final String token;
  const PaymentMethodsPage({super.key, required this.token});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  late Future<List<Map<String, dynamic>>> methodsFuture;

  @override
  void initState() {
    super.initState();
    methodsFuture = ApiService.adminPaymentMethods(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      methodsFuture = ApiService.adminPaymentMethods(widget.token);
    });
    await methodsFuture;
  }

  Future<void> _toggleActive(Map<String, dynamic> method) async {
    try {
      await ApiService.updatePaymentMethod(widget.token, {
        'id': method['id'],
        'is_active': !(method['is_active'] == 1 || method['is_active'] == true),
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final accountNameController = TextEditingController(
      text: existing?['account_name'] ?? '',
    );
    final accountNumberController = TextEditingController(
      text: existing?['account_number'] ?? '',
    );
    final instructionsController = TextEditingController(
      text: existing?['instructions'] ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Ongeza Njia ya Malipo' : 'Hariri Njia ya Malipo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Jina (mfano M-Pesa)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accountNameController,
                decoration: const InputDecoration(labelText: 'Jina la akaunti'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accountNumberController,
                decoration: const InputDecoration(labelText: 'Namba ya akaunti'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instructionsController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Maelekezo (hiari)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hifadhi'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    if (nameController.text.trim().isEmpty ||
        accountNameController.text.trim().isEmpty ||
        accountNumberController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jaza taarifa zote muhimu')),
      );
      return;
    }
    try {
      final payload = {
        'name': nameController.text.trim(),
        'account_name': accountNameController.text.trim(),
        'account_number': accountNumberController.text.trim(),
        'instructions': instructionsController.text.trim(),
      };
      if (existing == null) {
        await ApiService.addPaymentMethod(widget.token, payload);
      } else {
        await ApiService.updatePaymentMethod(widget.token, {
          ...payload,
          'id': existing['id'],
        });
      }
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
      title: const Text('Njia za Malipo'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openEditor(),
      icon: const Icon(Icons.add),
      label: const Text('Ongeza'),
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: methodsFuture,
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
          final methods = snapshot.data ?? [];
          if (methods.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Bado hakuna njia ya malipo')),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: methods.length,
            itemBuilder: (context, index) {
              final method = methods[index];
              final active = method['is_active'] == 1 || method['is_active'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: active
                        ? green.withValues(alpha: .15)
                        : Colors.grey.shade300,
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: active ? green : Colors.grey,
                    ),
                  ),
                  title: Text('${method['name']}'),
                  subtitle: Text(
                    '${method['account_name']} • ${method['account_number']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: active,
                        onChanged: (_) => _toggleActive(method),
                      ),
                      IconButton(
                        onPressed: () => _openEditor(existing: method),
                        icon: const Icon(Icons.edit_outlined),
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
