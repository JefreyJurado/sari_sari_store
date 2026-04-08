import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/filipino_categories.dart';

// ── STEP 1: Customer Info ─────────────────────────────────────
class CreditOrderScreen extends StatefulWidget {
  const CreditOrderScreen({super.key});
  @override
  State<CreditOrderScreen> createState() =>
      _CreditOrderScreenState();
}

class _CreditOrderScreenState extends State<CreditOrderScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  Customer? _existingCustomer;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(title: const Text('Bagong Uutang')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Existing customers
            if (prov.customers.isNotEmpty) ...[
              const Text('Piliin mula sa listahan:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: prov.customers.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = prov.customers[i];
                    final sel = _existingCustomer?.id == c.id;
                    return FilterChip(
                      label: Text(c.name),
                      selected: sel,
                      selectedColor: const Color(0xFF2E7D32)
                          .withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF2E7D32),
                      onSelected: (_) => setState(() {
                        if (sel) {
                          _existingCustomer = null;
                          _nameCtrl.clear();
                          _phoneCtrl.clear();
                        } else {
                          _existingCustomer = c;
                          _nameCtrl.text = c.name;
                          _phoneCtrl.text = c.phone ?? '';
                        }
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('o bagong customer',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
            ],

            // Name field
            _field(_nameCtrl, 'Pangalan ng Uutang *',
                Icons.person_outlined,
                onChanged: (_) =>
                    setState(() => _existingCustomer = null)),
            const SizedBox(height: 12),

            // Phone field
            _field(_phoneCtrl, 'Numero ng Telepono (optional)',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 32),

            // Next button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content: Text('Ilagay ang pangalan!'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreditProductScreen(
                        customerName: _nameCtrl.text.trim(),
                        customerPhone:
                            _phoneCtrl.text.trim().isEmpty
                                ? null
                                : _phoneCtrl.text.trim(),
                        existingCustomer: _existingCustomer,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16)),
                child: const Text('Pumili ng mga Item →',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      );
    });
  }

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
}

// ── STEP 2: Product Selection ─────────────────────────────────
class CreditProductScreen extends StatefulWidget {
  final String customerName;
  final String? customerPhone;
  final Customer? existingCustomer;

  const CreditProductScreen({
    super.key,
    required this.customerName,
    this.customerPhone,
    this.existingCustomer,
  });

  @override
  State<CreditProductScreen> createState() =>
      _CreditProductScreenState();
}

