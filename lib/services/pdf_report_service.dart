import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../services/report_service.dart';
import '../utils/currency_formatter.dart';

class PdfReportService {
  static final PdfReportService instance = PdfReportService._();
  PdfReportService._();

  static const _blue = PdfColor.fromInt(0xFF1E3A8A);
  static const _lightBlue = PdfColor.fromInt(0xFFEFF6FF);
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _lightGrey = PdfColor.fromInt(0xFFF9FAFB);
  static const _red = PdfColor.fromInt(0xFFDC2626);
  static const _green = PdfColor.fromInt(0xFF16A34A);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);
  static const _black = PdfColor.fromInt(0xFF111827);
  static const _whiteSubtle = PdfColor.fromInt(0xFFCCDDFF);

  // Same category labels the Expenses section merges grocery/transport
  // into (see _buildExpensesSection) — kept here too so the period
  // breakdown and the highlighted summary rows agree on what counts as
  // "grocery" vs. "transport" without re-deriving the mapping twice.
  static const _groceryCategory = 'Grocery / Resupply';
  static const _transportCategory = 'Fare / Transport';

  static final _monthYearFormat = DateFormat('MMMM yyyy');
  static final _shortMonthDayFormat = DateFormat('MMM d');

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-').map(int.parse).toList();
    return _monthYearFormat.format(DateTime(parts[0], parts[1]));
  }

  // Mirrors GroceryScreen._weekLabel — Monday-of-week key formatted as a
  // "MMM d–d, yyyy" range so the PDF reads the same as the in-app cards.
  String _weekLabel(String weekKey) {
    final parts = weekKey.split('-').map(int.parse).toList();
    final monday = DateTime(parts[0], parts[1], parts[2]);
    final sunday = monday.add(const Duration(days: 6));
    final sameMonth =
        monday.month == sunday.month && monday.year == sunday.year;
    final start = _shortMonthDayFormat.format(monday);
    final end =
        sameMonth ? '${sunday.day}' : _shortMonthDayFormat.format(sunday);
    return '$start–$end, ${sunday.year}';
  }

  // Shared by the Grocery and Fare/Transport weekly/monthly breakdowns —
  // both group a (date, amount) series into Mon-Sun weeks or calendar
  // months the same way.
  List<MapEntry<String, double>> _groupByPeriod(
    Iterable<MapEntry<DateTime, double>> items,
    String Function(DateTime) keyOf,
  ) {
    final totals = <String, double>{};
    for (final it in items) {
      final key = keyOf(it.key);
      totals[key] =
          CurrencyFormatter.roundCents((totals[key] ?? 0) + it.value);
    }
    return totals.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  String _monthKeyOf(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  // Monday of the date's week, as "yyyy-MM-dd" — mirrors GroceryEntry.weekKey.
  String _weekKeyOf(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  // ── Replace ₱ with PHP for PDF font compatibility ──
  String _c(double amount) {
    final negative = amount < 0;
    final formatted = amount.abs().toStringAsFixed(2);
    final parts = formatted.split('.');
    final whole = parts[0];
    final decimal = parts[1];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = whole.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
      count++;
    }
    final grouped = buffer.toString().split('').reversed.join();
    return '${negative ? '-' : ''}PHP $grouped.$decimal';
  }

  Future<void> generateAndPrint({
    required AppProvider prov,
    required String periodLabel,
    required ReportData report,
  }) async {
    final pdf = await buildDocument(
      prov: prov,
      periodLabel: periodLabel,
      report: report,
    );

    final now = DateTime.now();
    final dateStr = '${now.month}/${now.day}/${now.year}';

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'StorePH_Report_${periodLabel.replaceAll(' ', '_')}_$dateStr.pdf',
    );
  }

  /// Builds the report document without triggering the OS print/preview
  /// dialog — used by [generateAndPrint] and directly testable on its own.
  Future<pw.Document> buildDocument({
    required AppProvider prov,
    required String periodLabel,
    required ReportData report,
  }) async {
    final pdf = pw.Document();
    const pageFormat = PdfPageFormat.legal;

    final fontData = await rootBundle
        .load('assets/fonts/Poppins-Regular.ttf');
    final boldData = await rootBundle
        .load('assets/fonts/Poppins-Bold.ttf');
    final font =
        pw.Font.ttf(fontData.buffer.asByteData());
    final bold =
        pw.Font.ttf(boldData.buffer.asByteData());

    final now = DateTime.now();
    final dateStr =
        '${now.month}/${now.day}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final prefs = await SharedPreferences.getInstance();
    final storeName =
        prefs.getString('store_name') ?? 'StorePH';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 48),
        header: (ctx) => ctx.pageNumber == 1
            ? _buildHeader(ctx, periodLabel, dateStr, timeStr,
                bold, font, storeName)
            : pw.SizedBox(),
        footer: (ctx) => _buildFooter(ctx, font),
        build: (ctx) => [
          _buildSummarySection(report, bold, font),
          pw.SizedBox(height: 16),
          _buildCicoSection(report, bold, font),
          pw.SizedBox(height: 16),
          _buildCapitalSection(prov, bold, font),
          pw.SizedBox(height: 16),
          _buildTopProductsSection(report, bold, font),
          pw.SizedBox(height: 16),
          _buildExpensesSection(report, bold, font),
          pw.SizedBox(height: 16),
          _buildGroceryPeriodSection(report, bold, font),
          pw.SizedBox(height: 16),
          _buildTransportPeriodSection(report, bold, font),
          pw.SizedBox(height: 16),
          _buildCreditSection(prov, bold, font),
          pw.SizedBox(height: 16),
          _buildDailyBreakdown(report, bold, font),
        ],
      ),
    );

    return pdf;
  }

  // ── HEADER ────────────────────────────────────────────
  pw.Widget _buildHeader(
    pw.Context ctx,
    String periodLabel,
    String dateStr,
    String timeStr,
    pw.Font bold,
    pw.Font font,
    String storeName,
  ) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: const pw.BoxDecoration(
          color: _blue,
          borderRadius: pw.BorderRadius.all(
              pw.Radius.circular(6)),
        ),
        child: pw.Row(
          crossAxisAlignment:
              pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      'BUSINESS PERFORMANCE REPORT',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 14,
                          color: PdfColors.white)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      storeName,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: _whiteSubtle)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Period: $periodLabel',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 10,
                        color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text(
                    'Generated: $dateStr $timeStr',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: _whiteSubtle)),
                pw.SizedBox(height: 2),
                pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: _whiteSubtle)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
    ]);
  }

  // ── FOOTER ────────────────────────────────────────────
  pw.Widget _buildFooter(pw.Context ctx, pw.Font font) {
    return pw.Column(children: [
      pw.Divider(color: _border, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Powered by StorePH',
              style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: _grey)),
          pw.Text(
              'This report is auto-generated and for internal use only.',
              style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: _grey)),
        ],
      ),
    ]);
  }

  // ── SUMMARY ───────────────────────────────────────────
  pw.Widget _buildSummarySection(
    ReportData report,
    pw.Font bold,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('FINANCIAL SUMMARY', bold),
        pw.SizedBox(height: 8),
        // Bumped past the rest of the report's text — these four numbers
        // are the ones an owner (including older readers) needs to read
        // at a glance. Kept short of the first size tried (18pt): at four
        // cards per row that pushed "PHP 12,345.00" onto two lines, which
        // reads worse than a slightly smaller single line.
        pw.Row(children: [
          _summaryCard('Total Sales',
              _c(report.totalRevenue), bold, font,
              isHighlight: true,
              labelFontSize: 9, valueFontSize: 13),
          pw.SizedBox(width: 8),
          _summaryCard('Total Profit',
              _c(report.totalProfit), bold, font,
              valueColor: _green,
              labelFontSize: 9, valueFontSize: 13),
          pw.SizedBox(width: 8),
          _summaryCard('Total Expenses',
              _c(report.totalExpenses), bold, font,
              valueColor: report.totalExpenses > 0
                  ? _red
                  : _black,
              labelFontSize: 9, valueFontSize: 13),
          pw.SizedBox(width: 8),
          _summaryCard('Net Income',
              _c(report.netIncome), bold, font,
              valueColor: report.netIncome >= 0
                  ? _green
                  : _red,
              isHighlight: report.netIncome >= 0,
              labelFontSize: 9, valueFontSize: 13),
        ]),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _lightGrey,
            borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(6)),
            border:
                pw.Border.all(color: _border, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Text('Total Transactions: ',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: _grey)),
                pw.Text('${report.transactionCount}',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 11,
                        color: _black)),
                pw.Spacer(),
                pw.Text('Average Sale Amount: ',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: _grey)),
                pw.Text(
                    report.transactionCount > 0
                        ? _c(report.totalRevenue /
                            report.transactionCount)
                        : 'PHP 0.00',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 11,
                        color: _black)),
              ]),
              pw.SizedBox(height: 4),
              pw.Text(
                'Average Sale Amount = Total Sales ÷ Total '
                'Transactions — the typical peso amount per sale, not '
                'profit.',
                style: pw.TextStyle(font: font, fontSize: 7.5, color: _grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── CICO ──────────────────────────────────────────────
  // Mirrors the "Cash In-Cash Out" card Reports shows on-screen for the
  // same period — that card used to have no PDF counterpart at all, so
  // anyone exporting a report to check CICO numbers found the section
  // just missing with no note that it was intentionally left out.
  pw.Widget _buildCicoSection(
    ReportData report,
    pw.Font bold,
    pw.Font font,
  ) {
    if (report.cicoTransactionCount == 0 &&
        report.cicoCommission <= 0 &&
        report.cicoCashInVolume <= 0 &&
        report.cicoCashOutVolume <= 0) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('CASH IN - CASH OUT (AGENT SERVICES)', bold),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _summaryCard('Commission', _c(report.cicoCommission), bold, font,
              isHighlight: true, valueColor: _green),
          pw.SizedBox(width: 8),
          _summaryCard('Cash In', _c(report.cicoCashInVolume), bold, font),
          pw.SizedBox(width: 8),
          _summaryCard('Cash Out', _c(report.cicoCashOutVolume), bold, font),
        ]),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _lightGrey,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _border, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Text('CICO Transactions: ',
                    style:
                        pw.TextStyle(font: font, fontSize: 9, color: _grey)),
                pw.Text('${report.cicoTransactionCount}',
                    style:
                        pw.TextStyle(font: bold, fontSize: 11, color: _black)),
              ]),
              pw.SizedBox(height: 4),
              pw.Text(
                'Commission is separate agent-service income — not '
                'included in Net Income above.',
                style: pw.TextStyle(font: font, fontSize: 8, color: _grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── CAPITAL ───────────────────────────────────────────
  pw.Widget _buildCapitalSection(
    AppProvider prov,
    pw.Font bold,
    pw.Font font,
  ) {
    if (prov.capital == null) return pw.SizedBox();

    final roi = prov.roiPercent;
    final isProfit = roi >= 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('CAPITAL & ROI OVERVIEW', bold),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _lightBlue,
            borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(6)),
            border:
                pw.Border.all(color: _blue, width: 0.5),
          ),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  _capitalRow('Business Setup Costs',
                      _c(prov.capital!.setupCosts),
                      font, bold),
                  pw.SizedBox(height: 4),
                  _capitalRow('Starting Inventory Value',
                      _c(prov.capital!.inventoryValue),
                      font, bold),
                  pw.SizedBox(height: 4),
                  pw.Divider(
                      color: _border, thickness: 0.5),
                  pw.SizedBox(height: 4),
                  _capitalRow('Total Initial Investment',
                      _c(prov.totalInvestment),
                      font, bold,
                      isBold: true),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Container(
                width: 1, height: 80, color: _border),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  _capitalRow('Total Sales Profit',
                      _c(prov.totalSalesProfit),
                      font, bold,
                      valueColor: _green),
                  pw.SizedBox(height: 4),
                  _capitalRow(
                      'Total Expenses',
                      prov.totalExpensesAmount > 0
                          ? '- ${_c(prov.totalExpensesAmount)}'
                          : _c(prov.totalExpensesAmount),
                      font, bold,
                      valueColor: _red),
                  pw.SizedBox(height: 4),
                  pw.Divider(
                      color: _border, thickness: 0.5),
                  pw.SizedBox(height: 4),
                  _capitalRow('Current Capital',
                      _c(prov.currentCapital),
                      font, bold,
                      isBold: true,
                      valueColor: _blue),
                  pw.SizedBox(height: 4),
                  _capitalRow(
                      isProfit ? 'Net Gain' : 'Net Loss',
                      '${isProfit ? '+' : ''}${_c(prov.netGainLoss)}',
                      font, bold,
                      isBold: true,
                      valueColor:
                          isProfit ? _green : _red),
                  pw.SizedBox(height: 4),
                  _capitalRow('ROI',
                      '${isProfit ? '+' : ''}${roi.toStringAsFixed(2)}%',
                      font, bold,
                      isBold: true,
                      valueColor:
                          isProfit ? _green : _red),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ── TOP PRODUCTS ──────────────────────────────────────
  pw.Widget _buildTopProductsSection(
    ReportData report,
    pw.Font bold,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('TOP SELLING PRODUCTS', bold),
        pw.SizedBox(height: 8),
        if (report.topProducts.isEmpty)
          _emptyBox('No product sales recorded', font)
        else ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: _blue,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 20,
                  child: pw.Text('#',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.Expanded(
                  flex: 4,
                  child: pw.Text('PRODUCT',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 60,
                  child: pw.Text('QTY SOLD',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 90,
                  child: pw.Text('REVENUE',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 90,
                  child: pw.Text('PROFIT',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
            ]),
          ),
          ...report.topProducts.asMap().entries.map((e) {
            final isEven = e.key.isEven;
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: isEven
                    ? PdfColors.white
                    : _lightGrey,
                border: const pw.Border(
                    bottom: pw.BorderSide(
                        color: _border, width: 0.5)),
              ),
              child: pw.Row(children: [
                pw.SizedBox(
                    width: 20,
                    child: pw.Text('${e.key + 1}',
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 8,
                            color: _grey))),
                pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                        e.value['productName'] ?? '',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _black))),
                pw.SizedBox(
                    width: 60,
                    child: pw.Text(
                        '${e.value['totalQty']}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            color: _black))),
                pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                        _c((e.value['totalRevenue']
                                    as num?)
                                ?.toDouble() ??
                            0),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _black))),
                pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                        _c((e.value['totalProfit']
                                    as num?)
                                ?.toDouble() ??
                            0),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            color: _green))),
              ]),
            );
          }),
        ],
      ],
    );
  }

  // ── EXPENSES ──────────────────────────────────────────
  pw.Widget _buildExpensesSection(
    ReportData report,
    pw.Font bold,
    pw.Font font,
  ) {
    // Expense records + the *transport* cost of grocery resupply trips
    // merged into one shape so the category totals and itemized table both
    // add up to report.totalExpenses — grocery entries aren't Expense
    // rows, but their transpo is folded into that total (see
    // ReportService), so it has to appear here too or the listed rows
    // would undercount it. The item-cost portion is excluded on purpose:
    // that's capital buying inventory, already netted out of Total Profit
    // once the item sells, not a real expense.
    final rows = [
      ...report.expenses.map((e) => (
            description: e.description,
            category: e.category,
            date: e.date,
            amount: e.amount,
          )),
      ...report.groceryEntries.where((g) => g.transpo > 0).map((g) => (
            description: '${g.productName} ×${g.quantity} (transport)',
            category: _groceryCategory,
            date: g.date,
            amount: g.transpo,
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final Map<String, double> byCategory = {};
    for (final r in rows) {
      byCategory[r.category] =
          (byCategory[r.category] ?? 0) + r.amount;
    }
    final total = report.totalExpenses;

    // Grocery and transport are the two categories the user most wants to
    // watch trip-to-trip — call them out as their own highlighted rows
    // above the rest instead of leaving them to sort wherever they land
    // among the other categories. Still the same byCategory map/total, so
    // nothing is double-counted or re-summed.
    const highlightOrder = [_groceryCategory, _transportCategory];
    final highlightEntries = highlightOrder
        .where((k) => byCategory.containsKey(k))
        .map((k) => MapEntry(k, byCategory[k]!))
        .toList();
    final otherEntries = byCategory.entries
        .where((e) => !highlightOrder.contains(e.key))
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('EXPENSES BREAKDOWN', bold),
        pw.SizedBox(height: 8),
        if (rows.isEmpty)
          _emptyBox(
              'No expenses recorded for this period',
              font)
        else ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _lightGrey,
              borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(6)),
              border: pw.Border.all(
                  color: _border, width: 0.5),
            ),
            child: pw.Column(children: [
              ...highlightEntries.map((e) => pw.Padding(
                    padding:
                        const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(children: [
                      pw.Container(
                        width: 3,
                        height: 12,
                        margin: const pw.EdgeInsets.only(
                            right: 6),
                        color: e.key == _groceryCategory
                            ? _blue
                            : _green,
                      ),
                      pw.Text(e.key,
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: _black)),
                      pw.Spacer(),
                      pw.Text(_c(e.value),
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9.5,
                              color: _black)),
                    ]),
                  )),
              if (highlightEntries.isNotEmpty &&
                  otherEntries.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 3),
                  child: pw.Divider(
                      color: _border, thickness: 0.5),
                ),
              ...otherEntries.map((e) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(
                        bottom: 4),
                    child: pw.Row(children: [
                      pw.Text(e.key,
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              color: _grey)),
                      pw.Spacer(),
                      pw.Text(_c(e.value),
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: _black)),
                    ]),
                  )),
              pw.Divider(
                  color: _border, thickness: 0.5),
              pw.Row(children: [
                pw.Text('TOTAL EXPENSES',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 10,
                        color: _black)),
                pw.Spacer(),
                pw.Text(_c(total),
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 11,
                        color: _red)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: _blue,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(children: [
              pw.Expanded(
                  flex: 3,
                  child: pw.Text('DESCRIPTION',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(width: 14),
              pw.Expanded(
                  flex: 2,
                  child: pw.Text('CATEGORY',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 70,
                  child: pw.Text('DATE',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 90,
                  child: pw.Text('AMOUNT',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
            ]),
          ),
          ...rows.asMap().entries.map((e) {
            final isEven = e.key.isEven;
            final row = e.value;
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: isEven
                    ? PdfColors.white
                    : _lightGrey,
                border: const pw.Border(
                    bottom: pw.BorderSide(
                        color: _border, width: 0.5)),
              ),
              child: pw.Row(children: [
                pw.Expanded(
                    flex: 3,
                    child: pw.Text(row.description,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _black))),
                pw.SizedBox(width: 14),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(row.category,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _grey))),
                pw.SizedBox(
                    width: 70,
                    child: pw.Text(
                        '${row.date.month}/${row.date.day}/${row.date.year}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: _grey))),
                pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                        _c(row.amount),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            color: _red))),
              ]),
            );
          }),
        ],
      ],
    );
  }

  // ── GROCERY WEEKLY/MONTHLY ────────────────────────────
  // Same week/month grouping as GroceryScreen's Weekly/Monthly Grocery
  // cards, but scoped to just this report's date range so a reader can
  // see resupply spend trend-over-time without cross-referencing the
  // Grocery screen's all-time totals separately.
  pw.Widget _buildGroceryPeriodSection(
    ReportData report,
    pw.Font bold,
    pw.Font font,
  ) {
    if (report.groceryEntries.isEmpty) return pw.SizedBox();

    final byDate =
        report.groceryEntries.map((g) => MapEntry(g.date, g.totalExpenses));
    final weekly =
        _groupByPeriod(byDate, _weekKeyOf).take(12).toList();
    final monthly =
        _groupByPeriod(byDate, _monthKeyOf).take(12).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('GROCERY SPEND — WEEKLY & MONTHLY', bold),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
                child: _periodBox(
                    'WEEKLY GROCERY', weekly, _weekLabel, bold, font)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _periodBox(
                    'MONTHLY GROCERY', monthly, _monthLabel, bold, font)),
          ],
        ),
      ],
    );
  }

  // ── FARE/TRANSPORT WEEKLY/MONTHLY ─────────────────────
  // Fare/delivery cost for grocery trips is logged once per trip as its
  // own Expense row (category "Fare / Transport") rather than per
  // product — see GroceryScreen. It already gets a highlighted total in
  // the Expenses Breakdown above, but had no trend view of its own the
  // way Grocery spend does, so mirror that same weekly/monthly box here.
  pw.Widget _buildTransportPeriodSection(
    ReportData report,
    pw.Font bold,
    pw.Font font,
  ) {
    final transportExpenses = report.expenses
        .where((e) => e.category == _transportCategory)
        .toList();
    if (transportExpenses.isEmpty) return pw.SizedBox();

    final byDate =
        transportExpenses.map((e) => MapEntry(e.date, e.amount));
    final weekly =
        _groupByPeriod(byDate, _weekKeyOf).take(12).toList();
    final monthly =
        _groupByPeriod(byDate, _monthKeyOf).take(12).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('FARE / TRANSPORT SPEND — WEEKLY & MONTHLY', bold),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
                child: _periodBox(
                    'WEEKLY TRANSPORT', weekly, _weekLabel, bold, font)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _periodBox(
                    'MONTHLY TRANSPORT', monthly, _monthLabel, bold, font)),
          ],
        ),
      ],
    );
  }

  pw.Widget _periodBox(
    String title,
    List<MapEntry<String, double>> items,
    String Function(String) labelOf,
    pw.Font bold,
    pw.Font font,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _lightGrey,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: _border, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    font: bold, fontSize: 9, color: _grey)),
            pw.SizedBox(height: 6),
            ...items.map((e) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(children: [
                    pw.Expanded(
                        child: pw.Text(labelOf(e.key),
                            style: pw.TextStyle(
                                font: font,
                                fontSize: 8.5,
                                color: _black))),
                    pw.Text(_c(e.value),
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 8.5,
                            color: _black)),
                  ]),
                )),
          ],
        ),
      );

  // ── CREDIT ────────────────────────────────────────────
  pw.Widget _buildCreditSection(
    AppProvider prov,
    pw.Font bold,
    pw.Font font,
  ) {
    final unpaidDebts = prov.debts
        .where((d) =>
            d.status.toString() != 'DebtStatus.paid')
        .toList();
    final totalUnpaid = CurrencyFormatter.roundCents(
        unpaidDebts.fold(0.0, (s, d) => s + d.remaining));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('CREDIT / DEBT REPORT', bold),
        pw.SizedBox(height: 8),
        if (unpaidDebts.isEmpty)
          _emptyBox('No outstanding credit accounts', font)
        else ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFEF2F2),
              borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(6)),
              border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFFECACA),
                  width: 0.5),
            ),
            child: pw.Row(children: [
              pw.Text('Total Outstanding Credit: ',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      color: _grey)),
              pw.Spacer(),
              pw.Text(_c(totalUnpaid),
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 13,
                      color: _red)),
            ]),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: _blue,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(children: [
              pw.Expanded(
                  flex: 3,
                  child: pw.Text('CUSTOMER',
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 65,
                  child: pw.Text('DATE',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 65,
                  child: pw.Text('DUE DATE',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 75,
                  child: pw.Text('ORIGINAL',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 75,
                  child: pw.Text('PAID',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
              pw.SizedBox(
                  width: 75,
                  child: pw.Text('BALANCE',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 8,
                          color: PdfColors.white))),
            ]),
          ),
          ...unpaidDebts.asMap().entries.map((e) {
            final isEven = e.key.isEven;
            final debt = e.value;
            final isOverdue =
                debt.dueDate.isBefore(DateTime.now());
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: isOverdue
                    ? const PdfColor.fromInt(0xFFFFF5F5)
                    : (isEven
                        ? PdfColors.white
                        : _lightGrey),
                border: const pw.Border(
                    bottom: pw.BorderSide(
                        color: _border, width: 0.5)),
              ),
              child: pw.Row(children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(debt.customerName,
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 9,
                              color: _black)),
                      if (isOverdue)
                        pw.Text('OVERDUE',
                            style: pw.TextStyle(
                                font: bold,
                                fontSize: 7,
                                color: _red)),
                    ],
                  ),
                ),
                pw.SizedBox(
                    width: 65,
                    child: pw.Text(
                        '${debt.createdAt.month}/${debt.createdAt.day}/${debt.createdAt.year}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: _grey))),
                pw.SizedBox(
                    width: 65,
                    child: pw.Text(
                        '${debt.dueDate.month}/${debt.dueDate.day}/${debt.dueDate.year}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: isOverdue
                                ? _red
                                : _grey))),
                pw.SizedBox(
                    width: 75,
                    child: pw.Text(
                        _c(debt.originalAmount),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _black))),
                pw.SizedBox(
                    width: 75,
                    child: pw.Text(
                        _c(debt.paidAmount),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _green))),
                pw.SizedBox(
                    width: 75,
                    child: pw.Text(
                        _c(debt.remaining),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            color: _red))),
              ]),
            );
          }),
        ],
      ],
    );
  }

  // ── DAILY BREAKDOWN ───────────────────────────────────
  pw.Widget _buildDailyBreakdown(
    ReportData report,
    pw.Font bold,
    pw.Font font,
  ) {
    if (report.dailyRevenue.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('DAILY SALES BREAKDOWN', bold),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(
            color: _blue,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(6),
              topRight: pw.Radius.circular(6),
            ),
          ),
          child: pw.Row(children: [
            pw.Expanded(
                flex: 2,
                child: pw.Text('DATE',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 8,
                        color: PdfColors.white))),
            pw.SizedBox(
                width: 80,
                child: pw.Text('TRANSACTIONS',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 8,
                        color: PdfColors.white))),
            pw.SizedBox(
                width: 90,
                child: pw.Text('REVENUE',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 8,
                        color: PdfColors.white))),
            pw.SizedBox(
                width: 90,
                child: pw.Text('PROFIT',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 8,
                        color: PdfColors.white))),
          ]),
        ),
        ...report.dailyRevenue.asMap().entries.map((e) {
          final isEven = e.key.isEven;
          final day = e.value;
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color:
                  isEven ? PdfColors.white : _lightGrey,
              border: const pw.Border(
                  bottom: pw.BorderSide(
                      color: _border, width: 0.5)),
            ),
            child: pw.Row(children: [
              pw.Expanded(
                  flex: 2,
                  child: pw.Text(day['day'] ?? '',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: _black))),
              pw.SizedBox(
                  width: 80,
                  child: pw.Text(
                      '${day['txCount'] ?? 0}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 9,
                          color: _black))),
              pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                      _c((day['revenue'] as num?)
                              ?.toDouble() ??
                          0),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 9,
                          color: _black))),
              pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                      _c((day['profit'] as num?)
                              ?.toDouble() ??
                          0),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 9,
                          color: _green))),
            ]),
          );
        }),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: _blue,
            borderRadius: pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(6),
              bottomRight: pw.Radius.circular(6),
            ),
          ),
          child: pw.Row(children: [
            pw.Expanded(
                flex: 2,
                child: pw.Text('TOTAL',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        color: PdfColors.white))),
            pw.SizedBox(
                width: 80,
                child: pw.Text(
                    '${report.transactionCount}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        color: PdfColors.white))),
            pw.SizedBox(
                width: 90,
                child: pw.Text(
                    _c(report.totalRevenue),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        color: PdfColors.white))),
            pw.SizedBox(
                width: 90,
                child: pw.Text(
                    _c(report.totalProfit),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        color: PdfColors.white))),
          ]),
        ),
      ],
    );
  }

  // ── HELPERS ───────────────────────────────────────────
  pw.Widget _sectionTitle(
          String title, pw.Font bold) =>
      pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: bold,
                  fontSize: 11,
                  color: _blue)),
          pw.SizedBox(height: 4),
          pw.Divider(color: _blue, thickness: 1),
        ],
      );

  pw.Widget _summaryCard(
    String label,
    String value,
    pw.Font bold,
    pw.Font font, {
    bool isHighlight = false,
    PdfColor? valueColor,
    double labelFontSize = 8,
    double valueFontSize = 11,
  }) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: isHighlight ? _lightBlue : _lightGrey,
            borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(6)),
            border: pw.Border.all(
                color: isHighlight ? _blue : _border,
                width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: font,
                      fontSize: labelFontSize,
                      color: _grey)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: valueFontSize,
                      color: valueColor ?? _black)),
            ],
          ),
        ),
      );

  pw.Widget _capitalRow(
    String label,
    String value,
    pw.Font font,
    pw.Font bold, {
    bool isBold = false,
    PdfColor? valueColor,
  }) =>
      pw.Row(children: [
        pw.Expanded(
          child: pw.Text(label,
              style: pw.TextStyle(
                  font: isBold ? bold : font,
                  fontSize: 9,
                  color: isBold ? _black : _grey)),
        ),
        pw.Text(value,
            style: pw.TextStyle(
                font: bold,
                fontSize: isBold ? 10 : 9,
                color: valueColor ?? _black)),
      ]);

  pw.Widget _emptyBox(String msg, pw.Font font) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _lightGrey,
          borderRadius: const pw.BorderRadius.all(
              pw.Radius.circular(6)),
          border:
              pw.Border.all(color: _border, width: 0.5),
        ),
        child: pw.Center(
          child: pw.Text(msg,
              style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: _grey)),
        ),
      );
}