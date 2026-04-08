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
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('Lista ng Utang'),
          actions: [
            IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'Bagong Uutang',
                onPressed: () => _addDebtor(context, prov)),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Hindi Pa Bayad',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text('${unpaidCustomers.length}',
                        style:
                            const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bayad Na',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text('${paidCustomers.length}',
                        style:
                            const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(children: [
          // Summary banner
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFB71C1C),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Kabuuang Hindi Pa Bayad',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white70)),
                Text(
                    CurrencyFormatter.format(
                        prov.totalUnpaidDebt),
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Text('${unpaidCustomers.length}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Text('may utang',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70)),
                ]),
              ),
            ]),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
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
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Hanapin ang pangalan...',
                  hintStyle:
                      TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.grey[400]),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

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
          icon: const Icon(Icons.add_shopping_cart_outlined),
          label: const Text('Bagong Uutang'),
          backgroundColor: Colors.orange,
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
              size: 72, color: Colors.green[200]),
          const SizedBox(height: 16),
          Text(
              _search.isEmpty
                  ? 'Walang utang!'
                  : 'Walang nahanap',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          if (_search.isEmpty)
            Text('Lahat ay bayad na.',
                style: TextStyle(color: Colors.grey[500])),
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
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: hasOverdue
                ? Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            onTap: () => _showCustomerDebts(
                context, c, prov.debtsFor(c.id), prov),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: hasOverdue
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              child: Text(
                c.name[0].toUpperCase(),
                style: TextStyle(
                    color: hasOverdue
                        ? Colors.red
                        : Colors.orange,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(children: [
              Expanded(
                child: Text(c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
              if (hasOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('OVERDUE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.phone != null)
                  Text(c.phone!,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12)),
                Text('${unpaidDebts.length} beses nag-utang',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(totalOwed),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16),
                ),
                const Text('utang',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey)),
              ],
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
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
              _search.isEmpty
                  ? 'Wala pang nakapagbayad'
                  : 'Walang nahanap',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
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
          margin: const EdgeInsets.only(bottom: 10),
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32)
                  .withValues(alpha: 0.12),
              child: Text(
                c.name[0].toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(c.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.phone != null)
                  Text(c.phone!,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12)),
                if (lastPaid != null)
                  Text(
                      'Huling bayad: ${DateHelper.formatDate(lastPaid)}',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(totalPaid),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('BAYAD NA',
                      style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CustomerDebtSheet(
          customer: customer, debts: debts, prov: prov),
    );
  }

  void _addDebtor(BuildContext context, AppProvider prov) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Bagong Uutang'),
        content:
            Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'I-add ang pangalan ng taong uutang sa iyo.',
            style:
                TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Pangalan *',
                  prefixIcon: Icon(Icons.person_outlined),
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Numero (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(
                        content: Text('Lagyan ng pangalan!'),
                        backgroundColor: Colors.red));
                return;
              }
              await prov.addCustomer(
                nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(
                      '${nameCtrl.text.trim()} ay naidagdag na!'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            child: const Text('I-save'),
          ),
        ],
      ),
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
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
        ),

        // Customer header
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32)
                  .withValues(alpha: 0.12),
              radius: 24,
              child: Text(
                widget.customer.name[0].toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              Text(widget.customer.name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              if (widget.customer.phone != null)
                Text(widget.customer.phone!,
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13)),
            ]),
            const Spacer(),
            Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
              Text(CurrencyFormatter.format(totalUnpaid),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.red)),
              const Text('natitira',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey)),
            ]),
          ]),
        ),

        // Summary cards
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(children: [
                  Text(
                      CurrencyFormatter.format(totalUnpaid),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 16)),
                  const Text('Hindi Pa Bayad',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.green
                          .withValues(alpha: 0.2)),
                ),
                child: Column(children: [
                  Text(CurrencyFormatter.format(totalPaid),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16)),
                  const Text('Bayad Na',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.green)),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 10),
        const Divider(height: 1),

        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : widget.debts.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                        Icon(Icons.check_circle_outline,
                            size: 56,
                            color: Colors.green[300]),
                        const SizedBox(height: 8),
                        const Text('Walang utang!',
                            style:
                                TextStyle(fontSize: 16)),
                      ]))
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (unpaid.isNotEmpty) ...[
                          _sectionLabel(
                              'Hindi Pa Bayad', Colors.red),
                          const SizedBox(height: 8),
                          ...unpaid.map((d) =>
                              _debtCard(d, isUnpaid: true)),
                          const SizedBox(height: 16),
                        ],
                        if (paid.isNotEmpty) ...[
                          _sectionLabel(
                              'Bayad Na', Colors.green),
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

  Widget _sectionLabel(String text, Color color) => Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13)),
        ],
      );

  Widget _debtCard(Debt d, {required bool isUnpaid}) {
    final sale = _saleCache[d.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isUnpaid && d.isOverdue
            ? Border.all(
                color: Colors.red.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        onTap: () => _showDebtDetail(d, sale, isUnpaid),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isUnpaid
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isUnpaid
                ? Icons.credit_card_outlined
                : Icons.check_circle_outline,
            color: isUnpaid ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          CurrencyFormatter.format(
              isUnpaid ? d.remaining : d.originalAmount),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isUnpaid ? Colors.red : Colors.green,
              fontSize: 17),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateHelper.formatDate(d.createdAt),
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 12)),
            if (sale != null)
              Text('${sale.items.length} item',
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUnpaid && d.isOverdue)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('OVERDUE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showDebtDetail(Debt d, Sale? sale, bool isUnpaid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnpaid
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUnpaid
                      ? Icons.credit_card_outlined
                      : Icons.check_circle_outline,
                  color:
                      isUnpaid ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(
                  isUnpaid
                      ? 'Hindi Pa Bayad'
                      : 'Bayad Na',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isUnpaid
                          ? Colors.red
                          : Colors.green),
                ),
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
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isUnpaid
                        ? Colors.red
                        : Colors.green),
              ),
            ]),
          ),
          const Divider(height: 16),

          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                if (sale != null &&
                    sale.items.isNotEmpty) ...[
                  const Text('Mga Item na Inutang:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 10),
                  ...sale.items.map((item) => Container(
                        margin:
                            const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ]),
                      )),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Text('Walang detalye ng items',
                        style: TextStyle(
                            color: Colors.grey[400])),
                  ),
                  const SizedBox(height: 8),
                ],

                // Summary
                _summaryRow('Orihinal na Utang:',
                    CurrencyFormatter.format(
                        d.originalAmount)),
                if (d.paidAmount > 0)
                  _summaryRow('Bayad na:',
                      CurrencyFormatter.format(
                          d.paidAmount),
                      color: Colors.green),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUnpaid
                        ? Colors.red.withValues(alpha: 0.08)
                        : Colors.green
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isUnpaid
                            ? Colors.red
                                .withValues(alpha: 0.2)
                            : Colors.green
                                .withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Text(
                      isUnpaid ? 'NATITIRA:' : 'BAYAD NA:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isUnpaid
                              ? Colors.red
                              : Colors.green),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(isUnpaid
                          ? d.remaining
                          : d.originalAmount),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: isUnpaid
                              ? Colors.red
                              : Colors.green),
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
                              builder: (_) => PaymentScreen(
                                  debt: d,
                                  customer:
                                      widget.customer)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 14)),
                      child: const Text('Tanggap ng Bayad',
                          style: TextStyle(fontSize: 15)),
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

  Widget _summaryRow(String label, String value,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      );
}