import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/loyalty.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';

const _uuid = Uuid();

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});
  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  Map<String, LoyaltyAccount> _accounts = {};
  Map<String, List<LoyaltyTransaction>> _transactions = {};
  bool _loading = true;
  String _search = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('loyalty_accounts') ?? '{}';
    final txJson = prefs.getString('loyalty_transactions') ?? '{}';
    try {
      final accountsMap =
          jsonDecode(accountsJson) as Map<String, dynamic>;
      _accounts = accountsMap.map((k, v) => MapEntry(
          k, LoyaltyAccount.fromMap(v as Map<String, dynamic>)));
      final txMap = jsonDecode(txJson) as Map<String, dynamic>;
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
        jsonEncode(_transactions.map(
            (k, v) => MapEntry(k, v.map((t) => t.toMap()).toList()))));
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

  Future<void> addPointsFromSale(
      String customerId, String customerName, double saleAmount,
      {DateTime? saleDate}) async {
    final points = _pointsFor(saleAmount);
    if (points <= 0) return;
    final account = _getOrCreate(customerId);
    _accounts[customerId] =
        account.copyWith(totalPoints: account.totalPoints + points);
    _transactions[customerId] ??= [];
    _transactions[customerId]!.insert(
        0,
        LoyaltyTransaction(
          id: _uuid.v4(),
          customerId: customerId,
          points: points,
          type: 'earned',
          description:
              'Binili ng ${CurrencyFormatter.format(saleAmount)}',
          createdAt: saleDate ?? DateTime.now(),
        ));
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _redeemAsDiscount(
      Customer customer, int points) async {
    final account = _getOrCreate(customer.id);
    if (points > account.availablePoints) return;
    final pesoValue = points * 0.10;
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
              '💰 Peso Discount — ₱${pesoValue.toStringAsFixed(2)}',
          createdAt: DateTime.now(),
        ));
    await _save();
    setState(() {});
  }

  Future<void> _redeemAsFreeItem(
      Customer customer, int points, Product product) async {
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
          description: '🎁 Libreng ${product.name}',
          createdAt: DateTime.now(),
        ));
    await _save();
    setState(() {});
  }

  void _showRedeemOptions(
      BuildContext context, Customer customer, AppProvider prov) {
    final account = _getOrCreate(customer.id);
    if (account.availablePoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Walang available na points!'),
          backgroundColor: Colors.red));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RedeemSheet(
        customer: customer,
        account: account,
        prov: prov,
        onRedeem: (type, points, product) async {
          if (type == 'discount') {
            await _redeemAsDiscount(customer, points);
            if (context.mounted) {
              final discountAmount = (points * 0.10).toStringAsFixed(2);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Na-redeem! ₱$discountAmount discount para kay ${customer.name}!'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Pumunta sa Benta',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).popUntil(
                        (route) => route.isFirst);
                  },
                ),
                duration: const Duration(seconds: 5),
              ));
            }
          } else {
            await _redeemAsFreeItem(customer, points, product!);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Na-redeem! Libreng ${product.name} para kay ${customer.name}!'),
                backgroundColor: Colors.orange,
              ));
            }
          }
        },
      ),
    );
  }

  void _showCustomerLoyalty(Customer customer) {
    final account = _getOrCreate(customer.id);
    final txList = _transactions[customer.id] ?? [];
    final earnedList = txList.where((t) => t.isEarned).toList();
    final redeemedList = txList.where((t) => !t.isEarned).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) =>
          Consumer<AppProvider>(builder: (_, prov, __) {
        return StatefulBuilder(
          builder: (ctx, setS) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            builder: (_, ctrl) => DefaultTabController(
              length: 2,
              child: Column(children: [
                Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 10),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),

                // Customer header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
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
                              fontSize: 18)),
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
                              color: Colors.grey,
                              fontSize: 12)),
                    ]),
                    const Spacer(),
                    if (account.availablePoints > 0)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRedeemOptions(
                              context, customer, prov);
                        },
                        icon: const Icon(
                            Icons.redeem_outlined,
                            size: 16),
                        label: const Text('Redeem'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),

                // Points summary
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
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
                              '${account.redeemedPoints}',
                              'Na-redeem',
                              Colors.orange)),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),

                // Tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: const Color(0xFF2E7D32),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF2E7D32),
                    tabs: [
                      Tab(
                          child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                            const Icon(Icons.star_outline,
                                size: 14),
                            const SizedBox(width: 4),
                            Text(
                                'Earned (${earnedList.length})'),
                          ])),
                      Tab(
                          child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                            const Icon(Icons.redeem_outlined,
                                size: 14),
                            const SizedBox(width: 4),
                            Text(
                                'Redeemed (${redeemedList.length})'),
                          ])),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      // Earned
                      earnedList.isEmpty
                          ? Center(
                              child: Text('Walang earned pa',
                                  style: TextStyle(
                                      color: Colors.grey[400])))
                          : ListView.builder(
                              controller: ctrl,
                              padding:
                                  const EdgeInsets.fromLTRB(
                                      16, 8, 16, 16),
                              itemCount: earnedList.length,
                              itemBuilder: (_, i) =>
                                  _txTile(earnedList[i]),
                            ),

                      // Redeemed
                      redeemedList.isEmpty
                          ? Center(
                              child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                Icon(Icons.redeem_outlined,
                                    size: 56,
                                    color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text('Wala pang na-redeem',
                                    style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 15)),
                              ]))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                      16, 8, 16, 16),
                              itemCount: redeemedList.length,
                              itemBuilder: (_, i) =>
                                  _txTile(redeemedList[i]),
                            ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _txTile(LoyaltyTransaction tx) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: tx.isEarned
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tx.isEarned ? Icons.add : Icons.redeem_outlined,
              size: 18,
              color: tx.isEarned ? Colors.green : Colors.orange,
            ),
          ),
          title: Text(tx.description,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${DateHelper.formatDate(tx.createdAt)}  •  ${DateHelper.formatTime(tx.createdAt)}',
            style:
                TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.isEarned ? '+' : '-'}${tx.points} pts',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: tx.isEarned
                        ? Colors.green
                        : Colors.orange),
              ),
              if (tx.isEarned)
                Text(
                  '≈ ${CurrencyFormatter.format(tx.points * 0.10)}',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[400]),
                ),
            ],
          ),
        ),
      );

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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final allCustomers = prov.customers
          .where((c) =>
              _search.isEmpty ||
              c.name
                  .toLowerCase()
                  .contains(_search.toLowerCase()))
          .toList();

      final activeCustomers = allCustomers.where((c) {
        final account = _getOrCreate(c.id);
        return account.availablePoints > 0;
      }).toList();

      final redeemedCustomers = allCustomers.where((c) {
        final account = _getOrCreate(c.id);
        return account.redeemedPoints > 0;
      }).toList();

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 16,
          title: const Text('Loyalty Points',
              style: TextStyle(
                  fontSize: 25, fontWeight: FontWeight.bold)),
        ),
        body: Column(children: [

          // ── Gradient Header ──────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF388E3C),
                  Color(0xFF43A047),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Stack(children: [
              ...[
                [20.0, 10.0], [280.0, 8.0], [50.0, 55.0],
                [310.0, 40.0], [150.0, 5.0],
              ].map((pos) => Positioned(
                left: pos[0], top: pos[1],
                child: Container(
                  width: 3, height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              )),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(children: [
                  Row(children: [
                    Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      const Text(
                          '1 point bawat ₱10 na benta',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(
                          '₱0.10 ang halaga ng bawat point',
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
                        color: Colors.white
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white
                                .withValues(alpha: 0.2)),
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
                  const SizedBox(height: 14),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Hanapin ang customer...',
                        hintStyle: TextStyle(
                            color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey[400]),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                vertical: 0),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // ── Tabs ─────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFF2E7D32),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2E7D32),
              tabs: [
                Tab(
                  child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.star_outline, size: 14),
                    const SizedBox(width: 4),
                    Text(
                        'May Points (${activeCustomers.length})'),
                  ]),
                ),
                Tab(
                  child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.redeem_outlined,
                        size: 14),
                    const SizedBox(width: 4),
                    Text(
                        'Nakapag-redeem (${redeemedCustomers.length})'),
                  ]),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildCustomerList(
                          activeCustomers, prov,
                          emptyMsg:
                              'Walang customer na may points'),
                      _buildCustomerList(
                          redeemedCustomers, prov,
                          emptyMsg:
                              'Wala pang nakapag-redeem'),
                    ],
                  ),
          ),
        ]),
      );
    });
  }

  Widget _buildCustomerList(
      List<Customer> customers, AppProvider prov,
      {required String emptyMsg}) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.people_outline,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(emptyMsg,
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 16)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: customers.length,
      itemBuilder: (_, i) {
        final c = customers[i];
        final account = _getOrCreate(c.id);
        final hasPoints = account.availablePoints > 0;

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
            onTap: () => _showCustomerLoyalty(c),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: hasPoints
                  ? const Color(0xFF2E7D32)
                      .withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              child: Text(c.name[0].toUpperCase(),
                  style: TextStyle(
                      color: hasPoints
                          ? const Color(0xFF2E7D32)
                          : Colors.orange,
                      fontWeight: FontWeight.bold)),
            ),
            title: Text(c.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            subtitle: Text(
              c.phone ?? 'Walang numero',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${account.availablePoints} pts',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasPoints
                          ? const Color(0xFF2E7D32)
                          : Colors.grey),
                ),
                if (account.redeemedPoints > 0)
                  Text(
                    '${account.redeemedPoints} redeemed',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.orange),
                  )
                else
                  Text(
                    CurrencyFormatter.format(
                        account.pesoValue),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.blue),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Redeem Sheet ──────────────────────────────────────────────
