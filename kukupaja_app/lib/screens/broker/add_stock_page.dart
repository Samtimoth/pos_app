import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';

class AddStockPage extends StatefulWidget {
  final String token;
  const AddStockPage({super.key, required this.token});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

const _chickenTypes = [
  'kienyeji',
  'broiler',
  'kuku_wakisasa',
  'mayai',
  'vifaranga',
  'vingine',
];

String _chickenTypeLabel(String value) => switch (value) {
  'kienyeji' => 'Kienyeji',
  'broiler' => 'Broiler',
  'kuku_wakisasa' => 'Kuku wa Kisasa',
  'mayai' => 'Mayai',
  'vifaranga' => 'Vifaranga',
  _ => 'Nyingine',
};

class _AddStockPageState extends State<AddStockPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final otherType = TextEditingController();
  final stock = TextEditingController();
  final weight = TextEditingController();
  final age = TextEditingController();
  final vaccination = TextEditingController();
  final price = TextEditingController();
  final location = TextEditingController();
  bool loading = false;
  bool uploadingImage = false;
  String category = 'kienyeji';
  XFile? pickedImage;

  @override
  void dispose() {
    for (final controller in [
      name,
      otherType,
      stock,
      weight,
      age,
      vaccination,
      price,
      location,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => pickedImage = picked);
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      String? imageUrl;
      if (pickedImage != null) {
        setState(() => uploadingImage = true);
        imageUrl = await ApiService.uploadProductImage(
          widget.token,
          pickedImage!,
        );
        if (mounted) setState(() => uploadingImage = false);
      }
      final description = category == 'vingine'
          ? 'Aina: ${otherType.text.trim()}. Listing kutoka kwa broker'
          : 'Listing kutoka kwa broker';
      await ApiService.submitBrokerProduct(widget.token, {
        'category': category,
        'name': name.text.trim(),
        'description': description,
        'stock': int.parse(stock.text),
        'weight': weight.text.trim(),
        'age': age.text.trim(),
        'vaccination': vaccination.text.trim(),
        'supplier_price': double.parse(price.text),
        'location': location.text.trim(),
        'image_url': imageUrl,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing imetumwa kwa Admin')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weka Kuku')),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Aina ya Kuku',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _chickenTypes
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_chickenTypeLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => category = value ?? 'vingine'),
            ),
          ),
          if (category == 'vingine')
            _field(
              otherType,
              'Fafanua aina (mfano: Sasso, Kroiler)',
              icon: Icons.short_text,
            ),
          _field(name, 'Jina la Bidhaa (Tangazo)', icon: Icons.label_outline),
          _field(
            stock,
            'Kiasi (Kuku)',
            icon: Icons.inventory_2_outlined,
            numeric: true,
          ),
          _field(
            weight,
            'Uzito wa wastani',
            icon: Icons.monitor_weight_outlined,
            hint: 'mfano: 1.5kg',
          ),
          _field(age, 'Umri', icon: Icons.cake_outlined, hint: 'mfano: wiki 6'),
          _field(
            vaccination,
            'Chanjo',
            icon: Icons.vaccines_outlined,
            hint: 'mfano: Newcastle, Gumboro',
          ),
          _field(
            price,
            'Bei kwa Kuku',
            icon: Icons.payments_outlined,
            numeric: true,
          ),
          _field(location, 'Eneo / Wilaya', icon: Icons.location_on_outlined),
          Text(
            'Picha ya bidhaa (hiari)',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          if (pickedImage == null)
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Chagua Picha'),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(pickedImage!.path),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Picha imechaguliwa',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => pickedImage = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading ? null : submit,
            child: Text(
              uploadingImage
                  ? 'Inapakia picha...'
                  : loading
                  ? 'Inatuma...'
                  : 'Wasilisha kwa Admin kwa Idhini',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    required IconData icon,
    bool numeric = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label inahitajika' : null,
    ),
  );
}
