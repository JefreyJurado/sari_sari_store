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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('TindaPH'),
        actions: [
          IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Gastos',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ExpensesScreen()))),
          IconButton(
              icon: const Icon(Icons.backup_outlined),
              tooltip: 'Backup',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const BackupScreen()))),
          IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()))),
        ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Banner ─────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                        20, 12, 20, 28),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(DateHelper.todayFormatted(),
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          'Magandang ${DateHelper.greeting()}! 👋',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        // Stats row
                        Row(children: [
                          _statCard('Benta',
                              CurrencyFormatter.format(
                                  prov.todayRevenue),
                              Icons.shopping_bag_outlined),
                          const SizedBox(width: 10),
                          _statCard('Kita',
                              CurrencyFormatter.format(
                                  prov.todayProfit),
                              Icons.trending_up_outlined),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          _statCard('Transaksyon',
                              prov.todaySales.length
                                  .toString(),
                              Icons.receipt_outlined),
                          const SizedBox(width: 10),
                          _statCard('Total Utang',
                              CurrencyFormatter.format(
                                  prov.totalUnpaidDebt),
                              Icons.account_balance_wallet_outlined,
                              isRed: true),
                        ]),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // ── Quick Actions ──────────────────
                        _sectionTitle('Mabilis na Aksyon'),
                        const SizedBox(height: 10),
                        const QuickActionButtons(),
                        const SizedBox(height: 20),

                        // ── Alerts ─────────────────────────
                        if (prov.outOfStock.isNotEmpty ||
                            prov.lowStock.isNotEmpty) ...[
                          _sectionTitle('Mga Alerto'),
                          const SizedBox(height: 8),
                          if (prov.outOfStock.isNotEmpty)
                            _alertCard(
                              'Ubos na ang stock!',
                              prov.outOfStock
                                  .map((p) => p.name)
                                  .take(3)
                                  .join(', '),
                              Colors.red,
                              Icons.warning_rounded,
                            ),
                          if (prov.lowStock.isNotEmpty)
                            _alertCard(
                              'Mababang stock',
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

                        // ── Lista ng Utang ─────────────────
                        Row(children: [
                          _sectionTitle('Lista ng Utang'),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ListaScreen())),
                            child: const Text(
                              'Tingnan Lahat →',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E7D32),
                                  fontWeight:
                                      FontWeight.w600),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),

                        if (customersWithDebt.isEmpty)
                          _emptyCard(
                              'Walang utang! Lahat ay bayad na.',
                              Icons.check_circle_outline,
                              Colors.green)
                        else
                          ...customersWithDebt.take(5).map((c) {
                            final unpaidDebts = prov
                                .debtsFor(c.id)
                                .where((d) =>
                                    d.status != DebtStatus.paid)
                                .toList();
                            final totalOwed = unpaidDebts.fold(
                                0.0, (s, d) => s + d.remaining);
                            final hasOverdue = unpaidDebts
                                .any((d) => d.isOverdue);

                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: hasOverdue
                                    ? Border.all(
                                        color: Colors.red
                                            .withValues(alpha: 0.3),
                                        width: 1)
                                    : null,
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
                                onTap: () => _showDebtDetails(
                                    context,
                                    c,
                                    unpaidDebts,
                                    prov),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: hasOverdue
                                      ? Colors.red
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.1),
                                  child: Text(
                                    c.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: hasOverdue
                                          ? Colors.red
                                          : const Color(
                                              0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(children: [
                                  Expanded(
                                    child: Text(c.name,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 14)),
                                  ),
                                  if (hasOverdue)
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 6,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(4)),
                                      child: const Text(
                                          'OVERDUE',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight:
                                                  FontWeight
                                                      .bold)),
                                    ),
                                ]),
                                subtitle: Text(
                                    '${unpaidDebts.length} utang',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12)),
                                trailing: Text(
                                  CurrencyFormatter.format(
                                      totalOwed),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 15),
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
                              padding: const EdgeInsets.only(
                                  top: 4, bottom: 8),
                              child: Text(
                                '+ ${customersWithDebt.length - 5} pa na may utang...',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
                                    fontWeight:
                                        FontWeight.w600),
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // ── Huling Benta ───────────────────
                        _sectionTitle('Mga Huling Benta'),
                        const SizedBox(height: 10),

                        if (cashSales.isEmpty)
                          _emptyCard('Wala pang benta ngayon',
                              Icons.receipt_long_outlined,
                              Colors.grey)
                        else
                          ...cashSales
                              .take(10)
                              .map((s) => _SaleTile(sale: s)),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {bool isRed = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(icon,
                color: isRed
                    ? Colors.red[200]
                    : Colors.white70,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: isRed
                              ? Colors.red[100]
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11)),
                ],
              ),
            ),
          ]),
        ),
      );

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
      );

  Widget _emptyCard(String msg, IconData icon, Color color) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Icon(icon, color: color.withValues(alpha: 0.6), size: 22),
          const SizedBox(width: 10),
          Text(msg,
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 13)),
        ]),
      );

  Widget _alertCard(
          String title, String msg, Color color, IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
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
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2E7D32)
                    .withValues(alpha: 0.15),
                child: Text(customer.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(customer.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                if (customer.phone != null)
                  Text(customer.phone,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13)),
              ]),
              const Spacer(),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text(CurrencyFormatter.format(totalOwed),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.red)),
                const Text('kabuuang utang',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: debts.map((d) {
                final sale = saleCache[d.id];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: d.isOverdue
                        ? Border.all(
                            color: Colors.red
                                .withValues(alpha: 0.3))
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius:
                                    BorderRadius.circular(6)),
                            child: const Text('OVERDUE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.bold)),
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
                                            fontSize: 14)),
                                    Text(
                                        '${CurrencyFormatter.format(item.price)} × ${item.quantity}',
                                        style: TextStyle(
                                            color:
                                                Colors.grey[500],
                                            fontSize: 12)),
                                  ]),
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                      item.subtotal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                              ]),
                            )),
                        const Divider(height: 12),
                      ],
                      if (d.paidAmount > 0)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Text('Bayad na:',
                                style: TextStyle(
                                    color: Colors.grey[600])),
                            const Spacer(),
                            Text(
                                CurrencyFormatter.format(
                                    d.paidAmount),
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight:
                                        FontWeight.w600)),
                          ]),
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Text('NATITIRA:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 13)),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.format(
                                d.remaining),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.red),
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
                                  builder: (_) => PaymentScreen(
                                      debt: d,
                                      customer: customer)),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 12)),
                          child: const Text(
                              'Tanggap ng Bayad'),
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _showSaleDetails(context, sale),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isOnline
                ? Colors.blue.withValues(alpha: 0.1)
                : const Color(0xFF2E7D32)
                    .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
              isOnline ? Icons.phone_android : Icons.payments,
              size: 20,
              color: isOnline
                  ? Colors.blue
                  : const Color(0xFF2E7D32)),
        ),
        title: Row(children: [
          Expanded(
            child: Text(
              isOnline ? 'Online Payment' : 'Cash Sale',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Text(
            DateHelper.formatDate(sale.createdAt),
            style: TextStyle(
                fontSize: 11, color: Colors.grey[400]),
          ),
        ]),
        subtitle: Text(
            '${sale.items.length} item  •  ${DateHelper.formatTime(sale.createdAt)}',
            style: TextStyle(
                fontSize: 12, color: Colors.grey[500])),
        trailing: Text(
          CurrencyFormatter.format(sale.totalAmount),
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2E7D32)),
        ),
      ),
    );
  }

  void _showSaleDetails(BuildContext context, Sale sale) {
    final isOnline = sale.notes?.contains('Online') ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.blue.withValues(alpha: 0.1)
                      : const Color(0xFF2E7D32)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    isOnline
                        ? Icons.phone_android
                        : Icons.payments,
                    color: isOnline
                        ? Colors.blue
                        : const Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(
                    isOnline ? 'Online Payment' : 'Cash Sale',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                    '${DateHelper.formatDate(sale.createdAt)}  •  ${DateHelper.formatTime(sale.createdAt)}',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12)),
              ]),
              const Spacer(),
              Text(
                  CurrencyFormatter.format(sale.totalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF2E7D32))),
            ]),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Mga Item:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
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
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
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
                                fontSize: 14)),
                      ]),
                    )),
                const Divider(),
                const SizedBox(height: 4),
                if (sale.cashPaid > sale.totalAmount) ...[
                  _row('Cash na Ibinigay:',
                      CurrencyFormatter.format(sale.cashPaid)),
                  _row('Sukli:',
                      CurrencyFormatter.format(sale.change),
                      color: Colors.blue),
                ],
                if (isOnline && sale.notes != null)
                  _row('Payment:', sale.notes!,
                      color: Colors.blue),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Text('KABUUAN:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF2E7D32))),
                    const Spacer(),
                    Text(
                        CurrencyFormatter.format(
                            sale.totalAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Color(0xFF2E7D32))),
                  ]),
                ),
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 14)),
                    child: const Text('Tingnan Receipt'),
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

  Widget _row(String label, String value, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}