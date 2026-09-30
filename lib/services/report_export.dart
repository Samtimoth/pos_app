import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/sale.dart';
import 'export/file_saver.dart';

/// Builds the Excel workbook for a report payload (from reports.php) and
/// hands it to the platform saver (share sheet on phones, download on web).
class ReportExport {
  ReportExport._();

  static double _n(dynamic v) => double.tryParse('$v') ?? 0;

  static Future<String> exportPnl({
    required Map<String, dynamic> report,
    required String businessName,
    required String currency,
  }) async {
    final range = Map<String, dynamic>.from(report['range'] as Map? ?? {});
    final pnl = Map<String, dynamic>.from(report['pnl'] as Map? ?? {});
    final sales = Map<String, dynamic>.from(report['sales'] as Map? ?? {});
    final expenses = Map<String, dynamic>.from(report['expenses'] as Map? ?? {});
    final from = '${range['from'] ?? ''}';
    final to = '${range['to'] ?? ''}';

    final excel = Excel.createExcel();
    final bold = CellStyle(bold: true);
    final head = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'));
    final money = CellStyle(numberFormat: NumFormat.standard_3);
    final moneyBold = CellStyle(bold: true, numberFormat: NumFormat.standard_3);

    TextCellValue tx(String s) => TextCellValue(s);
    DoubleCellValue dv(dynamic v) => DoubleCellValue(_n(v));

    // ── Sheet 1: P&L statement ─────────────────────────────────────────────
    final s1 = excel['P&L'];
    excel.setDefaultSheet('P&L');
    void row1(List<CellValue?> cells, {CellStyle? style}) {
      s1.appendRow(cells);
      if (style != null) {
        final r = s1.maxRows - 1;
        for (var c = 0; c < cells.length; c++) {
          s1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = style;
        }
      }
    }

    row1([tx('TAARIFA YA FAIDA NA HASARA (P&L)')], style: bold);
    row1([tx(businessName)]);
    row1([tx('Kipindi'), tx('$from  hadi  $to')]);
    row1([tx('Sarafu'), tx(currency)]);
    row1([tx('Imetolewa'), tx(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))]);
    row1([]);
    row1([tx('Kipengele'), tx('Kiasi ($currency)'), tx('% ya mauzo')], style: head);
    final rev = _n(pnl['revenue']);
    double pct(double v) => rev > 0 ? (v / rev * 100) : 0;
    row1([tx('Mauzo (Revenue)'), dv(rev), DoubleCellValue(100)], style: moneyBold);
    row1([tx('  Pesa iliyopokelewa'), dv(sales['collected']), DoubleCellValue(pct(_n(sales['collected'])))], style: money);
    row1([tx('  Madeni ya wateja (bado)'), dv(sales['outstanding']), DoubleCellValue(pct(_n(sales['outstanding'])))], style: money);
    row1([tx('(-) Gharama ya bidhaa zilizouzwa (COGS)'), dv(pnl['cogs']), DoubleCellValue(pct(_n(pnl['cogs'])))], style: money);
    row1([tx('= FAIDA GHAFI (Gross Profit)'), dv(pnl['gross_profit']), DoubleCellValue(_n(pnl['gross_margin_pct']))], style: moneyBold);
    row1([tx('(-) Matumizi (Expenses)'), dv(pnl['expenses']), DoubleCellValue(pct(_n(pnl['expenses'])))], style: money);
    row1([tx('= FAIDA HALISI (Net Profit)'), dv(pnl['net_profit']), DoubleCellValue(_n(pnl['net_margin_pct']))], style: moneyBold);
    row1([]);
    row1([tx('Mchanganuo wa matumizi'), tx('Kiasi'), tx('Idadi')], style: head);
    for (final e in (expenses['by_category'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(e as Map);
      row1([tx('${m['category']}'), dv(m['amount']), IntCellValue(int.tryParse('${m['count']}') ?? 0)], style: money);
    }
    row1([]);
    row1([tx('Mwezi'), tx('Mauzo'), tx('COGS'), tx('Faida ghafi'), tx('Matumizi'), tx('Faida halisi')], style: head);
    for (final e in (pnl['monthly'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(e as Map);
      row1([
        tx('${m['month']}'), dv(m['revenue']), dv(m['cogs']),
        dv(m['gross_profit']), dv(m['expenses']), dv(m['net_profit']),
      ], style: money);
    }
    s1.setColumnWidth(0, 42);
    s1.setColumnWidth(1, 18);
    for (var c = 2; c < 6; c++) {
      s1.setColumnWidth(c, 16);
    }

    // ── Sheet 2: Mauzo ─────────────────────────────────────────────────────
    final s2 = excel['Mauzo'];
    void row2(List<CellValue?> cells, {CellStyle? style}) {
      s2.appendRow(cells);
      if (style != null) {
        final r = s2.maxRows - 1;
        for (var c = 0; c < cells.length; c++) {
          s2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = style;
        }
      }
    }
    row2([tx('MCHANGANUO WA MAUZO  $from – $to')], style: bold);
    row2([tx('Idadi ya mauzo'), IntCellValue(int.tryParse('${sales['count']}') ?? 0)]);
    row2([tx('Mauzo jumla'), dv(sales['revenue'])], style: money);
    row2([tx('Pesa iliyopokelewa'), dv(sales['collected'])], style: money);
    row2([tx('Madeni'), dv(sales['outstanding'])], style: money);
    row2([tx('Punguzo'), dv(sales['discounts'])], style: money);
    row2([tx('Zilizofutwa'), IntCellValue(int.tryParse('${sales['voided_count']}') ?? 0), dv(sales['voided_amount'])], style: money);
    row2([]);
    row2([tx('Tarehe'), tx('Idadi'), tx('Mauzo'), tx('Imepokelewa')], style: head);
    for (final e in (sales['by_day'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(e as Map);
      row2([tx('${m['date']}'), IntCellValue(int.tryParse('${m['count']}') ?? 0), dv(m['revenue']), dv(m['collected'])], style: money);
    }
    row2([]);
    row2([tx('Aina ya malipo'), tx('Idadi'), tx('Kiasi')], style: head);
    for (final e in (sales['by_type'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(e as Map);
      row2([tx('${m['type']}'), IntCellValue(int.tryParse('${m['count']}') ?? 0), dv(m['amount'])], style: money);
    }
    row2([]);
    row2([tx('Bidhaa'), tx('Kategoria'), tx('Idadi'), tx('Mauzo'), tx('Gharama'), tx('Faida')], style: head);
    for (final e in (sales['top_products'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(e as Map);
      row2([tx('${m['name']}'), tx('${m['category']}'), dv(m['qty']), dv(m['revenue']), dv(m['cost']), dv(m['profit'])], style: money);
    }
    s2.setColumnWidth(0, 30);
    for (var c = 1; c < 6; c++) {
      s2.setColumnWidth(c, 16);
    }

    // ── Sheet 3: Matumizi ──────────────────────────────────────────────────
    final s3 = excel['Matumizi'];
    s3.appendRow([tx('Tarehe'), tx('Kategoria'), tx('Maelezo'), tx('Kiasi')]);
    for (var c = 0; c < 4; c++) {
      s3.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = head;
    }
    for (final e in (expenses['items'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(e as Map);
      s3.appendRow([tx('${m['expense_date']}'), tx('${m['category']}'), tx('${m['description'] ?? ''}'), dv(m['amount'])]);
    }
    s3.appendRow([tx(''), tx(''), tx('JUMLA'), dv(expenses['total'])]);
    s3.setColumnWidth(0, 14);
    s3.setColumnWidth(1, 20);
    s3.setColumnWidth(2, 40);
    s3.setColumnWidth(3, 16);

    excel.delete('Sheet1');
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Imeshindwa kutengeneza Excel');
    final safeName = businessName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final fname = 'PnL_${safeName}_${from}_$to.xlsx';
    return saveAndShare(fname, bytes, subject: 'P&L $businessName $from–$to');
  }

  /// Sales list (as currently filtered in the Sales screen) → one sheet.
  static Future<String> exportSalesList({
    required List<Sale> sales,
    required String businessName,
    required String label,
  }) async {
    final excel = Excel.createExcel();
    final head = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'));
    final money = CellStyle(numberFormat: NumFormat.standard_3);
    final sh = excel['Mauzo'];
    excel.setDefaultSheet('Mauzo');
    sh.appendRow([TextCellValue('MAUZO — $businessName ($label)')]);
    sh.appendRow([TextCellValue('Imetolewa ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}')]);
    sh.appendRow([]);
    final cols = ['Tarehe', 'Risiti', 'Mteja', 'Simu', 'Aina', 'Hali', 'Jumla', 'Imelipwa', 'Deni', 'Bidhaa'];
    sh.appendRow(cols.map((c) => TextCellValue(c)).toList());
    final hr = sh.maxRows - 1;
    for (var c = 0; c < cols.length; c++) {
      sh.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: hr)).cellStyle = head;
    }
    double total = 0, paid = 0, due = 0;
    for (final s in sales) {
      if (!s.isVoided) {
        total += s.totalAmount;
        paid += s.paidAmount;
        due += s.balanceAmount;
      }
      sh.appendRow([
        TextCellValue(s.createdAt),
        TextCellValue(s.saleNo.isNotEmpty ? s.saleNo : '#${s.saleId}'),
        TextCellValue(s.customerName),
        TextCellValue(s.customerPhone),
        TextCellValue(s.saleType),
        TextCellValue(s.paymentStatus),
        DoubleCellValue(s.totalAmount),
        DoubleCellValue(s.paidAmount),
        DoubleCellValue(s.balanceAmount),
        IntCellValue(s.itemCount),
      ]);
      final r = sh.maxRows - 1;
      for (var c = 6; c <= 8; c++) {
        sh.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = money;
      }
    }
    sh.appendRow([]);
    sh.appendRow([
      TextCellValue('JUMLA (bila zilizofutwa)'), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), TextCellValue(''), TextCellValue(''),
      DoubleCellValue(total), DoubleCellValue(paid), DoubleCellValue(due),
    ]);
    sh.setColumnWidth(0, 20);
    sh.setColumnWidth(1, 20);
    sh.setColumnWidth(2, 24);
    for (var c = 3; c < 10; c++) {
      sh.setColumnWidth(c, 14);
    }
    excel.delete('Sheet1');
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Imeshindwa kutengeneza Excel');
    final safe = businessName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final fname = 'Mauzo_${safe}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    return saveAndShare(fname, bytes, subject: 'Mauzo $businessName');
  }
}
