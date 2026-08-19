import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

const String kCompanyPaymentNumber = '+255 794 975 594';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _refCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _plans = [];
  int? _planId;
  XFile? _proofFile;
  bool _loadingPlans = true;
  bool _saving = false;

  Map<String, dynamic>? _subSummary;
  List<Map<String, dynamic>> _myBusinesses = [];
  bool _loadingSub = true;

  List<Map<String, dynamic>> _myPayments = [];
  bool _loadingPayments = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadMySubscription();
    _loadMyPayments();
  }

  Future<void> _loadMyPayments() async {
    final app = context.read<AppProvider>();
    final user = app.user;
    if (app.api == null || user == null) return;
    try {
      final res = await app.api!.getMyPayments(user.userId);
      if (mounted && res['success'] == true) {
        setState(() {
          _myPayments = (res['payments'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPayments = false);
  }

  Future<void> _loadMySubscription() async {
    final app = context.read<AppProvider>();
    final user = app.user;
    if (app.api == null || user == null) return;
    try {
      final res = await app.api!.getMySubscription(user.userId);
      if (mounted && res['success'] == true) {
        setState(() {
          _subSummary   = Map<String, dynamic>.from(res['summary'] as Map);
          _myBusinesses = (res['businesses'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSub = false);
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    final app = context.read<AppProvider>();
    if (app.api == null) return;
    try {
      final plans = await app.api!.getPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _planId = plans.isNotEmpty ? plans.first['plan_id'] as int : null;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPlans = false);
  }

  Future<void> _pickProof(ImageSource source) async {
    final xf = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (xf != null) setState(() => _proofFile = xf);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_planId == null) {
      AppNotification.show(context, 'Chagua mpango', AppColors.chartRed, icon: Icons.error_rounded);
      return;
    }
    final app  = context.read<AppProvider>();
    final user = app.user;
    final biz  = app.selectedBusiness;
    if (app.api == null || user == null || biz == null) return;

    setState(() => _saving = true);
    try {
      final res = await app.api!.submitPayment(
        userId: user.userId,
        businessId: biz.businessId,
        planId: _planId!,
        refCode: _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        proofPath: _proofFile?.path,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotification.show(context, res['message'] as String? ?? '✅ Malipo yametumwa',
            AppColors.accent, icon: Icons.check_circle_rounded);
        Navigator.pop(context);
      } else {
        AppNotification.show(context, res['message'] as String? ?? 'Hitilafu',
            AppColors.chartRed, icon: Icons.error_rounded);
      }
    } catch (e) {
      if (mounted) AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildForm()),
          SliverToBoxAdapter(child: _buildPaymentHistory()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: AppColors.gradHeader,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
            const Text('Lipia Muda wa Matumizi',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(45)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text('Lipa kwenye namba ya Kampuni',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                const SizedBox(height: 6),
                Text(kCompanyPaymentNumber,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Baada ya kulipa, jaza fomu hapa chini na uambatishe nambari ya rejea (reference) na/au picha ya risiti. Msimamizi atakagua na kuwasha akaunti yako.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ]),
            ),
          ),
        ]),
      ),
    ),
  );

  Widget _buildForm() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_loadingSub && _myBusinesses.isNotEmpty) _buildSubscriptionSummary(),
        if (!_loadingSub && _myBusinesses.isNotEmpty) const SizedBox(height: 24),

        Text('Chagua Mpango', style: TextStyle(color: AppColors.textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _loadingPlans
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLt))
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgInput, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _planId,
                    isExpanded: true,
                    dropdownColor: AppColors.bgCard,
                    style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                    items: _plans.map((p) {
                      final price = ((p['price_cents'] as int) / 100).toStringAsFixed(0);
                      return DropdownMenuItem(
                        value: p['plan_id'] as int,
                        child: Text('${p['name']} — ${p['currency']} $price / ${p['billing_cycle']}'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _planId = v),
                  ),
                ),
              ),
        const SizedBox(height: 20),

        Text('Nambari ya Rejea (Reference)', style: TextStyle(color: AppColors.textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextFormField(
          controller: _refCtrl,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nambari ya rejea inahitajika' : null,
          style: TextStyle(color: AppColors.textWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'mf. QGT7X4YABC',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppColors.textMuted, size: 18),
            filled: true, fillColor: AppColors.bgInput,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
          ),
        ),
        const SizedBox(height: 20),

        Text('Maelezo (hiari)', style: TextStyle(color: AppColors.textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          style: TextStyle(color: AppColors.textWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Maelezo mengine ya malipo...',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true, fillColor: AppColors.bgInput,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
          ),
        ),
        const SizedBox(height: 20),

        Text('Picha ya Risiti (hiari)', style: TextStyle(color: AppColors.textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_proofFile != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(File(_proofFile!.path), fit: BoxFit.cover),
            ),
          ),
        Row(children: [
          Expanded(child: _photoBtn('Kamera', Icons.camera_alt_rounded, () => _pickProof(ImageSource.camera))),
          const SizedBox(width: 10),
          Expanded(child: _photoBtn('Galari', Icons.photo_library_rounded, () => _pickProof(ImageSource.gallery))),
        ]),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(_saving ? 'Inatuma...' : 'Tuma Malipo',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    ),
  );

  Widget _photoBtn(String label, IconData icon, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18, color: AppColors.textMuted),
    label: Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 13),
      side: BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _buildSubscriptionSummary() {
    final s        = _subSummary ?? {};
    final active   = s['is_active'] == true;
    final status   = (s['status'] as String? ?? 'none');
    final daysLeft = (s['days_left'] as int? ?? 0);
    final planName = (s['plan_name'] as String? ?? '');
    final color    = active ? AppColors.accent : Colors.redAccent;
    final label = status == 'none'
        ? 'Huna subscription bado'
        : (active
            ? 'Inaendelea${planName.isNotEmpty ? " · $planName" : ""} · siku $daysLeft zimebaki'
            : 'Imeisha muda');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(active ? Icons.verified_rounded : Icons.error_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Subscription Yako: $label',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 10),
        Text('Malipo haya yatawasha maduka yako YOTE (${_myBusinesses.length}):',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: _myBusinesses.map((b) {
          return Chip(
            label: Text(b['business_name'] as String? ?? '',
                style: TextStyle(color: AppColors.textWhite, fontSize: 11)),
            backgroundColor: AppColors.bgInput,
            side: BorderSide(color: AppColors.border),
            visualDensity: VisualDensity.compact,
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildPaymentHistory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history_rounded, size: 18, color: AppColors.textWhite),
          const SizedBox(width: 8),
          Text('Historia ya Malipo', style: TextStyle(color: AppColors.textWhite,
              fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        if (_loadingPayments)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.primaryLt, strokeWidth: 2),
          ))
        else if (_myPayments.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Bado hujawahi kutuma malipo', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ))
        else
          ..._myPayments.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PaymentHistoryCard(payment: p),
          )),
      ]),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentHistoryCard({required this.payment});

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return AppColors.accent;
      case 'rejected': return Colors.redAccent;
      default: return AppColors.chartOrange;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved': return 'IMEIDHINISHWA';
      case 'rejected': return 'IMEKATALIWA';
      default: return 'INASUBIRI';
    }
  }

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,###', 'en_US');
    final amount = numFmt.format(((payment['amount_cents'] as int) / 100));
    final status = payment['status'] as String;
    final color  = _statusColor(status);
    String paidAt = '';
    try { paidAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(payment['paid_at'] as String)); }
    catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(payment['plan_name'] as String? ?? '',
              style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Text(_statusLabel(status),
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.payments_rounded, size: 13, color: AppColors.accent),
          const SizedBox(width: 4),
          Text('${payment['currency']} $amount',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          Icon(Icons.confirmation_number_outlined, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(child: Text('Ref: ${payment['ref_code']}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        ]),
        if (paidAt.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(paidAt, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ],
      ]),
    );
  }
}
