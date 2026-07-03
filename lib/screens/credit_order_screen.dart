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

const _blue = Color(0xFF1E3A8A);

// ── STEP 1: Customer Info ─────────────────────────────────────
class CreditOrderScreen extends StatefulWidget {
  const CreditOrderScreen({super.key});
  @override
  State<CreditOrderScreen> createState() =>
      _CreditOrderScreenState();
}

class _CreditOrderScreenState
    extends State<CreditOrderScreen> {
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('New Credit',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child:
                Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

            if (prov.customers.isNotEmpty) ...[
              Text('Select existing customer',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey[700])),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: prov.customers.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final c = prov.customers[i];
                    final sel =
                        _existingCustomer?.id == c.id;
                    return GestureDetector(
                      onTap: () => setState(() {
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
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? _blue
                              : Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(c.name,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey[700])),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: Divider(
                        color: Colors.grey.shade200)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10),
                  child: Text('or new customer',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11)),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.grey.shade200)),
              ]),
              const SizedBox(height: 16),
            ],

            _field(_nameCtrl, 'Customer name *',
                Icons.person_outlined,
                onChanged: (_) =>
                    setState(() => _existingCustomer = null)),
            const SizedBox(height: 12),
            _field(
                _phoneCtrl, 'Phone number (optional)',
                Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                            content:
                                Text('Name is required.'),
                            backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreditProductScreen(
                        customerName:
                            _nameCtrl.text.trim(),
                        customerPhone:
                            _phoneCtrl.text.trim().isEmpty
                                ? null
                                : _phoneCtrl.text.trim(),
                        existingCustomer:
                            _existingCustomer,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
                child: const Text('Select Items →',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
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
          labelStyle: TextStyle(
              color: Colors.grey[600], fontSize: 13),
          prefixIcon:
              Icon(icon, size: 18, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.shade300)),
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
  String _category = 'All';
  final _searchCtrl = TextEditingController();
  DateTime _dueDate =
      DateTime.now().add(const Duration(days: 30));

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
            p.name
                .toLowerCase()
                .contains(_search.toLowerCase());
        final mc =
            _category == 'All' || p.category == _category;
        return ms && mc;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final filtered = _filter(prov.products);
      final categories = [
        'All',
        ...FilipinoCategories.productCategories
      ];

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Select Items',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            Text(widget.customerName,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey[500])),
          ]),
          actions: [
            if (_itemCount > 0)
              Badge(
                label: Text('$_itemCount'),
                child: IconButton(
                  icon: const Icon(
                      Icons.shopping_basket_outlined,
                      color: Colors.black54),
                  onPressed: () =>
                      _goToSummary(context, prov),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child:
                Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: Column(children: [

          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              // Search
              TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(
                      color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_outlined,
                      color: Colors.grey[400], size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.grey[400],
                              size: 18),
                          onPressed: () {
                            setState(() => _search = '');
                            _searchCtrl.clear();
                          })
                      : null,
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

              // Category chips
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    final sel = _category == cat;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? _blue
                              : Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: cat == 'All'
                            ? Text(
                                'All',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: sel
                                        ? Colors.white
                                        : Colors.grey[600]),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FilipinoCategories.getIcon(cat),
                                    size: 14,
                                    color: sel ? Colors.white : _blue,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: sel
                                            ? Colors.white
                                            : Colors.grey[600]),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // Products grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      Icon(Icons.search_off_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('No products found',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14)),
                    ]))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        16, 12, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.05,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final qty = _selected[p] ?? 0;
                      final inCart = qty > 0;

                      return GestureDetector(
                        onTap: p.isOutOfStock
                            ? null
                            : () => setState(() =>
                                _selected[p] = qty + 1),
                        child: AnimatedContainer(
                          duration: const Duration(
                              milliseconds: 150),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: inCart
                                  ? _blue
                                  : Colors.grey.shade200,
                              width: inCart ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Icon(
                                  FilipinoCategories.getIcon(p.category),
                                  size: 18,
                                  color: _blue,
                                ),
                                const Spacer(),
                                if (p.isOutOfStock)
                                  _badge('Out', Colors.red)
                                else if (p.isLowStock)
                                  _badge(
                                      '${p.stock}',
                                      Colors.orange)
                                else if (inCart)
                                  _badge('$qty', _blue),
                              ]),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(p.name,
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 13,
                                        color: p.isOutOfStock
                                            ? Colors.grey[400]
                                            : Colors.black87),
                                    maxLines: 2,
                                    overflow: TextOverflow
                                        .ellipsis),
                              ),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: Text(
                                    CurrencyFormatter.format(
                                        p.sellPrice),
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        color: p.isOutOfStock
                                            ? Colors.grey[400]
                                            : Colors.black87,
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
                                                    .bold,
                                            fontSize: 13)),
                                  ),
                                  _smallBtn(
                                      Icons.add,
                                      _blue,
                                      Colors.white,
                                      () => setState(() =>
                                          _selected[p] =
                                              qty + 1)),
                                ] else
                                  _smallBtn(
                                      Icons.add,
                                      p.isOutOfStock
                                          ? Colors.grey
                                              .shade100
                                          : _blue,
                                      p.isOutOfStock
                                          ? Colors.grey
                                              .shade400
                                          : Colors.white,
                                      p.isOutOfStock
                                          ? () {}
                                          : () => setState(
                                              () => _selected[
                                                  p] = 1)),
                              ]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),

        // ── Bottom Bar ────────────────────────────────
        bottomNavigationBar: _itemCount > 0
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        top: BorderSide(
                            color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Due date picker
                      GestureDetector(
                        onTap: () async {
                          final picked =
                              await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                                const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(
                                () => _dueDate = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _blue
                                .withValues(alpha: 0.05),
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                                color: _blue.withValues(
                                    alpha: 0.2)),
                          ),
                          child: Row(children: [
                            const Icon(
                                Icons.calendar_today_outlined,
                                color: _blue, size: 16),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Payment deadline',
                                    style: TextStyle(
                                        color: _blue
                                            .withValues(
                                                alpha: 0.7),
                                        fontWeight:
                                            FontWeight.w500,
                                        fontSize: 10)),
                                Text(
                                  DateHelper.formatDate(
                                      _dueDate),
                                  style: const TextStyle(
                                      color: _blue,
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(
                                Icons.edit_calendar_outlined,
                                color: _blue
                                    .withValues(alpha: 0.6),
                                size: 16),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Proceed button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              _goToSummary(context, prov),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets
                                .symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        10)),
                          ),
                          child: Text(
                            '$_itemCount item${_itemCount > 1 ? 's' : ''}  •  ${CurrencyFormatter.format(_total)}   Save Credit →',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      );
    });
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 0.5)),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      );

  Widget _smallBtn(IconData icon, Color bg, Color fg,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: fg),
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
          dueDate: _dueDate,
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
  final DateTime dueDate;

  const CreditSummaryScreen({
    super.key,
    required this.customerName,
    this.customerPhone,
    this.existingCustomer,
    required this.selectedItems,
    required this.dueDate,
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
      final image =
          await boundary.toImage(pixelRatio: 3.0);
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
          '${dir.path}/credit_${widget.customerName}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Credit Record — ${widget.customerName}\n${DateHelper.formatDate(DateTime.now())}',
        ),
      );
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
        await prov.addCustomer(widget.customerName,
            phone: widget.customerPhone);
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
        dueDate: widget.dueDate,
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: const Text('Credit Summary',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          actions: [
            IconButton(
              icon: _sharing
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                  : const Icon(Icons.share_outlined,
                      color: Colors.black54, size: 22),
              onPressed: _sharing ? null : _share,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child:
                Divider(height: 1, color: Colors.grey.shade200),
          ),
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
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [

                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                        20, 20, 20, 20),
                    color: _blue,
                    child: Column(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.credit_card_outlined,
                            color: Colors.white,
                            size: 24),
                      ),
                      const SizedBox(height: 10),
                      const Text('CREDIT RECORD',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                            DateHelper.formatDate(
                                DateTime.now()),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11)),
                      ),
                    ]),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [

                      // Customer info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _blue
                                .withValues(alpha: 0.1),
                            child: Text(
                              widget.customerName[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: _blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text(widget.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87)),
                            if (widget.customerPhone != null)
                              Text(widget.customerPhone!,
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // Items header
                      Row(children: [
                        Expanded(
                            flex: 4,
                            child: Text('PRODUCT',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    letterSpacing: 0.5))),
                        Text('QTY',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: Colors.grey[500])),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: Text('AMOUNT',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Divider(
                          height: 1,
                          color: Colors.grey.shade200),
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
                                              fontSize: 13,
                                              color:
                                                  Colors.black87)),
                                      Text(
                                          CurrencyFormatter.format(
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
                                    width: 70,
                                    child: Text(
                                      CurrencyFormatter.format(
                                          e.key.sellPrice *
                                              e.value),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.black87),
                                    ),
                                  ),
                                ]),
                              )),

                      Divider(
                          height: 16,
                          color: Colors.grey.shade200),

                      // Total
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.06),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  _blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Text('TOTAL CREDIT',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _blue)),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.format(_total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: _blue),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),

                      // Due date
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_outlined,
                              color: Colors.grey[500], size: 14),
                          const SizedBox(width: 8),
                          Text('Due date:',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12)),
                          const Spacer(),
                          Text(
                            DateHelper.formatDate(
                                widget.dueDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.black87),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // Footer
                      Center(
                        child: Text('TindaPH',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11)),
                      ),
                      const SizedBox(height: 6),
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
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.share_outlined,
                            size: 16),
                    label: const Text('Share',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: BorderSide(
                          color: _blue.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
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
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : const Icon(Icons.save_outlined,
                            size: 16),
                    label: Text(
                        _saving ? 'Saving...' : 'Save Credit',
                        style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.green.shade100),
                ),
                child: Column(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text('Credit saved!',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.green)),
                  const SizedBox(height: 4),
                  Text('Visible in Credit screen',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: const Icon(Icons.share_outlined,
                        size: 16),
                    label: const Text('Share',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: BorderSide(
                          color: _blue.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil(
                            (route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined,
                        size: 16),
                    label: const Text('Go Home',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
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