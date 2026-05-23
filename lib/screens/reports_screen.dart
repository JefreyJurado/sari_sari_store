import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/report_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/profit_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;
  ReportData? _report;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prov = context.read<AppProvider>();
    final r = await ReportService.instance.generateReport(
      sales: prov.sales,
      expenses: prov.expenses,
      days: _days,
    );
    if (mounted) setState(() { _report = r; _loading = false; });
  }

  String get _periodLabel {
    switch (_days) {
      case 1: return 'Today';
      case 7: return '7 Days';
      case 14: return '14 Days';
      case 30: return '1 Month';
      case 60: return '2 Months';
      case 90: return '3 Months';
      case 180: return '6 Months';
      case 365: return '1 Year';
      case 730: return '2 Years';
      case 1825: return '5 Years';
      default: return '$_days Days';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text('Reports',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined,
                color: Colors.black54, size: 22),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(children: [

        // ── Period Selector ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Row(children: [
              Text('Period',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
                ),
                child: DropdownButton<int>(
                  value: _days,
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF1E3A8A), size: 18),
                  items: const [
                    DropdownMenuItem(
                        value: 1, child: Text('Today')),
                    DropdownMenuItem(
                        value: 7, child: Text('7 Days')),
                    DropdownMenuItem(
                        value: 14, child: Text('14 Days')),
                    DropdownMenuItem(
                        value: 30, child: Text('1 Month')),
                    DropdownMenuItem(
                        value: 60, child: Text('2 Months')),
                    DropdownMenuItem(
                        value: 90, child: Text('3 Months')),
                    DropdownMenuItem(
                        value: 180, child: Text('6 Months')),
                    DropdownMenuItem(
                        value: 365, child: Text('1 Year')),
                    DropdownMenuItem(
                        value: 730, child: Text('2 Years')),
                    DropdownMenuItem(
                        value: 1825, child: Text('5 Years')),
                  ],
                  onChanged: (v) =>
                      setState(() { _days = v!; _load(); }),
                ),
              ),
            ]),
            const SizedBox(height: 10),
          ]),
        ),

        Divider(height: 1, color: Colors.grey.shade100),

        // ── Body ──────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _report == null
                  ? Center(
                      child: Text('No data',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            // ── Summary Cards ──────────
                            Row(children: [
                              _statCard(
                                'Total Sales',
                                CurrencyFormatter.format(
                                    _report!.totalRevenue),
                                Icons.shopping_bag_outlined,
                              ),
                              const SizedBox(width: 10),
                              _statCard(
                                'Total Profit',
                                CurrencyFormatter.format(
                                    _report!.totalProfit),
                                Icons.trending_up_outlined,
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              _statCard(
                                'Expenses',
                                CurrencyFormatter.format(
                                    _report!.totalExpenses),
                                Icons.receipt_outlined,
                                isAlert:
                                    _report!.totalExpenses > 0,
                              ),
                              const SizedBox(width: 10),
                              _statCard(
                                'Net Income',
                                CurrencyFormatter.format(
                                    _report!.netIncome),
                                Icons.account_balance_wallet_outlined,
                                isAlert:
                                    _report!.netIncome < 0,
                              ),
                            ]),
                            const SizedBox(height: 10),

                            // ── Transactions ───────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.grey.shade200),
                              ),
                              child: Row(children: [
                                Icon(Icons.receipt_outlined,
                                    color: Colors.grey[400],
                                    size: 18),
                                const SizedBox(width: 10),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Transactions',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.black87)),
                                  Text(
                                      'Within $_periodLabel',
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11)),
                                ]),
                                const Spacer(),
                                Text(
                                    '${_report!.transactionCount}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 26,
                                        color: Colors.black87)),
                              ]),
                            ),
                            const SizedBox(height: 20),

                            // ── Chart ──────────────────
                            _sectionHeader('Sales Trend'),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.grey.shade200),
                              ),
                              child: ProfitChart(
                                  dailyData:
                                      _report!.dailyRevenue),
                            ),
                            const SizedBox(height: 20),

                            // ── Top Products ───────────
                            _sectionHeader('Top Products'),
                            const SizedBox(height: 10),

                            if (_report!.topProducts.isEmpty)
                              Container(
                                padding:
                                    const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          Colors.grey.shade200),
                                ),
                                child: Center(
                                  child: Text('No data yet',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13)),
                                ),
                              )
                            else
                              ..._report!.topProducts
                                  .asMap()
                                  .entries
                                  .map((e) => Container(
                                        margin: const EdgeInsets
                                            .only(bottom: 8),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                          border: Border.all(
                                              color: Colors
                                                  .grey.shade200),
                                        ),
                                        child: Row(children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration:
                                                BoxDecoration(
                                              color: Colors
                                                  .grey.shade100,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(6),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${e.key + 1}',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                    color: Colors
                                                        .grey[600],
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                              Text(
                                                  e.value[
                                                          'productName'] ??
                                                      '',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .w600,
                                                      fontSize: 13,
                                                      color: Colors
                                                          .black87)),
                                              Text(
                                                  '${e.value['totalQty']} sold',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors
                                                          .grey[500])),
                                            ]),
                                          ),
                                          Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .end,
                                              children: [
                                            Text(
                                                CurrencyFormatter
                                                    .format((e.value[
                                                                    'totalRevenue']
                                                                as num?)
                                                            ?.toDouble() ??
                                                        0),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Colors
                                                        .black87)),
                                            Text(
                                                'profit: ${CurrencyFormatter.format((e.value['totalProfit'] as num?)?.toDouble() ?? 0)}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors
                                                        .grey[500])),
                                          ]),
                                        ]),
                                      )),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {bool isAlert = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isAlert
                    ? Colors.red.shade100
                    : const Color(0xFF1E3A8A).withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon,
                    color: isAlert
                  ? Colors.red.shade300
                  : const Color(0xFF1E3A8A).withValues(alpha: 0.5),
                    size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isAlert
                          ? Colors.red.shade400
                          : Colors.black87),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87));
}