import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/installment.dart';
import '../models/customer.dart';
import '../providers/app_provider.dart';
import '../services/installment_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/help_sheet.dart';
import '../widgets/search_field.dart';

const _uuid = Uuid();
const _blue = AppColors.blue;

class InstallmentScreen extends StatefulWidget {
  const InstallmentScreen({super.key});
  @override
  State<InstallmentScreen> createState() => _InstallmentScreenState();
}

class _InstallmentScreenState extends State<InstallmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Installment> _installments = [];
  bool _loading = true;
  bool _payInFlight = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Installment> _applySearch(List<Installment> list) {
    if (_search.isEmpty) return list;
    final q = _search.toLowerCase();
    return list
        .where((i) =>
            i.customerName.toLowerCase().contains(q) ||
            i.itemDescription.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _installments = await InstallmentService.instance.getAll();
    setState(() => _loading = false);
  }

  /// The rounded monthly amount, except on the final month where it's
  /// the exact remaining balance — so centavo rounding drift across the
  /// earlier months never leaves the plan over- or under-collected.
  double _nextPaymentAmount(Installment inst) =>
      inst.paidMonths + 1 >= inst.totalMonths
          ? CurrencyFormatter.roundCents(inst.remainingBalance)
          : inst.monthlyPayment;

  List<Installment> get _ongoing => _installments
      .where((i) => i.status == InstallmentStatus.ongoing)
      .toList();
  List<Installment> get _completed => _installments
      .where((i) => i.status == InstallmentStatus.completed)
      .toList();
  List<Installment> get _overdue => _ongoing.where((i) => i.isOverdue).toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final ongoing = _applySearch(_ongoing);
      final overdue = _applySearch(_overdue);
      final completed = _applySearch(_completed);
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Installment',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          actions: const [
            HelpIconButton(
              title: 'Installment Plans (Hulugan)',
              points: [
                'Use this for big-ticket items a customer pays off over time — record the item, a down payment, and the monthly term.',
                "Each plan tracks progress automatically as you record payments, so you always know what's left to collect.",
                "Overdue plans are flagged here so nothing slips through — check in with those customers first.",
                "This is separate from the Credit Ledger's utang tracking, which is for everyday small purchases on credit rather than a fixed payment schedule.",
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('Manage payment plans',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                hintText: 'Search customer or item...',
              ),
            ),
            const SizedBox(height: 8),

            // ── Tab Bar ────────────────────────────
            Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: _blue,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: _blue,
                indicatorWeight: 2,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: [
                  Tab(text: 'Ongoing (${ongoing.length})'),
                  Tab(text: 'Overdue (${overdue.length})'),
                  Tab(text: 'Completed (${completed.length})'),
                ],
              ),
            ),

            // ── Tab Content ────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _buildList(ongoing, prov),
                        _buildList(overdue, prov),
                        _buildList(completed, prov),
                      ],
                    ),
            ),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'installment_fab',
          onPressed: () => _showAddForm(prov),
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Installment',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    });
  }

  Widget _buildList(List<Installment> list, AppProvider prov) {
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset(
            'assets/mascot/storeph_mascot_neutral_idle.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.credit_score_outlined,
                size: 48, color: Colors.grey[300]),
          ),
          const SizedBox(height: 12),
          Text('No installments yet',
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final inst = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inst.isOverdue
                  ? Colors.red.shade200
                  : inst.isCompleted
                      ? Colors.green.shade100
                      : _blue.withValues(alpha: 0.15),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: inst.isCompleted
                        ? Colors.green.shade50
                        : inst.isOverdue
                            ? Colors.red.shade50
                            : _blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    inst.isCompleted
                        ? Icons.check_circle_outline
                        : Icons.credit_score_outlined,
                    color: inst.isCompleted
                        ? Colors.green
                        : inst.isOverdue
                            ? Colors.red
                            : _blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inst.itemDescription,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.black87)),
                        Text(inst.customerName,
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ]),
                ),
                if (inst.isOverdue)
                  _statusBadge('Overdue', Colors.red)
                else if (inst.isCompleted)
                  _statusBadge('Paid', Colors.green),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert_outlined,
                      size: 18, color: Colors.grey[400]),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.red, fontSize: 13)),
                      ]),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'delete') {
                      _confirmDelete(inst, prov);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: inst.progressPercent,
                  backgroundColor: Colors.grey.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                      inst.isCompleted ? Colors.green : _blue),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),

              Row(children: [
                Text('${inst.paidMonths}/${inst.totalMonths} months',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const Spacer(),
                Text(
                    'Balance: ${CurrencyFormatter.format(inst.remainingBalance)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(
                    'Monthly: ${CurrencyFormatter.format(inst.monthlyPayment)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const Spacer(),
                Text('Due: ${DateHelper.formatDate(inst.nextDueDate)}',
                    style: TextStyle(
                        color: inst.isOverdue ? Colors.red : Colors.grey[500],
                        fontSize: 11,
                        fontWeight: inst.isOverdue
                            ? FontWeight.w600
                            : FontWeight.normal)),
              ]),

              if (!inst.isCompleted) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showPayment(inst, prov),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                        'Pay — ${CurrencyFormatter.format(_nextPaymentAmount(inst))}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: color.withValues(alpha: 0.3), width: 0.5)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  void _showAddForm(AppProvider prov) {
    Customer? selectedCustomer;
    final nameCtrl = TextEditingController();
    final Map<Product, int> selectedProducts = {};
    final downCtrl = TextEditingController();
    int selectedMonths = 3;
    DateTime startDate = DateTime.now();
    // Guards the Save button against a rapid double-tap while the async
    // save chain (stock decrement + installment record) is in flight,
    // which would otherwise create two installment plans and take the
    // stock twice.
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final totalAmount = CurrencyFormatter.roundCents(selectedProducts
              .entries
              .fold(0.0, (s, e) => s + e.key.sellPrice * e.value));
          final down = double.tryParse(downCtrl.text) ?? 0;
          final monthly = selectedMonths > 0
              ? CurrencyFormatter.roundCents(
                  (totalAmount - down) / selectedMonths)
              : 0.0;

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Text('New Installment',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 16),

                // Step 1
                _stepLabel('1', 'Customer'),
                const SizedBox(height: 8),
                if (prov.customers.isNotEmpty) ...[
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: prov.customers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final c = prov.customers[i];
                        final sel = selectedCustomer?.id == c.id;
                        return GestureDetector(
                          onTap: () => setS(() {
                            if (sel) {
                              selectedCustomer = null;
                              nameCtrl.clear();
                            } else {
                              selectedCustomer = c;
                              nameCtrl.text = c.name;
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel ? _blue : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(c.name,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color:
                                        sel ? Colors.white : Colors.grey[700])),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or type',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                  ]),
                  const SizedBox(height: 8),
                ],
                _field(nameCtrl, 'Customer name *', Icons.person_outlined,
                    onChanged: (_) => setS(() => selectedCustomer = null)),
                const SizedBox(height: 20),

                // Step 2
                _stepLabel('2', 'Products'),
                const SizedBox(height: 8),
                if (selectedProducts.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: selectedProducts.entries
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  Expanded(
                                    child: Text(e.key.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87)),
                                  ),
                                  GestureDetector(
                                    onTap: () => setS(() {
                                      if (e.value <= 1) {
                                        selectedProducts.remove(e.key);
                                      } else {
                                        selectedProducts[e.key] = e.value - 1;
                                      }
                                    }),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: const Icon(Icons.remove,
                                          size: 14, color: Colors.grey),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Text('${e.value}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ),
                                  GestureDetector(
                                    // Same stock cap as the product picker
                                    // sheet — without it this stepper could
                                    // sell more units than exist, silently
                                    // corrupting the inventory count.
                                    onTap: e.value >= e.key.stock
                                        ? null
                                        : () => setS(() =>
                                            selectedProducts[e.key] =
                                                e.value + 1),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                          color: e.value >= e.key.stock
                                              ? Colors.grey.shade300
                                              : _blue,
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: const Icon(Icons.add,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    CurrencyFormatter.format(
                                        e.key.sellPrice * e.value),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Colors.black87),
                                  ),
                                ]),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: ctx,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (_) => StatefulBuilder(
                        builder: (pCtx, pSetS) {
                          String search = '';
                          return StatefulBuilder(
                            builder: (_, sSetS) => DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.75,
                              builder: (_, ctrl) => Column(children: [
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(2)),
                                ),
                                const Text('Select Products',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87)),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: TextField(
                                    onChanged: (v) => sSetS(() => search = v),
                                    decoration: InputDecoration(
                                      hintText: 'Search products...',
                                      hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13),
                                      prefixIcon: Icon(Icons.search_outlined,
                                          color: Colors.grey[400], size: 18),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide.none),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 0),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView(
                                    controller: ctrl,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    children: prov.products
                                        .where((p) =>
                                            !p.isOutOfStock &&
                                            (search.isEmpty ||
                                                p.name.toLowerCase().contains(
                                                    search.toLowerCase())))
                                        .map((p) {
                                      final qty = selectedProducts[p] ?? 0;
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: qty > 0
                                              ? _blue.withValues(alpha: 0.05)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: qty > 0
                                                  ? _blue.withValues(alpha: 0.2)
                                                  : Colors.grey.shade200),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4),
                                              title: Text(p.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Colors.black87)),
                                              subtitle: Text(
                                                  CurrencyFormatter.format(
                                                      p.sellPrice),
                                                  style: const TextStyle(
                                                      color: _blue,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12)),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (qty > 0) ...[
                                                    GestureDetector(
                                                      onTap: () {
                                                        pSetS(() {
                                                          sSetS(() {
                                                            setS(() {
                                                              if (qty <= 1) {
                                                                selectedProducts
                                                                    .remove(p);
                                                              } else {
                                                                selectedProducts[
                                                                        p] =
                                                                    qty - 1;
                                                              }
                                                            });
                                                          });
                                                        });
                                                      },
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                            color: Colors
                                                                .grey.shade100,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6)),
                                                        child: const Icon(
                                                            Icons.remove,
                                                            size: 14,
                                                            color: Colors.grey),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8),
                                                      child: Text('$qty',
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      14)),
                                                    ),
                                                  ],
                                                  GestureDetector(
                                                    onTap: qty >= p.stock
                                                        ? null
                                                        : () {
                                                            pSetS(() {
                                                              sSetS(() {
                                                                setS(() {
                                                                  selectedProducts[
                                                                          p] =
                                                                      qty + 1;
                                                                });
                                                              });
                                                            });
                                                          },
                                                    child: Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                          color: qty >= p.stock
                                                              ? Colors
                                                                  .grey.shade300
                                                              : _blue,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6)),
                                                      child: const Icon(
                                                          Icons.add,
                                                          size: 14,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(pCtx),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _blue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      minimumSize:
                                          const Size(double.infinity, 46),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: Text(
                                        selectedProducts.isEmpty
                                            ? 'Back'
                                            : 'Done (${selectedProducts.length} product${selectedProducts.length != 1 ? 's' : ''})',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedProducts.isEmpty
                              ? Icons.add_shopping_cart_outlined
                              : Icons.edit_outlined,
                          color: _blue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedProducts.isEmpty
                              ? 'Select Products'
                              : 'Edit Products',
                          style: const TextStyle(
                              color: _blue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Step 3
                _stepLabel('3', 'Payment Details'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setS(() => startDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                      Text('Start Date: ',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[700])),
                      Text(DateHelper.formatDate(startDate),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const Spacer(),
                      Icon(Icons.edit_calendar_outlined,
                          size: 16, color: Colors.grey[400]),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: totalAmount > 0
                        ? _blue.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: totalAmount > 0
                            ? _blue.withValues(alpha: 0.2)
                            : Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Text('Total Amount:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.grey[700])),
                    const Spacer(),
                    Text(
                      totalAmount > 0
                          ? CurrencyFormatter.format(totalAmount)
                          : '—',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: totalAmount > 0 ? _blue : Colors.grey),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                _fieldNum(downCtrl, 'Down payment (optional)', '₱',
                    onChanged: (_) => setS(() {})),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: selectedMonths,
                  decoration: InputDecoration(
                    labelText: 'Number of months',
                    labelStyle:
                        TextStyle(color: Colors.grey[600], fontSize: 13),
                    prefixIcon: Icon(Icons.calendar_month_outlined,
                        size: 18, color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1} month${i > 0 ? 's' : ''}',
                                style: const TextStyle(fontSize: 13)),
                          )),
                  onChanged: (v) => setS(() => selectedMonths = v!),
                ),
                const SizedBox(height: 10),
                if (totalAmount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Text('Monthly payment:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontSize: 13)),
                      const Spacer(),
                      Text(CurrencyFormatter.format(monthly < 0 ? 0 : monthly),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: _blue)),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final customerName =
                                selectedCustomer?.name ?? nameCtrl.text.trim();
                            if (customerName.isEmpty) {
                              CenterToast.showError(
                                  context, 'Customer name required.');
                              return;
                            }
                            if (selectedProducts.isEmpty) {
                              CenterToast.showError(
                                  context, 'Select at least one product.');
                              return;
                            }
                            if (totalAmount <= 0) {
                              CenterToast.showError(
                                  context, 'Total cannot be zero.');
                              return;
                            }
                            final down = double.tryParse(downCtrl.text) ?? 0;
                            if (down < 0) {
                              CenterToast.showError(
                                  context, 'Down payment cannot be negative.');
                              return;
                            }
                            if (down >= totalAmount) {
                              CenterToast.showError(
                                  context, 'Down payment cannot exceed total.');
                              return;
                            }
                            setS(() => isSubmitting = true);
                            String customerId;
                            if (selectedCustomer != null) {
                              customerId = selectedCustomer!.id;
                            } else {
                              final existing = prov.customers
                                  .where((c) =>
                                      c.name.toLowerCase() ==
                                      customerName.toLowerCase())
                                  .firstOrNull;
                              if (existing != null) {
                                customerId = existing.id;
                              } else {
                                final newCustomer =
                                    await prov.addCustomer(customerName);
                                customerId = newCustomer.id;
                              }
                            }
                            final itemDesc = selectedProducts.entries
                                .map((e) => '${e.key.name} x${e.value}')
                                .join(', ');
                            final mon = selectedMonths > 0
                                ? CurrencyFormatter.roundCents(
                                    (totalAmount - down) / selectedMonths)
                                : 0.0;
                            // Records the actual sale (stock decrement, revenue,
                            // profit) now — the goods leave the shelf today even
                            // though the customer pays it off over time.
                            String saleId;
                            try {
                              saleId = await prov.recordInstallmentSale(
                                items: selectedProducts,
                                customerId: customerId,
                                customerName: customerName,
                                totalAmount: totalAmount,
                                downPayment: down,
                              );
                            } on InsufficientStockException catch (e) {
                              setS(() => isSubmitting = false);
                              if (mounted) CenterToast.showError(context, '$e');
                              return;
                            }
                            final installment = Installment(
                              id: _uuid.v4(),
                              customerId: customerId,
                              customerName: customerName,
                              itemDescription: itemDesc,
                              totalAmount: totalAmount,
                              downPayment: down,
                              monthlyPayment: mon,
                              totalMonths: selectedMonths,
                              paidMonths: 0,
                              totalPaid: down,
                              status: InstallmentStatus.ongoing,
                              startDate: startDate,
                              nextDueDate:
                                  startDate.add(const Duration(days: 30)),
                              saleId: saleId,
                            );
                            await InstallmentService.instance.save(installment);
                            // recordInstallmentSale above already reloaded
                            // AppProvider, but before this plan existed —
                            // reload again now so its balance is visible
                            // to the credit-limit check immediately.
                            await prov.reload();
                            await _load();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              CenterToast.showSuccess(
                                  context, 'Installment saved!');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor: _blue.withValues(alpha: 0.5),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Installment',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _stepLabel(String num, String label) => Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
          child: Center(
            child: Text(num,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87)),
      ]);

  Widget _field(TextEditingController ctrl, String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text,
          void Function(String)? onChanged}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      );

  Widget _fieldNum(TextEditingController ctrl, String label, String prefix,
          {void Function(String)? onChanged}) =>
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixText: '$prefix ',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      );

  void _showPayment(Installment inst, AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Accept Payment',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inst.itemDescription,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87)),
              Text(inst.customerName,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 10),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 6),
              _row('Monthly:', CurrencyFormatter.format(inst.monthlyPayment)),
              _row('Paid:', CurrencyFormatter.format(inst.totalPaid)),
              _row('Balance:', CurrencyFormatter.format(inst.remainingBalance)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: inst.progressPercent,
                  backgroundColor: Colors.grey.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(_blue),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text('${inst.paidMonths}/${inst.totalMonths} months',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () async {
              if (_payInFlight) return;
              _payInFlight = true;
              try {
                final payAmount = _nextPaymentAmount(inst);
                final newPaid =
                    CurrencyFormatter.roundCents(inst.totalPaid + payAmount);
                final newMonths = inst.paidMonths + 1;
                final isComplete = newMonths >= inst.totalMonths;
                final updated = inst.copyWith(
                  paidMonths: newMonths,
                  totalPaid: newPaid,
                  status: isComplete
                      ? InstallmentStatus.completed
                      : InstallmentStatus.ongoing,
                  // Extend from the *original* due date, not from today —
                  // resetting the clock on a late payment would reward
                  // lateness by pushing the whole schedule back every time.
                  nextDueDate: isComplete
                      ? inst.nextDueDate
                      : inst.nextDueDate.add(const Duration(days: 30)),
                );
                await InstallmentService.instance.save(updated);
                // AppProvider caches installments separately (see
                // _loadAll) for the credit-limit check and the dashboard's
                // debt total — without this they'd keep showing the
                // pre-payment balance until something else reloads it.
                await prov.reload();
                await _load();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isComplete
                        ? 'Installment fully paid!'
                        : 'Payment accepted!'),
                    backgroundColor: isComplete ? Colors.green : _blue,
                  ));
                }
              } finally {
                _payInFlight = false;
              }
            },
            child: Text(
                'Pay ${CurrencyFormatter.format(_nextPaymentAmount(inst))}',
                style: const TextStyle(
                    color: _blue, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Installment inst, AppProvider prov) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Installment?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inst.itemDescription,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87)),
              Text('Customer: ${inst.customerName}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 6),
              Text('Total: ${CurrencyFormatter.format(inst.totalAmount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Text('This cannot be undone.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Give back the stock this plan took, unless it's already fully
      // paid off — those goods were legitimately sold. Looked up by id
      // straight from the DB: the provider's in-memory list only holds
      // recent sales, so an old plan's sale may not be in it.
      if (inst.status != InstallmentStatus.completed && inst.saleId != null) {
        final error = await prov.voidSaleById(inst.saleId!);
        if (error != null) {
          // voidSaleById refused (e.g. monthly payments already collected
          // on this plan) — deleting the Installment now would destroy the
          // only record of that money without ever reversing the sale, so
          // stop here instead of deleting anything.
          if (mounted) CenterToast.showError(context, error);
          return;
        }
      }
      await InstallmentService.instance.delete(inst.id);
      // Keeps AppProvider's installments cache (credit-limit check,
      // dashboard debt total) from still counting this plan's balance.
      await prov.reload();
      await _load();
      if (mounted) {
        CenterToast.showError(context, 'Installment deleted.');
      }
    }
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87,
                  fontSize: 12)),
        ]),
      );
}
