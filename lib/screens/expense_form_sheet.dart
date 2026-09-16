import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Add / edit one expense. Returns true when saved.
class ExpenseFormSheet extends StatefulWidget {
  final Expense? existing;
  const ExpenseFormSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {Expense? existing}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ExpenseFormSheet(existing: existing),
      );

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String _category = Expense.categories.last;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amount.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toInt().toString()
          : e.amount.toString();
      _desc.text = e.description;
      _category = e.category;
      _date = DateTime.tryParse(e.expenseDate) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amt == null || amt <= 0) {
      AppNotification.show(context, 'Weka kiasi sahihi', AppColors.chartOrange,
          icon: Icons.error_outline_rounded);
      return;
    }
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    if (app.api == null || biz == null) return;
    setState(() => _saving = true);
    try {
      final res = await app.api!.saveExpense(
        businessId: biz.businessId,
        expenseId: widget.existing?.expenseId,
        branchId: app.selectedBranch?.branchId,
        userId: app.user?.userId,
        category: _category,
        description: _desc.text.trim(),
        amount: amt,
        expenseDate: DateFormat('yyyy-MM-dd').format(_date),
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotification.show(context, '${res['message'] ?? 'Imehifadhiwa'}',
            res['offline'] == true ? Colors.orange : AppColors.accent,
            icon: Icons.check_circle_rounded);
        Navigator.pop(context, true);
      } else {
        AppNotification.show(context, '${res['message'] ?? 'Hitilafu'}', AppColors.chartRed,
            icon: Icons.error_rounded);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final edit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: AppColors.chartOrange.withAlpha(30),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(Icons.receipt_long_rounded, color: AppColors.chartOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(edit ? 'Hariri matumizi' : 'Ongeza matumizi',
                        style: TextStyle(
                            color: AppColors.textWhite, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
                ]),
                const SizedBox(height: 14),
                // amount
                TextField(
                  controller: _amount,
                  autofocus: !edit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: TextStyle(
                      color: AppColors.textWhite, fontSize: 26, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    prefixText: 'TZS ',
                    prefixStyle: TextStyle(color: AppColors.textMuted, fontSize: 18, fontWeight: FontWeight.w700),
                    hintText: '0',
                    hintStyle: TextStyle(color: AppColors.textMuted.withAlpha(120), fontSize: 26),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('KATEGORIA',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10.5,
                        fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in Expense.categories)
                      ChoiceChip(
                        label: Text(c,
                            style: TextStyle(
                                color: _category == c ? Colors.white : AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: _category == c ? FontWeight.w700 : FontWeight.w500)),
                        selected: _category == c,
                        showCheckmark: false,
                        selectedColor: AppColors.chartOrange,
                        backgroundColor: AppColors.bgInput,
                        side: BorderSide(
                            color: _category == c ? AppColors.chartOrange : AppColors.border),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMM yyyy').format(_date),
                              style: TextStyle(
                                  color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _desc,
                      style: TextStyle(color: AppColors.textWhite, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Maelezo (optional)',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.bgInput,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chartOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: Text(edit ? 'Hifadhi mabadiliko' : 'Hifadhi matumizi',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
