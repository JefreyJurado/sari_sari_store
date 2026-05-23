import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../widgets/quick_action_buttons.dart';
import '../models/transaction.dart';
import '../models/debt.dart';
import 'settings_screen.dart';
import 'backup_screen.dart';
import 'expenses_screen.dart';
import 'receipt_screen.dart';
import 'lista_screen.dart';
import 'payment_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _userName = prefs.getString('user_name') ?? '');
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
        title: const Text('TindaPH',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        actions: [
          IconButton(
              icon: const Icon(Icons.receipt_long_outlined,
                  color: Colors.black54, size: 22),
              tooltip: 'Expenses',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ExpensesScreen()))),
          IconButton(
              icon: const Icon(Icons.backup_outlined,
                  color: Colors.black54, size: 22),
              tooltip: 'Backup',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const BackupScreen()))),
          IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: Colors.black54, size: 22),
              tooltip: 'Settings',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final cashSales = prov.sales
              .where((s) =>
                  s.status == TxStatus.completed &&
                  s.type != PaymentType.credit)
              .toList();

          final customersWithDebt = prov.customers.where((c) {
            final unpaid = prov
                .debtsFor(c.id)
                .where((d) => d.status != DebtStatus.paid)
                .toList();
            return unpaid.isNotEmpty;
          }).toList();

          return RefreshIndicator(
            onRefresh: prov.reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Greeting ───────────────────────────
                  Row(children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateHelper.todayFormatted(),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          _userName.isEmpty
                              ? 'Good ${DateHelper.greeting()} 👋'
                              : 'Good ${DateHelper.greeting()}, $_userName 👋',
                          style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.circle,
                            size: 8,
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.6)),
                        const SizedBox(width: 6),
                        Text('TindaPH',
                            style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Stats Grid ─────────────────────────
                  Row(children: [
                    _statCard(
                      "Today's Sales",
                      CurrencyFormatter.format(prov.todayRevenue),
                      Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      "Today's Profit",
                      CurrencyFormatter.format(prov.todayProfit),
                      Icons.trending_up_outlined,
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _statCard(
                      'Transactions',
                      prov.todaySales.length.toString(),
                      Icons.receipt_outlined,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Total Credit',
                      CurrencyFormatter.format(
                          prov.totalUnpaidDebt),
                      Icons.account_balance_wallet_outlined,
                      isAlert: prov.totalUnpaidDebt > 0,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Quick Actions ──────────────────────
                  _sectionHeader('Quick Actions'),
                  const SizedBox(height: 10),
                  const QuickActionButtons(),
                  const SizedBox(height: 20),

                  // ── Alerts ─────────────────────────────
                  if (prov.outOfStock.isNotEmpty ||
                      prov.lowStock.isNotEmpty) ...[
                    _sectionHeader('Alerts'),
                    const SizedBox(height: 8),
                    if (prov.outOfStock.isNotEmpty)
                      _alertCard(
                        'Out of stock',
                        prov.outOfStock
                            .map((p) => p.name)
                            .take(3)
                            .join(', '),
                        Colors.red,
                        Icons.warning_amber_outlined,
                      ),
                    if (prov.lowStock.isNotEmpty)
                      _alertCard(
                        'Low stock',
                        prov.lowStock
                            .map((p) =>
                                '${p.name} (${p.stock})')
                            .take(3)
                            .join(', '),
                        Colors.orange,
                        Icons.info_outline,
                      ),
                    const SizedBox(height: 20),
                  ],

                  // ── Credit List ────────────────────────
                  Row(children: [
                    _sectionHeader('Credit'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ListaScreen())),
                      child: Text('View all',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  if (customersWithDebt.isEmpty)
                    _emptyCard(
                        prov.customers.isEmpty
                            ? 'No customers yet.'
                            : 'No outstanding credit.',
                        prov.customers.isEmpty
                            ? Icons.people_outline
                            : Icons.check_circle_outline)
                  else
                    ...customersWithDebt.take(5).map((c) {
                      final unpaidDebts = prov
                          .debtsFor(c.id)
                          .where(
                              (d) => d.status != DebtStatus.paid)
                          .toList();
                      final totalOwed = unpaidDebts.fold(
                          0.0, (s, d) => s + d.remaining);
                      final hasOverdue =
                          unpaidDebts.any((d) => d.isOverdue);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: hasOverdue
                                  ? Colors.red.shade200
                                  : Colors.grey.shade200),
                        ),
                        child: ListTile(
                          onTap: () => _showDebtDetails(
                              context, c, unpaidDebts, prov),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: hasOverdue
                                ? Colors.red.shade50
                                : Colors.grey.shade100,
                            child: Text(
                              c.name[0].toUpperCase(),
                              style: TextStyle(
                                color: hasOverdue
                                    ? Colors.red
                                    : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Row(children: [
                            Expanded(
                              child: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87)),
                            ),
                            if (hasOverdue)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    border: Border.all(
                                        color:
                                            Colors.red.shade200)),
                                child: Text('Overdue',
                                    style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontSize: 9,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                          ]),
                          subtitle: Text(
                              '${unpaidDebts.length} unpaid',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12)),
                          trailing: Text(
                            CurrencyFormatter.format(totalOwed),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 14),
                          ),
                        ),
                      );
                    }),

                  if (customersWithDebt.length > 5)
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ListaScreen())),
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          '+ ${customersWithDebt.length - 5} more',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ── Recent Sales ───────────────────────
                  _sectionHeader('Recent Sales'),
                  const SizedBox(height: 10),

                  if (cashSales.isEmpty)
                    _emptyCard('No sales yet today.',
                        Icons.receipt_long_outlined)
                  else
                    ...cashSales
                        .take(10)
                        .map((s) => _SaleTile(sale: s)),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

