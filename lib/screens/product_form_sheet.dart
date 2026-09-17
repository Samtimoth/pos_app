import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/product.dart'; // exports ProductUnit
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADD SINGLE PRODUCT — bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class AddProductSheet extends StatefulWidget {
  final VoidCallback onSaved;
  /// When non-null, the sheet opens in **edit** mode with fields pre-filled.
  final Product? initialProduct;

  const AddProductSheet({super.key, required this.onSaved, this.initialProduct});

  bool get isEditMode => initialProduct != null;

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _form         = GlobalKey<FormState>();
  final _nameCtr      = TextEditingController();
  final _catCtr       = TextEditingController();
  final _unitCtr      = TextEditingController();
  final _buyPriceCtr  = TextEditingController(text: '0');
  final _sellPriceCtr = TextEditingController();
  final _stockCtr     = TextEditingController(text: '0');
  final _minStockCtr  = TextEditingController(text: '5');
  final _barcodeCtr       = TextEditingController();
  final _descCtr          = TextEditingController();
  final _wholesaleCtr     = TextEditingController();
  final _codeCtr          = TextEditingController();
  final _expiryCtr        = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  List<String> _categories  = [];
  List<String> _units        = [];
  bool _saving         = false;
  bool _loadingMeta    = true;
  // ── Selling units editor ───────────────────────────────────────────────────
  final List<_UnitRow> _sellingUnits = [];
  bool _barcodeTyping  = false; // mobile: show keyboard instead of tap-to-scan
  bool _barcodeFocused = false; // desktop: scan card highlight when focused
  XFile? _imageFile;             // newly picked local image (not yet uploaded)

  /// Camera barcode scanning: phones + web browsers (mobile_scanner/ZXing).
  bool get _canScan => kIsWeb || Platform.isAndroid || Platform.isIOS;
  /// Native gallery/camera image pickers (desktop uses a file dialog).
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void _onBarcodeChanged()     => setState(() {});
  void _onBarcodeFocusChange() => setState(() => _barcodeFocused = _barcodeFocusNode.hasFocus);

  // ── expiry date color ──────────────────────────────────────────────────────
  Color get _expiryColor {
    if (_expiryCtr.text.isEmpty) return AppColors.textMuted;
    final d = DateTime.tryParse(_expiryCtr.text);
    if (d == null) return AppColors.textMuted;
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 0)   return AppColors.chartRed;
    if (diff <= 30) return AppColors.chartOrange;
    return AppColors.accent;
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing an existing product
    final p = widget.initialProduct;
    if (p != null) {
      _nameCtr.text      = p.name;
      _catCtr.text       = p.category;
      _unitCtr.text      = p.unit;
      _buyPriceCtr.text  = p.buyPrice.toStringAsFixed(0);
      _sellPriceCtr.text = p.sellPrice.toStringAsFixed(0);
      _stockCtr.text     = p.stock.toString();
      _minStockCtr.text  = p.minStock.toString();
      _barcodeCtr.text   = p.barcode;
      _expiryCtr.text    = p.expiryDate ?? '';
      // Pre-fill selling units from product model
      for (final u in p.units) {
        _sellingUnits.add(_UnitRow(
          unitId: u.unitId,
          name:  u.unitName,
          conv:  u.conversionQty == u.conversionQty.truncateToDouble()
                    ? u.conversionQty.toInt().toString()
                    : u.conversionQty.toStringAsFixed(2),
          price: u.sellingPrice.toStringAsFixed(0),
        ));
      }
    }
    _loadMeta();
    _barcodeCtr.addListener(_onBarcodeChanged);
    _barcodeFocusNode.addListener(_onBarcodeFocusChange);
  }

  @override
  void dispose() {
    _barcodeCtr.removeListener(_onBarcodeChanged);
    _barcodeFocusNode.removeListener(_onBarcodeFocusChange);
    _barcodeFocusNode.dispose();
    for (final c in [_nameCtr, _catCtr, _unitCtr, _buyPriceCtr, _sellPriceCtr,
                     _stockCtr, _minStockCtr, _barcodeCtr, _descCtr,
                     _wholesaleCtr, _codeCtr, _expiryCtr]) {
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
    final biz = app.selectedBusiness!.businessId;
    try {
      final catList  = await app.api!.getCategories(biz);
      final unitList = await app.api!.getUnits(biz);
      final cats  = catList.map((c) => (c as Map<String, dynamic>)['name'] as String).toList();
      if (mounted) {
        setState(() {
          _categories  = cats;
          _units       = unitList;
          _loadingMeta = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  // ── Barcode helpers ────────────────────────────────────────────────────────
  // ── Image picker ──────────────────────────────────────────────────────────
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
      type: FileType.image,
      withData: false,
    );
    if (result != null && result.files.single.path != null && mounted) {
      setState(() => _imageFile = XFile(result.files.single.path!));
    }
  }

  // ── Barcode helpers ────────────────────────────────────────────────────────
  void _generateBarcode() {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() {
      _barcodeCtr.text = 'INT$ts';
      _barcodeTyping = false;
    });
  }

  void _scanBarcode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BarcodeScanSheet(
        onScanned: (value) => setState(() {
          _barcodeCtr.text = value;
          _barcodeTyping = false;
        }),
      ),
    );
  }

  Future<void> _printBarcode() async {
    final code = _barcodeCtr.text.trim();
    if (code.isEmpty) return;
    final name  = _nameCtr.text.trim();
    final price = _sellPriceCtr.text.trim();

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(72 * PdfPageFormat.mm, 38 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (name.isNotEmpty)
            pw.Text(name,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: code,
            width: 60 * PdfPageFormat.mm,
            height: 14 * PdfPageFormat.mm,
            drawText: false,
          ),
          pw.SizedBox(height: 2),
          pw.Text(code,
              style: pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center),
          if (price.isNotEmpty)
            pw.Text('TZS $price',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  // ── Expiry date picker ─────────────────────────────────────────────────────
  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _expiryCtr.text.isNotEmpty
        ? (DateTime.tryParse(_expiryCtr.text) ?? now.add(const Duration(days: 180)))
        : now.add(const Duration(days: 180));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate:  now.add(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary:   AppColors.primaryLt,
            onPrimary: AppColors.bgDark,
            surface:   AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _expiryCtr.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> res;
      final isEdit = widget.isEditMode;

      if (isEdit) {
        // ── EDIT MODE ─────────────────────────────────────────────────────
        res = await app.api!.updateProduct(
          productId:      widget.initialProduct!.productId,
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
          wholesalePrice: _wholesaleCtr.text.trim().isEmpty
              ? null : double.tryParse(_wholesaleCtr.text),
          expiryDate:     _expiryCtr.text.trim(),
          imagePath:      _imageFile?.path,
        );
      } else {
        // ── ADD MODE ──────────────────────────────────────────────────────
        res = await app.api!.addProduct(
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
          wholesalePrice: _wholesaleCtr.text.trim().isEmpty
              ? null : double.tryParse(_wholesaleCtr.text),
          expiryDate:     _expiryCtr.text.trim(),
          imagePath:      _imageFile?.path,
        );
      }

      if (!mounted) return;
      if (res['success'] == true) {
        // ── Save selling units ───────────────────────────────────────────────
        final savedPid = isEdit
            ? widget.initialProduct!.productId
            : (res['product_id'] as num?)?.toInt() ?? 0;

        if (savedPid > 0 && app.api != null) {
          final validUnits = _sellingUnits
              .where((u) => u.nameCtr.text.trim().isNotEmpty)
              .map((u) => {
                    'unit_name':      u.nameCtr.text.trim(),
                    'conversion_qty': double.tryParse(u.convCtr.text) ?? 1.0,
                    'selling_price':  double.tryParse(u.priceCtr.text) ?? 0.0,
                  })
              .toList();
          try {
            await app.api!.manageProductUnits(
              productId:  savedPid,
              businessId: app.selectedBusiness!.businessId,
              units:      validUnits,
            );
          } catch (_) {} // units save failure is non-fatal
        }

        if (!mounted) return;
        Navigator.pop(context);
        widget.onSaved();
        final msg = isEdit
            ? (L.of(context).isSw ? '✅ Bidhaa imesasishwa!' : '✅ Product updated!')
            : L.of(context).productAdded;
        AppNotification.show(context, msg, AppColors.accent,
            icon: isEdit ? Icons.edit_rounded : Icons.check_circle_rounded);
      } else if (!isEdit && res['exists'] == true) {
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

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating));

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize:     0.6,
      maxChildSize:     0.97,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _form,
          child: CustomScrollView(
            controller: scroll,
            slivers: [

              // ── Header ───────────────────────────────────────────────────
              SliverToBoxAdapter(child: Column(children: [
                Container(
                  width: 44, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: widget.isEditMode
                            ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)])
                            : const LinearGradient(colors: AppColors.gradPrimary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.isEditMode ? Icons.edit_rounded : Icons.add_box_rounded,
                        color: Colors.white, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        widget.isEditMode
                            ? (l.isSw ? 'Hariri Bidhaa' : 'Edit Product')
                            : l.addProductTitle,
                        style: TextStyle(color: AppColors.textWhite,
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (widget.isEditMode)
                        Text(widget.initialProduct!.name,
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
                  ]),
                ),
              ])),

              if (_loadingMeta)
                SliverFillRemaining(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const CircularProgressIndicator(color: AppColors.primaryLt),
                    const SizedBox(height: 16),
                    Text(l.loading, style: TextStyle(color: AppColors.textMuted)),
                  ]),
                )
              else ...[

                // ── Product Image ─────────────────────────────────────────
                SliverToBoxAdapter(child: StaggeredItem(index: 0, child: _imageSection(l))),

                // ── Basic Info ────────────────────────────────────────────
                SliverToBoxAdapter(child: StaggeredItem(index: 1, child: _section(
                  icon: Icons.inventory_2_rounded,
                  label: l.isSw ? 'Taarifa za Bidhaa' : 'Product Info',
                  child: Column(children: [
                    _field(ctrl: _nameCtr, label: l.productName,
                        icon: Icons.drive_file_rename_outline_rounded,
                        required: true,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? '${l.productName} ${l.requiredField}' : null),
                    const SizedBox(height: 12),
                    _autocomplete(ctrl: _catCtr, label: l.category,
                        icon: Icons.category_outlined,
                        suggestions: _categories, required: true,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? '${l.category} ${l.requiredField}' : null),
                    const SizedBox(height: 12),
                    _autocomplete(ctrl: _unitCtr, label: l.unit,
                        icon: Icons.straighten_rounded,
                        suggestions: _units, required: true,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? '${l.unit} ${l.requiredField}' : null),
                    const SizedBox(height: 12),
                    // Barcode row with scan + generate buttons
                    _barcodeRow(l),
                    if (_barcodeCtr.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _barcodePreview(l),
                    ],
                    const SizedBox(height: 12),
                    _field(ctrl: _codeCtr, label: l.productCode,
                        icon: Icons.tag_rounded),
                    const SizedBox(height: 12),
                    // Expiry date picker
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
                            prefixIcon: Icon(Icons.calendar_month_rounded,
                                color: _expiryColor, size: 18),
                            suffixIcon: _expiryCtr.text.isNotEmpty
                                ? null
                                : Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textMuted, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _expiryCtr.text.isEmpty
                                    ? AppColors.border : _expiryColor.withAlpha(120)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _expiryColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: AppColors.bgCard,
                          ),
                        ),
                      ),
                    ),
                    // Show clear button if date selected
                    if (_expiryCtr.text.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _expiryCtr.clear()),
                          icon: const Icon(Icons.clear_rounded, size: 14),
                          label: Text(l.isSw ? 'Futa tarehe' : 'Clear date',
                              style: const TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                        ),
                      ),
                  ]),
                ))),

                // ── Pricing ───────────────────────────────────────────────
                SliverToBoxAdapter(child: StaggeredItem(index: 2, child: _section(
                  icon: Icons.payments_rounded,
                  label: l.isSw ? 'Bei' : 'Pricing',
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _field(ctrl: _buyPriceCtr, label: l.buyPrice,
                          icon: Icons.arrow_downward_rounded,
                          iconColor: AppColors.chartOrange,
                          keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(ctrl: _sellPriceCtr, label: l.sellPrice,
                          icon: Icons.arrow_upward_rounded,
                          iconColor: AppColors.primaryLt,
                          keyboardType: TextInputType.number,
                          required: true,
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return '${l.sellPrice} ${l.requiredField}';
                            if ((double.tryParse(v!) ?? 0) <= 0) return '> 0';
                            return null;
                          })),
                    ]),
                    const SizedBox(height: 12),
                    _field(ctrl: _wholesaleCtr, label: l.wholesalePrice,
                        icon: Icons.storefront_outlined,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
                    // Faida ya moja kwa moja — wanao ruhusa pekee (Hatua 1)
                    if (context.read<AppProvider>().user?.canSeeCosts ?? false)
                      _ProfitPreview(buyCtr: _buyPriceCtr, sellCtr: _sellPriceCtr),
                  ]),
                ))),

                // ── Stock ─────────────────────────────────────────────────
                SliverToBoxAdapter(child: StaggeredItem(index: 3, child: _section(
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
                ))),

                // ── Description ───────────────────────────────────────────
                SliverToBoxAdapter(child: StaggeredItem(index: 4, child: _section(
                  icon: Icons.notes_rounded,
                  label: l.isSw ? 'Maelezo' : 'Notes',
                  child: _field(ctrl: _descCtr, label: l.description_,
                      icon: Icons.edit_note_rounded, maxLines: 3),
                ))),

                // ── Selling Units ─────────────────────────────────────────
                SliverToBoxAdapter(child: StaggeredItem(index: 5, child: _unitsSection(l))),

                // ── Save button ───────────────────────────────────────────
                SliverToBoxAdapter(child: StaggeredItem(index: 6, child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + mq.padding.bottom),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isEditMode
                            ? const Color(0xFF7C3AED) : AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: _saving
                          ? SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Icon(
                              widget.isEditMode
                                  ? Icons.save_rounded : Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                      label: Text(
                        _saving
                            ? (l.isSw ? 'Inahifadhi...' : 'Saving...')
                            : widget.isEditMode
                                ? (l.isSw ? 'Hifadhi Mabadiliko' : 'Save Changes')
                                : l.addProductTitle,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Image section ─────────────────────────────────────────────────────────
  Widget _imageSection(L l) {
    final existingUrl  = widget.initialProduct?.image ?? '';
    final hasExisting  = existingUrl.isNotEmpty;
    final hasNewImage  = _imageFile != null;
    final hasAnyImage  = hasNewImage || hasExisting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
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
              l.isSw ? 'Picha ya Bidhaa' : 'Product Image',
              style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            )),
            if (hasAnyImage)
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

          // Image preview area
          GestureDetector(
            onTap: _isMobile ? _pickImageFromGallery : _pickImageDesktop,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 160,
              decoration: BoxDecoration(
                color: hasAnyImage
                    ? Colors.transparent
                    : AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasAnyImage
                      ? AppColors.primaryLt.withAlpha(100)
                      : AppColors.border,
                  width: hasAnyImage ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasNewImage
                  ? (kIsWeb
                      ? Image.network(_imageFile!.path, fit: BoxFit.cover, width: double.infinity)
                      : Image.file(File(_imageFile!.path), fit: BoxFit.cover,
                          width: double.infinity))
                  : hasExisting
                      ? Image.network(existingUrl, fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (ctx, err, stack) => _imagePlaceholder(l))
                      : _imagePlaceholder(l),
            ),
          ),

          const SizedBox(height: 10),
          // Pick buttons
          if (_isMobile)
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
                label: l.isSw ? 'Chagua Picha' : 'Gallery',
                color: AppColors.accent,
                onTap: _pickImageFromGallery,
              )),
            ])
          else
            SizedBox(
              width: double.infinity,
              child: _imgPickBtn(
                icon: Icons.folder_open_rounded,
                label: l.isSw ? 'Chagua Faili la Picha' : 'Choose Image File',
                color: AppColors.primaryLt,
                onTap: _pickImageDesktop,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _imagePlaceholder(L l) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryLt.withAlpha(18),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryLt.withAlpha(50)),
        ),
        child: const Icon(Icons.add_photo_alternate_rounded,
            color: AppColors.primaryLt, size: 26),
      ),
      const SizedBox(height: 8),
      Text(
        l.isSw ? 'Gonga kuongeza picha' : 'Tap to add image',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      Text(
        l.isSw ? 'Hiari — si lazima' : 'Optional',
        style: TextStyle(color: AppColors.textMuted.withAlpha(150), fontSize: 11),
      ),
    ],
  );

  Widget _imgPickBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      );

  // ── Barcode row ────────────────────────────────────────────────────────────
  // Mobile: tap the big card to open camera directly → scans → fills field.
  // Desktop: prominent scan card — click focuses field, USB scanner types into it.
  Widget _barcodeRow(L l) {
    final hasCode = _barcodeCtr.text.isNotEmpty;

    // Desktop — prominent scan card (USB scanner types barcode + Enter into field)
    if (!_canScan) {
      return GestureDetector(
        // Tap anywhere on the card → focus the text field
        onTap: () => _barcodeFocusNode.requestFocus(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _barcodeFocused
                ? AppColors.primary.withAlpha(35)
                : AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _barcodeFocused
                  ? AppColors.primaryLt
                  : AppColors.primary.withAlpha(90),
              width: _barcodeFocused ? 1.8 : 1.2,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header: icon + label + generate button ──────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _barcodeFocused
                      ? AppColors.primaryLt.withAlpha(35)
                      : AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _barcodeFocused ? AppColors.primaryLt : AppColors.primary.withAlpha(220),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.isSw ? 'Ingiza / Scan Barcode' : 'Enter / Scan Barcode',
                    style: TextStyle(
                      color: _barcodeFocused ? AppColors.primaryLt : AppColors.textLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.isSw
                        ? 'Bonyeza hapa → scan kwa USB scanner (Enter inajaza)'
                        : 'Click here → scan with USB scanner (Enter to confirm)',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              )),
              const SizedBox(width: 8),
              // Generate random barcode button
              _actionBtn(
                icon: Icons.auto_fix_high_rounded,
                color: AppColors.accent,
                tooltip: l.autoGenerate,
                onTap: _generateBarcode,
              ),
            ]),
            const SizedBox(height: 10),
            // ── Actual text field ──────────────────────────────────────
            TextFormField(
              controller:  _barcodeCtr,
              focusNode:   _barcodeFocusNode,
              style: TextStyle(color: AppColors.textWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: l.isSw
                    ? 'Barcode itaonekana hapa baada ya scan...'
                    : 'Barcode appears here after scan...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                prefixIcon: Icon(Icons.qr_code_rounded,
                    color: AppColors.textMuted, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primaryLt, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
                filled:    true,
                fillColor: AppColors.bgDark,
              ),
            ),
            if (hasCode) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _barcodeCtr.clear()),
                  icon: const Icon(Icons.close_rounded, size: 13),
                  label: Text(l.isSw ? 'Futa barcode' : 'Clear barcode',
                      style: const TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ]),
        ),
      );
    }

    // Mobile — tap-to-scan card when empty, filled field when value present
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: (hasCode || _barcodeTyping)
              // Show filled text field (for edit / display)
              ? _field(ctrl: _barcodeCtr, label: l.barcode_,
                    icon: Icons.qr_code_rounded)
              // Show big tap-to-scan button
              : GestureDetector(
                  onTap: _scanBarcode,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryLt.withAlpha(130)),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded,
                              color: AppColors.primaryLt, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            l.isSw
                                ? 'Gonga Kuanza Scan Barcode'
                                : 'Tap to Scan Barcode',
                            style: const TextStyle(
                                color: AppColors.primaryLt,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ]),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        // Re-scan button (only when barcode already filled)
        if (hasCode) ...[
          _actionBtn(
            icon: Icons.qr_code_scanner_rounded,
            color: AppColors.primaryLt,
            tooltip: l.scanBarcode,
            onTap: _scanBarcode,
          ),
          const SizedBox(width: 6),
        ],
        // Generate barcode button
        _actionBtn(
          icon: Icons.auto_fix_high_rounded,
          color: AppColors.accent,
          tooltip: l.autoGenerate,
          onTap: _generateBarcode,
        ),
      ]),
      // "Type manually" link — shown only when scan card is visible
      if (!hasCode && !_barcodeTyping)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => _barcodeTyping = true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l.isSw ? 'Ingiza namba mkono' : 'Type manually',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ),
    ]);
  }

  Widget _barcodePreview(L l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        bw.BarcodeWidget(
          barcode: bw.Barcode.code128(),
          data: _barcodeCtr.text,
          width: double.infinity,
          height: 68,
          style: const TextStyle(color: Colors.black87, fontSize: 11),
          color: Colors.black,
          backgroundColor: Colors.white,
          errorBuilder: (ctx, err) => Center(
            child: Text(err,
                style: const TextStyle(color: AppColors.chartRed, fontSize: 11)),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(
            onPressed: _printBarcode,
            icon: const Icon(Icons.print_rounded, size: 16),
            label: Text(l.isSw ? 'Chapisha Label' : 'Print Label'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryLt,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String tooltip = '',
  }) =>
      Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(90)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );

  // ── Selling Units section ────────────────────────────────────────────────
  static const _blue = Color(0xFF3B82F6);

  static const _unitTemplates = [
    ('🥤 Vinywaji', [('Bottle','1'),('Half Dozen','6'),('Dozen','12'),('Crate','24')]),
    ('🍪 Chakula',  [('Piece','1'),('Pack','6'),('Dozen','12'),('Carton','48')]),
    ('📦 Kawaida',  [('Each','1'),('Pack','10'),('Box','12')]),
  ];

  void _applyUnitTemplate(List<(String, String)> units) {
    for (final u in _sellingUnits) { u.dispose(); }
    _sellingUnits.clear();
    final basePrice = double.tryParse(_sellPriceCtr.text.trim()) ?? 0.0;
    for (final (name, conv) in units) {
      final convQty = double.tryParse(conv) ?? 1.0;
      final price = basePrice > 0
          ? (basePrice * convQty).toStringAsFixed(0) : '';
      _sellingUnits.add(_UnitRow(name: name, conv: conv, price: price));
    }
    setState(() {});
  }

  Widget _unitsSection(L l) {
    const blue = _blue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: blue.withAlpha(28),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: blue.withAlpha(80)),
              ),
              child: const Icon(Icons.layers_rounded, color: blue, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.isSw ? 'Unit za Mauzo' : 'Selling Units',
                  style: TextStyle(color: AppColors.textLight,
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(l.isSw
                  ? 'Weka unit tofauti za kuuza (Bottle, Dozen, Crate...)'
                  : 'Set multiple units (Bottle, Dozen, Crate...)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ])),
          ]),

          // Quick-add templates (shown only when no units configured yet)
          if (_sellingUnits.isEmpty) ...[
            const SizedBox(height: 10),
            Text(l.isSw ? 'Template za haraka:' : 'Quick templates:',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: _unitTemplates.map((t) {
              final (label, units) = t;
              return GestureDetector(
                onTap: () => _applyUnitTemplate(units),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: blue.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: blue.withAlpha(80)),
                  ),
                  child: Text(label, style: TextStyle(
                      color: blue, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList()),
          ],

          if (_sellingUnits.isNotEmpty) ...[
            const SizedBox(height: 14),
            // Column labels
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(flex: 3, child: Text(l.isSw ? 'Jina' : 'Unit Name',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: Text(l.isSw ? 'Conv. Qty' : 'Conv. Qty',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: Text(l.isSw ? 'Bei (TZS)' : 'Price (TZS)',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
                const SizedBox(width: 32), // space for delete btn
              ]),
            ),
            // Unit rows
            ...List.generate(_sellingUnits.length, (i) {
              final u = _sellingUnits[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(flex: 3, child: _miniField(
                    ctrl: u.nameCtr,
                    hint: l.isSw ? 'Dozen' : 'Dozen',
                    color: blue,
                  )),
                  const SizedBox(width: 6),
                  Expanded(flex: 2, child: _miniField(
                    ctrl: u.convCtr,
                    hint: '12',
                    color: AppColors.accent,
                    numeric: true,
                  )),
                  const SizedBox(width: 6),
                  Expanded(flex: 3, child: _miniField(
                    ctrl: u.priceCtr,
                    hint: '11500',
                    color: AppColors.primaryLt,
                    numeric: true,
                  )),
                  const SizedBox(width: 4),
                  // Remove row button
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
          const SizedBox(height: 12),
          // Add unit button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                // Auto-suggest price from base sell price if first unit
                final suggestedPrice = _sellingUnits.isEmpty
                    ? _sellPriceCtr.text.trim()
                    : '';
                _sellingUnits.add(_UnitRow(price: suggestedPrice));
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: blue,
                side: BorderSide(color: blue.withAlpha(120)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
              label: Text(l.isSw ? '+ Ongeza Unit' : '+ Add Unit',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          if (_sellingUnits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: blue.withAlpha(14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: blue.withAlpha(50)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: blue, size: 13),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    l.isSw
                        ? 'Conv. Qty = base units kwa kila unit. Mfano: Dozen → 12'
                        : 'Conv. Qty = base units per 1 selling unit. e.g. Dozen → 12',
                    style: TextStyle(color: blue.withAlpha(200), fontSize: 10, height: 1.4),
                  )),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _miniField({
    required TextEditingController ctrl,
    required String hint,
    required Color  color,
    bool numeric = false,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(color: AppColors.textWhite, fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          filled: true,
          fillColor: AppColors.bgCard,
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

  // ── Section card ─────────────────────────────────────────────────────────
  Widget _section({required IconData icon, required String label, required Widget child}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(16),
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
              Text(label, style: TextStyle(
                  color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            SizedBox(height: 14),
            child,
          ]),
        ),
      );

  // ── Text field ────────────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    Color iconColor = const Color(0xFF94A3B8), // AppColors.textMuted dark default
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: AppColors.textWhite),
        validator: validator,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: iconColor, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.bgCard,
        ),
      );

  // ── Autocomplete field ────────────────────────────────────────────────────
  Widget _autocomplete({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required List<String> suggestions,
    bool required = false,
    String? Function(String?)? validator,
  }) =>
      Autocomplete<String>(
        optionsBuilder: (v) => suggestions
            .where((s) => s.toLowerCase().contains(v.text.toLowerCase()))
            .take(8),
        onSelected: (v) => ctrl.text = v,
        fieldViewBuilder: (ctx, fieldCtrl, focusNode, onSubmit) {
          fieldCtrl.text = ctrl.text;
          fieldCtrl.addListener(() => ctrl.text = fieldCtrl.text);
          return TextFormField(
            controller: fieldCtrl,
            focusNode: focusNode,
            onFieldSubmitted: (_) => onSubmit(),
            style: TextStyle(color: AppColors.textWhite),
            validator: validator != null ? (_) => validator(ctrl.text) : null,
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.textMuted, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.bgCard,
            ),
          );
        },
        optionsViewBuilder: (ctx, onSelected, opts) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.bgCard,
            elevation: 8,
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
                      child: Text(opt,
                          style: TextStyle(color: AppColors.textWhite, fontSize: 14)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
}

// ── Live profit preview ───────────────────────────────────────────────────────
class _ProfitPreview extends StatefulWidget {
  final TextEditingController buyCtr;
  final TextEditingController sellCtr;
  const _ProfitPreview({required this.buyCtr, required this.sellCtr});

  @override
  State<_ProfitPreview> createState() => _ProfitPreviewState();
}

class _ProfitPreviewState extends State<_ProfitPreview> {
  double _profit = 0;
  double _margin = 0;

  @override
  void initState() {
    super.initState();
    widget.buyCtr.addListener(_recalc);
    widget.sellCtr.addListener(_recalc);
  }

  @override
  void dispose() {
    widget.buyCtr.removeListener(_recalc);
    widget.sellCtr.removeListener(_recalc);
    super.dispose();
  }

  void _recalc() {
    final buy  = double.tryParse(widget.buyCtr.text) ?? 0;
    final sell = double.tryParse(widget.sellCtr.text) ?? 0;
    setState(() {
      _profit = sell - buy;
      _margin = sell > 0 ? (_profit / sell * 100) : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l      = L.of(context);
    final isGood = _profit >= 0;
    final color  = isGood ? AppColors.accent : AppColors.chartRed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        Icon(isGood ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color, size: 18),
        const SizedBox(width: 8),
        AnimatedCounter(
          value: _profit,
          formatter: (v) => 'TZS ${v.toStringAsFixed(0)}',
          prefix: '${l.profit}: ',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          duration: const Duration(milliseconds: 500),
        ),
        const SizedBox(width: 12),
        Text('(${_margin.toStringAsFixed(1)}%)',
            style: TextStyle(color: color.withAlpha(180), fontSize: 12)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARCODE SCANNER SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _BarcodeScanSheet extends StatefulWidget {
  final void Function(String) onScanned;
  const _BarcodeScanSheet({required this.onScanned});

  @override
  State<_BarcodeScanSheet> createState() => _BarcodeScanSheetState();
}

class _BarcodeScanSheetState extends State<_BarcodeScanSheet>
    with SingleTickerProviderStateMixin {
  final _scanCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late AnimationController _lineCtrl;
  late Animation<double>    _lineAnim;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw != null && raw.isNotEmpty) {
      _scanned = true;
      _scanCtrl.stop();
      setState(() {}); // trigger green flash rebuild
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) {
          Navigator.pop(context);
          widget.onScanned(raw);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);
    const windowSize = 260.0;

    return Container(
      height: mq.size.height * 0.78,
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        Container(
          width: 44, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.border.withAlpha(80),
              borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradPrimary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l.scanBarcode,
                style: TextStyle(color: AppColors.textWhite,
                    fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
            ),
          ]),
        ),
        // Scanner area
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(fit: StackFit.expand, children: [
              // Camera feed
              MobileScanner(controller: _scanCtrl, onDetect: _onDetect),
              // Overlay with scan window cutout
              CustomPaint(
                painter: _ScanOverlayPainter(
                    windowSize: windowSize, scanned: _scanned),
              ),
              // Animated scan line
              AnimatedBuilder(
                animation: _lineAnim,
                builder: (ctx, ch) {
                  final screenH = mq.size.height * 0.78 - 100;
                  final top = screenH / 2 - windowSize / 2 +
                      _lineAnim.value * (windowSize - 4);
                  final leftRight = mq.size.width / 2 - windowSize / 2 + 14;
                  return Positioned(
                    top: top,
                    left: leftRight,
                    right: leftRight,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          _scanned ? AppColors.accent : AppColors.primaryLt,
                          _scanned ? AppColors.accentBright : AppColors.accent,
                          _scanned ? AppColors.accent : AppColors.primaryLt,
                          Colors.transparent,
                        ]),
                        boxShadow: [BoxShadow(
                          color: (_scanned ? AppColors.accent : AppColors.primaryLt)
                              .withAlpha(150),
                          blurRadius: 8,
                        )],
                      ),
                    ),
                  );
                },
              ),
              // Success flash overlay
              if (_scanned)
                Container(
                  color: AppColors.accent.withAlpha(50),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded,
                        color: AppColors.accent, size: 80),
                  ),
                ),
              // Bottom hint
              Positioned(
                bottom: 24,
                left: 0, right: 0,
                child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.bgDark.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _scanned ? l.barcodeHint : l.pointCamera,
                    style: TextStyle(
                      color: _scanned ? AppColors.accent : AppColors.textLight,
                      fontSize: 13,
                      fontWeight: _scanned ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                )),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Scan overlay custom painter ───────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  final double windowSize;
  final bool   scanned;
  const _ScanOverlayPainter({required this.windowSize, required this.scanned});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = windowSize / 2;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: windowSize, height: windowSize);

    // Semi-transparent dark overlay with clear window
    final overlay = Paint()..color = const Color(0xAA000000);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // Window border
    final borderPaint = Paint()
      ..color = scanned ? AppColors.accent : Colors.white.withAlpha(76)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), borderPaint);

    // Corner L-marks
    final corner = Paint()
      ..color = scanned ? AppColors.accentBright : AppColors.accent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const arm = 22.0;
    final corners = [
      // top-left
      [Offset(cx-half, cy-half+arm), Offset(cx-half, cy-half), Offset(cx-half+arm, cy-half)],
      // top-right
      [Offset(cx+half-arm, cy-half), Offset(cx+half, cy-half), Offset(cx+half, cy-half+arm)],
      // bottom-left
      [Offset(cx-half, cy+half-arm), Offset(cx-half, cy+half), Offset(cx-half+arm, cy+half)],
      // bottom-right
      [Offset(cx+half-arm, cy+half), Offset(cx+half, cy+half), Offset(cx+half, cy+half-arm)],
    ];
    for (final pts in corners) {
      final p = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, corner);
    }
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.scanned != scanned;
}


// ─────────────────────────────────────────────────────────────────────────────
// Unit row data holder (used in AddProductSheet units editor)
// ─────────────────────────────────────────────────────────────────────────────
class _UnitRow {
  int    unitId;
  final TextEditingController nameCtr;
  final TextEditingController convCtr;
  final TextEditingController priceCtr;

  _UnitRow({
    this.unitId  = 0,
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

  ProductUnit toProductUnit(int productId) => ProductUnit(
    unitId:        unitId,
    productId:     productId,
    unitName:      nameCtr.text.trim(),
    conversionQty: double.tryParse(convCtr.text) ?? 1.0,
    sellingPrice:  double.tryParse(priceCtr.text) ?? 0.0,
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// EXCEL IMPORT SHEET — bottom sheet (3-step wizard)
// ─────────────────────────────────────────────────────────────────────────────

class _ImportRow {
  final int rowNum;
  final Map<String, String> data;
  bool selected;
  final List<String> errors;

  _ImportRow({
    required this.rowNum,
    required this.data,
    required this.errors,
  }) : selected = true;

  bool get isValid => errors.isEmpty;
  String get name  => data['product_name'] ?? '';
}

class ExcelImportSheet extends StatefulWidget {
  final VoidCallback onImported;
  const ExcelImportSheet({super.key, required this.onImported});

  @override
  State<ExcelImportSheet> createState() => _ExcelImportSheetState();
}

class _ExcelImportSheetState extends State<ExcelImportSheet> {
  int _step = 0; // 0=guide, 1=preview, 2=result

  String?          _fileName;
  List<_ImportRow> _rows     = [];
  bool _parsing   = false;
  bool _importing = false;

  int?         _importedCount;
  int?         _skippedCount;
  List<String> _importErrors = [];

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
    final l = L.of(context);
    setState(() => _parsing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _parsing = false);
        return;
      }
      final file = result.files.single;
      final name = file.name;
      Uint8List bytes;

      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        _snack(l.parseError, Colors.redAccent);
        setState(() => _parsing = false);
        return;
      }

      final rows = name.toLowerCase().endsWith('.csv')
          ? _parseCsv(bytes)
          : _parseXlsx(bytes);

      setState(() {
        _fileName = name;
        _rows     = rows;
        _step     = 1;
        _parsing  = false;
      });
    } catch (e) {
      if (mounted) {
        _snack('${L.of(context).parseError}: $e', Colors.redAccent);
        setState(() => _parsing = false);
      }
    }
  }

  List<_ImportRow> _parseXlsx(Uint8List bytes) {
    final workbook = xl.Excel.decodeBytes(bytes);
    final sheet    = workbook.tables.values.first;
    if (sheet.rows.isEmpty) return [];

    final headers = sheet.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
        .toList();
    final colIdx = _buildColIdx(headers);

    final rows = <_ImportRow>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      final raw = sheet.rows[r];
      if (raw.every((c) => (c?.value?.toString() ?? '').trim().isEmpty)) continue;
      final data = <String, String>{};
      colIdx.forEach((field, idx) {
        if (idx < raw.length) data[field] = (raw[idx]?.value?.toString() ?? '').trim();
      });
      rows.add(_ImportRow(rowNum: r + 1, data: data, errors: _validateRow(data)));
    }
    return rows;
  }

  List<_ImportRow> _parseCsv(Uint8List bytes) {
    final text  = String.fromCharCodes(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = _splitCsvLine(lines[0])
        .map((h) => h.trim().toLowerCase().replaceAll('"', ''))
        .toList();
    final colIdx = _buildColIdx(headers);

    final rows = <_ImportRow>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      final data = <String, String>{};
      colIdx.forEach((field, idx) {
        if (idx < cols.length) data[field] = cols[idx].trim().replaceAll('"', '');
      });
      if (data.values.every((v) => v.isEmpty)) continue;
      rows.add(_ImportRow(rowNum: i + 1, data: data, errors: _validateRow(data)));
    }
    return rows;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buf    = StringBuffer();
    var inQuote  = false;
    for (final ch in line.split('')) {
      if (ch == '"') {
        inQuote = !inQuote;
      } else if (ch == ',' && !inQuote) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }

  Map<String, int> _buildColIdx(List<String> headers) {
    final idx = <String, int>{};
    _colMap.forEach((field, aliases) {
      for (var i = 0; i < headers.length; i++) {
        if (aliases.contains(headers[i])) { idx[field] = i; break; }
      }
    });
    return idx;
  }

  List<String> _validateRow(Map<String, String> d) {
    final e = <String>[];
    if ((d['product_name'] ?? '').isEmpty)     e.add('name required');
    if ((d['product_category'] ?? '').isEmpty) e.add('category required');
    if ((d['product_satuan'] ?? '').isEmpty)   e.add('unit required');
    final sp = double.tryParse(d['sell_price'] ?? '');
    if (sp == null || sp <= 0) e.add('sell_price must be > 0');
    return e;
  }

  Future<void> _import() async {
    final selected = _rows.where((r) => r.selected && r.isValid).toList();
    if (selected.isEmpty) {
      _snack(L.of(context).cartNotEmpty, Colors.orange);
      return;
    }
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;

    setState(() => _importing = true);
    try {
      final payload = selected.map((r) => {
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
          _importErrors  = (res['errors'] as List?)?.cast<String>() ?? [];
          _step      = 2;
          _importing = false;
        });
        widget.onImported();
      } else {
        _snack(res['message'] as String? ?? L.of(context).error, Colors.redAccent);
        setState(() => _importing = false);
      }
    } catch (e) {
      if (mounted) {
        _snack('$e', Colors.redAccent);
        setState(() => _importing = false);
      }
    }
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating));

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.55,
      maxChildSize:     0.97,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Container(
            width: 44, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.gradGreen),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.importExcel, style: TextStyle(
                    color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
                if (_fileName != null)
                  Text(_fileName!, style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted)),
            ]),
          ),
          _StepBar(step: _step),
          const SizedBox(height: 8),
          Expanded(child: _step == 0
              ? _buildGuide(l, mq, scroll)
              : _step == 1
                  ? _buildPreview(l, mq, scroll)
                  : _buildResult(l, mq)),
        ]),
      ),
    );
  }

  // ── Step 0: Guide ──────────────────────────────────────────────────────────
  Widget _buildGuide(L l, MediaQueryData mq, ScrollController scroll) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg, borderRadius: BorderRadius.circular(16),
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
                child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Text(l.formatGuide, style: TextStyle(
                  color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            Text(l.colHint, style: TextStyle(
                color: AppColors.textMuted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 14),
            _ColTable(l: l),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withAlpha(40), AppColors.primaryDk.withAlpha(40)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.accent, size: 16),
              const SizedBox(width: 6),
              Text(l.isSw ? 'Mfano wa safu' : 'Example row',
                  style: const TextStyle(color: AppColors.accent,
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            const _SampleRow(),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
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
        ),
      ],
    );
  }

  // ── Step 1: Preview ────────────────────────────────────────────────────────
  Widget _buildPreview(L l, MediaQueryData mq, ScrollController scroll) {
    final valid    = _rows.where((r) => r.isValid).length;
    final invalid  = _rows.where((r) => !r.isValid).length;
    final selected = _rows.where((r) => r.selected && r.isValid).length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          _badge('${_rows.length}', l.rowsFound, AppColors.chartPurple),
          const SizedBox(width: 8),
          _badge('$valid', l.validRows, AppColors.accent),
          if (invalid > 0) ...[
            const SizedBox(width: 8),
            _badge('$invalid', l.invalidRows, AppColors.chartRed),
          ],
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              final allSel = _rows.where((r) => r.isValid).every((r) => r.selected);
              for (final r in _rows.where((row) => row.isValid)) {
                r.selected = !allSel;
              }
            }),
            child: Text(
              _rows.where((r) => r.isValid).every((r) => r.selected)
                  ? l.deselectAll : l.selectAll,
              style: const TextStyle(color: AppColors.primaryLt, fontSize: 12),
            ),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: _rows.length,
          itemBuilder: (ctx, i) {
            final row      = _rows[i];
            final rowValid = row.isValid;
            final borderColor = rowValid
                ? (row.selected ? AppColors.primaryLt : AppColors.border)
                : AppColors.chartRed.withAlpha(120);
            return StaggeredItem(
              index: i.clamp(0, 12),
              delay: const Duration(milliseconds: 30),
              child: GestureDetector(
                onTap: rowValid ? () => setState(() => row.selected = !row.selected) : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: rowValid
                        ? (row.selected ? AppColors.primary.withAlpha(20) : AppColors.bg)
                        : AppColors.chartRed.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(children: [
                    SizedBox(width: 24, child: rowValid
                        ? Checkbox(
                            value: row.selected,
                            onChanged: (v) => setState(() => row.selected = v!),
                            activeColor: AppColors.primaryLt,
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          )
                        : const Icon(Icons.error_outline_rounded,
                            color: AppColors.chartRed, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(
                          row.data['product_name']?.isNotEmpty == true
                              ? row.data['product_name']! : '— no name —',
                          style: TextStyle(
                            color: rowValid ? AppColors.textWhite : AppColors.chartRed,
                            fontWeight: FontWeight.w600, fontSize: 13,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                        Text('Row ${row.rowNum}',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ]),
                      const SizedBox(height: 3),
                      Wrap(spacing: 8, children: [
                        if (row.data['product_category']?.isNotEmpty == true)
                          _miniChip(row.data['product_category']!, AppColors.chartPurple),
                        if (row.data['product_satuan']?.isNotEmpty == true)
                          _miniChip(row.data['product_satuan']!, AppColors.chartBlue),
                        if (row.data['sell_price']?.isNotEmpty == true)
                          _miniChip('TZS ${row.data['sell_price']}', AppColors.accent),
                        if (row.data['stock']?.isNotEmpty == true)
                          _miniChip('Stock: ${row.data['stock']}', AppColors.chartGray),
                      ]),
                      if (!rowValid) ...[
                        const SizedBox(height: 4),
                        Text(row.errors.join(' • '),
                            style: const TextStyle(
                                color: AppColors.chartRed, fontSize: 11)),
                      ],
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
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickFile,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textLight,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(l.changeFile),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: (_importing || selected == 0) ? null : _import,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              icon: _importing
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: AppColors.bgDark, strokeWidth: 2))
                  : Icon(Icons.cloud_upload_rounded, color: AppColors.bgDark, size: 20),
              label: Text(
                _importing ? l.importing : '${l.importNow} ($selected)',
                style: TextStyle(color: AppColors.bgDark,
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Step 2: Result ─────────────────────────────────────────────────────────
  Widget _buildResult(L l, MediaQueryData mq) {
    final success = (_importedCount ?? 0) > 0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + mq.padding.bottom),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: success ? AppColors.gradLime : AppColors.gradOrange),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: (success ? AppColors.accent : AppColors.chartOrange).withAlpha(80),
              blurRadius: 30, offset: const Offset(0, 8),
            )],
          ),
          child: Icon(
            success ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: success ? AppColors.bgDark : Colors.white, size: 46,
          ),
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
              l.isSw ? 'Zimepigwa Skip' : 'Skipped', AppColors.chartOrange),
        ]),
        if (_importErrors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.chartRed.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.chartRed.withAlpha(60)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.chartRed, size: 16),
                const SizedBox(width: 6),
                Text(l.invalidRows, style: const TextStyle(
                    color: AppColors.chartRed, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              ..._importErrors.take(10).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e', style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
              )),
              if (_importErrors.length > 10)
                Text('+ ${_importErrors.length - 10} more...',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: Icon(Icons.check_rounded, color: AppColors.bgDark, size: 22),
            label: Text(l.done, style: TextStyle(
                color: AppColors.bgDark, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() { _step = 0; _rows = []; _fileName = null; }),
          child: Text(l.isSw ? 'Ingiza Faili Jingine' : 'Import Another File',
              style: const TextStyle(color: AppColors.primaryLt)),
        ),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _badge(String v, String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withAlpha(25), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withAlpha(80)),
    ),
    child: Text('$v $label',
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _miniChip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _resultTile(String v, String label, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: c.withAlpha(20), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Column(children: [
        Text(v, style: TextStyle(color: c, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: c.withAlpha(180), fontSize: 12)),
      ]),
    ),
  );
}

