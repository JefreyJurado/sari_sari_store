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
import 'capital_screen.dart';
import 'daily_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sales_history_screen.dart';


const _brandBlue = Color(0xFF1E3A8A);
const _brandGreen = Color(0xFF059669);
const _brandOrange = Color(0xFFEA580C);
const _brandPurple = Color(0xFF7C3AED);

class CrossFadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  CrossFadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              child,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration:
              const Duration(milliseconds: 220),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeOutCubic;
            final slideAnim = Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: curve));

            return SlideTransition(
              position: slideAnim,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: curve),
                child: child,
              ),
            );
          },
        );
}

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
      setState(
          () => _userName = prefs.getString('user_name') ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer<AppProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    _brandBlue),
                strokeWidth: 3,
              ),
            );
          }

          final cashSales = prov.sales
              .where((s) =>
                  s.status == TxStatus.completed &&
                  s.type != PaymentType.credit)
              .toList();

          final customersWithDebt =
              prov.customers.where((c) {
            final unpaid = prov
                .debtsFor(c.id)
                .where((d) => d.status != DebtStatus.paid)
                .toList();
            return unpaid.isNotEmpty;
          }).toList();

          return RefreshIndicator(
            onRefresh: prov.reload,
            color: _brandBlue,
            backgroundColor: Colors.white,
            edgeOffset: topPadding + 50,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ──────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.only(
                      top: topPadding + 12,
                      bottom: 16,
                      left: 20,
                      right: 8,
                    ),
                    child: Row(children: [
                      const Text(
                        'StorePH',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: _brandBlue),
                      ),
                      const Spacer(),
                      _appBarButton(
                        icon: Icons.receipt_long_rounded,
                        tooltip: 'Expenses',
                        onPressed: () => Navigator.push(
                            context,
                            CrossFadePageRoute(
                                child:
                                    const ExpensesScreen())),
                      ),
                      _appBarButton(
                        icon: Icons.cloud_upload_rounded,
                        tooltip: 'Backup',
                        onPressed: () => Navigator.push(
                            context,
                            CrossFadePageRoute(
                                child:
                                    const BackupScreen())),
                      ),
                      _appBarButton(
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        onPressed: () => Navigator.push(
                            context,
                            CrossFadePageRoute(
                                child:
                                    const SettingsScreen())),
                      ),
                    ]),
                  ),

                  // ── Main Content ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        // ── Greeting ─────────────────────
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateHelper.todayFormatted()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w700,
                                      letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userName.isEmpty
                                      ? 'Good ${DateHelper.greeting()}'
                                      : 'Good ${DateHelper.greeting()}, $_userName',
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 22,
                                      fontWeight:
                                          FontWeight.w800,
                                      letterSpacing: -0.5),
                                ),
                              ],
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                                border: Border.all(
                                    color:
                                        Colors.grey.shade200),
                              ),
                              child: const Row(children: [
                                Icon(
                                    Icons.storefront_rounded,
                                    size: 14,
                                    color: _brandBlue),
                                SizedBox(width: 6),
                                Text('Live Store',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                        fontWeight:
                                            FontWeight.w700)),
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Stats ─────────────────────────
                        Row(children: [
                          _statCard(
                            "Today's Sales",
                            CurrencyFormatter.format(
                                prov.todayRevenue),
                            Icons.analytics_rounded,
                            accentColor: _brandGreen,
                            onTap: () => Navigator.push(
                                context,
                                CrossFadePageRoute(
                                    child: const SalesHistoryScreen())),
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            "Today's Profit",
                            CurrencyFormatter.format(
                                prov.todayProfit),
                            Icons.trending_up_rounded,
                            accentColor: const Color(0xFF10B981),
                            onTap: () => Navigator.push(
                                context,
                                CrossFadePageRoute(
                                    child: const DailySummaryScreen())),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          _statCard(
                            'Transactions',
                            prov.todaySales.length.toString(),
                            Icons.receipt_rounded,
                            accentColor: _brandPurple,
                            onTap: () => Navigator.push(
                                context,
                                CrossFadePageRoute(
                                    child: const SalesHistoryScreen())),
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            'Total Credit',
                            CurrencyFormatter.format(
                                prov.totalUnpaidDebt),
                            Icons.account_balance_wallet_rounded,
                            accentColor: _brandOrange,
                            isAlert:
                                prov.totalUnpaidDebt > 0,
                            onTap: () => Navigator.push(
                                context,
                                CrossFadePageRoute(
                                    child: const ListaScreen())),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // ── Capital Overview ──────────────
                        if (prov.capital != null) ...[
                          _CapitalCard(prov: prov),
                          const SizedBox(height: 16),
                        ] else ...[
                          _SetupCapitalBanner(
                              onTap: () => Navigator.push(
                                  context,
                                  CrossFadePageRoute(
                                      child: const CapitalScreen()))),
                          const SizedBox(height: 16),
                        ],

                        // ── Quick Actions ─────────────────
                        _sectionHeader(
                            title: 'Quick Actions'),
                        const SizedBox(height: 10),
                        const QuickActionButtons(),
                        const SizedBox(height: 20),

                        // ── Alerts ────────────────────────
                        if (prov.outOfStock.isNotEmpty ||
                            prov.lowStock.isNotEmpty) ...[
                          _sectionHeader(
                              title: 'Critical Alerts'),
                          const SizedBox(height: 12),
                          if (prov.outOfStock.isNotEmpty)
                            _alertCard(
                              'Out of Stock',
                              prov.outOfStock
                                  .map((p) => p.name)
                                  .take(3)
                                  .join(', '),
                              Colors.red.shade600,
                              Icons.cancel_rounded,
                            ),
                          if (prov.lowStock.isNotEmpty)
                            _alertCard(
                              'Low Stock Warning',
                              prov.lowStock
                                  .map((p) =>
                                      '${p.name} (${p.stock})')
                                  .take(3)
                                  .join(', '),
                              Colors.amber.shade700,
                              Icons.error_rounded,
                            ),
                          const SizedBox(height: 24),
                        ],

                        // ── Credit ────────────────────────
                        _sectionHeader(
                          title: 'Credit Accounts',
                          trailingText: 'View Register',
                          onTrailingTap: () => Navigator.push(
                              context,
                              CrossFadePageRoute(
                                  child:
                                      const ListaScreen())),
                        ),
                        const SizedBox(height: 12),

                        if (customersWithDebt.isEmpty)
                          _emptyCard(
                              prov.customers.isEmpty
                                  ? 'No registered customer database found.'
                                  : 'All customer accounts fully settled.',
                              prov.customers.isEmpty
                                  ? Icons
                                      .people_outline_rounded
                                  : Icons.verified_rounded)
                        else
                          ...customersWithDebt.take(5).map(
                            (c) {
                              final unpaidDebts = prov
                                  .debtsFor(c.id)
                                  .where((d) =>
                                      d.status !=
                                      DebtStatus.paid)
                                  .toList();
                              final totalOwed =
                                  unpaidDebts.fold(
                                      0.0,
                                      (s, d) =>
                                          s + d.remaining);
                              final hasOverdue = unpaidDebts
                                  .any((d) => d.isOverdue);

                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(
                                          14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(
                                              alpha: 0.02),
                                      blurRadius: 8,
                                      offset:
                                          const Offset(0, 4),
                                    )
                                  ],
                                  border: Border.all(
                                      color: hasOverdue
                                          ? Colors.red.shade100
                                          : Colors
                                              .grey.shade200),
                                ),
                                child: ListTile(
                                  onTap: () =>
                                      _showDebtDetails(
                                          context,
                                          c,
                                          unpaidDebts,
                                          prov),
                                  contentPadding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal: 16,
                                          vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: hasOverdue
                                        ? Colors.red.shade50
                                        : const Color(
                                            0xFFF1F5F9),
                                    child: Text(
                                      c.name[0].toUpperCase(),
                                      style: TextStyle(
                                        color: hasOverdue
                                            ? Colors
                                                .red.shade700
                                            : _brandBlue,
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  title: Row(children: [
                                    Expanded(
                                      child: Text(c.name,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                              fontSize: 15,
                                              color: Colors
                                                  .black87)),
                                    ),
                                    if (hasOverdue)
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal: 8,
                                                vertical: 3),
                                        decoration:
                                            BoxDecoration(
                                                color: Colors
                                                    .red
                                                    .shade50,
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            30),
                                                border: Border.all(
                                                    color: Colors
                                                        .red
                                                        .shade100)),
                                        child: Text('OVERDUE',
                                            style: TextStyle(
                                                color: Colors
                                                    .red
                                                    .shade700,
                                                fontSize: 9,
                                                fontWeight:
                                                    FontWeight
                                                        .w800,
                                                letterSpacing:
                                                    0.3)),
                                      ),
                                  ]),
                                  subtitle: Padding(
                                    padding:
                                        const EdgeInsets.only(
                                            top: 4),
                                    child: Text(
                                      '${unpaidDebts.length} outstanding receipt${unpaidDebts.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12),
                                    ),
                                  ),
                                  trailing: Text(
                                    CurrencyFormatter.format(
                                        totalOwed),
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.w800,
                                        color: hasOverdue
                                            ? Colors.red.shade700
                                            : Colors.black87,
                                        fontSize: 15),
                                  ),
                                ),
                              );
                            },
                          ),

                        if (customersWithDebt.length > 5)
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  CrossFadePageRoute(
                                      child: const ListaScreen())),
                              icon: const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: _brandBlue),
                              label: Text(
                                'See ${customersWithDebt.length - 5} more accounts',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: _brandBlue,
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // ── Recent Sales ──────────────────
                        _sectionHeader(
                          title: 'Recent Activity Log',
                          trailingText: 'View All',
                          onTrailingTap: () => Navigator.push(
                              context,
                              CrossFadePageRoute(
                                  child: const SalesHistoryScreen())),
                        ),
                        const SizedBox(height: 12),

                        if (cashSales.isEmpty)
                          _emptyCard(
                              'No finalized counter sales recorded today.',
                              Icons.receipt_long_rounded)
                        else
                          ...cashSales
                              .take(10)
                              .map((s) => _SaleTile(sale: s)),
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

  Widget _appBarButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon,
            color: Colors.blueGrey.shade700, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {bool isAlert = false,
      Color? accentColor,
      VoidCallback? onTap}) {
    final Color bg = isAlert
        ? Colors.red.shade600
        : (accentColor ?? _brandBlue);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Icon(icon, color: Colors.white, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
      {required String title,
      String? trailingText,
      VoidCallback? onTrailingTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
        if (trailingText != null && onTrailingTap != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailingText,
                style: const TextStyle(
                    fontSize: 13,
                    color: _brandBlue,
                    fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _emptyCard(String msg, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.grey.shade300, size: 28),
          const SizedBox(height: 8),
          Text(msg,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _alertCard(String title, String msg, Color color,
          IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(msg,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );

  void _showDebtDetails(BuildContext context, customer,
    List<Debt> debts, AppProvider prov) {
  final Map<String, Sale?> saleCache = {};
  for (final d in debts) {
    final sale = prov.sales
        .where((s) => s.id == d.saleId)
        .firstOrNull;
    saleCache[d.id] = sale;
  }
  final totalOwed = debts.fold(0.0, (s, d) => s + d.remaining);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetCtx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40, height: 5,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 8),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFF1F5F9),
              child: Text(
                  customer.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: _brandBlue,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87)),
                if (customer.phone != null)
                  Text(customer.phone,
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    CurrencyFormatter.format(totalOwed),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Colors.red.shade700)),
                const Text('total credit',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade200, height: 1),
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: debts.map((d) {
              final sale = saleCache[d.id];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: d.isOverdue
                          ? Colors.red.shade200
                          : Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        DateHelper.formatDate(d.createdAt),
                        style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (d.isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.red.shade100)),
                          child: Text('OVERDUE',
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3)),
                        ),
                    ]),
                    if (sale != null && sale.items.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ...sale.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${CurrencyFormatter.format(item.price)} × ${item.quantity}',
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.black87),
                              ),
                            ]),
                          )),
                      Divider(height: 20, color: Colors.grey.shade200),
                    ],
                    if (d.paidAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          const Text('Partial Payments Made:',
                              style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text(
                              CurrencyFormatter.format(d.paidAmount),
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ]),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Text('Net Due Balance',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                fontSize: 13)),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(d.remaining),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.black87),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            CrossFadePageRoute(
                                child: PaymentScreen(
                                    debt: d,
                                    customer: customer)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                            'Accept Settlement Payment',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    ),
  );
}

} // ← closing ng _HomeScreenState

