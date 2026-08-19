import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ADD PRODUCT PAGE — full-screen mobile page, 3 bottom tabs
//  Tab 0: Fomu   — manual form
//  Tab 1: Scan   — camera scan → fill & save
//  Tab 2: Excel  — bulk import from .xlsx/.csv
// ─────────────────────────────────────────────────────────────────────────────
class AddProductPage extends StatefulWidget {
  final VoidCallback onProductsAdded;
  const AddProductPage({super.key, required this.onProductsAdded});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage>
    with TickerProviderStateMixin {
  late final TabController _tab;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _onProductAdded() {
    setState(() => _added++);
    widget.onProductsAdded();
  }

  @override
  Widget build(BuildContext context) {
    final l      = L.of(context);
    final app    = context.watch<AppProvider>();
    final biz    = app.selectedBusiness;
    final branch = app.selectedBranch;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 148,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.bgCard,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.gradHeader,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.add_box_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.addProductTitle,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              // Branch / business chip
                              Row(children: [
                                const Icon(Icons.store_mall_directory_rounded,
                                    color: Colors.white54, size: 13),
                                const SizedBox(width: 5),
                                Flexible(child: Text(
                                  branch != null
                                      ? '${biz?.businessName ?? ''} › ${branch.branchName}'
                                      : (biz?.businessName ?? '—'),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                )),
                              ]),
                            ],
                          )),
                          // "N zimehifadhiwa" badge
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, anim) => ScaleTransition(
                                scale: anim, child: child),
                            child: _added > 0
                                ? Container(
                                    key: ValueKey(_added),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [BoxShadow(
                                        color: AppColors.accent.withAlpha(100),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      )],
                                    ),
                                    child: Text(
                                      '$_added ${l.isSw ? 'zimehifadhiwa ✓' : 'saved ✓'}',
                                      style: TextStyle(
                                          color: AppColors.bgDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: AppColors.bgCard,
                child: TabBar(
                  controller: _tab,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  unselectedLabelStyle: const TextStyle(fontSize: 11),
                  tabs: [
                    Tab(icon: const Icon(Icons.edit_note_rounded, size: 18),
                        text: l.isSw ? 'Fomu' : 'Form'),
                    const Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 18),
                        text: 'Scan'),
                    const Tab(icon: Icon(Icons.table_chart_rounded, size: 18),
                        text: 'Excel'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _FormTab(onSaved: _onProductAdded),
            _ScanTab(onSaved: _onProductAdded),
            _ExcelTab(onImported: _onProductAdded),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 0 — Manual form
// ─────────────────────────────────────────────────────────────────────────────
class _FormTab extends StatefulWidget {
  final VoidCallback onSaved;
  const _FormTab({required this.onSaved});
  @override
  State<_FormTab> createState() => _FormTabState();
}

class _FormTabState extends State<_FormTab> {
  final _form         = GlobalKey<FormState>();
  final _nameCtr      = TextEditingController();
  final _catCtr       = TextEditingController();
  final _unitCtr      = TextEditingController();
  final _barcodeCtr   = TextEditingController();
  final _codeCtr      = TextEditingController();
  final _expiryCtr    = TextEditingController();
  final _buyPriceCtr  = TextEditingController(text: '0');
  final _sellPriceCtr = TextEditingController();
  final _wholeCtr     = TextEditingController();
  final _stockCtr     = TextEditingController(text: '0');
  final _minStockCtr  = TextEditingController(text: '5');
  final _descCtr      = TextEditingController();
  final _barcodeFocus = FocusNode();

  List<String> _cats  = [];
  List<String> _units = [];
  bool _saving      = false;
  bool _loadingMeta = true;
  bool _barcFocused = false;
  XFile?                   _imageFile;
  final List<_PageUnitRow> _sellingUnits = [];
  bool get _canScan => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void _onBarcFocus() => setState(() => _barcFocused = _barcodeFocus.hasFocus);

  @override
  void initState() {
    super.initState();
    _barcodeFocus.addListener(_onBarcFocus);
    _barcodeCtr.addListener(() => setState(() {}));
    _loadMeta();
  }

  @override
  void dispose() {
    _barcodeFocus.removeListener(_onBarcFocus);
    _barcodeFocus.dispose();
    for (final c in [_nameCtr,_catCtr,_unitCtr,_barcodeCtr,_codeCtr,_expiryCtr,
                     _buyPriceCtr,_sellPriceCtr,_wholeCtr,_stockCtr,_minStockCtr,_descCtr]) {
      c.dispose();
    }
    for (final u in _sellingUnits) { u.dispose(); }
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) {
      setState(() => _loadingMeta = false);
      return;
    }
    try {
      final cats  = await app.api!.getCategories(app.selectedBusiness!.businessId);
      final units = await app.api!.getUnits(app.selectedBusiness!.businessId);
      if (mounted) {
        setState(() {
          _cats  = cats.map((c) => (c as Map<String,dynamic>)['name'] as String).toList();
          _units = units;
          _loadingMeta = false;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => _loadingMeta = false); }
    }
  }

  void _generateBarcode() {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() => _barcodeCtr.text = 'INT$ts');
  }

  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickScanSheet(
        onScanned: (v) => setState(() => _barcodeCtr.text = v),
      ),
    );
  }

  // ── Image pickers ──────────────────────────────────────────────────────────
  Future<void> _pickImageFromCamera() async {
    final xf = await ImagePicker().pickImage(
        source: ImageSource.camera, imageQuality: 80, maxWidth: 1024);
    if (xf != null && mounted) setState(() => _imageFile = xf);
  }

  Future<void> _pickImageFromGallery() async {
    final xf = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
    if (xf != null && mounted) setState(() => _imageFile = xf);
  }

  Future<void> _pickImageDesktop() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: false);
    if (result != null && result.files.single.path != null && mounted) {
      setState(() => _imageFile = XFile(result.files.single.path!));
    }
  }

  Future<void> _printBarcode() async {
    final code = _barcodeCtr.text.trim();
    if (code.isEmpty) return;
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(72 * PdfPageFormat.mm, 38 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        if (_nameCtr.text.isNotEmpty)
          pw.Text(_nameCtr.text.trim(),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 3),
        pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: code,
            width: 60 * PdfPageFormat.mm, height: 14 * PdfPageFormat.mm, drawText: false),
        pw.SizedBox(height: 2),
        pw.Text(code, style: pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
        if (_sellPriceCtr.text.isNotEmpty)
          pw.Text('TZS ${_sellPriceCtr.text}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryCtr.text.isNotEmpty
          ? (DateTime.tryParse(_expiryCtr.text) ?? now.add(const Duration(days: 180)))
          : now.add(const Duration(days: 180)),
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryLt,
            onPrimary: AppColors.bgDark,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _expiryCtr.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Color get _expiryColor {
    if (_expiryCtr.text.isEmpty) return AppColors.textMuted;
    final d = DateTime.tryParse(_expiryCtr.text);
    if (d == null) return AppColors.textMuted;
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 0) return AppColors.chartRed;
    if (diff <= 30) return AppColors.chartOrange;
    return AppColors.accent;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    setState(() => _saving = true);
    try {
      final res = await app.api!.addProduct(
        businessId:     app.selectedBusiness!.businessId,
        branchId:       app.selectedBranch?.branchId ?? 0,
        name:           _nameCtr.text.trim(),
        category:       _catCtr.text.trim(),
        unit:           _unitCtr.text.trim(),
        buyPrice:       double.tryParse(_buyPriceCtr.text) ?? 0,
        sellPrice:      double.tryParse(_sellPriceCtr.text) ?? 0,
        stock:          int.tryParse(_stockCtr.text) ?? 0,
        minStock:       int.tryParse(_minStockCtr.text) ?? 5,
        barcode:        _barcodeCtr.text.trim(),
        description:    _descCtr.text.trim(),
        productCode:    _codeCtr.text.trim(),
        wholesalePrice: _wholeCtr.text.trim().isEmpty ? null : double.tryParse(_wholeCtr.text),
        expiryDate:     _expiryCtr.text.trim(),
        imagePath:      _imageFile?.path,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        // ── Save selling units ───────────────────────────────────────────────
        final savedPid = (res['product_id'] as num?)?.toInt() ?? 0;
        if (savedPid > 0 && _sellingUnits.isNotEmpty) {
          final validUnits = _sellingUnits
              .where((u) => u.nameCtr.text.trim().isNotEmpty)
              .map((u) => {
                    'unit_name':      u.nameCtr.text.trim(),
                    'conversion_qty': double.tryParse(u.convCtr.text) ?? 1.0,
                    'selling_price':  double.tryParse(u.priceCtr.text) ?? 0.0,
                  })
              .toList();
          if (validUnits.isNotEmpty) {
            try {
              await app.api!.manageProductUnits(
                productId:  savedPid,
                businessId: app.selectedBusiness!.businessId,
                units:      validUnits,
              );
            } catch (_) {} // non-fatal
          }
        }
        if (!mounted) return;
        _clearForm();
        widget.onSaved();
        _snack(L.of(context).productAdded, AppColors.accent);
      } else if (res['exists'] == true) {
        _snack(L.of(context).productExists, Colors.orange);
      } else {
        _snack(res['message'] as String? ?? L.of(context).error, Colors.redAccent);
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    _nameCtr.clear(); _catCtr.clear(); _unitCtr.clear();
    _barcodeCtr.clear(); _codeCtr.clear(); _expiryCtr.clear();
    _buyPriceCtr.text = '0'; _sellPriceCtr.clear();
    _wholeCtr.clear(); _stockCtr.text = '0'; _minStockCtr.text = '5';
    _descCtr.clear();
    for (final u in _sellingUnits) { u.dispose(); }
    _sellingUnits.clear();
    setState(() => _imageFile = null);
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);

    if (_loadingMeta) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppColors.primaryLt),
        const SizedBox(height: 14),
        Text(l.loading, style: TextStyle(color: AppColors.textMuted)),
      ]));
    }

    return Form(
      key: _form,
      child: Column(children: [
        Expanded(child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [

          // ── Product Image ──────────────────────────────────────────
          StaggeredItem(index: 0, child: _imageSection(l)),

          // ── Section: Taarifa za Bidhaa ─────────────────────────────
          StaggeredItem(index: 1, child: _section(
            icon: Icons.inventory_2_rounded,
            label: l.isSw ? 'Taarifa za Bidhaa' : 'Product Info',
            child: Column(children: [
              _field(ctrl: _nameCtr, label: l.productName,
                  icon: Icons.drive_file_rename_outline_rounded, required: true,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? '${l.productName} ${l.requiredField}' : null),
              const SizedBox(height: 12),
              _autocomplete(ctrl: _catCtr, label: l.category,
                  icon: Icons.category_outlined, suggestions: _cats, required: true,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? '${l.category} ${l.requiredField}' : null),
              const SizedBox(height: 12),
              _autocomplete(ctrl: _unitCtr, label: l.unit,
                  icon: Icons.straighten_rounded, suggestions: _units, required: true,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? '${l.unit} ${l.requiredField}' : null),
              const SizedBox(height: 12),
              // Barcode — prominent scan card
              _barcodeCard(l),
              if (_barcodeCtr.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _barcodePreview(l),
              ],
              const SizedBox(height: 12),
              _field(ctrl: _codeCtr, label: l.productCode, icon: Icons.tag_rounded),
              const SizedBox(height: 12),
              // Expiry date
              GestureDetector(
                onTap: _pickExpiryDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _expiryCtr,
                    style: TextStyle(color: _expiryColor),
                    decoration: InputDecoration(
                      labelText: l.expiryOptional,
                      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      hintText: l.tapToPickDate,
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      prefixIcon: Icon(Icons.calendar_month_rounded, color: _expiryColor, size: 18),
                      suffixIcon: _expiryCtr.text.isNotEmpty ? null
                          : Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _expiryCtr.text.isEmpty
                              ? AppColors.border : _expiryColor.withAlpha(120))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _expiryColor, width: 1.5)),
                      filled: true, fillColor: AppColors.bgCard,
                    ),
                  ),
                ),
              ),
              if (_expiryCtr.text.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expiryCtr.clear()),
                    icon: const Icon(Icons.clear_rounded, size: 14),
                    label: Text(l.isSw ? 'Futa tarehe' : 'Clear date',
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
            ]),
          )),

          // ── Section: Bei ──────────────────────────────────────────
          StaggeredItem(index: 2, child: _section(
            icon: Icons.payments_rounded,
            label: l.isSw ? 'Bei' : 'Pricing',
            child: Column(children: [
              Row(children: [
                Expanded(child: _field(ctrl: _buyPriceCtr, label: l.buyPrice,
                    icon: Icons.arrow_downward_rounded, iconColor: AppColors.chartOrange,
                    keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(ctrl: _sellPriceCtr, label: l.sellPrice,
                    icon: Icons.arrow_upward_rounded, iconColor: AppColors.primaryLt,
                    keyboardType: TextInputType.number, required: true,
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return '${l.sellPrice} ${l.requiredField}';
                      if ((double.tryParse(v!) ?? 0) <= 0) return '> 0';
                      return null;
                    })),
              ]),
              const SizedBox(height: 12),
              _field(ctrl: _wholeCtr, label: l.wholesalePrice,
                  icon: Icons.storefront_outlined, keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _ProfitRow(buyCtr: _buyPriceCtr, sellCtr: _sellPriceCtr),
            ]),
          )),

          // ── Section: Stock ────────────────────────────────────────
          StaggeredItem(index: 3, child: _section(
            icon: Icons.layers_rounded,
            label: l.isSw ? 'Hifadhi (Stock)' : 'Stock',
            child: Row(children: [
              Expanded(child: _field(ctrl: _stockCtr, label: l.stock,
                  icon: Icons.inventory_rounded, iconColor: AppColors.accent,
                  keyboardType: TextInputType.number, required: true,
                  validator: (v) => int.tryParse(v ?? '') == null ? '≥ 0' : null)),
              const SizedBox(width: 12),
              Expanded(child: _field(ctrl: _minStockCtr, label: l.minStock,
                  icon: Icons.warning_amber_rounded, iconColor: AppColors.chartOrange,
                  keyboardType: TextInputType.number, required: true,
                  validator: (v) => int.tryParse(v ?? '') == null ? '≥ 0' : null)),
            ]),
          )),

          // ── Section: Maelezo ──────────────────────────────────────
          StaggeredItem(index: 4, child: _section(
            icon: Icons.notes_rounded,
            label: l.isSw ? 'Maelezo' : 'Notes',
            child: _field(ctrl: _descCtr, label: l.description_,
                icon: Icons.edit_note_rounded, maxLines: 3),
          )),

          // ── Selling Units ─────────────────────────────────────────
          StaggeredItem(index: 5, child: _unitsSection(l)),
        ],
        )),
        // ── Save button — pinned at the bottom, always visible ──────
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + mq.padding.bottom),
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: _saving
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: AppColors.bgDark, strokeWidth: 2))
                  : Icon(Icons.check_circle_rounded, color: AppColors.bgDark, size: 22),
              label: Text(_saving ? l.addingProduct : l.addProductTitle,
                  style: TextStyle(color: AppColors.bgDark,
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Barcode card (prominent, tap to scan) ─────────────────────────────────
  Widget _barcodeCard(L l) {
    final hasCode = _barcodeCtr.text.isNotEmpty;
    return GestureDetector(
      onTap: () => _barcodeFocus.requestFocus(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: _barcFocused
              ? AppColors.primary.withAlpha(38) : AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _barcFocused ? AppColors.primaryLt : AppColors.primary.withAlpha(90),
            width: _barcFocused ? 1.8 : 1.2,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _barcFocused
                    ? AppColors.primaryLt.withAlpha(35) : AppColors.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.qr_code_scanner_rounded,
                  color: _barcFocused
                      ? AppColors.primaryLt : AppColors.primary.withAlpha(220),
                  size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.isSw ? 'Barcode ya Bidhaa' : 'Product Barcode',
                  style: TextStyle(
                      color: _barcFocused ? AppColors.primaryLt : AppColors.textLight,
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(l.isSw ? 'Scan kwa kamera au ingiza mkono' : 'Scan with camera or type',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ])),
            const SizedBox(width: 8),
            // Scan button
            _iconBtn(
              icon: Icons.qr_code_scanner_rounded,
              color: AppColors.primaryLt,
              tooltip: l.scanBarcode,
              onTap: _openBarcodeScanner,
            ),
            const SizedBox(width: 8),
            // Generate button
            _iconBtn(
              icon: Icons.auto_fix_high_rounded,
              color: AppColors.accent,
              tooltip: l.autoGenerate,
              onTap: _generateBarcode,
            ),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: _barcodeCtr,
            focusNode: _barcodeFocus,
            style: TextStyle(color: AppColors.textWhite, fontSize: 14),
            decoration: InputDecoration(
              hintText: l.isSw
                  ? 'Barcode itaonekana hapa...'
                  : 'Barcode appears here...',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
              prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.textMuted, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
              filled: true, fillColor: AppColors.bgDark,
            ),
          ),
          if (hasCode) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _barcodeCtr.clear()),
                icon: const Icon(Icons.close_rounded, size: 13),
                label: Text(l.isSw ? 'Futa barcode' : 'Clear',
                    style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _barcodePreview(L l) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      bw.BarcodeWidget(
        barcode: bw.Barcode.code128(), data: _barcodeCtr.text,
        width: double.infinity, height: 60,
        style: const TextStyle(color: Colors.black87, fontSize: 11),
        color: Colors.black, backgroundColor: Colors.white,
        errorBuilder: (ctx, err) => Center(child: Text(err,
            style: const TextStyle(color: AppColors.chartRed, fontSize: 11))),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(
          onPressed: _printBarcode,
          icon: const Icon(Icons.print_rounded, size: 16),
          label: Text(l.isSw ? 'Chapisha Label' : 'Print Label'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryLt,
              textStyle: const TextStyle(fontSize: 12)),
        ),
      ]),
    ]),
  );

  // ── Product image section ─────────────────────────────────────────────────
  Widget _imageSection(L l) {
    final hasNew = _imageFile != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradPrimary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(
              l.isSw ? 'Picha ya Bidhaa (Hiari)' : 'Product Image (Optional)',
              style: TextStyle(color: AppColors.textLight,
                  fontWeight: FontWeight.w600, fontSize: 13),
            )),
            if (hasNew)
              TextButton.icon(
                onPressed: () => setState(() => _imageFile = null),
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: Text(l.isSw ? 'Ondoa' : 'Remove',
                    style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.chartRed,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ]),
          const SizedBox(height: 12),

          // Preview
          GestureDetector(
            onTap: _canScan ? _pickImageFromGallery : _pickImageDesktop,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 150,
              decoration: BoxDecoration(
                color: hasNew ? Colors.transparent : AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasNew
                      ? AppColors.primaryLt.withAlpha(100) : AppColors.border,
                  width: hasNew ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasNew
                  ? (kIsWeb
                      ? Image.network(_imageFile!.path, fit: BoxFit.cover, width: double.infinity)
                      : Image.file(File(_imageFile!.path),
                          fit: BoxFit.cover, width: double.infinity))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLt.withAlpha(18),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryLt.withAlpha(50)),
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded,
                            color: AppColors.primaryLt, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(l.isSw ? 'Gonga kuongeza picha' : 'Tap to add image',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ]),
            ),
          ),
          const SizedBox(height: 10),

          // Pick buttons
          if (_canScan)
            Row(children: [
              Expanded(child: _imgPickBtn(
                icon: Icons.camera_alt_rounded,
                label: l.isSw ? 'Kamera' : 'Camera',
                color: AppColors.primaryLt,
                onTap: _pickImageFromCamera,
              )),
              const SizedBox(width: 8),
              Expanded(child: _imgPickBtn(
                icon: Icons.photo_library_rounded,
                label: l.isSw ? 'Picha' : 'Gallery',
                color: AppColors.accent,
                onTap: _pickImageFromGallery,
              )),
            ])
          else
            SizedBox(
              width: double.infinity,
              child: _imgPickBtn(
                icon: Icons.folder_open_rounded,
                label: l.isSw ? 'Chagua Faili' : 'Choose File',
                color: AppColors.primaryLt,
                onTap: _pickImageDesktop,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _imgPickBtn({
    required IconData icon, required String label,
    required Color color, required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );

  // ── Selling units section ─────────────────────────────────────────────────
  static const _blue = Color(0xFF3B82F6);

  // Quick-add templates: each is a (display label, [(unitName, convQty)])
  static const _unitTemplates = [
    ('🥤 Vinywaji', [('Bottle','1'),('Half Dozen','6'),('Dozen','12'),('Crate','24')]),
    ('🍪 Chakula',  [('Piece','1'),('Pack','6'),('Dozen','12'),('Carton','48')]),
    ('📦 Kawaida',  [('Each','1'),('Pack','10'),('Box','12')]),
  ];

  void _applyTemplate(List<(String, String)> units) {
    for (final u in _sellingUnits) { u.dispose(); }
    _sellingUnits.clear();
    final basePrice = double.tryParse(_sellPriceCtr.text.trim()) ?? 0.0;
    for (final (name, conv) in units) {
      final convQty = double.tryParse(conv) ?? 1.0;
      final price = basePrice > 0
          ? (basePrice * convQty).toStringAsFixed(0) : '';
      _sellingUnits.add(_PageUnitRow(name: name, conv: conv, price: price));
    }
    setState(() {});
  }

  Widget _unitsSection(L l) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _blue.withAlpha(28), borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _blue.withAlpha(80)),
          ),
          child: const Icon(Icons.layers_rounded, color: _blue, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.isSw ? 'Unit za Mauzo' : 'Selling Units',
              style: TextStyle(color: AppColors.textLight,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Text(l.isSw
              ? 'Bottle, Dozen, Crate... kwa bei tofauti'
              : 'Bottle, Dozen, Crate... at different prices',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
      ]),
      const SizedBox(height: 12),

      // Quick-add templates
      if (_sellingUnits.isEmpty) ...[
        Text(l.isSw ? 'Template za haraka:' : 'Quick templates:',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: _unitTemplates.map((t) {
          final (label, units) = t;
          return GestureDetector(
            onTap: () => _applyTemplate(units),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _blue.withAlpha(15), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _blue.withAlpha(80)),
              ),
              child: Text(label,
                  style: TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          );
        }).toList()),
        const SizedBox(height: 10),
      ],

      // Column headers
      if (_sellingUnits.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(flex: 3, child: Text(l.isSw ? 'Unit' : 'Unit Name',
                style: TextStyle(color: AppColors.textMuted,
                    fontSize: 10, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Text('Conv. Qty',
                style: TextStyle(color: AppColors.textMuted,
                    fontSize: 10, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Expanded(flex: 3, child: Text('Bei (TZS)',
                style: TextStyle(color: AppColors.textMuted,
                    fontSize: 10, fontWeight: FontWeight.w600))),
            const SizedBox(width: 32),
          ]),
        ),
        ...List.generate(_sellingUnits.length, (i) {
          final u = _sellingUnits[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(flex: 3, child: _miniUnitField(
                ctrl: u.nameCtr, hint: 'Dozen', color: _blue)),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: _miniUnitField(
                ctrl: u.convCtr, hint: '12',
                color: AppColors.accent, numeric: true)),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: _miniUnitField(
                ctrl: u.priceCtr, hint: '11500',
                color: AppColors.primaryLt, numeric: true)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() {
                  _sellingUnits[i].dispose();
                  _sellingUnits.removeAt(i);
                }),
                child: Container(
                  width: 28, height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.chartRed.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.chartRed, size: 14),
                ),
              ),
            ]),
          );
        }),
      ],

      // Add unit button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() {
            final suggestedPrice = _sellingUnits.isEmpty
                ? _sellPriceCtr.text.trim() : '';
            _sellingUnits.add(_PageUnitRow(price: suggestedPrice));
          }),
          style: OutlinedButton.styleFrom(
            foregroundColor: _blue,
            side: BorderSide(color: _blue.withAlpha(120)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
          label: Text(l.isSw ? '+ Ongeza Unit' : '+ Add Unit',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),

      // Info tip
      if (_sellingUnits.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _blue.withAlpha(14), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _blue.withAlpha(50)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: _blue, size: 13),
            const SizedBox(width: 8),
            Expanded(child: Text(
              l.isSw
                  ? 'Conv. Qty = base units kwa kila unit. Dozen → 12'
                  : 'Conv. Qty = base units per selling unit. Dozen → 12',
              style: TextStyle(color: _blue.withAlpha(200), fontSize: 10, height: 1.4),
            )),
          ]),
        ),
      ],
    ]),
  );

  Widget _miniUnitField({
    required TextEditingController ctrl, required String hint,
    required Color color, bool numeric = false,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
    style: TextStyle(color: AppColors.textWhite, fontSize: 12),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true, fillColor: AppColors.bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
    ),
  );

  Widget _iconBtn({
    required IconData icon, required Color color,
    required VoidCallback onTap, String tooltip = '',
  }) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    ),
  );

  Widget _section({required IconData icon, required String label, required Widget child}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.gradPrimary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: AppColors.textLight,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            SizedBox(height: 14),
            child,
          ]),
        ),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    Color iconColor = const Color(0xFF94A3B8), // AppColors.textMuted dark default
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => TextFormField(
    controller: ctrl, keyboardType: keyboardType, maxLines: maxLines,
    style: TextStyle(color: AppColors.textWhite),
    validator: validator,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: iconColor, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      filled: true, fillColor: AppColors.bgCard,
    ),
  );

  Widget _autocomplete({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required List<String> suggestions,
    bool required = false,
    String? Function(String?)? validator,
  }) => Autocomplete<String>(
    optionsBuilder: (v) =>
        suggestions.where((s) => s.toLowerCase().contains(v.text.toLowerCase())).take(8),
    onSelected: (v) => ctrl.text = v,
    fieldViewBuilder: (ctx, fc, fn, onSubmit) {
      fc.text = ctrl.text;
      fc.addListener(() => ctrl.text = fc.text);
      return TextFormField(
        controller: fc, focusNode: fn,
        onFieldSubmitted: (_) => onSubmit(),
        style: TextStyle(color: AppColors.textWhite),
        validator: validator != null ? (_) => validator(ctrl.text) : null,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          filled: true, fillColor: AppColors.bgCard,
        ),
      );
    },
    optionsViewBuilder: (ctx, onSelected, opts) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: AppColors.bgCard, elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 260,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            itemCount: opts.length,
            itemBuilder: (ctx2, i) {
              final opt = opts.elementAt(i);
              return InkWell(
                onTap: () => onSelected(opt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(opt, style: TextStyle(color: AppColors.textWhite, fontSize: 14)),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

// ── Profit row (live preview) ──────────────────────────────────────────────────
class _ProfitRow extends StatefulWidget {
  final TextEditingController buyCtr;
  final TextEditingController sellCtr;
  const _ProfitRow({required this.buyCtr, required this.sellCtr});
  @override State<_ProfitRow> createState() => _ProfitRowState();
}
class _ProfitRowState extends State<_ProfitRow> {
  double _profit = 0, _margin = 0;
  @override
  void initState() {
    super.initState();
    widget.buyCtr.addListener(_calc);
    widget.sellCtr.addListener(_calc);
  }
  @override
  void dispose() {
    widget.buyCtr.removeListener(_calc);
    widget.sellCtr.removeListener(_calc);
    super.dispose();
  }
  void _calc() {
    final buy  = double.tryParse(widget.buyCtr.text) ?? 0;
    final sell = double.tryParse(widget.sellCtr.text) ?? 0;
    setState(() {
      _profit = sell - buy;
      _margin = sell > 0 ? (_profit / sell * 100) : 0;
    });
  }
  @override
  Widget build(BuildContext context) {
    final ok = _profit >= 0;
    final c  = ok ? AppColors.accent : AppColors.chartRed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withAlpha(18), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: c, size: 18),
        const SizedBox(width: 8),
        Text('${L.of(context).profit}: TZS ${_profit.toStringAsFixed(0)}',
            style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 12),
        Text('(${_margin.toStringAsFixed(1)}%)',
            style: TextStyle(color: c.withAlpha(180), fontSize: 12)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 1 — Scan + form
// ─────────────────────────────────────────────────────────────────────────────
class _ScanTab extends StatefulWidget {
  final VoidCallback onSaved;
  const _ScanTab({required this.onSaved});
  @override State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> with SingleTickerProviderStateMixin {
  final _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _form     = GlobalKey<FormState>();
  final _nameCtr  = TextEditingController();
  final _catCtr   = TextEditingController();
  final _unitCtr  = TextEditingController();
  final _sellCtr  = TextEditingController();
  final _buyCtr   = TextEditingController(text: '0');
  final _stockCtr = TextEditingController(text: '0');

  late final AnimationController _lineCtrl;
  late final Animation<double>   _lineAnim;
  List<String> _cats  = [];
  List<String> _units = [];
  String? _code;
  bool _saving = false;
  int  _added  = 0;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);
    _loadMeta();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _lineCtrl.dispose();
    for (final c in [_nameCtr,_catCtr,_unitCtr,_sellCtr,_buyCtr,_stockCtr]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    try {
      final cats  = await app.api!.getCategories(app.selectedBusiness!.businessId);
      final units = await app.api!.getUnits(app.selectedBusiness!.businessId);
      if (mounted) {
        setState(() {
          _cats  = cats.map((c) => (c as Map<String,dynamic>)['name'] as String).toList();
          _units = units;
        });
      }
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture cap) {
    if (_code != null) return;
    final raw = cap.barcodes.firstOrNull?.rawValue;
    if (raw != null && raw.isNotEmpty) {
      _ctrl.stop();
      setState(() => _code = raw);
    }
  }

  void _resetScan() {
    _nameCtr.clear(); _catCtr.clear(); _unitCtr.clear();
    _sellCtr.clear(); _buyCtr.text = '0'; _stockCtr.text = '0';
    setState(() => _code = null);
    _ctrl.start();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    setState(() => _saving = true);
    try {
      final res = await app.api!.addProduct(
        businessId: app.selectedBusiness!.businessId,
        branchId:   app.selectedBranch?.branchId ?? 0,
        name:       _nameCtr.text.trim(),
        category:   _catCtr.text.trim(),
        unit:       _unitCtr.text.trim(),
        buyPrice:   double.tryParse(_buyCtr.text)  ?? 0,
        sellPrice:  double.tryParse(_sellCtr.text) ?? 0,
        stock:      int.tryParse(_stockCtr.text)   ?? 0,
        barcode:    _code ?? '',
      );
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _added++);
        widget.onSaved();
        _resetScan();
      } else if (res['exists'] == true) {
        _snack(L.of(context).productExists, Colors.orange);
        _resetScan();
      } else {
        _snack(res['message'] as String? ?? L.of(context).error, Colors.redAccent);
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween(
          begin: _code == null
              ? const Offset(-1, 0) : const Offset(1, 0),
          end: Offset.zero,
        ).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: _code == null
          ? _buildScanner(l, mq)
          : _buildMiniForm(l, mq),
    );
  }

  Widget _buildScanner(L l, MediaQueryData mq) {
    const winSize = 240.0;
    return Stack(key: const ValueKey('scan'), children: [
      Positioned.fill(child: MobileScanner(controller: _ctrl, onDetect: _onDetect)),
      // Overlay with cutout
      Positioned.fill(child: CustomPaint(
        painter: _ScanOverlay(winSize: winSize),
      )),
      // Scan line
      AnimatedBuilder(
        animation: _lineAnim,
        builder: (ctx, _) {
          final h  = mq.size.height - 200;
          final lr = mq.size.width / 2 - winSize / 2 + 14;
          return Positioned(
            top: h / 2 - winSize / 2 + _lineAnim.value * (winSize - 4),
            left: lr, right: lr,
            child: Container(
              height: 2.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent, AppColors.primaryLt,
                  AppColors.accent, AppColors.primaryLt, Colors.transparent,
                ]),
              ),
            ),
          );
        },
      ),
      // Counter badge
      if (_added > 0)
        Positioned(
          top: 12, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.accent.withAlpha(100), blurRadius: 12)],
            ),
            child: Text('$_added ${l.isSw ? 'zimehifadhiwa' : 'saved'}',
                style: TextStyle(color: AppColors.bgDark,
                    fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      // Instruction
      Positioned(
        bottom: 32, left: 20, right: 20,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgDark.withAlpha(210),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.isSw
                  ? 'Elekeza kamera kwenye barcode ya bidhaa'
                  : 'Point camera at the product barcode',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildMiniForm(L l, MediaQueryData mq) {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + mq.padding.bottom),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Scanned barcode card
          StaggeredItem(index: 0, child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withAlpha(40), AppColors.primaryDk.withAlpha(40)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryLt.withAlpha(100)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.isSw ? 'Barcode iliyoscaniwa' : 'Scanned barcode',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text(_code ?? '',
                    style: TextStyle(color: AppColors.textWhite,
                        fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
              ])),
              TextButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 15),
                label: Text(l.isSw ? 'Scan Tena' : 'Rescan'),
                style: TextButton.styleFrom(foregroundColor: AppColors.chartOrange,
                    textStyle: const TextStyle(fontSize: 12)),
              ),
            ]),
          )),
          const SizedBox(height: 14),

          StaggeredItem(index: 1, child: _miniField(ctrl: _nameCtr,
              label: l.isSw ? 'Jina la Bidhaa *' : 'Product Name *',
              icon: Icons.drive_file_rename_outline_rounded,
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? (l.isSw ? 'Jina linahitajika' : 'Name required') : null)),
          const SizedBox(height: 10),

          StaggeredItem(index: 2, child: _miniAuto(ctrl: _catCtr,
              label: l.category, icon: Icons.category_outlined, suggestions: _cats)),
          const SizedBox(height: 10),

          StaggeredItem(index: 3, child: _miniAuto(ctrl: _unitCtr,
              label: l.unit, icon: Icons.straighten_rounded, suggestions: _units)),
          const SizedBox(height: 10),

          StaggeredItem(index: 4, child: Row(children: [
            Expanded(child: _miniField(ctrl: _sellCtr,
                label: l.isSw ? 'Bei Uuzaji *' : 'Sell Price *',
                icon: Icons.sell_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  return (d == null || d <= 0)
                      ? (l.isSw ? 'Lazima > 0' : 'Must be > 0') : null;
                })),
            const SizedBox(width: 10),
            Expanded(child: _miniField(ctrl: _buyCtr,
                label: l.buyPrice, icon: Icons.shopping_cart_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          ])),
          const SizedBox(height: 10),

          StaggeredItem(index: 5, child: _miniField(ctrl: _stockCtr,
              label: l.stock, icon: Icons.inventory_2_outlined,
              keyboardType: TextInputType.number)),
          const SizedBox(height: 22),

          StaggeredItem(index: 6, child: SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: _saving
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: AppColors.bgDark, strokeWidth: 2))
                  : Icon(Icons.check_circle_rounded, color: AppColors.bgDark, size: 22),
              label: Text(
                _saving
                    ? (l.isSw ? 'Inahifadhi...' : 'Saving...')
                    : (l.isSw ? 'Hifadhi & Scan Nyingine' : 'Save & Scan Next'),
                style: TextStyle(color: AppColors.bgDark,
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _miniField({
    required TextEditingController ctrl, required String label, required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl, keyboardType: keyboardType, validator: validator,
    style: TextStyle(color: AppColors.textWhite),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      filled: true, fillColor: AppColors.bgCard,
    ),
  );

  Widget _miniAuto({
    required TextEditingController ctrl, required String label,
    required IconData icon, required List<String> suggestions,
  }) => Autocomplete<String>(
    optionsBuilder: (v) =>
        suggestions.where((s) => s.toLowerCase().contains(v.text.toLowerCase())).take(6),
    onSelected: (v) => ctrl.text = v,
    fieldViewBuilder: (ctx, fc, fn, sub) {
      fc.text = ctrl.text;
      fc.addListener(() => ctrl.text = fc.text);
      return TextFormField(
        controller: fc, focusNode: fn, onFieldSubmitted: (_) => sub(),
        style: TextStyle(color: AppColors.textWhite),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5)),
          filled: true, fillColor: AppColors.bgCard,
        ),
      );
    },
    optionsViewBuilder: (ctx, sel, opts) => Align(
      alignment: Alignment.topLeft,
      child: Material(color: AppColors.bgCard, elevation: 8, borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 240,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6), shrinkWrap: true,
            itemCount: opts.length,
            itemBuilder: (ctx2, i) {
              final o = opts.elementAt(i);
              return InkWell(onTap: () => sel(o),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(o, style: TextStyle(color: AppColors.textWhite))));
            }),
        ),
      ),
    ),
  );
}