class _CreditProductScreenState
    extends State<CreditProductScreen> {
  final Map<Product, int> _selected = {};
  String _search = '';
  String _category = 'Lahat';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _total => _selected.entries
      .fold(0, (s, e) => s + e.key.sellPrice * e.value);

  int get _itemCount =>
      _selected.values.fold(0, (s, q) => s + q);

  List<Product> _filter(List<Product> products) =>
      products.where((p) {
        final ms = _search.isEmpty ||
            p.name.toLowerCase().contains(_search.toLowerCase());
        final mc =
            _category == 'Lahat' || p.category == _category;
        return ms && mc;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final filtered = _filter(prov.products);
      final categories = [
        'Lahat',
        ...FilipinoCategories.productCategories
      ];

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Piliin ang Items'),
            Text(widget.customerName,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70)),
          ]),
          actions: [
            if (_itemCount > 0)
              Badge(
                label: Text('$_itemCount'),
                child: IconButton(
                  icon:
                      const Icon(Icons.shopping_basket_outlined),
                  onPressed: () => _goToSummary(context, prov),
                ),
              ),
          ],
        ),
        body: Column(children: [
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
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Hanapin ang produkto...',
                  hintStyle:
                      TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.grey[400]),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: Colors.grey[400]),
                          onPressed: () {
                            setState(() => _search = '');
                            _searchCtrl.clear();
                          })
                      : null,
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

          // Categories
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF2E7D32)
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      cat == 'Lahat'
                          ? 'Lahat'
                          : '${FilipinoCategories.emoji(cat)} $cat',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: sel
                              ? Colors.white
                              : Colors.grey[700]),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Products grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      Icon(Icons.search_off,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Walang nahanap',
                          style: TextStyle(
                              color: Colors.grey[400])),
                    ]))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        16, 4, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.05,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final qty = _selected[p] ?? 0;
                      final inCart = qty > 0;

                      return GestureDetector(
                        onTap: p.isOutOfStock
                            ? null
                            : () => setState(
                                () => _selected[p] = qty + 1),
                        child: AnimatedContainer(
                          duration: const Duration(
                              milliseconds: 150),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(14),
                            border: inCart
                                ? Border.all(
                                    color:
                                        const Color(0xFF2E7D32),
                                    width: 2)
                                : Border.all(
                                    color: Colors.transparent,
                                    width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: inCart
                                    ? const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.1)
                                    : Colors.black
                                        .withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Text(
                                    FilipinoCategories.emoji(
                                        p.category),
                                    style: const TextStyle(
                                        fontSize: 22)),
                                const Spacer(),
                                if (p.isOutOfStock)
                                  _badge('Ubos', Colors.red)
                                else if (p.isLowStock)
                                  _badge('${p.stock}',
                                      Colors.orange)
                                else if (inCart)
                                  _badge('$qty',
                                      const Color(0xFF2E7D32)),
                              ]),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(p.name,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 13),
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis),
                              ),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: Text(
                                    CurrencyFormatter.format(
                                        p.sellPrice),
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        color:
                                            Color(0xFF2E7D32),
                                        fontSize: 14),
                                  ),
                                ),
                                if (inCart) ...[
                                  _smallBtn(
                                      Icons.remove,
                                      Colors.grey.shade100,
                                      Colors.grey.shade700,
                                      () => setState(() {
                                            if (qty <= 1) {
                                              _selected
                                                  .remove(p);
                                            } else {
                                              _selected[p] =
                                                  qty - 1;
                                            }
                                          })),
                                  Padding(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        horizontal: 6),
                                    child: Text('$qty',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold)),
                                  ),
                                  _smallBtn(
                                      Icons.add,
                                      const Color(0xFF2E7D32),
                                      Colors.white,
                                      () => setState(() =>
                                          _selected[p] =
                                              qty + 1)),
                                ] else
                                  _smallBtn(
                                      Icons.add,
                                      p.isOutOfStock
                                          ? Colors.grey.shade100
                                          : const Color(
                                              0xFF2E7D32),
                                      p.isOutOfStock
                                          ? Colors.grey.shade400
                                          : Colors.white,
                                      p.isOutOfStock
                                          ? () {}
                                          : () => setState(() =>
                                              _selected[p] = 1)),
                              ]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
        bottomNavigationBar: _itemCount > 0
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () =>
                        _goToSummary(context, prov),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16)),
                    child: Text(
                      '$_itemCount item  •  ${CurrencyFormatter.format(_total)}   I-save ang Utang →',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            : null,
      );
    });
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  Widget _smallBtn(
          IconData icon, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: fg),
        ),
      );

  void _goToSummary(BuildContext context, AppProvider prov) {
    if (_selected.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreditSummaryScreen(
          customerName: widget.customerName,
          customerPhone: widget.customerPhone,
          existingCustomer: widget.existingCustomer,
          selectedItems: Map.from(_selected),
        ),
      ),
    );
  }
}

// ── STEP 3: Summary & Save ────────────────────────────────────
class CreditSummaryScreen extends StatefulWidget {
  final String customerName;
  final String? customerPhone;
  final Customer? existingCustomer;
  final Map<Product, int> selectedItems;

  const CreditSummaryScreen({
    super.key,
    required this.customerName,
    this.customerPhone,
    this.existingCustomer,
    required this.selectedItems,
  });

  @override
  State<CreditSummaryScreen> createState() =>
      _CreditSummaryScreenState();
}