// ── Capital Overview Card ──────────────────────────────────────
class _CapitalCard extends StatelessWidget {
  final AppProvider prov;
  const _CapitalCard({required this.prov});

  @override
  Widget build(BuildContext context) {
    final roi = prov.roiPercent;
    final isProfit = roi >= 0;
    final roiColor =
        isProfit ? Colors.green.shade600 : Colors.red.shade600;
    final roiBg =
        isProfit ? Colors.green.shade50 : Colors.red.shade50;
    final roiBorder =
        isProfit ? Colors.green.shade200 : Colors.red.shade200;

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.account_balance_outlined,
                size: 16, color: _brandBlue),
            const SizedBox(width: 8),
            const Text('Capital Overview',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: roiBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roiBorder),
              ),
              child: Text(
                '${isProfit ? '+' : ''}${roi.toStringAsFixed(1)}% ROI',
                style: TextStyle(
                    color: roiColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _miniStat(
                'Total Investment',
                CurrencyFormatter.format(
                    prov.totalInvestment),
                Colors.grey.shade600),
            _divider(),
            _miniStat(
                'Current Capital',
                CurrencyFormatter.format(
                    prov.currentCapital),
                _brandBlue),
            _divider(),
            _miniStat(
                isProfit ? 'Net Gain' : 'Net Loss',
                CurrencyFormatter.format(
                    prov.netGainLoss.abs()),
                roiColor),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Tap for breakdown',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 14, color: Colors.grey[400]),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _miniStat(
          String label, String value, Color color) =>
      Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: color),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _divider() => Container(
      width: 1,
      height: 32,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  void _showDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CapitalScreen()),
    );
  }

  Widget _perfRow(String label, String value, Color color,
          {bool bold = false}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: bold
                        ? FontWeight.w700
                        : FontWeight.w500))),
        Text(value,
            style: TextStyle(
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w600,
                fontSize: bold ? 14 : 12,
                color: bold ? color : Colors.black87)),
      ]);
}

