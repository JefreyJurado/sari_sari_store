import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/loyalty.dart';
import '../models/customer.dart';
import '../providers/app_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';

const _uuid = Uuid();

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});
  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  Map<String, LoyaltyAccount> _accounts = {};
  Map<String, List<LoyaltyTransaction>> _transactions = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final accountsJson =
        prefs.getString('loyalty_accounts') ?? '{}';
    final txJson =
        prefs.getString('loyalty_transactions') ?? '{}';
    try {
      final accountsMap =
          jsonDecode(accountsJson) as Map<String, dynamic>;
      _accounts = accountsMap.map((k, v) => MapEntry(
          k,
          LoyaltyAccount.fromMap(v as Map<String, dynamic>)));
      final txMap =
          jsonDecode(txJson) as Map<String, dynamic>;
      _transactions = txMap.map((k, v) => MapEntry(
          k,
          (v as List)
              .map((t) => LoyaltyTransaction.fromMap(
                  t as Map<String, dynamic>))
              .toList()));
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loyalty_accounts',
        jsonEncode(_accounts.map((k, v) => MapEntry(k, v.toMap()))));
    await prefs.setString(
        'loyalty_transactions',
        jsonEncode(_transactions.map((k, v) =>
            MapEntry(k, v.map((t) => t.toMap()).toList()))));
  }

  int _pointsFor(double amount) => (amount / 10).floor();

  LoyaltyAccount _getOrCreate(String customerId) =>
      _accounts[customerId] ??
      LoyaltyAccount(
        customerId: customerId,
        totalPoints: 0,
        redeemedPoints: 0,
        lastUpdated: DateTime.now(),
      );

  Future<void> _addPoints(
      Customer customer, double saleAmount) async {
    final points = _pointsFor(saleAmount);
    if (points <= 0) return;
    final account = _getOrCreate(customer.id);
    _accounts[customer.id] = account.copyWith(
        totalPoints: account.totalPoints + points);
    _transactions[customer.id] ??= [];
    _transactions[customer.id]!.insert(
        0,
        LoyaltyTransaction(
          id: _uuid.v4(),
          customerId: customer.id,
          points: points,
          type: 'earned',
          description:
              'Binenta ng ${CurrencyFormatter.format(saleAmount)}',
          createdAt: DateTime.now(),
        ));
    await _save();
    setState(() {});
  }

  Future<void> _redeemPoints(
      Customer customer, int points) async {
    final account = _getOrCreate(customer.id);
    if (points > account.availablePoints) return;
    _accounts[customer.id] = account.copyWith(
        redeemedPoints: account.redeemedPoints + points);
    _transactions[customer.id] ??= [];
    _transactions[customer.id]!.insert(
        0,
        LoyaltyTransaction(
          id: _uuid.v4(),
          customerId: customer.id,
          points: points,
          type: 'redeemed',
          description:
              'Na-redeem ng ${CurrencyFormatter.format(points * 0.10)}',
          createdAt: DateTime.now(),
        ));
    await _save();
    setState(() {});
  }

  void _showCustomerLoyalty(Customer customer) {
    final account = _getOrCreate(customer.id);
    final txList = _transactions[customer.id] ?? [];
    final redeemCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (_, ctrl) => Column(children: [
            Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 10),
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
                  radius: 22,
                  child: Text(
                    customer.name[0].toUpperCase(),
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
                  Text(customer.name,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Text('Loyalty Member',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            // Points summary
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF2E7D32)
                          .withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Expanded(
                      child: _pointsStat(
                          '${account.availablePoints}',
                          'Available',
                          const Color(0xFF2E7D32))),
                  Container(
                      width: 1,
                      height: 44,
                      color: Colors.grey[300]),
                  Expanded(
                      child: _pointsStat(
                          CurrencyFormatter.format(
                              account.pesoValue),
                          'Halaga',
                          Colors.blue)),
                  Container(
                      width: 1,
                      height: 44,
                      color: Colors.grey[300]),
                  Expanded(
                      child: _pointsStat(
                          '${account.totalPoints}',
                          'Kabuuan',
                          Colors.grey[700]!)),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Redeem
            if (account.availablePoints > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: redeemCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'I-redeem ang points',
                          prefixIcon: const Icon(
                              Icons.card_membership_outlined,
                              size: 20),
                          suffixText: 'pts',
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final pts =
                          int.tryParse(redeemCtrl.text) ?? 0;
                      if (pts <= 0 ||
                          pts > account.availablePoints) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                                content: Text(
                                    'Hindi sapat ang points!'),
                                backgroundColor: Colors.red));
                        return;
                      }
                      await _redeemPoints(customer, pts);
                      setS(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                        content: Text(
                            'Na-redeem ang $pts pts = ${CurrencyFormatter.format(pts * 0.10)}!'),
                        backgroundColor: Colors.green,
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14)),
                    child: const Text('Redeem'),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Transaction history
            Expanded(
              child: txList.isEmpty
                  ? Center(
                      child: Text('Walang history pa',
                          style: TextStyle(
                              color: Colors.grey[400])))
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(
                          16, 8, 16, 16),
                      itemCount: txList.length,
                      itemBuilder: (_, i) {
                        final tx = txList[i];
                        return Container(
                          margin: const EdgeInsets.only(
                              bottom: 8),
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
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: tx.isEarned
                                    ? Colors.green
                                        .withValues(alpha: 0.1)
                                    : Colors.orange
                                        .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Icon(
                                tx.isEarned
                                    ? Icons.add
                                    : Icons.remove,
                                size: 18,
                                color: tx.isEarned
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            title: Text(tx.description,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w500)),
                            subtitle: Text(
                                DateHelper.formatDate(
                                    tx.createdAt),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500])),
                            trailing: Text(
                              '${tx.isEarned ? '+' : '-'}${tx.points} pts',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: tx.isEarned
                                      ? Colors.green
                                      : Colors.orange),
                            ),
                          ),
                        );
                      }),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pointsStat(String value, String label, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey[600])),
      ]);

  void _showAddPoints(BuildContext context, AppProvider prov) {
    Customer? selectedCustomer;
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Magdagdag ng Points'),
          content:
              Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Customer>(
              value: selectedCustomer,
              decoration: InputDecoration(
                labelText: 'Customer',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon:
                    const Icon(Icons.person_outlined),
              ),
              borderRadius: BorderRadius.circular(12),
              items: prov.customers
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (c) =>
                  setS(() => selectedCustomer = c),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Halaga ng Benta (₱)',
                prefixText: '₱ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (_) => setS(() {}),
            ),
            const SizedBox(height: 8),
            if (amountCtrl.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.star_outline,
                      color: Color(0xFF2E7D32), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${_pointsFor(double.tryParse(amountCtrl.text) ?? 0)} points',
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ]),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kanselahin')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCustomer == null) return;
                final amount =
                    double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                await _addPoints(selectedCustomer!, amount);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('I-add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final customers = prov.customers
          .where((c) =>
              _search.isEmpty ||
              c.name
                  .toLowerCase()
                  .contains(_search.toLowerCase()))
          .toList();

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(title: const Text('Loyalty Points')),
        body: Column(children: [
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
            padding:
                const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(children: [
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                const Text('1 point bawat ₱10 na benta',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('₱0.10 ang halaga ng bawat point',
                    style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: 0.7),
                        fontSize: 12)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text('${_accounts.length}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Text('members',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70)),
                ]),
              ),
            ]),
          ),

          // Search
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  hintText: 'Hanapin ang customer...',
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

          // Customer list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator())
                : customers.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                          Icon(Icons.people_outline,
                              size: 64,
                              color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Walang customers',
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16)),
                        ]))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 4, 16, 16),
                        itemCount: customers.length,
                        itemBuilder: (_, i) {
                          final c = customers[i];
                          final account = _getOrCreate(c.id);
                          final hasPoints =
                              account.availablePoints > 0;
                          return Container(
                            margin: const EdgeInsets.only(
                                bottom: 10),
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
                              onTap: () =>
                                  _showCustomerLoyalty(c),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: hasPoints
                                    ? const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.12)
                                    : Colors.grey
                                        .withValues(alpha: 0.1),
                                child: Text(
                                    c.name[0].toUpperCase(),
                                    style: TextStyle(
                                        color: hasPoints
                                            ? const Color(
                                                0xFF2E7D32)
                                            : Colors.grey,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text(
                                  c.phone ?? 'Walang numero',
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
                                    '${account.availablePoints} pts',
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 14,
                                        color: hasPoints
                                            ? const Color(
                                                0xFF2E7D32)
                                            : Colors.grey),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                        account.pesoValue),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddPoints(context, prov),
          icon: const Icon(Icons.star_outline),
          label: const Text('Magdagdag ng Points'),
        ),
      );
    });
  }
}