class _CreditSummaryScreenState
    extends State<CreditSummaryScreen> {
  final _receiptKey = GlobalKey();
  bool _saving = false;
  bool _sharing = false;
  bool _saved = false;

  double get _total => widget.selectedItems.entries
      .fold(0, (s, e) => s + e.key.sellPrice * e.value);

  Future<Uint8List?> _capture() async {
    try {
      final boundary = _receiptKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/utang_${widget.customerName}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text:
              'Listahan ng Utang ni ${widget.customerName}\n${DateHelper.formatDate(DateTime.now())}');
    } catch (_) {}
    if (mounted) setState(() => _sharing = false);
  }

  Future<void> _saveDebt(AppProvider prov) async {
    setState(() => _saving = true);
    try {
      Customer customer;
      if (widget.existingCustomer != null) {
        customer = widget.existingCustomer!;
      } else {
        await prov.addCustomer(
          widget.customerName,
          phone: widget.customerPhone,
        );
        customer = prov.customers.firstWhere(
            (c) => c.name == widget.customerName,
            orElse: () => prov.customers.last);
      }

      final items = widget.selectedItems.entries
          .map((e) => {'product': e.key, 'qty': e.value})
          .toList();

      await prov.completeSaleWithItems(
        items: items,
        cashPaid: 0,
        creditAmount: _total,
        type: _PaymentTypeCredit(),
        customer: customer,
      );

      setState(() {
        _saving = false;
        _saved = true;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('Listahan ng Utang'),
          actions: [
            IconButton(
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.share_outlined),
              onPressed: _sharing ? null : _share,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Receipt card
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                        20, 24, 20, 24),
                    color: Colors.orange,
                    child: Column(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: const Icon(
                            Icons.credit_card_outlined,
                            color: Colors.white,
                            size: 28),
                      ),
                      const SizedBox(height: 10),
                      const Text('LISTAHAN NG UTANG',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                            DateHelper.formatDate(
                                DateTime.now()),
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.9),
                                fontSize: 12)),
                      ),
                    ]),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      // Customer info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange
                                  .withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                widget.customerName[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text(widget.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            if (widget.customerPhone != null)
                              Text(widget.customerPhone!,
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Items header
                      Row(children: [
                        const Expanded(
                            flex: 4,
                            child: Text('PRODUKTO',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.grey,
                                    letterSpacing: 0.5))),
                        const Text('QTY',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 75,
                          child: const Text('HALAGA',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // Items
                      ...widget.selectedItems.entries
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 10),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                      Text(e.key.name,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600,
                                              fontSize: 13)),
                                      Text(
                                          CurrencyFormatter
                                              .format(
                                                  e.key.sellPrice),
                                          style: TextStyle(
                                              color:
                                                  Colors.grey[500],
                                              fontSize: 11)),
                                    ]),
                                  ),
                                  Text('×${e.value}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              Colors.grey[600])),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 75,
                                    child: Text(
                                      CurrencyFormatter.format(
                                          e.key.sellPrice *
                                              e.value),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ),
                                ]),
                              )),

                      const Divider(height: 16),

                      // Total
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Text('KABUUANG UTANG',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange)),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.format(_total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.orange),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Footer
                      Center(
                        child: Column(children: [
                          Text(
                              'Due: ${DateHelper.formatDate(DateTime.now().add(const Duration(days: 30)))}',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            'Powered by TindaPH 🇵🇭',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            if (!_saved) ...[
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.share_outlined),
                    label: const Text('I-share'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _saveDebt(prov),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving
                        ? 'Sine-save...'
                        : 'I-save ang Utang'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14)),
                  ),
                ),
              ]),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 32),
                  ),
                  const SizedBox(height: 10),
                  const Text('Na-save na ang Utang!',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green)),
                  const SizedBox(height: 4),
                  Text('Makikita sa Lista ng Utang',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('I-share'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil(
                            (route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Uwi sa Home'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14)),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 20),
          ]),
        ),
      );
    });
  }
}

class _PaymentTypeCredit {}