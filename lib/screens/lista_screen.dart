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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: const Text('Credit',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(children: [
              Divider(height: 1, color: Colors.grey.shade200),
              TabBar(
                controller: _tabCtrl,
                labelColor: const Color(0xFF1E3A8A),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF1E3A8A),
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13),
                tabs: [
                  Tab(
                      text:
                          'Unpaid (${unpaidCustomers.length})'),
                  Tab(
                      text: 'Paid (${paidCustomers.length})'),
                ],
              ),
            ]),
          ),
        ),
        body: Column(children: [

          // ── Search + Summary ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [

              // Summary row
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.people_outline,
                          color: Colors.grey[400], size: 16),
                      const SizedBox(width: 8),
                      Text('${unpaidCustomers.length} with credit',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12)),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(
                            prov.totalUnpaidDebt),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87),
                      ),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Search
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: TextStyle(
                      color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_outlined,
                      color: Colors.grey[400], size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildUnpaidList(unpaidCustomers, prov),
                _buildPaidList(paidCustomers, prov),
              ],
            ),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CreditOrderScreen()),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_shopping_cart_outlined,
              size: 18),
          label: const Text('New Credit',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
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
                  ? 'No outstanding credit'
                  : 'No results found',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500])),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasOverdue
                  ? Colors.red.shade200
                  : Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            onTap: () => _showCustomerDebts(
                context, c, prov.debtsFor(c.id), prov),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: hasOverdue
                  ? Colors.red.shade50
                  : Colors.grey.shade100,
              child: Text(c.name[0].toUpperCase(),
                  style: TextStyle(
                      color: hasOverdue
                          ? Colors.red
                          : Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            title: Row(children: [
              Expanded(
                child: Text(c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87)),
              ),
              if (hasOverdue)
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
                          color: Colors.red.shade400,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            subtitle: Text(
                '${unpaidDebts.length} unpaid'
                '${c.phone != null ? '  •  ${c.phone}' : ''}',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 11)),
            trailing: Text(
              CurrencyFormatter.format(totalOwed),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 14),
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
                  ? 'No paid credit yet'
                  : 'No results found',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey[500])),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade100,
              child: Text(c.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            title: Text(c.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.phone != null)
                  Text(c.phone!,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11)),
                if (lastPaid != null)
                  Text(
                      'Last paid: ${DateHelper.formatDate(lastPaid)}',
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
                        fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.green.shade200)),
                  child: Text('Paid',
                      style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
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

// ── Customer Debt Sheet ───────────────────────────────────────
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

        // Header
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade100,
              child: Text(
                  widget.customer.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              Text(widget.customer.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87)),
              Text('remaining',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500])),
            ]),
          ]),
        ),

        // Summary chips
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
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
                          fontSize: 15)),
                  Text('Unpaid',
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  Text(
                      CurrencyFormatter.format(totalPaid),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 15)),
                  Text('Paid',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500])),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: Colors.grey.shade200),

        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : widget.debts.isEmpty
                  ? Center(
                      child: Text('No credit records',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14)))
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (unpaid.isNotEmpty) ...[
                          _sectionLabel('Unpaid'),
                          const SizedBox(height: 8),
                          ...unpaid.map((d) =>
                              _debtCard(d, isUnpaid: true)),
                          const SizedBox(height: 16),
                        ],
                        if (paid.isNotEmpty) ...[
                          _sectionLabel('Paid'),
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
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          fontSize: 12));

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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUnpaid && d.isOverdue
              ? Colors.red.shade200
              : isNearDue
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        onTap: () => _showDebtDetail(d, sale, isUnpaid),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isUnpaid
                ? Icons.credit_card_outlined
                : Icons.check_circle_outline,
            color: isUnpaid
                ? Colors.black54
                : Colors.green,
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
          Text(DateHelper.formatDate(d.createdAt),
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 11)),
          if (isUnpaid)
            Text(
              d.isOverdue
                  ? 'Overdue — Due ${DateHelper.formatDate(d.dueDate)}'
                  : 'Due ${DateHelper.formatDate(d.dueDate)}',
              style: TextStyle(
                  color: d.isOverdue
                      ? Colors.red
                      : isNearDue
                          ? Colors.orange
                          : Colors.grey[500],
                  fontSize: 11,
                  fontWeight: d.isOverdue || isNearDue
                      ? FontWeight.w600
                      : FontWeight.normal),
            ),
          if (sale != null)
            Text('${sale.items.length} item',
                style: TextStyle(
                    color: Colors.grey[400], fontSize: 11)),
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
                      color: Colors.red.shade400,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
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
                      color: Colors.orange.shade600,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
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
                Text(isUnpaid ? 'Unpaid' : 'Paid',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87),
              ),
            ]),
          ),
          Divider(
              height: 16, color: Colors.grey.shade200),

          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [

                // Items
                if (sale != null &&
                    sale.items.isNotEmpty) ...[
                  Text('Items',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey[700])),
                  const SizedBox(height: 10),
                  ...sale.items.map((item) => Container(
                        margin: const EdgeInsets.only(
                            bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(10),
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
                              Text(
                                  '${CurrencyFormatter.format(item.price)} × ${item.quantity}',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11)),
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
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.grey.shade200)),
                    child: Text('No item details',
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                ],

                // Summary
                _summaryRow('Original amount:',
                    CurrencyFormatter.format(
                        d.originalAmount)),
                if (d.paidAmount > 0)
                  _summaryRow('Amount paid:',
                      CurrencyFormatter.format(
                          d.paidAmount)),
                const SizedBox(height: 8),

                // Due date
                if (isUnpaid) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: d.isOverdue
                          ? Colors.red.shade50
                          : isNearDue
                              ? Colors.orange.shade50
                              : Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(10),
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
                                ? Colors.orange
                                : Colors.grey[500],
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text('Due date:',
                          style: TextStyle(
                              color: d.isOverdue
                                  ? Colors.red
                                  : isNearDue
                                      ? Colors.orange
                                      : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                        DateHelper.formatDate(d.dueDate),
                        style: TextStyle(
                            color: d.isOverdue
                                ? Colors.red
                                : isNearDue
                                    ? Colors.orange
                                    : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ]),
                  ),
                  if (d.isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${(-daysUntilDue)} days overdue',
                        style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (isNearDue)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '$daysUntilDue day${daysUntilDue == 1 ? '' : 's'} left',
                        style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],

                // Remaining
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Text(
                        isUnpaid
                            ? 'Remaining'
                            : 'Total paid',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 13)),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(isUnpaid
                          ? d.remaining
                          : d.originalAmount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.black87),
                    ),
                  ]),
                ),

                if (isUnpaid) ...[
                  const SizedBox(height: 16),
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
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      child: const Text('Accept Payment',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
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
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.black87)),
        ]),
      );
}