Widget _statCard(String label, String value, IconData icon,
      {bool isAlert = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                      fontSize: 18,
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

  Widget _emptyCard(String msg, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.grey[400], size: 18),
          const SizedBox(width: 10),
          Text(msg,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13)),
        ]),
      );

  Widget _alertCard(
          String title, String msg, Color color, IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontSize: 13)),
              Text(msg,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 12)),
            ]),
          ),
        ]),
      );

  void _showDebtDetails(BuildContext context, customer,
      List<Debt> debts, AppProvider prov) {
    final Map<String, Sale?> saleCache = {};
    for (final d in debts) {
      final sale =
          prov.sales.where((s) => s.id == d.saleId).firstOrNull;
      saleCache[d.id] = sale;
    }
    final totalOwed = debts.fold(0.0, (s, d) => s + d.remaining);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade100,
                child: Text(customer.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(customer.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                if (customer.phone != null)
                  Text(customer.phone,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12)),
              ]),
              const Spacer(),
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                Text(CurrencyFormatter.format(totalOwed),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87)),
                Text('total credit',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500])),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade200),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: debts.map((d) {
                final sale = saleCache[d.id];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: d.isOverdue
                            ? Colors.red.shade200
                            : Colors.grey.shade200),
                  ),
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(
                        DateHelper.formatDate(d.createdAt),
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12),
                      ),
                      const Spacer(),
                      if (d.isOverdue)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius:
                                  BorderRadius.circular(4),
                              border: Border.all(
                                  color:
                                      Colors.red.shade200)),
                          child: Text('Overdue',
                              style: TextStyle(
                                  color:
                                      Colors.red.shade400,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w600)),
                        ),
                    ]),
                    if (sale != null &&
                        sale.items.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...sale.items.map((item) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: 8),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors
                                              .black87)),
                                  Text(
                                      '${CurrencyFormatter.format(item.price)} × ${item.quantity}',
                                      style: TextStyle(
                                          color: Colors
                                              .grey[500],
                                          fontSize: 12)),
                                ]),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                    item.subtotal),
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87),
                              ),
                            ]),
                          )),
                      Divider(
                          height: 12,
                          color: Colors.grey.shade200),
                    ],
                    if (d.paidAmount > 0)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Text('Paid:',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13)),
                          const Spacer(),
                          Text(
                              CurrencyFormatter.format(
                                  d.paidAmount),
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ]),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Text('Remaining',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                                fontSize: 13)),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(
                              d.remaining),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    PaymentScreen(
                                        debt: d,
                                        customer:
                                            customer)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                        ),
                        child: const Text('Accept Payment',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Sale Tile ─────────────────────────────────────────────────
class _SaleTile extends StatelessWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final isOnline = sale.notes?.contains('Online') ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showSaleDetails(context, sale),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
              isOnline
                  ? Icons.phone_android_outlined
                  : Icons.payments_outlined,
              size: 18,
              color: Colors.black54),
        ),
        title: Row(children: [
          Expanded(
            child: Text(
              isOnline ? 'Online Payment' : 'Cash Sale',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87),
            ),
          ),
          Text(
            DateHelper.formatDate(sale.createdAt),
            style:
                TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ]),
        subtitle: Text(
            '${sale.items.length} item${sale.items.length > 1 ? 's' : ''}  •  ${DateHelper.formatTime(sale.createdAt)}',
            style:
                TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: Text(
          CurrencyFormatter.format(sale.totalAmount),
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87),
        ),
      ),
    );
  }

  void _showSaleDetails(BuildContext context, Sale sale) {
    final isOnline = sale.notes?.contains('Online') ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    isOnline
                        ? Icons.phone_android_outlined
                        : Icons.payments_outlined,
                    color: Colors.black54,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(
                    isOnline
                        ? 'Online Payment'
                        : 'Cash Sale',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                Text(
                    '${DateHelper.formatDate(sale.createdAt)}  •  ${DateHelper.formatTime(sale.createdAt)}',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12)),
              ]),
              const Spacer(),
              Text(CurrencyFormatter.format(sale.totalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87)),
            ]),
          ),
          Divider(
              height: 16, color: Colors.grey.shade200),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Items',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey[700])),
                const SizedBox(height: 10),
                ...sale.items.map((item) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text(item.productName,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87)),
                            Text(
                                '${CurrencyFormatter.format(item.price)} × ${item.quantity}',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12)),
                          ]),
                        ),
                        Text(
                            CurrencyFormatter.format(
                                item.subtotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.black87)),
                      ]),
                    )),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 4),
                if (sale.cashPaid > sale.totalAmount) ...[
                  _row('Cash received:',
                      CurrencyFormatter.format(sale.cashPaid)),
                  _row('Change:',
                      CurrencyFormatter.format(sale.change)),
                ],
                if (isOnline && sale.notes != null)
                  _row('Payment:', sale.notes!),
                const SizedBox(height: 8),
                Row(children: [
                  Text('Total',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13)),
                  const Spacer(),
                  Text(
                      CurrencyFormatter.format(
                          sale.totalAmount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87)),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ReceiptScreen(sale: sale)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                    ),
                    child: const Text('View Receipt',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.black87)),
        ]),
      );
}