// ── Step bar ──────────────────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: List.generate(3, (i) {
        final active = i == step;
        final done   = i < step;
        final color  = done ? AppColors.accent : (active ? AppColors.primaryLt : AppColors.border);
        return Expanded(child: Row(children: [
          if (i > 0) Expanded(
            child: Container(height: 2, color: done ? AppColors.accent : AppColors.border),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: done || active ? color.withAlpha(30) : AppColors.bg,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: active ? 2 : 1),
            ),
            child: Center(
              child: done
                  ? Icon(Icons.check_rounded, color: color, size: 14)
                  : Text('${i + 1}', style: TextStyle(
                      color: color, fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal)),
            ),
          ),
          if (i < 2) Expanded(
            child: Container(height: 2, color: done ? AppColors.accent : AppColors.border),
          ),
        ]));
      })),
    );
  }
}

// ── Column format table ───────────────────────────────────────────────────────
class _ColTable extends StatelessWidget {
  final L l;
  const _ColTable({required this.l});

  @override
  Widget build(BuildContext context) {
    final cols = [
      ['product_name / jina',          l.isSw ? 'Lazima' : 'Required', true],
      ['product_category / kategoria', l.isSw ? 'Lazima' : 'Required', true],
      ['product_satuan / kitengo',     l.isSw ? 'Lazima' : 'Required', true],
      ['sell_price / uuzaji',          l.isSw ? 'Lazima' : 'Required', true],
      ['purchase_price / ununuzi',     l.isSw ? 'Hiari'  : 'Optional', false],
      ['stock / idadi',                l.isSw ? 'Hiari (default 0)' : 'Optional (default 0)', false],
      ['min_stock',                    l.isSw ? 'Hiari (default 5)' : 'Optional (default 5)', false],
      ['barcode',                      l.isSw ? 'Hiari'  : 'Optional', false],
    ];
    return Column(
      children: cols.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(
            width: 6, height: 6, margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: (c[2] as bool) ? AppColors.accent : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Text(c[0] as String,
              style: TextStyle(color: AppColors.textLight, fontSize: 12,
                  fontFamily: 'monospace'))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ((c[2] as bool) ? AppColors.accent : AppColors.textMuted).withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(c[1] as String,
                style: TextStyle(
                    color: (c[2] as bool) ? AppColors.accent : AppColors.textMuted,
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
      )).toList(),
    );
  }
}

// ── Sample row ────────────────────────────────────────────────────────────────
class _SampleRow extends StatelessWidget {
  const _SampleRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 36,
        columnSpacing: 14,
        headingTextStyle: TextStyle(
            color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
        dataTextStyle: TextStyle(color: AppColors.textWhite, fontSize: 11),
        columns: const [
          DataColumn(label: Text('product_name')),
          DataColumn(label: Text('product_category')),
          DataColumn(label: Text('product_satuan')),
          DataColumn(label: Text('purchase_price')),
          DataColumn(label: Text('sell_price')),
          DataColumn(label: Text('stock')),
        ],
        rows: const [
          DataRow(cells: [
            DataCell(Text('Sukari Kilo')),
            DataCell(Text('Vyakula')),
            DataCell(Text('Kg')),
            DataCell(Text('2500')),
            DataCell(Text('3000')),
            DataCell(Text('50')),
          ]),
          DataRow(cells: [
            DataCell(Text('Mafuta Ndebe')),
            DataCell(Text('Vyakula')),
            DataCell(Text('Ndebe')),
            DataCell(Text('18000')),
            DataCell(Text('22000')),
            DataCell(Text('20')),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAN-TO-ADD SHEET  — scan existing barcodes, fill form, save, repeat
// ─────────────────────────────────────────────────────────────────────────────
class ScanToAddSheet extends StatefulWidget {
  final VoidCallback onProductsAdded;
  const ScanToAddSheet({super.key, required this.onProductsAdded});

  @override
  State<ScanToAddSheet> createState() => _ScanToAddSheetState();
}

class _ScanToAddSheetState extends State<ScanToAddSheet>
    with SingleTickerProviderStateMixin {
  final _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates);

  final _form     = GlobalKey<FormState>();
  final _nameCtr  = TextEditingController();
  final _catCtr   = TextEditingController();
  final _unitCtr  = TextEditingController();
  final _sellCtr  = TextEditingController();
  final _buyCtr   = TextEditingController(text: '0');
  final _stockCtr = TextEditingController(text: '0');

  List<String> _cats  = [];
  List<String> _units = [];

  String? _code;    // null = scanning, non-null = form visible
  bool    _saving = false;
  int     _added  = 0;

  // scan-line animation
  late final AnimationController _lineCtrl;
  late final Animation<double>   _lineAnim;

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
    for (final c in [_nameCtr, _catCtr, _unitCtr, _sellCtr, _buyCtr, _stockCtr]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final app = context.read<AppProvider>();
    if (app.api == null || app.selectedBusiness == null) return;
    try {
      final catList  = await app.api!.getCategories(app.selectedBusiness!.businessId);
      final unitList = await app.api!.getUnits(app.selectedBusiness!.businessId);
      final cats = catList.map((c) => (c as Map<String, dynamic>)['name'] as String).toList();
      if (mounted) setState(() { _cats = cats; _units = unitList; });
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
    _nameCtr.clear();
    _catCtr.clear();
    _unitCtr.clear();
    _sellCtr.clear();
    _buyCtr.text  = '0';
    _stockCtr.text = '0';
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
        widget.onProductsAdded();
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

  void _snack(String m, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(m), backgroundColor: c,
              behavior: SnackBarBehavior.floating));

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l  = L.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.94,
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        Container(
          width: 44, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.border.withAlpha(80),
              borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradPrimary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.isSw ? 'Scan & Ingiza Bidhaa' : 'Scan & Add Products',
                  style: TextStyle(color: AppColors.textWhite,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              if (_added > 0)
                Text(
                  l.isSw ? '$_added bidhaa zimehifadhiwa' : '$_added products saved',
                  style: const TextStyle(color: AppColors.accent, fontSize: 12),
                ),
            ])),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.isSw ? 'Maliza' : 'Done',
                  style: const TextStyle(color: AppColors.primaryLt,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // Main area: scanner OR form
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _code == null
                ? _buildScanner(l, mq)
                : _buildForm(l, mq),
          ),
        ),
      ]),
    );
  }

