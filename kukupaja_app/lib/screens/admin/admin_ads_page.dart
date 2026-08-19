import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class AdminAdsPage extends StatefulWidget {
  final String token;
  const AdminAdsPage({super.key, required this.token});

  @override
  State<AdminAdsPage> createState() => _AdminAdsPageState();
}

class _AdminAdsPageState extends State<AdminAdsPage> {
  late Future<List<Map<String, dynamic>>> adsFuture;
  int? busyId;

  @override
  void initState() {
    super.initState();
    adsFuture = ApiService.adminAds(widget.token);
  }

  Future<void> _reload() async {
    setState(() {
      adsFuture = ApiService.adminAds(widget.token);
    });
    await adsFuture;
  }

  Future<void> _toggle(int id) async {
    setState(() => busyId = id);
    try {
      await ApiService.toggleAd(widget.token, id);
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

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateAdSheet(token: widget.token),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Matangazo'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _openCreate,
      backgroundColor: green,
      icon: const Icon(Icons.add),
      label: const Text('Tangazo Jipya'),
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: adsFuture,
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
          final ads = snapshot.data ?? [];
          if (ads.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.campaign_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                const Center(child: Text('Hakuna tangazo bado')),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              final active = ad['is_active'] == true || '${ad['is_active']}' == '1';
              final busy = busyId == ad['id'];
              final imageUrl = '${ad['image_url'] ?? ''}';
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 130,
                          color: const Color(0xFFFFF2C7),
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${ad['title']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (active ? green : Colors.grey)
                                      .withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  active ? 'Hai' : 'Imezimwa',
                                  style: TextStyle(
                                    color: active ? green : Colors.grey.shade700,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ('${ad['subtitle'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${ad['subtitle']}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${ad['advertiser_name']} • ${ad['target_category']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Malipo: ${money(num.tryParse('${ad['amount_paid']}') ?? 0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          active ? Colors.red : green,
                                      side: BorderSide(
                                        color: active ? Colors.red : green,
                                      ),
                                    ),
                                    onPressed: () => _toggle(ad['id'] as int),
                                    child: Text(active ? 'Zima' : 'Washa'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class _CreateAdSheet extends StatefulWidget {
  final String token;
  const _CreateAdSheet({required this.token});

  @override
  State<_CreateAdSheet> createState() => _CreateAdSheetState();
}

class _CreateAdSheetState extends State<_CreateAdSheet> {
  final advertiserController = TextEditingController();
  final titleController = TextEditingController();
  final subtitleController = TextEditingController();
  final imageUrlController = TextEditingController();
  final buttonTextController = TextEditingController(text: 'Angalia Sasa');
  final amountController = TextEditingController(text: '0');
  String targetCategory = 'wote';
  bool saving = false;

  static const categories = ['wote', 'kienyeji', 'broiler', 'layer', 'vingine'];

  @override
  void dispose() {
    advertiserController.dispose();
    titleController.dispose();
    subtitleController.dispose();
    imageUrlController.dispose();
    buttonTextController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (advertiserController.text.trim().isEmpty ||
        titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jaza jina la muuzaji na kichwa cha tangazo')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await ApiService.createAd(widget.token, {
        'advertiser_name': advertiserController.text.trim(),
        'title': titleController.text.trim(),
        'subtitle': subtitleController.text.trim(),
        'image_url': imageUrlController.text.trim(),
        'button_text': buttonTextController.text.trim(),
        'target_category': targetCategory,
        'amount_paid': num.tryParse(amountController.text) ?? 0,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tangazo Jipya',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: advertiserController,
            decoration: const InputDecoration(
              labelText: 'Jina la Muuzaji',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Kichwa cha Tangazo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: subtitleController,
            decoration: const InputDecoration(
              labelText: 'Maelezo mafupi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: imageUrlController,
            decoration: const InputDecoration(
              labelText: 'Picha (URL)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: buttonTextController,
            decoration: const InputDecoration(
              labelText: 'Maneno ya Kitufe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: targetCategory,
            decoration: const InputDecoration(
              labelText: 'Kundi Linalolengwa',
              border: OutlineInputBorder(),
            ),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => targetCategory = v ?? 'wote'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Malipo yaliyopokelewa (TZS)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : _submit,
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Chapisha Tangazo'),
            ),
          ),
        ],
      ),
    ),
  );
}