// ── Setup Capital Banner ───────────────────────────────────────
class _SetupCapitalBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SetupCapitalBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _brandBlue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _brandBlue.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
                Icons.account_balance_outlined,
                color: _brandBlue, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set up Beginning Balance',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                Text(
                    'Track your ROI and capital growth from day one.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey)),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: _brandBlue.withValues(alpha: 0.5),
              size: 18),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showSaleDetails(context, sale),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isOnline
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
              isOnline
                  ? Icons.phone_android_rounded
                  : Icons.payments_rounded,
              size: 20,
              color: isOnline
                  ? Colors.blue[700]
                  : Colors.green[700]),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isOnline
                  ? 'Online Transfer'
                  : 'Counter Cash Sale',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.black87),
            ),
            Text(
              DateHelper.formatTime(sale.createdAt),
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${sale.items.length} product item${sale.items.length > 1 ? 's' : ''} • ${DateHelper.formatDate(sale.createdAt)}',
            style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500),
          ),
        ),
        trailing: Text(
          CurrencyFormatter.format(sale.totalAmount),
          style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
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
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.90,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin:
                const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 5,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    isOnline
                        ? Icons.phone_android_rounded
                        : Icons.payments_rounded,
                    color: isOnline
                        ? Colors.blue[700]
                        : Colors.green[700],
                    size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                      isOnline
                          ? 'Online Transfer Details'
                          : 'Counter Cash Sale',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  Text(
                      '${DateHelper.formatDate(sale.createdAt)}  •  ${DateHelper.formatTime(sale.createdAt)}',
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              Text(
                  CurrencyFormatter.format(
                      sale.totalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black87)),
            ]),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade200, height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                const Text('RECEIPT BREAKDOWN',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Colors.grey,
                        letterSpacing: 0.5)),
                const SizedBox(height: 14),
                ...sale.items.map((item) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(item.productName,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                      fontSize: 14,
                                      color:
                                          Colors.black87)),
                              const SizedBox(height: 2),
                              Text(
                                  '${CurrencyFormatter.format(item.price)} × ${item.quantity}',
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w500)),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                              item.subtotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black87),
                        ),
                      ]),
                    )),
                Divider(
                    color: Colors.grey.shade200,
                    height: 24),
                if (sale.cashPaid > sale.totalAmount) ...[
                  _row('Tendered Cash Amount',
                      CurrencyFormatter.format(
                          sale.cashPaid)),
                  _row(
                      'Change Handed Back',
                      CurrencyFormatter.format(
                          sale.change),
                      highlightValueColor:
                          Colors.green[700]),
                  const SizedBox(height: 6),
                ],
                if (isOnline && sale.notes != null) ...[
                  _row('Payment Memo Reference',
                      sale.notes!),
                  const SizedBox(height: 6),
                ],
                Row(children: [
                  const Text('Grand Total',
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(
                        sale.totalAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                        color: Colors.black87),
                  ),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        CrossFadePageRoute(
                            child:
                                ReceiptScreen(sale: sale)),
                      );
                    },
                    icon: const Icon(Icons.print_rounded,
                        size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade900,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                    label: const Text(
                        'Generate Full Audit Receipt',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
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

  Widget _row(String label, String value,
          {Color? highlightValueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: highlightValueColor ??
                    Colors.blueGrey.shade700),
          ),
        ]),
      );
}