import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import 'payment_screen.dart';
import 'credit_order_screen.dart';

const _blue = Color(0xFF1E3A8A);

class ListaScreen extends StatefulWidget {
  final Map<dynamic, int>? cartItems;
  const ListaScreen({super.key, this.cartItems});
  @override
  State<ListaScreen> createState() => _ListaScreenState();
}

class _ListaScreenState extends State<ListaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final unpaidCustomers = prov.customers.where((c) {
        final unpaid = prov
            .debtsFor(c.id)
            .where((d) => d.status != DebtStatus.paid)
            .toList();
        if (unpaid.isEmpty) return false;
        return _search.isEmpty ||
            c.name.toLowerCase().contains(_search.toLowerCase());
      }).toList();

      final paidCustomers = prov.customers.where((c) {
        final allDebts = prov.debtsFor(c.id);
        if (allDebts.isEmpty) return false;
        final allPaid =
            allDebts.every((d) => d.status == DebtStatus.paid);
        if (!allPaid) return false;
        return _search.isEmpty ||
            c.name.toLowerCase().contains(_search.toLowerCase());
      }).toList();

      return Scaffold(
        backgroundColor: Colors.white,
        // Removed fixed appBar to allow natural non-sticky scrolling
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Non-sticky Title Bar
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Text(
                          'Credit Ledger',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // KPI Container & Search Inputs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _blue.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _blue.withValues(alpha: 0.1)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.people_outline,
                                        color: _blue, size: 18),
                                    const SizedBox(width: 10),
                                    Text('${unpaidCustomers.length} active balances',
                                        style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13)),
                                    const Spacer(),
                                    Text(
                                      CurrencyFormatter.format(
                                          prov.totalUnpaidDebt),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: Colors.redAccent),
                                    ),
                                  ]),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            TextField(
                              onChanged: (v) => setState(() => _search = v),
                              decoration: InputDecoration(
                                hintText: 'Search debtors by name...',
                                hintStyle: TextStyle(
                                    color: Colors.grey[400], fontSize: 14),
                                prefixIcon: Icon(Icons.search_outlined,
                                    color: Colors.grey[400], size: 20),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      // Non-sticky TabBar
                      TabBar(
                        controller: _tabCtrl,
                        labelColor: _blue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: _blue,
                        indicatorWeight: 2,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.normal),
                        tabs: [
                          Tab(text: 'Unpaid Session (${unpaidCustomers.length})'),
                          Tab(text: 'Fully Settled (${paidCustomers.length})'),
                        ],
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildUnpaidList(unpaidCustomers, prov),
                _buildPaidList(paidCustomers, prov),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CreditOrderScreen()),
          ),
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          icon: const Icon(Icons.add_shopping_cart_outlined,
              size: 18),
          label: const Text('New Credit',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      );
    });
  }

  Widget _buildUnpaidList(
      List<Customer> customers, AppProvider prov) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.check_circle_outline,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
              _search.isEmpty
                  ? 'No outstanding credit lines logged'
                  : 'No customer matches search query',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500])),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: customers.length,
      itemBuilder: (_, i) {
        final c = customers[i];
        final unpaidDebts = prov
            .debtsFor(c.id)
            .where((d) => d.status != DebtStatus.paid)
            .toList();
        final totalOwed =
            unpaidDebts.fold(0.0, (s, d) => s + d.remaining);
        final hasOverdue =
            unpaidDebts.any((d) => d.isOverdue);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasOverdue
                  ? Colors.red.shade200
                  : Colors.grey.shade200,
              width: hasOverdue ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            onTap: () => _showCustomerDebts(
                context, c, prov.debtsFor(c.id), prov),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: hasOverdue
                  ? Colors.red.shade50
                  : Colors.grey.shade100,
              child: Text(c.name[0].toUpperCase(),
                  style: TextStyle(
                      color: hasOverdue
                          ? Colors.red
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.red.shade200)),
                  child: Text('OVERDUE',
                      style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3)),
                ),
            ]),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  '${unpaidDebts.length} unresolved log'
                  '${c.phone != null ? '  •  ${c.phone}' : ''}',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12)),
            ),
            trailing: Text(
              CurrencyFormatter.format(totalOwed),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  fontSize: 15),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaidList(
      List<Customer> customers, AppProvider prov) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.history_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
              _search.isEmpty
                  ? 'No fully paid ledger sessions archived'
                  : 'No customer historical items match',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[500])),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: customers.length,
      itemBuilder: (_, i) {
        final c = customers[i];
        final allDebts = prov.debtsFor(c.id);
        final totalPaid = allDebts.fold(
            0.0, (s, d) => s + d.originalAmount);
        final lastPaid = allDebts.isNotEmpty
            ? allDebts
                .map((d) => d.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade100,
              child: Text(c.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            title: Text(c.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                if (c.phone != null)
                  Text(c.phone!,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12)),
                if (lastPaid != null)
                  Text(
                      'Last settlement: ${DateHelper.formatDate(lastPaid)}',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(totalPaid),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.green.shade200)),
                  child: Text('PAID',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomerDebts(BuildContext context,
      Customer customer, List<Debt> debts, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CustomerDebtSheet(
          customer: customer, debts: debts, prov: prov),
    );
  }
}

class _CustomerDebtSheet extends StatefulWidget {
  final Customer customer;
  final List<Debt> debts;
  final AppProvider prov;

  const _CustomerDebtSheet(
      {required this.customer,
      required this.debts,
      required this.prov});

  @override
  State<_CustomerDebtSheet> createState() =>
      _CustomerDebtSheetState();
}

class _CustomerDebtSheetState
    extends State<_CustomerDebtSheet> {
  final Map<String, Sale?> _saleCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    for (final d in widget.debts) {
      final sale = widget.prov.sales
          .where((s) => s.id == d.saleId)
          .firstOrNull;
      _saleCache[d.id] = sale;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final unpaid = widget.debts
        .where((d) => d.status != DebtStatus.paid)
        .toList();
    final paid = widget.debts
        .where((d) => d.status == DebtStatus.paid)
        .toList();
    final totalUnpaid =
        unpaid.fold(0.0, (s, d) => s + d.remaining);
    final totalPaid =
        paid.fold(0.0, (s, d) => s + d.originalAmount);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade100,
              child: Text(
                  widget.customer.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              Text(widget.customer.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              if (widget.customer.phone != null)
                Text(widget.customer.phone!,
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12)),
            ]),
            const Spacer(),
            Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
              Text(CurrencyFormatter.format(totalUnpaid),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.redAccent)),
              Text('unpaid remaining',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500])),
            ]),
          ]),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  Text(
                      CurrencyFormatter.format(
                          totalUnpaid),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Active Unpaid',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500])),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  Text(
                      CurrencyFormatter.format(totalPaid),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Settled Archived',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500])),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : widget.debts.isEmpty
                  ? Center(
                      child: Text('No credit records associated',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14)))
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (unpaid.isNotEmpty) ...[
                          _sectionLabel('UNSETTLED CREDITS'),
                          const SizedBox(height: 8),
                          ...unpaid.map((d) =>
                              _debtCard(d, isUnpaid: true)),
                          const SizedBox(height: 16),
                        ],
                        if (paid.isNotEmpty) ...[
                          _sectionLabel('COMPLETED LEDGER HISTORY'),
                          const SizedBox(height: 8),
                          ...paid.map((d) =>
                              _debtCard(d, isUnpaid: false)),
                        ],
                      ],
                    ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
          fontSize: 11,
          letterSpacing: 0.5));

  Widget _debtCard(Debt d, {required bool isUnpaid}) {
    final sale = _saleCache[d.id];
    final daysUntilDue =
        d.dueDate.difference(DateTime.now()).inDays;
    final isNearDue =
        isUnpaid && daysUntilDue <= 3 && !d.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnpaid && d.isOverdue
              ? Colors.red.shade200
              : isNearDue
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
          width: (isUnpaid && d.isOverdue) || isNearDue ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        onTap: () => _showDebtDetail(d, sale, isUnpaid),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isUnpaid
                ? Icons.credit_card_outlined
                : Icons.check_circle_outline,
            color: isUnpaid
                ? Colors.black54
                : Colors.green.shade600,
            size: 18,
          ),
        ),
        title: Text(
          CurrencyFormatter.format(
              isUnpaid ? d.remaining : d.originalAmount),
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 15),
        ),
        subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const SizedBox(height: 2),
          Text(DateHelper.formatDate(d.createdAt),
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 11)),
          if (isUnpaid) ...[
            const SizedBox(height: 1),
            Text(
              d.isOverdue
                  ? 'Overdue — Due ${DateHelper.formatDate(d.dueDate)}'
                  : 'Due ${DateHelper.formatDate(d.dueDate)}',
              style: TextStyle(
                  color: d.isOverdue
                      ? Colors.red
                      : isNearDue
                          ? Colors.orange.shade700
                          : Colors.grey[500],
                  fontSize: 11,
                  fontWeight: d.isOverdue || isNearDue
                      ? FontWeight.w600
                      : FontWeight.normal),
            ),
          ],
          if (sale != null) ...[
            const SizedBox(height: 2),
            Text('${sale.items.length} product units log',
                style: TextStyle(
                    color: Colors.grey[400], fontSize: 11)),
          ]
        ]),
        trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
          if (isUnpaid && d.isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: Colors.red.shade200)),
              child: Text('Overdue',
                  style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            )
          else if (isNearDue)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: Colors.orange.shade200)),
              child: Text('Soon',
                  style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: Colors.grey[400], size: 18),
        ]),
      ),
    );
  }

  void _showDebtDetail(Debt d, Sale? sale, bool isUnpaid) {
    final daysUntilDue =
        d.dueDate.difference(DateTime.now()).inDays;
    final isNearDue =
        isUnpaid && daysUntilDue <= 3 && !d.isOverdue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin:
                const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUnpaid
                      ? Icons.credit_card_outlined
                      : Icons.check_circle_outline,
                  color: isUnpaid
                      ? Colors.black54
                      : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(isUnpaid ? 'Unpaid Record Details' : 'Settled Summary Logs',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                Text(DateHelper.formatDate(d.createdAt),
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12)),
              ]),
              const Spacer(),
              Text(
                CurrencyFormatter.format(isUnpaid
                    ? d.remaining
                    : d.originalAmount),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.black87),
              ),
            ]),
          ),
          Divider(
              height: 20, color: Colors.grey.shade200),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                if (sale != null &&
                    sale.items.isNotEmpty) ...[
                  Text('Purchased Items Context',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey[500])),
                  const SizedBox(height: 10),
                  ...sale.items.map((item) => Container(
                        margin: const EdgeInsets.only(
                            bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.shade200),
                        ),
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
                              const SizedBox(height: 2),
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87)),
                        ]),
                      )),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.shade200)),
                    child: Text('No item statement parameters tracked.',
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                ],
                _summaryRow('Original balance logged:',
                    CurrencyFormatter.format(
                        d.originalAmount)),
                if (d.paidAmount > 0)
                  _summaryRow('Sum cumulative paid:',
                      CurrencyFormatter.format(
                          d.paidAmount)),
                const SizedBox(height: 12),
                if (isUnpaid) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: d.isOverdue
                          ? Colors.red.shade50
                          : isNearDue
                              ? Colors.orange.shade50
                              : Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: d.isOverdue
                              ? Colors.red.shade200
                              : isNearDue
                                  ? Colors.orange.shade200
                                  : Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: d.isOverdue
                            ? Colors.red
                            : isNearDue
                                ? Colors.orange.shade700
                                : Colors.grey[500],
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text('Maturity Due Date:',
                          style: TextStyle(
                              color: d.isOverdue
                                  ? Colors.red
                                  : isNearDue
                                      ? Colors.orange.shade700
                                      : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                        DateHelper.formatDate(d.dueDate),
                        style: TextStyle(
                            color: d.isOverdue
                                ? Colors.red
                                : isNearDue
                                    ? Colors.orange.shade700
                                    : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ]),
                  ),
                  if (d.isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Account is flag deferred (${-daysUntilDue} days overdue)',
                        style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (isNearDue)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Account deadline warnings ($daysUntilDue days left)',
                        style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Text(
                        isUnpaid
                            ? 'Net Remaining Deficit'
                            : 'Total Verified Settled Amount',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 13)),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(isUnpaid
                          ? d.remaining
                          : d.originalAmount),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: isUnpaid ? Colors.redAccent : _blue),
                    ),
                  ]),
                ),
                if (isUnpaid) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PaymentScreen(
                                      debt: d,
                                      customer:
                                          widget.customer)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                      child: const Text('Accept Balance Tender Payment',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
        ]),
      );
}