class _RedeemSheet extends StatefulWidget {
  final Customer customer;
  final LoyaltyAccount account;
  final AppProvider prov;
  final void Function(String type, int points, Product? product)
      onRedeem;

  const _RedeemSheet({
    required this.customer,
    required this.account,
    required this.prov,
    required this.onRedeem,
  });

  @override
  State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> {
  String _redeemType = 'discount';
  final _discountCtrl = TextEditingController();
  Product? _selectedProduct;
  int _freeItemPoints = 0;

  @override
  void initState() {
    super.initState();
    // Hindi auto-select sa initState — gagawin lang kapag pumili ng 'item'
  }

  // Auto-select pinaka-mura na produkto na kaya ng points
  void _autoSelectProduct() {
    final affordable = widget.prov.products
        .where((p) =>
            !p.isOutOfStock &&
            _pointsNeeded(p.sellPrice) <=
                widget.account.availablePoints)
        .toList();
    if (affordable.isEmpty) return;
    affordable.sort((a, b) =>
        _pointsNeeded(a.sellPrice)
            .compareTo(_pointsNeeded(b.sellPrice)));
    _selectedProduct = affordable.first;
    _freeItemPoints = _pointsNeeded(_selectedProduct!.sellPrice);
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  int _pointsNeeded(double price) => (price * 10).ceil();

  String _emoji(String category) {
    const map = {
      'Pagkain': '🍚', 'Inumin': '🥤', 'Meryenda': '🍟',
      'Panglinis': '🧹', 'Personal Care': '🧴',
      'Sigarilyo': '🚬', 'Alkohol': '🍺',
      'Gamot': '💊', 'Pang-bahay': '🏠', 'Iba Pa': '📦',
    };
    return map[category] ?? '📦';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (_, ctrl) => Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32)
                  .withValues(alpha: 0.12),
              radius: 20,
              child: Text(
                  widget.customer.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(widget.customer.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(
                  '${widget.account.availablePoints} pts  •  ${CurrencyFormatter.format(widget.account.pesoValue)}',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),

        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Piliin ang uri ng reward:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 12),

              // ── Option A: Peso Discount ────────────────
              GestureDetector(
                onTap: () => setState(() {
                  _redeemType = 'item';
                  // Auto-select kapag pumili ng item
                  _autoSelectProduct();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _redeemType == 'discount'
                        ? const Color(0xFF2E7D32)
                            .withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _redeemType == 'discount'
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade200,
                      width:
                          _redeemType == 'discount' ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32)
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.discount_outlined,
                          color: Color(0xFF2E7D32),
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        const Text('Peso Discount',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text('100 pts = ₱10 discount',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12)),
                      ]),
                    ),
                    if (_redeemType == 'discount')
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2E7D32),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                  ]),
                ),
              ),

              if (_redeemType == 'discount') ...[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                    controller: _discountCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText:
                          'Bilang ng Points (max ${widget.account.availablePoints})',
                      prefixIcon: const Icon(
                          Icons.star_outline,
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
                if (_discountCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32)
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.discount_outlined,
                          color: Color(0xFF2E7D32), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_discountCtrl.text} pts = ₱${((int.tryParse(_discountCtrl.text) ?? 0) * 0.10).toStringAsFixed(2)} discount',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ]),
                  ),
                ],
              ],

              const SizedBox(height: 10),

              // ── Option B: Free Item ───────────────────
              GestureDetector(
                onTap: () =>
                    setState(() => _redeemType = 'item'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _redeemType == 'item'
                        ? Colors.orange
                            .withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _redeemType == 'item'
                          ? Colors.orange
                          : Colors.grey.shade200,
                      width: _redeemType == 'item' ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.card_giftcard_outlined,
                          color: Colors.orange,
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        const Text('Libreng Produkto',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text(
                            'I-redeem ang points para sa libre na produkto',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12)),
                      ]),
                    ),
                    if (_redeemType == 'item')
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                  ]),
                ),
              ),

              // Product list — auto-selected ang pinaka-mura
              if (_redeemType == 'item') ...[
                const SizedBox(height: 10),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange
                            .withValues(alpha: 0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.auto_awesome_outlined,
                        color: Colors.orange, size: 14),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Auto-selected ang pinaka-mura na produkto. Pwede pa ring palitan.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),

                // Products
                ...widget.prov.products
                    .where((p) =>
                        !p.isOutOfStock &&
                        _pointsNeeded(p.sellPrice) <=
                            widget.account.availablePoints)
                    .map((p) {
                  final needed = _pointsNeeded(p.sellPrice);
                  final isSel = _selectedProduct?.id == p.id;
                  final isAutoSelected =
                      isSel && _selectedProduct != null;

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedProduct = p;
                      _freeItemPoints = needed;
                    }),
                    child: Container(
                      margin:
                          const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Colors.orange
                                .withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel
                              ? Colors.orange
                              : Colors.grey.shade200,
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orange
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Center(
                              child: Text(
                                  _emoji(p.category),
                                  style: const TextStyle(
                                      fontSize: 18))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                child: Text(p.name,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 13)),
                              ),
                              if (isSel)
                                Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 6,
                                      vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(
                                            6),
                                  ),
                                  child: const Text(
                                    'AUTO',
                                    style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 9,
                                        fontWeight:
                                            FontWeight.bold),
                                  ),
                                ),
                            ]),
                            Text(
                                CurrencyFormatter.format(
                                    p.sellPrice),
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.orange
                                : Colors.orange
                                    .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text('$needed pts',
                              style: TextStyle(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                      ]),
                    ),
                  );
                }),
                if (widget.prov.products
                    .where((p) =>
                        !p.isOutOfStock &&
                        _pointsNeeded(p.sellPrice) <=
                            widget.account.availablePoints)
                    .isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Walang produkto na kaya ng points.',
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 20),

              // ── Confirm Button ────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_redeemType == 'discount') {
                      final pts = int.tryParse(
                              _discountCtrl.text) ??
                          0;
                      if (pts <= 0) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                                content: Text(
                                    'Ilagay ang bilang ng points!'),
                                backgroundColor: Colors.red));
                        return;
                      }
                      if (pts >
                          widget.account.availablePoints) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                                content: Text(
                                    'Hindi sapat ang points!'),
                                backgroundColor: Colors.red));
                        return;
                      }
                      Navigator.pop(context);
                      widget.onRedeem('discount', pts, null);
                    } else {
                      if (_selectedProduct == null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                                content: Text(
                                    'Pumili ng produkto!'),
                                backgroundColor: Colors.red));
                        return;
                      }
                      Navigator.pop(context);
                      widget.onRedeem('item', _freeItemPoints,
                          _selectedProduct);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _redeemType == 'discount'
                            ? const Color(0xFF2E7D32)
                            : Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                  ),
                  child: Text(
                    _redeemType == 'discount'
                        ? 'I-redeem bilang Discount'
                        : _selectedProduct != null
                            ? 'I-redeem — Libreng ${_selectedProduct!.name}'
                            : 'I-redeem bilang Libreng Item',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ]),
    );
  }
}