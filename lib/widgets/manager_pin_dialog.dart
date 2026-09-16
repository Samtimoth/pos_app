import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Prompts for a manager's approval PIN before a sensitive action (stock
/// write-offs today). Returns the entered PIN, or null if cancelled. The
/// caller sends this PIN to the server, which is the only place it's
/// actually verified — this dialog just collects it.
class ManagerPinDialog extends StatefulWidget {
  final String reasonLabel;
  const ManagerPinDialog({super.key, required this.reasonLabel});

  static Future<String?> show(BuildContext context, {required String reasonLabel}) {
    return showDialog<String>(
      context: context,
      builder: (_) => ManagerPinDialog(reasonLabel: reasonLabel),
    );
  }

  @override
  State<ManagerPinDialog> createState() => _ManagerPinDialogState();
}

class _ManagerPinDialogState extends State<ManagerPinDialog> {
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: AppColors.chartOrange.withAlpha(28), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.admin_panel_settings_rounded, color: AppColors.chartOrange, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('Idhini ya Meneja', style: TextStyle(color: AppColors.textWhite, fontSize: 16))),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.reasonLabel, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: _pinCtrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: TextStyle(color: AppColors.textWhite, fontSize: 20, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '••••',
              hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 8),
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Ghairi', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.chartOrange, foregroundColor: Colors.white),
          child: const Text('Thibitisha'),
        ),
      ],
    );
  }

  void _confirm() {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) return;
    Navigator.pop(context, pin);
  }
}
