import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/profit_chart.dart';

const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _purple = Color(0xFF7C3AED);
const _amber = Color(0xFFD97706);

/// Detail behind Reports' "Total Profit" and "Net Income" cards — both
/// point here rather than to Daily Summary, which only ever shows today
/// regardless of which period was selected on Reports. Everything shown
/// is the exact [ReportData] Reports already computed for that period, so
/// the numbers here can never disagree with what was tapped to get here.
class PeriodSummaryScreen extends StatelessWidget {
  final String periodLabel;
  final ReportData report;
  const PeriodSummaryScreen({
    super.key,
    required this.periodLabel,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    // topProducts arrives sorted by quantity sold (Reports' own concern);
    // re-sorted here by profit contribution, since that's what explains
    // "why is my profit what it is".
    final byProfit = [...report.topProducts]
      ..sort((a, b) => ((b['totalProfit'] as num?)?.toDouble() ?? 0)
          .compareTo((a['totalProfit'] as num?)?.toDouble() ?? 0));

    final expenseByCategory = <String, double>{};
    for (final e in report.expenses) {
      expenseByCategory[e.category] =
          (expenseByCategory[e.category] ?? 0) + e.amount;
    }
    // Grocery trips aren't Expense records, but their cost is folded into
    // report.totalExpenses (see ReportService) — bucketed here too so the
    // category breakdown's percentages still add up to that total instead
    // of silently summing to less than 100%.
    if (report.groceryTotal > 0) {
      expenseByCategory['Grocery / Resupply'] =
          (expenseByCategory['Grocery / Resupply'] ?? 0) + report.groceryTotal;
    }
    final sortedExpenseCategories = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profit & Income Detail',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(periodLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Top-level numbers ──
              Row(children: [
                _statCard('Total Profit',
                    CurrencyFormatter.format(report.totalProfit),
                    Icons.trending_up_rounded, _green),
                const SizedBox(width: 10),
                _statCard(
                    'Net Income',
                    CurrencyFormatter.format(report.netIncome),
                    Icons.account_balance_wallet_outlined,
                    report.netIncome < 0 ? _red : _purple),
              ]),
              const SizedBox(height: 24),

              // ── Where sales came from ──
              _sectionHeader('Where Sales Came From'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _miniCard('Cash',
                        CurrencyFormatter.format(report.cashSales),
                        Icons.payments_outlined)),
                const SizedBox(width: 10),
                Expanded(
                    child: _miniCard('Online',
                        CurrencyFormatter.format(report.onlineSales),
                        Icons.phone_android_outlined)),
                const SizedBox(width: 10),
                Expanded(
                    child: _miniCard('Credit',
                        CurrencyFormatter.format(report.creditSales),
                        Icons.credit_card_outlined)),
              ]),
              const SizedBox(height: 24),

              // ── Trend ──
              _sectionHeader('Sales & Profit Trend'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                child: ProfitChart(dailyData: report.dailyRevenue),
              ),
              const SizedBox(height: 24),

              // ── Profit by product ──
              _sectionHeader('Profit by Product'),
              const SizedBox(height: 10),
              if (byProfit.isEmpty)
                _emptyCard('No product sales in this period')
              else
                ...byProfit.take(10).map(_productRow),
              const SizedBox(height: 24),

              // ── Expenses by category ──
              _sectionHeader('Expenses by Category'),
              const SizedBox(height: 10),
              if (sortedExpenseCategories.isEmpty)
                _emptyCard('No expenses logged in this period')
              else
                ...sortedExpenseCategories
                    .map((e) => _categoryRow(e.key, e.value)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.18)!]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(icon, color: Colors.white, size: 18),
              ]),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  Widget _miniCard(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(label,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87));

  Widget _emptyCard(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
            child: Text(msg,
                style: TextStyle(color: Colors.grey[400], fontSize: 13))),
      );

  Widget _productRow(Map<String, dynamic> p) {
    final profit = (p['totalProfit'] as num?)?.toDouble() ?? 0;
    final qty = (p['totalQty'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p['productName'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87)),
              Text('$qty sold',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ),
        Text(CurrencyFormatter.format(profit),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: _green)),
      ]),
    );
  }

  Widget _categoryRow(String category, double amount) {
    final pct = report.totalExpenses > 0
        ? (amount / report.totalExpenses).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(_amber),
                    minHeight: 5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(CurrencyFormatter.format(amount),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87)),
      ]),
    );
  }
}
