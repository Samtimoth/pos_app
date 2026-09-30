import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';
import '../utils/cat_style.dart';
import 'suppliers_screen.dart';

class AddBatchSheet extends StatefulWidget {
  final Product product;
  final VoidCallback onSaved;

  const AddBatchSheet({
    super.key,
    required this.product,
    required this.onSaved,
  });

  static void show(
    BuildContext context,
    Product product, {
    required VoidCallback onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBatchSheet(product: product, onSaved: onSaved),
    );
  }

  @override
  State<AddBatchSheet> createState() => _AddBatchSheetState();
}

class _AddBatchSheetState extends State<AddBatchSheet> {
  final _form = GlobalKey<FormState>();
  final _qtyCtr = TextEditingController(text: '1');
  final _priceCtr = TextEditingController();
  final _batchCtr = TextEditingController();
  final _mfgCtr = TextEditingController();
  final _expiryCtr = TextEditingController();
  final _supplierCtr = TextEditingController();
  final _notesCtr = TextEditingController();

  final _fmt = NumberFormat('#,###', 'en_US');
  final _displayDateFmt = DateFormat('dd/MM/yyyy');
  final _apiDateFmt = DateFormat('yyyy-MM-dd');

  String _expiryApiDate = '';
  int? _pickedSupplierId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _priceCtr.text = widget.product.buyPrice.toStringAsFixed(0);
    _batchCtr.text =
        'BATCH-${(now.year % 100).toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}-001';
    _mfgCtr.text = _displayDateFmt.format(now);
    _priceCtr.addListener(_refresh);
    _qtyCtr.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _priceCtr.removeListener(_refresh);
    _qtyCtr.removeListener(_refresh);
    _qtyCtr.dispose();
    _priceCtr.dispose();
    _batchCtr.dispose();
    _mfgCtr.dispose();
    _expiryCtr.dispose();
    _supplierCtr.dispose();
    _notesCtr.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyCtr.text.trim()) ?? 0;
  double get _buyPrice => double.tryParse(_priceCtr.text.trim()) ?? 0;
  double get _sellPrice => widget.product.sellPrice;
  double get _unitProfit => _sellPrice - _buyPrice;
  double get _totalBuy => _buyPrice * _qty;
  double get _totalSell => _sellPrice * _qty;
  double get _expectedProfit => _unitProfit * _qty;

  String get _unitLabel => widget.product.unit.trim().isNotEmpty
      ? widget.product.unit.trim()
      : 'pcs';

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;

    final notes = [
      if (_pickedSupplierId == null && _supplierCtr.text.trim().isNotEmpty)
        'Supplier: ${_supplierCtr.text.trim()}',
      if (_mfgCtr.text.trim().isNotEmpty) 'Mfg date: ${_mfgCtr.text.trim()}',
      if (_notesCtr.text.trim().isNotEmpty) _notesCtr.text.trim(),
    ].join('\n');

    setState(() => _saving = true);
    try {
      final res = await app.api!.addProductBatch(
        productId: widget.product.productId,
        businessId: app.selectedBusiness!.businessId,
        quantity: _qty,
        buyPrice: _buyPrice,
        batchNumber: _batchCtr.text.trim(),
        expiryDate: _expiryApiDate,
        notes: notes,
        supplierId: _pickedSupplierId,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotification.show(
          context,
          L.of(context).isSw ? 'Stock imeongezwa!' : 'Stock added!',
          AppColors.accent,
          icon: Icons.check_circle_rounded,
        );
        Navigator.pop(context);
        widget.onSaved();
      } else {
        AppNotification.show(
          context,
          res['message'] as String? ?? 'Error',
          AppColors.chartRed,
          icon: Icons.error_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          '$e',
          AppColors.chartRed,
          icon: Icons.error_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickSupplier() async {
    final picked = await Navigator.of(context).push<Supplier>(
      MaterialPageRoute(builder: (_) => const SuppliersScreen(pickMode: true)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedSupplierId = picked.supplierId;
      _supplierCtr.text = picked.name;
    });
  }

  Future<void> _pickManufactureDate() async {
    final now = DateTime.now();
    final date = await _pickDate(
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _mfgCtr.text = _displayDateFmt.format(date));
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final date = await _pickDate(
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(() {
        _expiryCtr.text = _displayDateFmt.format(date);
        _expiryApiDate = _apiDateFmt.format(date);
      });
    }
  }

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            surface: AppColors.bgCard,
            onSurface: AppColors.textWhite,
          ),
        ),
        child: child!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final mq = MediaQuery.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: mq.size.height,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _Header(product: widget.product),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    18 + mq.padding.bottom,
                  ),
                  children: [
                    _ProductCard(product: widget.product),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      text: l.isSw ? 'Maelezo ya Stock' : 'Stock Details',
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      ctrl: _qtyCtr,
                      label: l.isSw ? 'Kiasi' : 'Quantity',
                      keyboardType: TextInputType.number,
                      suffixText: _unitLabel,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return (n == null || n < 1)
                            ? (l.isSw
                                  ? 'Weka kiasi sahihi'
                                  : 'Enter a valid quantity')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _priceCtr,
                      label: l.isSw
                          ? 'Gharama kwa Kipande'
                          : 'Buy Cost Per Unit',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixText: 'TZS ',
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return (n == null || n < 0)
                            ? (l.isSw
                                  ? 'Weka gharama sahihi'
                                  : 'Enter a valid cost')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _ReadOnlyValue(
                      label: l.isSw ? 'Bei ya Kuuza' : 'Sell Price',
                      value: 'TZS ${_fmt.format(_sellPrice)}',
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      text: l.isSw ? 'Maelezo ya Batch' : 'Batch Details',
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      ctrl: _batchCtr,
                      label: l.isSw ? 'Batch Namba' : 'Batch Number',
                      suffixIcon: Icons.qr_code_scanner_rounded,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _mfgCtr,
                      label: l.isSw
                          ? 'Tarehe ya Kutengeneza'
                          : 'Manufacture Date',
                      readOnly: true,
                      suffixIcon: Icons.calendar_month_outlined,
                      onTap: _pickManufactureDate,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _expiryCtr,
                      label: l.isSw ? 'Tarehe ya Kuisha' : 'Expiry Date',
                      readOnly: true,
                      suffixIcon: Icons.calendar_month_outlined,
                      onTap: _pickExpiryDate,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _supplierCtr,
                      label: l.isSw ? 'Mtoa Huduma / Supplier' : 'Supplier',
                      readOnly: true,
                      suffixIcon: Icons.local_shipping_outlined,
                      onTap: _pickSupplier,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _notesCtr,
                      label: l.isSw
                          ? 'Maelezo (Si lazima)'
                          : 'Notes (optional)',
                      hintText: l.isSw
                          ? 'Andika maelezo yoyote...'
                          : 'Write any notes...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 22),
                    _SummaryCard(
                      fmt: _fmt,
                      qty: _qty,
                      unit: _unitLabel,
                      totalBuy: _totalBuy,
                      totalSell: _totalSell,
                      expectedProfit: _expectedProfit,
                    ),
                  ],
                ),
              ),
            ),
            _SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Product product;

  const _Header({required this.product});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final topPadding = MediaQueryData.fromView(View.of(context)).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, topPadding + 10, 16, 18),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.isSw ? 'Ongeza Stock (Batch)' : 'Add Stock (Batch)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.isSw
                        ? 'Ongeza stock mpya kwa batch'
                        : 'Add new stock by batch',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(55)),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final catColor = CatStyle.color(product.category);
    final catIcon = CatStyle.icon(product.category);
    final unit = product.unit.trim().isNotEmpty ? product.unit.trim() : 'pcs';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withAlpha(130)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: catColor.withAlpha(14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withAlpha(90)),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.image.isNotEmpty
                ? Image.network(
                    product.image,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) =>
                        Icon(catIcon, color: catColor, size: 32),
                  )
                : Icon(catIcon, color: catColor, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.category.isNotEmpty
                      ? product.category
                      : L.of(context).noCategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textLight, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'SKU: ${product.barcode.isNotEmpty ? product.barcode : 'P${product.productId}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  L.of(context).isSw ? 'Stock Sasa' : 'Current',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${product.stock}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w900,
      fontSize: 16,
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final IconData? suffixIcon;
  final String? suffixText;
  final String? prefixText;
  final int maxLines;
  final bool readOnly;

  const _Field({
    required this.ctrl,
    required this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onTap,
    this.suffixIcon,
    this.suffixText,
    this.prefixText,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    validator: validator,
    onTap: onTap,
    readOnly: readOnly,
    maxLines: maxLines,
    style: TextStyle(
      color: AppColors.textWhite,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
    decoration: _fieldDecoration(
      label: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      prefixText: prefixText,
    ),
  );
}

class _ReadOnlyValue extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value,
    readOnly: true,
    style: TextStyle(
      color: AppColors.textWhite,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
    decoration: _fieldDecoration(label: label),
  );
}

InputDecoration _fieldDecoration({
  required String label,
  String? hintText,
  IconData? suffixIcon,
  String? suffixText,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixText: prefixText,
    suffixText: suffixText,
    suffixIcon: suffixIcon != null
        ? Icon(suffixIcon, color: AppColors.textLight, size: 20)
        : null,
    labelStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
    prefixStyle: TextStyle(
      color: AppColors.textWhite,
      fontWeight: FontWeight.w700,
    ),
    suffixStyle: TextStyle(
      color: AppColors.textLight,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: AppColors.bgCard,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border.withAlpha(140)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border.withAlpha(140)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.chartRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.chartRed, width: 1.5),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  final NumberFormat fmt;
  final int qty;
  final String unit;
  final double totalBuy;
  final double totalSell;
  final double expectedProfit;

  const _SummaryCard({
    required this.fmt,
    required this.qty,
    required this.unit,
    required this.totalBuy,
    required this.totalSell,
    required this.expectedProfit,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final profitColor = expectedProfit >= 0
        ? AppColors.primary
        : AppColors.chartRed;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withAlpha(130)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              l.isSw ? 'Muhtasari' : 'Summary',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          _SummaryRow(
            label: l.isSw ? 'Kiasi' : 'Quantity',
            value: '$qty $unit',
          ),
          _SummaryRow(
            label: l.isSw ? 'Gharama ya Kununua' : 'Purchase Cost',
            value: 'TZS ${fmt.format(totalBuy)}',
          ),
          _SummaryRow(
            label: l.isSw ? 'Bei ya Kuuza (Jumla)' : 'Total Selling Price',
            value: 'TZS ${fmt.format(totalSell)}',
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: profitColor.withAlpha(16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.isSw ? 'Faida Inayotarajiwa' : 'Expected Profit',
                    style: TextStyle(
                      color: profitColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  'TZS ${fmt.format(expectedProfit.abs())}',
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textLight, fontSize: 14),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onPressed;

  const _SaveButton({required this.saving, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 10, 18, bottom + 12),
      color: AppColors.bg,
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: saving ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      l.isSw ? 'Hifadhi Stock' : 'Save Stock',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
