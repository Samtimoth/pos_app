import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DiscountResult {
  final double amount;
  const DiscountResult(this.amount);
  static const zero = DiscountResult(0);
}

/// Optional overall discount at checkout — collapsed by default so it never
/// gets in the way of the common no-discount sale. Amounts above 10% of the
/// subtotal need a manager PIN, checked server-side at submit time (see
/// create_sale.php) — this widget only collects the amount.
class DiscountField extends StatefulWidget {
  final double subtotal;
  final ValueChanged<DiscountResult> onChanged;

  const DiscountField({super.key, required this.subtotal, required this.onChanged});

  @override
  State<DiscountField> createState() => _DiscountFieldState();
}

class _DiscountFieldState extends State<DiscountField> {
  final _ctrl = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _amount {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '').trim()) ?? 0;
    return v.clamp(0, widget.subtotal);
  }

  void _emit() => widget.onChanged(DiscountResult(_open ? _amount : 0));

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _open = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(Icons.sell_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('Ongeza punguzo (discount)', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ]),
          ),
        ),
      );
    }

    final pct = widget.subtotal > 0 ? (_amount / widget.subtotal) * 100 : 0;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(Icons.sell_outlined, size: 16, color: AppColors.chartOrange),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: AppColors.textWhite, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Kiasi cha punguzo (TZS)',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
              isDense: true, border: InputBorder.none,
            ),
            onChanged: (_) {
              setState(() {});
              _emit();
            },
          ),
        ),
        if (_amount > 0)
          Text('${pct.toStringAsFixed(0)}%',
              style: TextStyle(color: pct > 10 ? Colors.orangeAccent : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => setState(() {
            _open = false;
            _ctrl.clear();
            _emit();
          }),
          icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        ),
      ]),
    );
  }
}
