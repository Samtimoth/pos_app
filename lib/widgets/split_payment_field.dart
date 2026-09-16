import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Result emitted by [SplitPaymentField] on every change. When [enabled] is
/// false the parent should behave exactly as before (send no `payments`
/// array) — this keeps the default single-method checkout path unchanged.
class SplitPaymentResult {
  final bool enabled;
  final bool valid;
  final List<Map<String, dynamic>> payments;
  final double changeAmount;
  const SplitPaymentResult({
    required this.enabled,
    required this.valid,
    required this.payments,
    required this.changeAmount,
  });

  static const off = SplitPaymentResult(enabled: false, valid: true, payments: [], changeAmount: 0);
}

const _methods = <String, String>{
  'cash': 'Cash',
  'mpesa': 'M-Pesa',
  'bank': 'Benki',
  'card': 'Kadi',
  'other': 'Nyingine',
};

/// Optional "gawanya malipo" (split payment) section for the POS checkout —
/// lets a cashier record a sale paid partly cash, partly M-Pesa, partly bank
/// in one transaction, and shows change owed when cash tendered > cash owed.
/// Collapsed (off) by default so the common single-method case is untouched.
class SplitPaymentField extends StatefulWidget {
  final double total;
  final ValueChanged<SplitPaymentResult> onChanged;

  const SplitPaymentField({super.key, required this.total, required this.onChanged});

  @override
  State<SplitPaymentField> createState() => _SplitPaymentFieldState();
}

class _Line {
  String method;
  final TextEditingController amountCtrl;
  final TextEditingController tenderedCtrl;
  final TextEditingController refCtrl;
  _Line({this.method = 'cash', String amount = ''})
      : amountCtrl = TextEditingController(text: amount),
        tenderedCtrl = TextEditingController(),
        refCtrl = TextEditingController();

  void dispose() {
    amountCtrl.dispose();
    tenderedCtrl.dispose();
    refCtrl.dispose();
  }
}

class _SplitPaymentFieldState extends State<SplitPaymentField> {
  final _fmt = NumberFormat('#,###', 'en_US');
  bool _split = false;
  late List<_Line> _lines;

  @override
  void initState() {
    super.initState();
    _lines = [_Line(method: 'cash')];
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  void _emit() {
    if (!_split) {
      widget.onChanged(SplitPaymentResult.off);
      return;
    }
    final payments = <Map<String, dynamic>>[];
    var change = 0.0;
    for (final l in _lines) {
      final amt = _num(l.amountCtrl);
      if (amt <= 0) continue;
      Map<String, dynamic> p = {'method': l.method, 'amount': amt};
      if (l.method == 'cash') {
        final tendered = _num(l.tenderedCtrl);
        if (tendered > amt) {
          change += tendered - amt;
          p['tendered'] = tendered;
        }
      } else if (l.refCtrl.text.trim().isNotEmpty) {
        p['reference'] = l.refCtrl.text.trim();
      }
      payments.add(p);
    }
    final sum = payments.fold<double>(0, (s, p) => s + (p['amount'] as double));
    final valid = payments.isNotEmpty && (sum - widget.total).abs() < 1.0;
    widget.onChanged(SplitPaymentResult(enabled: true, valid: valid, payments: payments, changeAmount: change));
  }

  void _addLine() {
    setState(() => _lines.add(_Line(method: _nextMethod())));
    _emit();
  }

  String _nextMethod() {
    final used = _lines.map((l) => l.method).toSet();
    for (final m in _methods.keys) {
      if (!used.contains(m)) return m;
    }
    return 'other';
  }

  void _removeLine(int i) {
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final sum = _lines.fold<double>(0, (s, l) => s + _num(l.amountCtrl));
    final diff = widget.total - sum;
    final matches = _split && diff.abs() < 1.0 && sum > 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_split_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Gawanya malipo (Cash + M-Pesa + Benki)',
                    style: TextStyle(color: AppColors.textWhite, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _split,
                  activeThumbColor: AppColors.chartBlue,
                  onChanged: (v) {
                    setState(() => _split = v);
                    _emit();
                  },
                ),
              ),
            ],
          ),
          if (_split) ...[
            const SizedBox(height: 8),
            ...List.generate(_lines.length, (i) => _lineRow(i)),
            TextButton.icon(
              onPressed: _lines.length < _methods.length ? _addLine : null,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Ongeza njia', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.chartBlue,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Jumla uliyoweka', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                Text(
                  'TZS ${_fmt.format(sum)} / ${_fmt.format(widget.total)}',
                  style: TextStyle(
                    color: matches ? AppColors.accent : Colors.orangeAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            if (!matches)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  diff > 0
                      ? 'Inapungua TZS ${_fmt.format(diff)}'
                      : 'Inazidi TZS ${_fmt.format(-diff)}',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _lineRow(int i) {
    final line = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: DropdownButtonFormField<String>(
              initialValue: line.method,
              isDense: true,
              dropdownColor: AppColors.bgCard,
              style: TextStyle(color: AppColors.textWhite, fontSize: 12),
              decoration: _fieldDecoration(),
              items: _methods.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                setState(() => line.method = v!);
                _emit();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: line.amountCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textWhite, fontSize: 12.5),
              decoration: _fieldDecoration(hint: 'Kiasi'),
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: line.method == 'cash' ? line.tenderedCtrl : line.refCtrl,
              keyboardType: line.method == 'cash' ? TextInputType.number : TextInputType.text,
              style: TextStyle(color: AppColors.textWhite, fontSize: 12.5),
              decoration: _fieldDecoration(hint: line.method == 'cash' ? 'Alitoa (chenji)' : 'Namba/Ref'),
              onChanged: (_) => _emit(),
            ),
          ),
          if (_lines.length > 1)
            IconButton(
              onPressed: () => _removeLine(i),
              icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.chartBlue)),
      );
}
