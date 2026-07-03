import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

const _blue = Color(0xFF1E3A8A);

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});
  @override
  State<DailySummaryScreen> createState() =>
      _DailySummaryScreenState();
}

class _DailySummaryScreenState
    extends State<DailySummaryScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _hourlyData = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHourlyData();
  }

  Future<void> _loadHourlyData() async {
    setState(() => _loading = true);
    final data = await DatabaseService.instance
        .getHourlySales(_selectedDate);
    setState(() {
      _hourlyData = data;
      _loading = false;
    });
  }

  List<Sale> _salesForDate(List<Sale> all) => all
      .where((s) =>
          s.status == TxStatus.completed &&
          DateHelper.isSameDay(s.createdAt, _selectedDate))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
        builder: (context, prov, _) {
      final sales = _salesForDate(prov.sales);
      final revenue =
          sales.fold(0.0, (s, t) => s + t.totalAmount);
      final profit =
          sales.fold(0.0, (s, t) => s + t.totalProfit);
      final cashSales = sales
          .where((s) => s.type == PaymentType.cash)
          .fold(0.0, (s, t) => s + t.totalAmount);
      final creditSales = sales
          .where((s) => s.type != PaymentType.cash)
          .fold(0.0, (s, t) => s + t.creditAmount);
      final expenses = prov.expenses
          .where((e) =>
              DateHelper.isSameDay(e.date, _selectedDate))
          .fold(0.0, (s, e) => s + e.amount);
      final netIncome = profit - expenses;

      final productMap = <String, Map<String, dynamic>>{};
      for (final sale in sales) {
        for (final item in sale.items) {
          productMap.putIfAbsent(item.productId, () => {
                'name': item.productName,
                'qty': 0,
                'revenue': 0.0,
                'profit': 0.0,
              });
          productMap[item.productId]!['qty'] +=
              item.quantity;
          productMap[item.productId]!['revenue'] +=
              item.subtotal;
          productMap[item.productId]!['profit'] +=
              item.profit;
        }
      }
      final topProducts = productMap.values.toList()
        ..sort((a, b) =>
            (b['qty'] as int).compareTo(a['qty'] as int));

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Daily Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined, color: Colors.black54, size: 22),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadHourlyData();
                }
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadHourlyData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View sales performance by day',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 20),

                  // ── Date + Summary ──────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          _blue.withValues(alpha: 0.04),
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: _blue
                              .withValues(alpha: 0.15)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Icon(
                            Icons.calendar_today_outlined,
                            color: _blue
                                .withValues(alpha: 0.6),
                            size: 16),
                        const SizedBox(width: 8),
                        Text(
                          DateHelper.isSameDay(
                                  _selectedDate,
                                  DateTime.now())
                              ? 'Today'
                              : DateHelper.formatDate(
                                  _selectedDate),
                          style: const TextStyle(
                              color: _blue,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '${sales.length} transaction${sales.length != 1 ? 's' : ''}',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        _topStat(
                            'Sales',
                            CurrencyFormatter.format(
                                revenue),
                            Icons.shopping_bag_outlined),
                        const SizedBox(width: 10),
                        _topStat(
                            'Profit',
                            CurrencyFormatter.format(
                                profit),
                            Icons.trending_up_outlined),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Summary Cards ───────────────────
                  Row(children: [
                    Expanded(
                        child: _summaryCard(
                            'Cash Sales',
                            CurrencyFormatter.format(
                                cashSales),
                            Icons.payments_outlined)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _summaryCard(
                            'Credit',
                            CurrencyFormatter.format(
                                creditSales),
                            Icons.credit_card_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _summaryCard(
                            'Expenses',
                            CurrencyFormatter.format(
                                expenses),
                            Icons.receipt_long_outlined,
                            isAlert: expenses > 0)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _summaryCard(
                            'Net Income',
                            CurrencyFormatter.format(
                                netIncome),
                            Icons
                                .account_balance_wallet_outlined,
                            isAlert: netIncome < 0)),
                  ]),
                  const SizedBox(height: 20),

                  // ── Hourly Breakdown ────────────────
                  _sectionHeader('Sales by Hour'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.shade200),
                    ),
                    child: _loading
                        ? const Center(
                            child:
                                CircularProgressIndicator())
                        : _hourlyData.isEmpty
                            ? Center(
                                child: Padding(
                                padding:
                                    const EdgeInsets.all(
                                        20),
                                child: Text('No data',
                                    style: TextStyle(
                                        color: Colors
                                            .grey[400],
                                        fontSize: 13)),
                              ))
                            : Column(
                                children: _hourlyData
                                    .map((h) {
                                  final hour =
                                      h['hour'] as int? ??
                                          0;
                                  final rev = (h['revenue']
                                              as num?)
                                          ?.toDouble() ??
                                      0;
                                  final maxRev =
                                      _hourlyData
                                          .map((x) =>
                                              (x['revenue']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0)
                                          .reduce((a, b) =>
                                              a > b
                                                  ? a
                                                  : b);
                                  final pct = maxRev > 0
                                      ? rev / maxRev
                                      : 0.0;
                                  final ampm =
                                      hour < 12
                                          ? 'AM'
                                          : 'PM';
                                  final h12 = hour == 0
                                      ? 12
                                      : hour > 12
                                          ? hour - 12
                                          : hour;

                                  return Padding(
                                    padding: const EdgeInsets
                                        .only(bottom: 10),
                                    child:
                                        Row(children: [
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                            '$h12:00 $ampm',
                                            style: TextStyle(
                                                fontSize:
                                                    11,
                                                color: Colors
                                                    .grey[600])),
                                      ),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      4),
                                          child:
                                              LinearProgressIndicator(
                                            value: pct
                                                .toDouble(),
                                            backgroundColor:
                                                Colors.grey
                                                    .withValues(
                                                        alpha:
                                                            0.12),
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                    _blue),
                                            minHeight: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 10),
                                      SizedBox(
                                        width: 76,
                                        child: Text(
                                          CurrencyFormatter
                                              .format(rev),
                                          textAlign:
                                              TextAlign
                                                  .right,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              color: Colors
                                                  .black87),
                                        ),
                                      ),
                                    ]),
                                  );
                                }).toList(),
                              ),
                  ),
                  const SizedBox(height: 20),

                  // ── Top Products ────────────────────
                  _sectionHeader('Top Products'),
                  const SizedBox(height: 10),
                  if (topProducts.isEmpty)
                    _emptyCard('No sales today')
                  else
                    ...topProducts.take(5).map((p) {
                      final rank =
                          topProducts.indexOf(p) + 1;
                      return Container(
                        margin: const EdgeInsets.only(
                            bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: _blue
                                  .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text('$rank',
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      color: _blue,
                                      fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                              Text(p['name'],
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      fontSize: 13,
                                      color:
                                          Colors.black87)),
                              Text('${p['qty']} sold',
                                  style: TextStyle(
                                      color:
                                          Colors.grey[500],
                                      fontSize: 11)),
                            ]),
                          ),
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                            Text(
                                CurrencyFormatter.format(
                                    p['revenue'] as double),
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black87)),
                            Text(
                                'profit: ${CurrencyFormatter.format(p['profit'] as double)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        Colors.grey[500])),
                          ]),
                        ]),
                      );
                    }),
                  const SizedBox(height: 20),

                  // ── Transactions ────────────────────
                  _sectionHeader('Transactions'),
                  const SizedBox(height: 10),
                  if (sales.isEmpty)
                    _emptyCard('No transactions today')
                  else
                    ...sales.map((s) => Container(
                          margin: const EdgeInsets.only(
                              bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4),
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                              ),
                              child: Icon(
                                s.type == PaymentType.cash
                                    ? Icons.payments_outlined
                                    : Icons
                                        .phone_android_outlined,
                                color: Colors.black54,
                                size: 18,
                              ),
                            ),
                            title: Text(
                                s.customerName ??
                                    'Cash Sale',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87)),
                            subtitle: Text(
                                '${s.items.length} item${s.items.length != 1 ? 's' : ''}  •  ${DateHelper.formatTime(s.createdAt)}',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11)),
                            trailing: Text(
                                CurrencyFormatter.format(
                                    s.totalAmount),
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                        )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _topStat(
          String label, String value, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _blue.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Icon(icon,
                color: _blue.withValues(alpha: 0.6),
                size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: TextStyle(
                          color: _blue
                              .withValues(alpha: 0.6),
                          fontSize: 10)),
                ],
              ),
            ),
          ]),
        ),
      );

  Widget _summaryCard(String label, String value,
          IconData icon,
          {bool isAlert = false}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isAlert
                  ? Colors.red.shade100
                  : _blue.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  color: isAlert
                      ? Colors.red.shade300
                      : _blue.withValues(alpha: 0.5),
                  size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isAlert
                        ? Colors.red.shade400
                        : Colors.black87),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87));

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
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 13)),
        ),
      );
}