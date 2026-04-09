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
      case 1: return 'Ngayon';
      case 7: return '7 Araw';
      case 14: return '14 Araw';
      case 30: return '1 Buwan';
      case 60: return '2 Buwan';
      case 90: return '3 Buwan';
      case 180: return '6 Buwan';
      case 365: return '1 Taon';
      case 730: return '2 Taon';
      case 1825: return '5 Taon';
      default: return '$_days Araw';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'Mga Ulat',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'I-refresh',
          ),
        ],
      ),
      body: Column(children: [
        // Header banner with period selector
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF2E7D32),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Panahon ng Ulat',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: _days,
                  dropdownColor: const Color(0xFF2E7D32),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white),
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 1,
                        child: Text('Ngayon')),
                    DropdownMenuItem(
                        value: 7,
                        child: Text('7 Araw')),
                    DropdownMenuItem(
                        value: 14,
                        child: Text('14 Araw')),
                    DropdownMenuItem(
                        value: 30,
                        child: Text('30 Araw (1 Buwan)')),
                    DropdownMenuItem(
                        value: 60,
                        child: Text('60 Araw (2 Buwan)')),
                    DropdownMenuItem(
                        value: 90,
                        child: Text('90 Araw (3 Buwan)')),
                    DropdownMenuItem(
                        value: 180, child: Text('6 Buwan')),
                    DropdownMenuItem(
                        value: 365, child: Text('1 Taon')),
                    DropdownMenuItem(
                        value: 730, child: Text('2 Taon')),
                    DropdownMenuItem(
                        value: 1825, child: Text('5 Taon')),
                  ],
                  onChanged: (v) =>
                      setState(() { _days = v!; _load(); }),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _report == null
                  ? const Center(child: Text('Walang data'))
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
                            // Summary cards
                            Row(children: [
                              Expanded(
                                child: _summaryCard(
                                  'Kabuuang Benta',
                                  CurrencyFormatter.format(
                                      _report!.totalRevenue),
                                  Icons.shopping_bag_outlined,
                                  const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _summaryCard(
                                  'Kabuuang Kita',
                                  CurrencyFormatter.format(
                                      _report!.totalProfit),
                                  Icons.trending_up_outlined,
                                  Colors.blue,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: _summaryCard(
                                  'Gastos',
                                  CurrencyFormatter.format(
                                      _report!.totalExpenses),
                                  Icons.receipt_outlined,
                                  Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _summaryCard(
                                  'Net Income',
                                  CurrencyFormatter.format(
                                      _report!.netIncome),
                                  Icons
                                      .account_balance_wallet_outlined,
                                  _report!.netIncome >= 0
                                      ? const Color(0xFF2E7D32)
                                      : Colors.red,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),

                            // Transactions card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.orange
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.receipt_outlined,
                                      color: Colors.orange),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Kabuuang Transaksyon',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 14)),
                                  Text('Sa loob ng $_periodLabel',
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12)),
                                ]),
                                const Spacer(),
                                Text(
                                    '${_report!.transactionCount}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 30,
                                        color: Colors.orange)),
                              ]),
                            ),
                            const SizedBox(height: 20),

                            // Chart
                            _sectionTitle('Trend ng Benta'),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ProfitChart(
                                  dailyData:
                                      _report!.dailyRevenue),
                            ),
                            const SizedBox(height: 20),

                            // Top products
                            _sectionTitle('Pinaka-mabenta'),
                            const SizedBox(height: 10),

                            if (_report!.topProducts.isEmpty)
                              Container(
                                padding:
                                    const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                child: Center(
                                    child: Text('Walang data',
                                        style: TextStyle(
                                            color:
                                                Colors.grey[400]))),
                              )
                            else
                              ..._report!.topProducts
                                  .asMap()
                                  .entries
                                  .map((e) => Container(
                                        margin: const EdgeInsets
                                            .only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(
                                                      alpha: 0.04),
                                              blurRadius: 6,
                                              offset:
                                                  const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 14,
                                                  vertical: 8),
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                      0xFF2E7D32)
                                                  .withValues(
                                                      alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${e.key + 1}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: Color(
                                                        0xFF2E7D32),
                                                    fontSize: 16),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                              e.value['productName'] ??
                                                  '',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 14)),
                                          subtitle: Text(
                                              '${e.value['totalQty']} pirasong naibenta',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey[500])),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
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
                                                          FontWeight
                                                              .bold,
                                                      fontSize: 14)),
                                              Text(
                                                  'tubo: ${CurrencyFormatter.format((e.value['totalProfit'] as num?)?.toDouble() ?? 0)}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(
                                                          0xFF2E7D32))),
                                            ],
                                          ),
                                        ),
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

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E)),
      );
}