  // ── Scanning view ──────────────────────────────────────────────────────────
  Widget _buildScanner(L l, MediaQueryData mq) {
    const winSize = 240.0;
    return Stack(key: const ValueKey('scanner'), children: [
      // Camera feed
      Positioned.fill(
        child: MobileScanner(controller: _ctrl, onDetect: _onDetect),
      ),
      // Dark overlay with cutout
      Positioned.fill(
        child: CustomPaint(
          painter: _ScanOverlayPainter(windowSize: winSize, scanned: false),
        ),
      ),
      // Animated scan line
      AnimatedBuilder(
        animation: _lineAnim,
        builder: (ctx, ch) {
          final screenH = mq.size.height * 0.94 - 90;
          final top = screenH / 2 - winSize / 2 + _lineAnim.value * (winSize - 4);
          final lr  = mq.size.width / 2 - winSize / 2 + 14;
          return Positioned(
            top: top, left: lr, right: lr,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.primaryLt,
                  AppColors.accent,
                  AppColors.primaryLt,
                  Colors.transparent,
                ]),
                boxShadow: [BoxShadow(
                    color: AppColors.primaryLt.withAlpha(150), blurRadius: 8)],
              ),
            ),
          );
        },
      ),
      // Bottom instruction
      Positioned(
        bottom: 32, left: 20, right: 20,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgDark.withAlpha(210),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.isSw
                  ? 'Elekeza kamera kwenye barcode ya bidhaa\niliyopo kwenye bidhaa'
                  : 'Point camera at the barcode\nprinted on your product',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Form view (after scan) ─────────────────────────────────────────────────
  Widget _buildForm(L l, MediaQueryData mq) {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + mq.padding.bottom),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Scanned barcode card
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(90)),
            ),
            child: Row(children: [
              const Icon(Icons.qr_code_rounded, color: AppColors.primaryLt, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.isSw ? 'Barcode iliyoscaniwa' : 'Scanned barcode',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text(_code ?? '',
                    style: TextStyle(
                        color: AppColors.textWhite, fontWeight: FontWeight.bold,
                        fontSize: 15, fontFamily: 'monospace')),
              ])),
              TextButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 15),
                label: Text(l.isSw ? 'Scan Nyingine' : 'Rescan'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.chartOrange,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Product name
          _qField(ctrl: _nameCtr,
              label: l.isSw ? 'Jina la Bidhaa *' : 'Product Name *',
              icon: Icons.drive_file_rename_outline_rounded,
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? (l.isSw ? 'Jina linahitajika' : 'Name required') : null),
          const SizedBox(height: 10),

          // Category autocomplete
          _qAuto(ctrl: _catCtr, label: l.category,
              icon: Icons.category_outlined, suggestions: _cats),
          const SizedBox(height: 10),

          // Unit autocomplete
          _qAuto(ctrl: _unitCtr, label: l.unit,
              icon: Icons.straighten_rounded, suggestions: _units),
          const SizedBox(height: 10),

          // Sell price + Buy price
          Row(children: [
            Expanded(
              child: _qField(
                  ctrl: _sellCtr,
                  label: l.isSw ? 'Bei Uuzaji *' : 'Sell Price *',
                  icon: Icons.sell_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final d = double.tryParse(v ?? '');
                    return (d == null || d <= 0)
                        ? (l.isSw ? 'Lazima > 0' : 'Must be > 0') : null;
                  }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _qField(
                  ctrl: _buyCtr,
                  label: l.buyPrice,
                  icon: Icons.shopping_cart_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ),
          ]),
          const SizedBox(height: 10),

          // Stock
          _qField(ctrl: _stockCtr, label: l.stock,
              icon: Icons.inventory_2_outlined,
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),

          // Save & Scan Next button
          SizedBox(
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
                      child: CircularProgressIndicator(
                          color: AppColors.bgDark, strokeWidth: 2))
                  : Icon(Icons.check_circle_rounded,
                      color: AppColors.bgDark, size: 22),
              label: Text(
                _saving
                    ? (l.isSw ? 'Inahifadhi...' : 'Saving...')
                    : (l.isSw ? 'Hifadhi & Scan Nyingine' : 'Save & Scan Next'),
                style: TextStyle(color: AppColors.bgDark,
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Compact text field ─────────────────────────────────────────────────────
  Widget _qField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: TextStyle(color: AppColors.textWhite),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.bgCard,
        ),
      );

  // ── Compact autocomplete field ─────────────────────────────────────────────
  Widget _qAuto({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required List<String> suggestions,
  }) =>
      Autocomplete<String>(
        optionsBuilder: (v) => suggestions
            .where((s) => s.toLowerCase().contains(v.text.toLowerCase()))
            .take(6),
        onSelected: (v) => ctrl.text = v,
        fieldViewBuilder: (ctx, fc, fn, onSubmit) {
          fc.text = ctrl.text;
          fc.addListener(() => ctrl.text = fc.text);
          return TextFormField(
            controller: fc,
            focusNode: fn,
            onFieldSubmitted: (_) => onSubmit(),
            style: TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.textMuted, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryLt, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.bgCard,
            ),
          );
        },
        optionsViewBuilder: (ctx, onSel, opts) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.bgCard, elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 220,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (ctx2, i) {
                  final opt = opts.elementAt(i);
                  return InkWell(
                    onTap: () => onSel(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Text(opt,
                          style: TextStyle(
                              color: AppColors.textWhite, fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
}
