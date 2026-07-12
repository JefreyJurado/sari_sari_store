import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // ── Replace ₱ with PHP for PDF font compatibility ──
  String _c(double amount) {
    final formatted = amount.toStringAsFixed(2);
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
    return 'PHP ${buffer.toString().split('').reversed.join()}.$decimal';
  }

  Future<void> generateAndPrint({
    required AppProvider prov,
    required int days,
    required String periodLabel,
    required ReportData report,
  }) async {
    final pdf = await buildDocument(
      prov: prov,
      days: days,
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
    required int days,
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
          _buildCapitalSection(prov, bold, font),
          pw.SizedBox(height: 16),
          _buildTopProductsSection(report, bold, font),
          pw.SizedBox(height: 16),
          _buildExpensesSection(prov, days, bold, font),
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
        pw.Row(children: [
          _summaryCard('Total Sales',
              _c(report.totalRevenue), bold, font,
              isHighlight: true),
          pw.SizedBox(width: 8),
          _summaryCard('Total Profit',
              _c(report.totalProfit), bold, font,
              valueColor: _green),
          pw.SizedBox(width: 8),
          _summaryCard('Total Expenses',
              _c(report.totalExpenses), bold, font,
              valueColor: report.totalExpenses > 0
                  ? _red
                  : _black),
          pw.SizedBox(width: 8),
          _summaryCard('Net Income',
              _c(report.netIncome), bold, font,
              valueColor: report.netIncome >= 0
                  ? _green
                  : _red,
              isHighlight: report.netIncome >= 0),
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
          child: pw.Row(children: [
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
            pw.Text('Average per Transaction: ',
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
                  _capitalRow('Total Expenses',
                      '- ${_c(prov.totalExpensesAmount)}',
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
    AppProvider prov,
    int days,
    pw.Font bold,
    pw.Font font,
  ) {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final filtered = prov.expenses
        .where((e) => !e.date.isBefore(since))
        .toList();

    final Map<String, double> byCategory = {};
    for (final e in filtered) {
      byCategory[e.category] =
          (byCategory[e.category] ?? 0) + e.amount;
    }
    final total = CurrencyFormatter.roundCents(
        filtered.fold(0.0, (s, e) => s + e.amount));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('EXPENSES BREAKDOWN', bold),
        pw.SizedBox(height: 8),
        if (filtered.isEmpty)
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
              ...byCategory.entries.map((e) =>
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
          ...filtered.asMap().entries.map((e) {
            final isEven = e.key.isEven;
            final exp = e.value;
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
                    child: pw.Text(exp.description,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _black))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(exp.category,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: _grey))),
                pw.SizedBox(
                    width: 70,
                    child: pw.Text(
                        '${exp.date.month}/${exp.date.day}/${exp.date.year}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: _grey))),
                pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                        _c(exp.amount),
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
                      fontSize: 8,
                      color: _grey)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 11,
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