import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});
  @override
  State<DailySummaryScreen> createState() =>
      _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
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
    return Consumer<AppProvider>(builder: (context, prov, _) {
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
          productMap[item.productId]!['qty'] += item.quantity;
          productMap[item.productId]!['revenue'] +=
              item.subtotal;
          productMap[item.productId]!['profit'] += item.profit;
        }
      }
      final topProducts = productMap.values.toList()
        ..sort((a, b) =>
            (b['qty'] as int).compareTo(a['qty'] as int));

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('Buod ng Araw'),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
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
        ),
        body: RefreshIndicator(
          onRefresh: _loadHourlyData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header banner
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                      20, 16, 20, 28),
                  child: Column(children: [
                    Text(
                      DateHelper.isSameDay(
                              _selectedDate, DateTime.now())
                          ? 'Ngayon'
                          : DateHelper.formatDate(
                              _selectedDate),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sales.length} transaksyon',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      _statCard('Benta',
                          CurrencyFormatter.format(revenue),
                          Icons.shopping_bag_outlined),
                      const SizedBox(width: 10),
                      _statCard('Kita',
                          CurrencyFormatter.format(profit),
                          Icons.trending_up_outlined),
                    ]),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Summary cards
                      Row(children: [
                        Expanded(
                            child: _summaryCard(
                                'Cash Sales',
                                CurrencyFormatter.format(
                                    cashSales),
                                Icons.payments_outlined,
                                const Color(0xFF2E7D32))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _summaryCard(
                                'Credit/Utang',
                                CurrencyFormatter.format(
                                    creditSales),
                                Icons.credit_card_outlined,
                                Colors.orange)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _summaryCard(
                                'Gastos',
                                CurrencyFormatter.format(
                                    expenses),
                                Icons.receipt_long_outlined,
                                Colors.red)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _summaryCard(
                                'Net Income',
                                CurrencyFormatter.format(
                                    netIncome),
                                Icons
                                    .account_balance_wallet_outlined,
                                netIncome >= 0
                                    ? const Color(0xFF2E7D32)
                                    : Colors.red)),
                      ]),
                      const SizedBox(height: 20),

                      // Hourly breakdown
                      _sectionTitle('Benta per Oras'),
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
                                    child: Text('Walang data',
                                        style: TextStyle(
                                            color: Colors
                                                .grey[400])),
                                  ))
                                : Column(
                                    children:
                                        _hourlyData.map((h) {
                                      final hour =
                                          h['hour'] as int? ??
                                              0;
                                      final rev = (h['revenue']
                                                  as num?)
                                              ?.toDouble() ??
                                          0;
                                      final maxRev = _hourlyData
                                          .map((x) =>
                                              (x['revenue']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0)
                                          .reduce((a, b) =>
                                              a > b ? a : b);
                                      final pct = maxRev > 0
                                          ? rev / maxRev
                                          : 0.0;
                                      final ampm = hour < 12
                                          ? 'AM'
                                          : 'PM';
                                      final h12 = hour == 0
                                          ? 12
                                          : hour > 12
                                              ? hour - 12
                                              : hour;

                                      return Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(bottom: 10),
                                        child: Row(children: [
                                          SizedBox(
                                            width: 64,
                                            child: Text(
                                                '$h12:00 $ampm',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors
                                                        .grey[600])),
                                          ),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(6),
                                              child:
                                                  LinearProgressIndicator(
                                                value: pct
                                                    .toDouble(),
                                                backgroundColor:
                                                    Colors.grey
                                                        .withValues(
                                                            alpha:
                                                                0.15),
                                                valueColor:
                                                    const AlwaysStoppedAnimation(
                                                        Color(
                                                            0xFF2E7D32)),
                                                minHeight: 22,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              CurrencyFormatter
                                                  .format(rev),
                                              textAlign:
                                                  TextAlign.right,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight
                                                          .w600),
                                            ),
                                          ),
                                        ]),
                                      );
                                    }).toList(),
                                  ),
                      ),
                      const SizedBox(height: 20),

                      // Top products
                      _sectionTitle('Pinaka-mabenta Ngayon'),
                      const SizedBox(height: 10),
                      if (topProducts.isEmpty)
                        _emptyCard('Walang benta ngayon')
                      else
                        ...topProducts.take(5).map((p) {
                          final rank =
                              topProducts.indexOf(p) + 1;
                          return Container(
                            margin:
                                const EdgeInsets.only(bottom: 8),
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
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text('$rank',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          color:
                                              Color(0xFF2E7D32),
                                          fontSize: 16)),
                                ),
                              ),
                              title: Text(p['name'],
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text(
                                  '${p['qty']} pirasong naibenta',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12)),
                              trailing: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                      CurrencyFormatter.format(
                                          p['revenue'] as double),
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 14)),
                                  Text(
                                      'tubo: ${CurrencyFormatter.format(p['profit'] as double)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color:
                                              Color(0xFF2E7D32))),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 20),

                      // Recent transactions
                      _sectionTitle('Mga Transaksyon'),
                      const SizedBox(height: 10),
                      if (sales.isEmpty)
                        _emptyCard('Walang transaksyon')
                      else
                        ...sales.map((s) => Container(
                              margin: const EdgeInsets.only(
                                  bottom: 8),
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
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: s.type ==
                                            PaymentType.cash
                                        ? const Color(0xFF2E7D32)
                                            .withValues(alpha: 0.1)
                                        : Colors.orange
                                            .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    s.type == PaymentType.cash
                                        ? Icons.payments_outlined
                                        : Icons
                                            .credit_card_outlined,
                                    color: s.type ==
                                            PaymentType.cash
                                        ? const Color(0xFF2E7D32)
                                        : Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                    s.customerName ?? 'Cash Sale',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                subtitle: Text(
                                    '${s.items.length} item  •  ${DateHelper.formatTime(s.createdAt)}',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12)),
                                trailing: Text(
                                    CurrencyFormatter.format(
                                        s.totalAmount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color:
                                            Color(0xFF2E7D32))),
                              ),
                            )),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _statCard(String label, String value, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ]),
        ),
      );

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
                    fontSize: 16,
                    color: color),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 11)),
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

  Widget _emptyCard(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(msg,
              style: TextStyle(color: Colors.grey[400])),
        ),
      );
}