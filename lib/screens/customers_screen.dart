import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../providers/app_provider.dart';
import '../services/crm_api.dart';
import '../theme/app_theme.dart';
import '../widgets/first_run_tutorial.dart';

/// Wateja: list with debts, search, add/edit, statement.
/// [pickMode] returns the chosen customer via Navigator.pop (used by POS).
class CustomersScreen extends StatefulWidget {
  final bool desktop;
  final bool pickMode;
  const CustomersScreen({super.key, this.desktop = false, this.pickMode = false});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _searchCtrl = TextEditingController();
  List<Customer> _all = [];
  bool _loading = true;
  bool _offline = false;
  String _q = '';
  String _filter = 'all'; // all | debt | wholesale

  CrmApi? get _crm {
    final app = context.read<AppProvider>();
    final url = app.user?.serverUrl;
    return url == null ? null : CrmApi(url);
  }

  @override
  void initState() {
    super.initState();
    _load();
    if (!widget.pickMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FirstRunTutorial.showIfNeeded(context, storageKey: 'customers', steps: const [
          TutorialStep(icon: Icons.people_alt_rounded, title: 'Wateja wako',
              body: 'Kila mteja aliyewahi kununua kwa simu yupo hapa — na deni lake. Gusa mteja kuona statement.',
              targetId: 'cust_list'),
          TutorialStep(icon: Icons.person_add_alt_1_rounded, title: 'Ongeza mteja',
              body: 'Jina, simu, aina (rejareja/jumla) na kikomo cha mkopo.', targetId: 'cust_add'),
        ]);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    final crm = _crm;
    if (biz == null || crm == null) return;
    setState(() => _loading = true);
    try {
      final rows = await crm.listCustomers(biz.businessId);
      if (!mounted) return;
      setState(() {
        _all = rows.map(Customer.fromJson).toList();
        _offline = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _offline = true);
        AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Customer> get _filtered {
    final s = _q.trim().toLowerCase();
    return _all.where((c) {
      if (_filter == 'debt' && !c.hasDebt) return false;
      if (_filter == 'wholesale' && c.customerType == 'retail') return false;
      if (s.isEmpty) return true;
      return c.name.toLowerCase().contains(s) || c.phone.contains(s);
    }).toList();
  }

  Future<void> _edit([Customer? c]) async {
    final saved = await CustomerFormSheet.show(context, existing: c);
    if (saved != null) {
      if (widget.pickMode && c == null && mounted) {
        Navigator.pop(context, saved);
        return;
      }
      _load();
    }
  }

  void _open(Customer c) {
    if (widget.pickMode) {
      Navigator.pop(context, c);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerDetailScreen(customer: c),
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final totalDebt = _all.fold<double>(0, (a, c) => a + c.balance);
    final debtors = _all.where((c) => c.hasDebt).length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: AppColors.gradHeader,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 12),
                child: Row(children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.pickMode ? 'Chagua mteja' : 'Wateja',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(
                        '${_all.length} wateja  ·  madeni TZS ${_fmt.format(totalDebt)} ($debtors)'
                        '${_offline ? '  ·  offline' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ]),
                  ),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
                ]),
              ),
            ),
          ),
          // search + filters
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                autofocus: widget.pickMode,
                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tafuta jina au simu',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  isDense: true, filled: true, fillColor: AppColors.bgCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              children: [
                _chip('Wote', 'all'),
                _chip('Wenye deni ($debtors)', 'debt', color: AppColors.chartRed),
                _chip('Jumla / VIP', 'wholesale', color: AppColors.chartPurple),
              ],
            ),
          ),
          Expanded(
            child: _loading && _all.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : list.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final row = _CustomerRow(c: list[i], fmt: _fmt, onTap: () => _open(list[i]));
                            return i == 0 ? TutorialTarget(id: 'cust_list', child: row) : row;
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: TutorialTarget(
        id: 'cust_add',
        child: FloatingActionButton.extended(
          heroTag: 'add_customer_fab',
          onPressed: () => _edit(),
          backgroundColor: AppColors.accent,
          icon: Icon(Icons.person_add_alt_1_rounded, color: AppColors.bgDark),
          label: Text('Mteja mpya', style: TextStyle(color: AppColors.bgDark, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _chip(String label, String v, {Color? color}) {
    final sel = _filter == v;
    final c = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        selected: sel, showCheckmark: false, selectedColor: c, backgroundColor: AppColors.bgCard,
        side: BorderSide(color: sel ? c : AppColors.border),
        visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) => setState(() => _filter = v),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline_rounded, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(_q.isEmpty ? 'Hakuna wateja bado' : 'Hakuna mteja anayelingana',
              style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            _q.isEmpty
                ? 'Wateja wanaongezwa wenyewe unapouza kwa simu — au bonyeza "Mteja mpya".'
                : 'Bonyeza "Mteja mpya" kumwongeza.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ]),
      );
}

class _CustomerRow extends StatelessWidget {
  final Customer c;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _CustomerRow({required this.c, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = c.hasDebt ? AppColors.chartRed : AppColors.primaryLt;
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.overLimit ? AppColors.chartRed.withAlpha(120) : AppColors.border),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: color.withAlpha(30),
              child: Text(c.initials, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  if (c.customerType != 'retail') ...[
                    const SizedBox(width: 6),
                    _tag(c.customerType == 'vip' ? 'VIP' : 'Jumla', AppColors.chartPurple),
                  ],
                  if (!c.isSynced) ...[const SizedBox(width: 6), _tag('offline', Colors.orange)],
                ]),
                const SizedBox(height: 2),
                Text(
                  [
                    if (c.phone.isNotEmpty) c.phone,
                    '${c.salesCount} mauzo',
                    if (c.totalBought > 0) 'TZS ${fmt.format(c.totalBought)}',
                  ].join('  ·  '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            if (c.hasDebt)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('-${fmt.format(c.balance)}',
                    style: TextStyle(color: AppColors.chartRed, fontWeight: FontWeight.w800, fontSize: 14)),
                Text(c.overLimit ? 'zaidi ya kikomo' : 'deni',
                    style: TextStyle(color: AppColors.chartRed, fontSize: 10)),
              ])
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(color: c.withAlpha(28), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w800)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail / statement
// ─────────────────────────────────────────────────────────────────────────────
class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat('#,###', 'en_US');
  late final TabController _tab = TabController(length: 2, vsync: this);
  late Customer _c = widget.customer;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    final url = app.user?.serverUrl;
    if (biz == null || url == null || _c.customerId < 0) {
      setState(() => _loading = false);
      return;
    }
    try {
      final r = await CrmApi(url).getCustomer(biz.businessId, _c.customerId);
      if (!mounted) return;
      if (r['success'] == true) {
        setState(() {
          _c = Customer.fromJson({...Map<String, dynamic>.from(r['customer'] as Map),
            'balance': (r['summary'] as Map?)?['balance'], 'sales_count': (r['summary'] as Map?)?['sales_count'],
            'total_bought': (r['summary'] as Map?)?['total_bought']});
          _sales = ((r['sales'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _payments = ((r['payments'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _summary = Map<String, dynamic>.from(r['summary'] as Map? ?? {});
        });
      }
    } catch (e) {
      if (mounted) AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _n(dynamic v) => double.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final debt = _n(_summary['balance'] ?? _c.balance);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: AppColors.gradHeader, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                Expanded(
                  child: Text(_c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Hariri',
                  onPressed: () async {
                    final saved = await CustomerFormSheet.show(context, existing: _c);
                    if (saved != null) { setState(() => _c = saved); _load(); }
                  },
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(children: [
                  _stat('Deni', 'TZS ${_fmt.format(debt)}', debt > 0 ? AppColors.accentBright : Colors.white),
                  _stat('Amenunua', 'TZS ${_fmt.format(_n(_summary['total_bought'] ?? _c.totalBought))}', Colors.white),
                  _stat('Mauzo', '${_summary['sales_count'] ?? _c.salesCount}', Colors.white),
                ]),
              ),
              if (_c.phone.isNotEmpty || _c.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    if (_c.phone.isNotEmpty) ...[
                      const Icon(Icons.phone_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(_c.phone, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 14),
                    ],
                    if (_c.address.isNotEmpty) ...[
                      const Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Flexible(child: Text(_c.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    ],
                    if (_c.creditLimit > 0) ...[
                      const Spacer(),
                      Text('Kikomo ${_fmt.format(_c.creditLimit)}',
                          style: TextStyle(color: _c.overLimit ? AppColors.accentBright : Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(color: Colors.white.withAlpha(22), borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  indicatorSize: TabBarIndicatorSize.tab, indicatorPadding: const EdgeInsets.all(3),
                  dividerColor: Colors.transparent, labelColor: AppColors.primary, unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  tabs: [Tab(height: 40, text: 'Mauzo (${_sales.length})'), Tab(height: 40, text: 'Malipo (${_payments.length})')],
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(controller: _tab, children: [_salesList(), _paymentsList()]),
        ),
      ]),
    );
  }

  Widget _stat(String l, String v, Color c) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(v, style: TextStyle(color: c, fontSize: 17, fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _salesList() {
    if (_sales.isEmpty) return Center(child: Text('Hakuna mauzo bado', style: TextStyle(color: AppColors.textMuted)));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
      itemCount: _sales.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final s = _sales[i];
        final bal = _n(s['balance_amount']);
        final status = '${s['payment_status']}'.toLowerCase();
        final color = status == 'voided' ? AppColors.chartGray : bal > 0 ? AppColors.chartRed : AppColors.accent;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s['sale_no']}', style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${s['created_at']}'.length > 16 ? '${s['created_at']}'.substring(0, 16) : '${s['created_at']}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt.format(_n(s['total_amount'])), style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w800)),
              Text(status == 'voided' ? 'imefutwa' : bal > 0 ? 'deni ${_fmt.format(bal)}' : 'imelipwa',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _paymentsList() {
    if (_payments.isEmpty) return Center(child: Text('Hakuna malipo bado', style: TextStyle(color: AppColors.textMuted)));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
      itemCount: _payments.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final p = _payments[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(Icons.payments_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['sale_no'] ?? ''}${'${p['note'] ?? ''}'.isNotEmpty ? ' · ${p['note']}' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textWhite, fontSize: 13)),
                Text('${p['payment_date']}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),
            Text('+${_fmt.format(_n(p['amount']))}', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form
// ─────────────────────────────────────────────────────────────────────────────
class CustomerFormSheet extends StatefulWidget {
  final Customer? existing;
  final String? initialName;
  final String? initialPhone;
  const CustomerFormSheet({super.key, this.existing, this.initialName, this.initialPhone});

  static Future<Customer?> show(BuildContext context, {Customer? existing, String? name, String? phone}) =>
      showModalBottomSheet<Customer>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CustomerFormSheet(existing: existing, initialName: name, initialPhone: phone),
      );

  @override
  State<CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<CustomerFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? widget.initialName ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? widget.initialPhone ?? '');
  late final _addr = TextEditingController(text: widget.existing?.address ?? '');
  late final _limit = TextEditingController(
      text: (widget.existing?.creditLimit ?? 0) > 0 ? widget.existing!.creditLimit.toStringAsFixed(0) : '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late String _type = widget.existing?.customerType ?? 'retail';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _addr, _limit, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppNotification.show(context, 'Andika jina la mteja', AppColors.chartOrange, icon: Icons.error_outline_rounded);
      return;
    }
    final app = context.read<AppProvider>();
    final biz = app.selectedBusiness;
    final url = app.user?.serverUrl;
    if (biz == null || url == null) return;
    setState(() => _saving = true);
    try {
      final r = await CrmApi(url).saveCustomer(
        businessId: biz.businessId,
        customerId: widget.existing?.customerId,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _addr.text.trim(),
        customerType: _type,
        creditLimit: double.tryParse(_limit.text.replaceAll(',', '')) ?? 0,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        final id = int.tryParse('${r['customer_id'] ?? widget.existing?.customerId ?? 0}') ?? 0;
        Navigator.pop(context, Customer(
          customerId: id, name: _name.text.trim(), phone: _phone.text.trim(), address: _addr.text.trim(),
          customerType: _type, creditLimit: double.tryParse(_limit.text.replaceAll(',', '')) ?? 0,
          notes: _notes.text.trim(), balance: widget.existing?.balance ?? 0,
          syncStatus: r['offline'] == true ? 'pending' : 'synced',
        ));
      } else if (r['exists'] == true) {
        // phone already registered → hand back that customer
        AppNotification.show(context, '${r['message']}', AppColors.chartOrange, icon: Icons.info_rounded);
        Navigator.pop(context, Customer(customerId: int.tryParse('${r['customer_id']}') ?? 0,
            name: _name.text.trim(), phone: _phone.text.trim()));
      } else {
        AppNotification.show(context, '${r['message'] ?? 'Hitilafu'}', AppColors.chartRed, icon: Icons.error_rounded);
      }
    } catch (e) {
      if (mounted) AppNotification.show(context, '$e', AppColors.chartRed, icon: Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        isDense: true, filled: true, fillColor: AppColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final edit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.person_rounded, color: AppColors.primaryLt),
                const SizedBox(width: 8),
                Expanded(child: Text(edit ? 'Hariri mteja' : 'Mteja mpya',
                    style: TextStyle(color: AppColors.textWhite, fontSize: 17, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _name, autofocus: !edit, textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: AppColors.textWhite, fontSize: 14), decoration: _deco('Jina kamili', Icons.badge_outlined)),
              const SizedBox(height: 8),
              TextField(controller: _phone, keyboardType: TextInputType.phone,
                  style: TextStyle(color: AppColors.textWhite, fontSize: 14), decoration: _deco('Simu (07…)', Icons.phone_outlined)),
              const SizedBox(height: 8),
              TextField(controller: _addr, style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                  decoration: _deco('Mahali / anuani (optional)', Icons.location_on_outlined)),
              const SizedBox(height: 12),
              Text('AINA YA MTEJA', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
              const SizedBox(height: 6),
              Row(children: [
                for (final t in const [('retail', 'Rejareja'), ('wholesale', 'Jumla'), ('vip', 'VIP')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(t.$2, style: TextStyle(color: _type == t.$1 ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                      selected: _type == t.$1, showCheckmark: false, selectedColor: AppColors.primary, backgroundColor: AppColors.bgInput,
                      side: BorderSide(color: _type == t.$1 ? AppColors.primary : AppColors.border),
                      visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => setState(() => _type = t.$1),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _limit, keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textWhite, fontSize: 14), decoration: _deco('Kikomo cha mkopo (TZS)', Icons.credit_score_outlined))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _notes, style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                    decoration: _deco('Maelezo', Icons.note_alt_outlined))),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                  label: Text(edit ? 'Hifadhi mabadiliko' : 'Hifadhi mteja', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