// ── Scan overlay painter ───────────────────────────────────────────────────────
class _ScanOverlay extends CustomPainter {
  final double winSize;
  const _ScanOverlay({required this.winSize});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, h = winSize / 2;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: winSize, height: winSize);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0xAA000000));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()..color = Colors.white.withAlpha(60)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    // Corner marks
    final c = Paint()..color = AppColors.accent..strokeWidth = 3.5
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const arm = 22.0;
    for (final pts in [
      [Offset(cx-h, cy-h+arm), Offset(cx-h, cy-h), Offset(cx-h+arm, cy-h)],
      [Offset(cx+h-arm, cy-h), Offset(cx+h, cy-h), Offset(cx+h, cy-h+arm)],
      [Offset(cx-h, cy+h-arm), Offset(cx-h, cy+h), Offset(cx-h+arm, cy+h)],
      [Offset(cx+h-arm, cy+h), Offset(cx+h, cy+h), Offset(cx+h, cy+h-arm)],
    ]) {
      canvas.drawPath(Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy), c);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 2 — Excel import (3-step wizard)
// ─────────────────────────────────────────────────────────────────────────────
class _ExRow {
  final int rowNum;
  final Map<String, String> data;
  bool selected;
  final List<String> errors;
  _ExRow({required this.rowNum, required this.data, required this.errors})
      : selected = true;
  bool get isValid => errors.isEmpty;
  String get name  => data['product_name'] ?? '';
}

