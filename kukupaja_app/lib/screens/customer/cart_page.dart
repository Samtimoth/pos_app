import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/login_required.dart';

class CartPage extends StatefulWidget {
  final List<Product> cart;
  final String? token;
  final Future<String?> Function() onRequireLogin;
  final VoidCallback onClear;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onRemove;
  final VoidCallback onGoToHome;
  const CartPage({
    super.key,
    required this.cart,
    required this.token,
    required this.onRequireLogin,
    required this.onClear,
    required this.onAdd,
    required this.onRemove,
    required this.onGoToHome,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final address = TextEditingController();
  final reference = TextEditingController();
  final payerName = TextEditingController();
  late Future<List<Map<String, dynamic>>> paymentMethodsFuture;
  Map<String, dynamic>? selectedMethod;
  XFile? proofImage;
  bool submitting = false;
  bool uploadingImage = false;

  @override
  void initState() {
    super.initState();
    paymentMethodsFuture = ApiService.paymentMethods();
  }

  @override
  void dispose() {
    address.dispose();
    reference.dispose();
    payerName.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => proofImage = picked);
  }

  Future<void> _submit(List<Product> cart) async {
    if (address.text.trim().length < 3) {
      _showMessage(
        tr('Weka anwani ya delivery kwanza', 'Enter your delivery address'),
      );
      return;
    }
    final isCash = selectedMethod == null;
    if (!isCash &&
        reference.text.trim().isEmpty &&
        proofImage == null) {
      _showMessage(
        tr(
          'Weka namba ya muamala au pakia screenshot ya malipo',
          'Enter a transaction reference or upload a payment screenshot',
        ),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      final activeToken = widget.token ?? await widget.onRequireLogin();
      if (activeToken == null) {
        setState(() => submitting = false);
        return;
      }
      String? proofUrl;
      if (proofImage != null) {
        setState(() => uploadingImage = true);
        proofUrl = await ApiService.uploadPaymentProof(activeToken, proofImage!);
        if (mounted) setState(() => uploadingImage = false);
      }
      final number = await ApiService.createOrder(
        activeToken,
        cart,
        address.text.trim(),
        isCash ? 'cash' : '${selectedMethod!['name']}'.toLowerCase().replaceAll(
          ' ',
          '_',
        ),
        paymentMethodId: isCash ? null : selectedMethod!['id'] as int,
        paymentReference: reference.text.trim().isEmpty
            ? null
            : reference.text.trim(),
        paymentPayerName: payerName.text.trim().isEmpty
            ? null
            : payerName.text.trim(),
        paymentProofImage: proofUrl,
      );
      widget.onClear();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('Oda imepokelewa', 'Order received')),
          content: Text(
            '${tr('Namba ya oda', 'Order number')}: $number\n${tr('Admin atathibitisha na kumchagua broker anayefaa.', 'Admin will confirm and assign the right broker.')}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Kikapu na Malipo', 'Cart & Payment'))),
        body: LoginRequired(
          title: tr(
            'Ingia ili uone kikapu chako na kuweka oda',
            'Sign in to view your cart and place an order',
          ),
          onPressed: () async {
            await widget.onRequireLogin();
          },
        ),
      );
    }
    final cart = widget.cart;
    final total = cart.fold<int>(0, (sum, p) => sum + p.price);
    final grouped = <int, ({Product product, int quantity})>{};
    for (final product in cart) {
      final old = grouped[product.id];
      grouped[product.id] = (
        product: product,
        quantity: (old?.quantity ?? 0) + 1,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kikapu na Malipo', 'Cart & Payment'))),
      body: cart.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              children: [
                const SizedBox(height: 90),
                Center(
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3CD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 52,
                      color: green,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Text(
                    tr('Kikapu chako ni tupu', 'Your cart is empty'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    tr(
                      'Bidhaa 0 • Jumla TSh 0',
                      '0 items • Total TSh 0',
                    ),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onGoToHome,
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(tr('Anza Kununua', 'Start Shopping')),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...grouped.values.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFFFF2C7),
                          child: Text('🐔'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                money(item.product.price * item.quantity),
                                style: const TextStyle(
                                  color: green,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => widget.onRemove(item.product),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        IconButton(
                          onPressed: item.quantity < item.product.stock
                              ? () => widget.onAdd(item.product)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: address,
                  decoration: InputDecoration(
                    labelText: tr('Anwani ya usafirishaji', 'Delivery address'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('Njia ya Malipo', 'Payment Method'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: paymentMethodsFuture,
                  builder: (context, snapshot) {
                    final methods = snapshot.data ?? [];
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MethodChip(
                          label: tr('Lipa Ukipokea', 'Cash on delivery'),
                          icon: Icons.local_shipping_outlined,
                          selected: selectedMethod == null,
                          onTap: () => setState(() {
                            selectedMethod = null;
                            proofImage = null;
                            reference.clear();
                          }),
                        ),
                        ...methods.map(
                          (method) => _MethodChip(
                            label: '${method['name']}',
                            icon: Icons.smartphone_outlined,
                            selected: selectedMethod?['id'] == method['id'],
                            onTap: () =>
                                setState(() => selectedMethod = method),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (selectedMethod != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: green.withValues(alpha: .25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: green, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              tr('Tuma malipo kwa', 'Send payment to'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${selectedMethod!['account_name']} • ${selectedMethod!['account_number']}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if ('${selectedMethod!['instructions'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${selectedMethod!['instructions']}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          tr(
                            'Baada ya kulipa, thibitisha kwa mojawapo:',
                            'After paying, confirm with one of these:',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: reference,
                          decoration: InputDecoration(
                            labelText: tr(
                              'Namba ya muamala (Reference)',
                              'Transaction reference',
                            ),
                            prefixIcon: const Icon(Icons.confirmation_number_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: payerName,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: tr(
                              'Jina la Malipo (aliyetuma)',
                              'Payer name',
                            ),
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              tr('au', 'or'),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (proofImage == null)
                          OutlinedButton.icon(
                            onPressed: _pickProofImage,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              tr(
                                'Pakia Screenshot ya Malipo',
                                'Upload payment screenshot',
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(proofImage!.path),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr('Picha imechaguliwa', 'Screenshot selected'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => proofImage = null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('Jumla', 'Total'),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    Text(
                      money(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: submitting ? null : () => _submit(cart),
                    child: submitting
                        ? Text(
                            uploadingImage
                                ? tr('Inapakia picha...', 'Uploading photo...')
                                : tr('Inatuma...', 'Submitting...'),
                          )
                        : Text(tr('Thibitisha Oda', 'Confirm Order')),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? green : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? green : const Color(0xFFE3DAD2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? Colors.white : green),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
