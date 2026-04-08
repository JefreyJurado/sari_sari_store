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

const _uuid = Uuid();

class InstallmentScreen extends StatefulWidget {
  const InstallmentScreen({super.key});
  @override
  State<InstallmentScreen> createState() =>
      _InstallmentScreenState();
}

class _InstallmentScreenState extends State<InstallmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Installment> _installments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _installments = await InstallmentService.instance.getAll();
    setState(() => _loading = false);
  }

  List<Installment> get _ongoing => _installments
      .where((i) => i.status == InstallmentStatus.ongoing)
      .toList();
  List<Installment> get _completed => _installments
      .where((i) => i.status == InstallmentStatus.completed)
      .toList();
  List<Installment> get _overdue =>
      _ongoing.where((i) => i.isOverdue).toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('Installment / Layaway'),
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
                    const Text('Ongoing',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text('${_ongoing.length}',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Overdue',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _overdue.isNotEmpty
                                ? Colors.yellow
                                : Colors.white)),
                    Text('${_overdue.length}',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tapos',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text('${_completed.length}',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildList(_ongoing, prov),
                  _buildList(_overdue, prov),
                  _buildList(_completed, prov),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddForm(prov),
          icon: const Icon(Icons.add),
          label: const Text('Bagong Installment'),
        ),
      );
    });
  }

  Widget _buildList(List<Installment> list, AppProvider prov) {
    if (list.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.credit_score_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Wala pang installment',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 16)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final inst = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: inst.isOverdue
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: inst.isCompleted
                        ? Colors.green.withValues(alpha: 0.1)
                        : inst.isOverdue
                            ? Colors.red.withValues(alpha: 0.1)
                            : const Color(0xFF2E7D32)
                                .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    inst.isCompleted
                        ? Icons.check_circle_outline
                        : Icons.credit_score_outlined,
                    color: inst.isCompleted
                        ? Colors.green
                        : inst.isOverdue
                            ? Colors.red
                            : const Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    Text(inst.itemDescription,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(inst.customerName,
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13)),
                  ]),
                ),
                if (inst.isOverdue)
                  _statusBadge('OVERDUE', Colors.red)
                else if (inst.isCompleted)
                  _statusBadge('BAYAD NA', Colors.green),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert,
                      size: 20, color: Colors.grey[400]),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Burahin',
                            style:
                                TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'delete') _confirmDelete(inst);
                  },
                ),
              ]),

              const SizedBox(height: 14),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: inst.progressPercent,
                  backgroundColor:
                      Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(
                      inst.isCompleted
                          ? Colors.green
                          : const Color(0xFF2E7D32)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),

              // Stats row
              Row(children: [
                Text('${inst.paidMonths}/${inst.totalMonths} buwan',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12)),
                const Spacer(),
                Text(
                    'Natitira: ${CurrencyFormatter.format(inst.remainingBalance)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(
                    'Monthly: ${CurrencyFormatter.format(inst.monthlyPayment)}',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12)),
                const Spacer(),
                Text(
                    'Due: ${DateHelper.formatDate(inst.nextDueDate)}',
                    style: TextStyle(
                        color: inst.isOverdue
                            ? Colors.red
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: inst.isOverdue
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ]),

              // Pay button
              if (!inst.isCompleted) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showPayment(inst),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12)),
                    child: Text(
                        'Bayad — ${CurrencyFormatter.format(inst.monthlyPayment)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

void _showAddForm(AppProvider prov) {
  Customer? selectedCustomer;
  final nameCtrl = TextEditingController();
  final Map<Product, int> selectedProducts = {};
  final downCtrl = TextEditingController();
  int selectedMonths = 3;

  // double total = selectedProducts.entries
  //   .fold(0.0, (s, e) => s + e.key.sellPrice * e.value);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF5F6FA),
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setS) {
        final totalAmount = selectedProducts.entries
            .fold(0.0, (s, e) => s + e.key.sellPrice * e.value);
        final down = double.tryParse(downCtrl.text) ?? 0;
        final monthly = selectedMonths > 0
            ? (totalAmount - down) / selectedMonths
            : 0.0;

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Bagong Installment',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // ── STEP 1: Customer ────────────────────────
              _stepLabel('1', 'Pangalan ng Customer'),
              const SizedBox(height: 8),
              if (prov.customers.isNotEmpty) ...[
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: prov.customers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = prov.customers[i];
                      final sel =
                          selectedCustomer?.id == c.id;
                      return FilterChip(
                        label: Text(c.name,
                            style:
                                const TextStyle(fontSize: 12)),
                        selected: sel,
                        selectedColor: const Color(0xFF2E7D32)
                            .withValues(alpha: 0.2),
                        checkmarkColor:
                            const Color(0xFF2E7D32),
                        onSelected: (_) => setS(() {
                          if (sel) {
                            selectedCustomer = null;
                            nameCtrl.clear();
                          } else {
                            selectedCustomer = c;
                            nameCtrl.text = c.name;
                          }
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10),
                    child: Text('o i-type',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 8),
              ],
              _field(nameCtrl, 'Pangalan ng Customer *',
                  Icons.person_outlined,
                  onChanged: (_) =>
                      setS(() => selectedCustomer = null)),
              const SizedBox(height: 20),

              // ── STEP 2: Products ─────────────────────────
              _stepLabel('2', 'Mga Produkto'),
              const SizedBox(height: 8),

              // Selected products summary
              if (selectedProducts.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32)
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2E7D32)
                            .withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: selectedProducts.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 6),
                              child: Row(children: [
                                Expanded(
                                  child: Text(e.key.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w500)),
                                ),
                                // Quantity controls
                                GestureDetector(
                                  onTap: () => setS(() {
                                    if (e.value <= 1) {
                                      selectedProducts
                                          .remove(e.key);
                                    } else {
                                      selectedProducts[e.key] =
                                          e.value - 1;
                                    }
                                  }),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(
                                                8)),
                                    child: const Icon(
                                        Icons.remove,
                                        size: 14,
                                        color: Colors.grey),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets
                                      .symmetric(horizontal: 8),
                                  child: Text('${e.value}',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold)),
                                ),
                                GestureDetector(
                                  onTap: () => setS(() =>
                                      selectedProducts[e.key] =
                                          e.value + 1),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                        color: const Color(
                                            0xFF2E7D32),
                                        borderRadius:
                                            BorderRadius.circular(
                                                8)),
                                    child: const Icon(Icons.add,
                                        size: 14,
                                        color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  CurrencyFormatter.format(
                                      e.key.sellPrice * e.value),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ]),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Add product button
              GestureDetector(
                onTap: () {
                  // Show product picker
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFFF5F6FA),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24))),
                    builder: (_) => StatefulBuilder(
                      builder: (pCtx, pSetS) {
                        String search = '';
                        return StatefulBuilder(
                          builder: (_, sSetS) =>
                              DraggableScrollableSheet(
                            expand: false,
                            initialChildSize: 0.75,
                            builder: (_, ctrl) => Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets
                                      .symmetric(vertical: 10),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius:
                                          BorderRadius.circular(
                                              2)),
                                ),
                                const Text('Pumili ng Produkto',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold)),
                                const SizedBox(height: 10),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16),
                                  child: TextField(
                                    onChanged: (v) =>
                                        sSetS(() => search = v),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Hanapin ang produkto...',
                                      prefixIcon: const Icon(
                                          Icons.search),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                          borderSide:
                                              BorderSide.none),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets
                                              .symmetric(
                                              vertical: 0),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView(
                                    controller: ctrl,
                                    padding:
                                        const EdgeInsets.fromLTRB(
                                            16, 0, 16, 16),
                                    children: prov.products
                                        .where((p) =>
                                            !p.isOutOfStock &&
                                            (search.isEmpty ||
                                                p.name
                                                    .toLowerCase()
                                                    .contains(search
                                                        .toLowerCase())))
                                        .map((p) {
                                      final qty =
                                          selectedProducts[p] ??
                                              0;
                                      return Container(
                                        margin: const EdgeInsets
                                            .only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: qty > 0
                                              ? const Color(
                                                      0xFF2E7D32)
                                                  .withValues(
                                                      alpha: 0.06)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                          border: qty > 0
                                              ? Border.all(
                                                  color: const Color(
                                                          0xFF2E7D32)
                                                      .withValues(
                                                          alpha:
                                                              0.3))
                                              : null,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(
                                                      alpha: 0.04),
                                              blurRadius: 6,
                                              offset: const Offset(
                                                  0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          title: Text(p.name,
                                              style:
                                                  const TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .w600,
                                                      fontSize:
                                                          14)),
                                          subtitle: Text(
                                              CurrencyFormatter
                                                  .format(
                                                      p.sellPrice),
                                              style: const TextStyle(
                                                  color: Color(
                                                      0xFF2E7D32),
                                                  fontWeight:
                                                      FontWeight
                                                          .w600)),
                                          trailing: Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              if (qty > 0) ...[
                                                GestureDetector(
                                                  onTap: () {
                                                    pSetS(() {
                                                      sSetS(() {
                                                        setS(() {
                                                          if (qty <=
                                                              1) {
                                                            selectedProducts
                                                                .remove(
                                                                    p);
                                                          } else {
                                                            selectedProducts[
                                                                    p] =
                                                                qty -
                                                                    1;
                                                          }
                                                        });
                                                      });
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors
                                                          .grey
                                                          .shade100,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  8),
                                                    ),
                                                    child: const Icon(
                                                        Icons.remove,
                                                        size: 16,
                                                        color: Colors
                                                            .grey),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8),
                                                  child: Text(
                                                      '$qty',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                          fontSize:
                                                              16)),
                                                ),
                                              ],
                                              GestureDetector(
                                                onTap: () {
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
                                                  decoration:
                                                      BoxDecoration(
                                                    color: const Color(
                                                        0xFF2E7D32),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                                8),
                                                  ),
                                                  child: const Icon(
                                                      Icons.add,
                                                      size: 16,
                                                      color: Colors
                                                          .white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(pCtx),
                                    style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(
                                            double.infinity, 48)),
                                    child: Text(
                                        selectedProducts.isEmpty
                                            ? 'Bumalik'
                                            : 'Tapos Na (${selectedProducts.length} produkto)'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2E7D32)
                            .withValues(alpha: 0.4),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        selectedProducts.isEmpty
                            ? Icons.add_shopping_cart_outlined
                            : Icons.edit_outlined,
                        color: const Color(0xFF2E7D32),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedProducts.isEmpty
                            ? 'Pumili ng Produkto'
                            : 'I-edit ang mga Produkto',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── STEP 3: Payment Details ──────────────────
              _stepLabel('3', 'Detalye ng Bayad'),
              const SizedBox(height: 8),

              // Total (auto-filled, read-only)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: totalAmount > 0
                      ? const Color(0xFF2E7D32)
                          .withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: totalAmount > 0
                          ? const Color(0xFF2E7D32)
                              .withValues(alpha: 0.2)
                          : Colors.grey
                              .withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Text('Kabuuang Halaga:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const Spacer(),
                  Text(
                    totalAmount > 0
                        ? CurrencyFormatter.format(totalAmount)
                        : '—',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: totalAmount > 0
                            ? const Color(0xFF2E7D32)
                            : Colors.grey),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              // Down payment
              _fieldNum(downCtrl, 'Down Payment (optional)',
                  '₱',
                  onChanged: (_) => setS(() {})),
              const SizedBox(height: 10),

              // Months dropdown
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<int>(
                  value: selectedMonths,
                  decoration: InputDecoration(
                    labelText: 'Bilang ng Buwan',
                    prefixIcon: const Icon(
                        Icons.calendar_month_outlined,
                        size: 20),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                                '${i + 1} ${i + 1 == 1 ? 'buwan' : 'buwan'}'),
                          )),
                  onChanged: (v) =>
                      setS(() => selectedMonths = v!),
                ),
              ),
              const SizedBox(height: 12),

              // Monthly payment preview
              if (totalAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                    const Text('Monthly Payment:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue)),
                    Text(
                        CurrencyFormatter.format(
                            monthly < 0 ? 0 : monthly),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.blue)),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Validation
                    final customerName =
                        selectedCustomer?.name ??
                            nameCtrl.text.trim();
                    if (customerName.isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content:
                            Text('Ilagay ang pangalan ng customer!'),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }
                    if (selectedProducts.isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content:
                            Text('Pumili ng kahit isang produkto!'),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }
                    if (totalAmount <= 0) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content: Text(
                            'Hindi maaaring zero ang kabuuan!'),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }
                    final down =
                        double.tryParse(downCtrl.text) ?? 0;
                    if (down >= totalAmount) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content: Text(
                            'Ang down payment ay hindi maaaring mas malaki sa kabuuan!'),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }

                    // Get or create customer
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
                        await prov.addCustomer(customerName);
                        customerId = prov.customers
                            .firstWhere(
                                (c) => c.name == customerName,
                                orElse: () =>
                                    prov.customers.last)
                            .id;
                      }
                    }

                    // Build item description
                    final itemDesc = selectedProducts.entries
                        .map((e) =>
                            '${e.key.name} x${e.value}')
                        .join(', ');
                    final monthly = selectedMonths > 0
                        ? (totalAmount - down) / selectedMonths
                        : 0.0;

                    final installment = Installment(
                      id: _uuid.v4(),
                      customerId: customerId,
                      customerName: customerName,
                      itemDescription: itemDesc,
                      totalAmount: totalAmount,
                      downPayment: down,
                      monthlyPayment: monthly,
                      totalMonths: selectedMonths,
                      paidMonths: 0,
                      totalPaid: down,
                      status: InstallmentStatus.ongoing,
                      startDate: DateTime.now(),
                      nextDueDate: DateTime.now()
                          .add(const Duration(days: 30)),
                    );

                    await InstallmentService.instance
                        .save(installment);
                    await _load();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content:
                            Text('Na-save ang installment!'),
                        backgroundColor: Colors.green,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14)),
                  child: const Text('I-save ang Installment',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
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
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF2E7D32),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(num,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14)),
    ]);

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  Widget _fieldNum(
    TextEditingController ctrl,
    String label,
    String prefix, {
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixText: '$prefix ',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  void _showPayment(Installment inst) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Mag-bayad ng Installment'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(inst.itemDescription,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          Text(inst.customerName,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _row('Monthly:',
              CurrencyFormatter.format(inst.monthlyPayment)),
          _row('Bayad na:',
              CurrencyFormatter.format(inst.totalPaid)),
          _row('Natitira:',
              CurrencyFormatter.format(inst.remainingBalance),
              color: Colors.red),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: inst.progressPercent,
              backgroundColor:
                  Colors.grey.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(
                  Color(0xFF2E7D32)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text('${inst.paidMonths}/${inst.totalMonths} buwan',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () async {
              final newPaid =
                  inst.totalPaid + inst.monthlyPayment;
              final newMonths = inst.paidMonths + 1;
              final isComplete =
                  newMonths >= inst.totalMonths;
              final updated = inst.copyWith(
                paidMonths: newMonths,
                totalPaid: newPaid,
                status: isComplete
                    ? InstallmentStatus.completed
                    : InstallmentStatus.ongoing,
                nextDueDate: isComplete
                    ? inst.nextDueDate
                    : DateTime.now()
                        .add(const Duration(days: 30)),
              );
              await InstallmentService.instance
                  .save(updated);
              await _load();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(isComplete
                      ? 'Bayad na ang installment!'
                      : 'Natanggap ang bayad!'),
                  backgroundColor: isComplete
                      ? Colors.green
                      : Colors.blue,
                ));
              }
            },
            child: Text(
                'Bayad — ${CurrencyFormatter.format(inst.monthlyPayment)}'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Installment inst) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Burahin ang Installment?'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(inst.itemDescription,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          Text('Customer: ${inst.customerName}',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 6),
          Text(
              'Kabuuan: ${CurrencyFormatter.format(inst.totalAmount)}',
              style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Hindi na mababawi ito.',
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 13)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Burahin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await InstallmentService.instance.delete(inst.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
          content: Text('Na-bura ang installment!'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _row(String label, String value, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}