class _ExcelTab extends StatefulWidget {
  final VoidCallback onImported;
  const _ExcelTab({required this.onImported});
  @override State<_ExcelTab> createState() => _ExcelTabState();
}

class _ExcelTabState extends State<_ExcelTab> {
  int _step = 0;
  List<_ExRow> _rows = [];
  bool _parsing = false, _importing = false;
  int? _importedCount, _skippedCount;

  static const _colMap = {
    'product_name':     ['jina la bidhaa','jina','product_name','name','bidhaa'],
    'product_category': ['kategoria','category','cat','product_category'],
    'product_satuan':   ['kitengo','unit','satuan','product_satuan','unit_name'],
    'purchase_price':   ['bei ya ununuzi','ununuzi','buy_price','purchase_price','bei_ununuzi','cost'],
    'sell_price':       ['bei ya uuzaji','uuzaji','sell_price','selling_price','bei_uuzaji','price'],
    'stock':            ['stock','idadi','qty','quantity','hisa'],
    'min_stock':        ['min_stock','stock ya chini','minimum_stock','min'],
    'barcode':          ['barcode','barcodi','bar_code'],
    'description':      ['maelezo','description','desc','notes'],
  };

  Future<void> _pickFile() async {
    setState(() => _parsing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx','xls','csv'], withData: true);
      if (result == null || result.files.isEmpty) { setState(() => _parsing = false); return; }
      final file = result.files.single;
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        setState(() => _parsing = false);
        return;
      }

      final rows = file.name.toLowerCase().endsWith('.csv')
          ? _parseCsv(bytes) : _parseXlsx(bytes);

      setState(() { _rows = rows; _step = 1; _parsing = false; });
    } catch (e) {
      if (mounted) { _snack('$e', Colors.redAccent); setState(() => _parsing = false); }
    }
  }

  List<_ExRow> _parseXlsx(Uint8List bytes) {
    final wb = xl.Excel.decodeBytes(bytes);
    final sheet = wb.tables.values.first;
    if (sheet.rows.isEmpty) return [];
    final headers = sheet.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase()).toList();
    final idx = _buildIdx(headers);
    final rows = <_ExRow>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      final raw = sheet.rows[r];
      if (raw.every((c) => (c?.value?.toString() ?? '').trim().isEmpty)) continue;
      final data = <String,String>{};
      idx.forEach((f, i) { if (i < raw.length) data[f] = (raw[i]?.value?.toString() ?? '').trim(); });
      rows.add(_ExRow(rowNum: r + 1, data: data, errors: _validate(data)));
    }
    return rows;
  }

  List<_ExRow> _parseCsv(Uint8List bytes) {
    final text  = String.fromCharCodes(bytes).replaceAll('\r\n','\n').replaceAll('\r','\n');
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final headers = _splitCsv(lines[0]).map((h) => h.trim().toLowerCase().replaceAll('"','')).toList();
    final idx = _buildIdx(headers);
    final rows = <_ExRow>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = _splitCsv(lines[i]);
      final data = <String,String>{};
      idx.forEach((f, ci) { if (ci < cols.length) data[f] = cols[ci].trim().replaceAll('"',''); });
      if (data.values.every((v) => v.isEmpty)) continue;
      rows.add(_ExRow(rowNum: i + 1, data: data, errors: _validate(data)));
    }
    return rows;
  }

  List<String> _splitCsv(String line) {
    final r = <String>[];
    final b = StringBuffer();
    var inQ = false;
    for (final ch in line.split('')) {
      if (ch == '"') { inQ = !inQ; }
      else if (ch == ',' && !inQ) { r.add(b.toString()); b.clear(); }
      else { b.write(ch); }
    }
    r.add(b.toString());
    return r;
  }

  Map<String,int> _buildIdx(List<String> headers) {
    final idx = <String,int>{};
    _colMap.forEach((field, aliases) {
      for (var i = 0; i < headers.length; i++) {
        if (aliases.contains(headers[i])) { idx[field] = i; break; }
      }
    });
    return idx;
  }

  List<String> _validate(Map<String,String> d) {
    final e = <String>[];
    if ((d['product_name'] ?? '').isEmpty) e.add('name required');
    if ((d['product_category'] ?? '').isEmpty) e.add('category required');
    if ((d['product_satuan'] ?? '').isEmpty) e.add('unit required');
    final sp = double.tryParse(d['sell_price'] ?? '');
    if (sp == null || sp <= 0) e.add('sell_price must be > 0');
    return e;
  }

  Future<void> _import() async {
    final l    = L.of(context);
    final sel  = _rows.where((r) => r.selected && r.isValid).toList();
    if (sel.isEmpty) { _snack(l.cartNotEmpty, Colors.orange); return; }
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    setState(() => _importing = true);
    try {
      final payload = sel.map((r) => {
        'product_name':     r.data['product_name'] ?? '',
        'product_category': r.data['product_category'] ?? '',
        'product_satuan':   r.data['product_satuan'] ?? '',
        'purchase_price':   double.tryParse(r.data['purchase_price'] ?? '') ?? 0.0,
        'sell_price':       double.tryParse(r.data['sell_price'] ?? '') ?? 0.0,
        'stock':            int.tryParse(r.data['stock'] ?? '') ?? 0,
        'min_stock':        int.tryParse(r.data['min_stock'] ?? '') ?? 5,
        'barcode':          r.data['barcode'] ?? '',
        'description':      r.data['description'] ?? '',
      }).toList();

      final res = await app.api!.importProductsBulk(
        businessId: app.selectedBusiness!.businessId,
        branchId:   app.selectedBranch?.branchId ?? 0,
        products:   payload,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _importedCount = res['inserted'] as int? ?? 0;
          _skippedCount  = res['skipped']  as int? ?? 0;
          _step = 2;
        });
        widget.onImported();
      } else {
        _snack(res['message'] as String? ?? l.error, Colors.redAccent);
      }
    } catch (e) {
      if (mounted) _snack('$e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: switch (_step) {
        1 => _buildPreview(),
        2 => _buildResult(),
        _ => _buildGuide(),
      },
    );
  }

  // Step 0: Guide ──────────────────────────────────────────────────────────────
  Widget _buildGuide() {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);
    return ListView(
      key: const ValueKey(0),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + mq.padding.bottom),
      children: [
        StaggeredItem(index: 0, child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.gradPrimary),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 14)),
              const SizedBox(width: 10),
              Text(l.formatGuide, style: TextStyle(
                  color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            Text(l.colHint, style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 14),
            ...[
              ['product_name / jina',  l.isSw ? 'Lazima' : 'Required', true],
              ['product_category',      l.isSw ? 'Lazima' : 'Required', true],
              ['product_satuan / unit', l.isSw ? 'Lazima' : 'Required', true],
              ['sell_price / uuzaji',  l.isSw ? 'Lazima' : 'Required', true],
              ['purchase_price',        l.isSw ? 'Hiari' : 'Optional', false],
              ['stock',                 l.isSw ? 'Hiari (0)' : 'Optional (0)', false],
              ['barcode',               l.isSw ? 'Hiari' : 'Optional', false],
            ].map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: (row[2] as bool) ? AppColors.accent : AppColors.textMuted,
                        shape: BoxShape.circle)),
                Expanded(child: Text(row[0] as String,
                    style: TextStyle(color: AppColors.textLight, fontSize: 12))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ((row[2] as bool) ? AppColors.accent : AppColors.textMuted).withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(row[1] as String,
                      style: TextStyle(
                          color: (row[2] as bool) ? AppColors.accent : AppColors.textMuted,
                          fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
            )),
          ]),
        )),
        const SizedBox(height: 20),
        StaggeredItem(index: 1, child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            onPressed: _parsing ? null : _pickFile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: _parsing
                ? SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: AppColors.bgDark, strokeWidth: 2))
                : Icon(Icons.upload_file_rounded, color: AppColors.bgDark, size: 22),
            label: Text(l.pickFile, style: TextStyle(
                color: AppColors.bgDark, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )),
      ],
    );
  }

  // Step 1: Preview ────────────────────────────────────────────────────────────
  Widget _buildPreview() {
    final l   = L.of(context);
    final mq  = MediaQuery.of(context);
    final sel = _rows.where((r) => r.selected && r.isValid).length;
    return Column(key: const ValueKey(1), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(children: [
          _chip('${_rows.length}', l.rowsFound, AppColors.chartPurple),
          const SizedBox(width: 8),
          _chip('${_rows.where((r) => r.isValid).length}', l.validRows, AppColors.accent),
          if (_rows.any((r) => !r.isValid)) ...[
            const SizedBox(width: 8),
            _chip('${_rows.where((r) => !r.isValid).length}', l.invalidRows, AppColors.chartRed),
          ],
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              final allSel = _rows.where((r) => r.isValid).every((r) => r.selected);
              for (final r in _rows.where((r) => r.isValid)) { r.selected = !allSel; }
            }),
            child: Text(_rows.where((r) => r.isValid).every((r) => r.selected)
                ? l.deselectAll : l.selectAll,
                style: const TextStyle(color: AppColors.primaryLt, fontSize: 12)),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: _rows.length,
          itemBuilder: (ctx, i) {
            final row = _rows[i];
            return StaggeredItem(
              index: i.clamp(0, 12), delay: const Duration(milliseconds: 30),
              child: GestureDetector(
                onTap: row.isValid ? () => setState(() => row.selected = !row.selected) : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: row.isValid
                        ? (row.selected ? AppColors.primary.withAlpha(20) : AppColors.bgCard)
                        : AppColors.chartRed.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: row.isValid
                        ? (row.selected ? AppColors.primaryLt : AppColors.border)
                        : AppColors.chartRed.withAlpha(120)),
                  ),
                  child: Row(children: [
                    SizedBox(width: 24, child: row.isValid
                        ? Checkbox(value: row.selected,
                            onChanged: (v) => setState(() => row.selected = v!),
                            activeColor: AppColors.primaryLt,
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))
                        : const Icon(Icons.error_outline_rounded, color: AppColors.chartRed, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(row.data['product_name']?.isNotEmpty == true
                          ? row.data['product_name']! : '— no name —',
                          style: TextStyle(color: row.isValid ? AppColors.textWhite : AppColors.chartRed,
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 3),
                      Wrap(spacing: 6, children: [
                        if (row.data['product_category']?.isNotEmpty == true)
                          _miniChip(row.data['product_category']!, AppColors.chartPurple),
                        if (row.data['sell_price']?.isNotEmpty == true)
                          _miniChip('TZS ${row.data['sell_price']}', AppColors.accent),
                        if (row.data['stock']?.isNotEmpty == true)
                          _miniChip('${row.data['stock']}', AppColors.chartGray),
                      ]),
                      if (!row.isValid)
                        Text(row.errors.join(' • '),
                            style: const TextStyle(color: AppColors.chartRed, fontSize: 11)),
                    ])),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + mq.padding.bottom),
        decoration: BoxDecoration(color: AppColors.bgCard,
            border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _pickFile,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.textLight,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(l.changeFile),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: (_importing || sel == 0) ? null : _import,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
            icon: _importing
                ? SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: AppColors.bgDark, strokeWidth: 2))
                : Icon(Icons.cloud_upload_rounded, color: AppColors.bgDark, size: 20),
            label: Text(_importing ? l.importing : '${l.importNow} ($sel)',
                style: TextStyle(color: AppColors.bgDark,
                    fontWeight: FontWeight.bold, fontSize: 14)),
          )),
        ]),
      ),
    ]);
  }

  // Step 2: Result ─────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final l       = L.of(context);
    final mq      = MediaQuery.of(context);
    final success = (_importedCount ?? 0) > 0;
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + mq.padding.bottom),
      child: Column(children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: success ? AppColors.gradLime : AppColors.gradOrange),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: (success ? AppColors.accent : AppColors.chartOrange).withAlpha(80),
                blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Icon(success ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: success ? AppColors.bgDark : Colors.white, size: 46),
        ),
        const SizedBox(height: 20),
        Text(l.importSummary, style: TextStyle(
            color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(children: [
          _resultTile('${_importedCount ?? 0}',
              l.isSw ? 'Zimeongezwa' : 'Imported', AppColors.accent),
          const SizedBox(width: 12),
          _resultTile('${_skippedCount ?? 0}',
              l.isSw ? 'Skip' : 'Skipped', AppColors.chartOrange),
        ]),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: () => setState(() { _step = 0; _rows = []; }),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            icon: Icon(Icons.add_rounded, color: AppColors.bgDark, size: 22),
            label: Text(l.isSw ? 'Ingiza Faili Jingine' : 'Import Another File',
                style: TextStyle(color: AppColors.bgDark, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String v, String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withAlpha(80))),
    child: Text('$v $label', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _miniChip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _resultTile(String v, String label, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(color: c.withAlpha(20), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withAlpha(60))),
    child: Column(children: [
      Text(v, style: TextStyle(color: c, fontSize: 32, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: c.withAlpha(180), fontSize: 12)),
    ]),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Unit row holder for _FormTab selling-units editor
// ─────────────────────────────────────────────────────────────────────────────
class _PageUnitRow {
  final TextEditingController nameCtr;
  final TextEditingController convCtr;
  final TextEditingController priceCtr;

  _PageUnitRow({
    String name  = '',
    String conv  = '1',
    String price = '',
  })  : nameCtr  = TextEditingController(text: name),
        convCtr  = TextEditingController(text: conv),
        priceCtr = TextEditingController(text: price);

  void dispose() {
    nameCtr.dispose();
    convCtr.dispose();
    priceCtr.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quick barcode scanner sheet (used inside Form tab)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickScanSheet extends StatefulWidget {
  final void Function(String) onScanned;
  const _QuickScanSheet({required this.onScanned});
  @override State<_QuickScanSheet> createState() => _QuickScanSheetState();
}

class _QuickScanSheetState extends State<_QuickScanSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _ctrl;
  late final AnimationController     _lineCtrl;
  late final Animation<double>       _lineAnim;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
    _lineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); _lineCtrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture cap) {
    if (_scanned) return;
    final raw = cap.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _scanned = true; _ctrl.stop(); setState(() {});
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) { Navigator.pop(context); widget.onScanned(raw); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const winSize = 220.0;
    return Container(
      height: mq.size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        Container(width: 44, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
          child: Row(children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryLt, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('Scan Barcode',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white54)),
          ]),
        ),
        Expanded(child: Stack(children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: MobileScanner(controller: _ctrl, onDetect: _onDetect)),
          Positioned.fill(child: CustomPaint(painter: _ScanOverlay(winSize: winSize))),
          AnimatedBuilder(
            animation: _lineAnim,
            builder: (ctx, _) {
              final h  = mq.size.height * 0.72 - 90;
              final lr = mq.size.width / 2 - winSize / 2 + 14;
              return Positioned(
                top: h / 2 - winSize / 2 + _lineAnim.value * (winSize - 4),
                left: lr, right: lr,
                child: Container(height: 2.5, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    _scanned ? AppColors.accent : AppColors.primaryLt,
                    _scanned ? AppColors.accent : AppColors.primaryLt,
                    Colors.transparent,
                  ]),
                )),
              );
            },
          ),
          if (_scanned) Container(color: AppColors.accent.withAlpha(50),
              child: const Center(child: Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 80))),
        ])),
      ]),
    );
  }
}
