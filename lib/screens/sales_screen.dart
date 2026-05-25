import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/customer.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import 'receipt_screen.dart';

const _blue = Color(0xFF1E3A8A);

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _search = '';
  String _category = 'All';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> products) =>
      products.where((p) {
        final ms = _search.isEmpty ||
            p.name.toLowerCase().contains(_search.toLowerCase());
        final mc = _category == 'All' || p.category == _category;
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
        // Removed fixed appBar to allow natural non-sticky scrolling
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Non-sticky App Header Block
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                            child: Row(
                              children: [
                                const Text(
                                  'Sales',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                if (prov.cartItemCount > 0)
                                  Badge(
                                    label: Text('${prov.cartItemCount}'),
                                    child: IconButton(
                                        icon: const Icon(
                                            Icons.shopping_cart_outlined,
                                            color: Colors.black87),
                                        onPressed: () => _showCart(context, prov)),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Icon(Icons.shopping_cart_outlined,
                                        color: Colors.black54),
                                  ),
                              ],
                            ),
                          ),
                          // Non-Sticky Filters & Search Inputs
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) => setState(() => _search = v),
                                  decoration: InputDecoration(
                                    hintText: 'Search products...',
                                    hintStyle: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                    prefixIcon: Icon(Icons.search_outlined,
                                        color: Colors.grey[400], size: 20),
                                    suffixIcon: _search.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.close,
                                                color: Colors.grey[400], size: 18),
                                            onPressed: () {
                                              setState(() => _search = '');
                                              _searchCtrl.clear();
                                            })
                                        : null,
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none),
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 0),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 36,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
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
                                              horizontal: 14, vertical: 8),
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
                                                      fontSize: 13,
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
                                                      color: sel ? Colors.white : Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      cat,
                                                      style: TextStyle(
                                                          fontSize: 13,
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
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.shade200),
                        ],
                      ),
                    ),
                    // Main Grid Content Area
                    filtered.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
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
                                ])),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: _ProductSliverGrid(
                              products: filtered,
                              cart: prov.cart,
                              onAdd: prov.addToCart,
                              onRemove: (p) {
                                final qty = prov.cart[p] ?? 0;
                                prov.setCartQty(p, qty - 1);
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: prov.cartItemCount > 0
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        top: BorderSide(
                            color: Colors.grey.shade200)),
                  ),
                  child: GestureDetector(
                    onTap: () => _showCart(context, prov),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${prov.cartItemCount} item${prov.cartItemCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(
                              prov.cartTotal),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white70, size: 14),
                      ]),
                    ),
                  ),
                ),
              )
            : null,
      );
    });
  }

  void _showCart(BuildContext context, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CartSheet(prov: prov),
    );
  }
}

// Converted standard GridView to a proper Sliver grid to prevent scrolling block conflicts
class _ProductSliverGrid extends StatelessWidget {
  final List<Product> products;
  final Map<Product, int> cart;
  final void Function(Product) onAdd;
  final void Function(Product) onRemove;

  const _ProductSliverGrid({
    required this.products,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.05,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final p = products[i];
          final qty = cart[p] ?? 0;
          final inCart = qty > 0;

          return GestureDetector(
            onTap: p.isOutOfStock ? null : () => onAdd(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: inCart ? _blue : Colors.grey.shade200,
                  width: inCart ? 1.5 : 1,
                ),
                boxShadow: inCart
                    ? [
                        BoxShadow(
                            color: _blue.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        FilipinoCategories.getIcon(p.category),
                        size: 20,
                        color: _blue,
                      ),
                      const Spacer(),
                      if (p.isOutOfStock)
                        _badge('Out', Colors.red)
                      else if (p.isLowStock)
                        _badge('Low', Colors.orange)
                      else if (inCart)
                        _badge('$qty', _blue),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(p.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: p.isOutOfStock ? Colors.grey[400] : Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Text(
                          CurrencyFormatter.format(p.sellPrice),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: p.isOutOfStock ? Colors.grey[400] : Colors.black87,
                              fontSize: 14),
                        ),
                      ),
                      if (inCart) ...[
                        _smallBtn(Icons.remove_outlined, Colors.grey.shade100, Colors.grey.shade700,
                            () => onRemove(p)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('$qty',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        _smallBtn(Icons.add, _blue, Colors.white, () => onAdd(p)),
                      ] else
                        _smallBtn(
                            Icons.add,
                            p.isOutOfStock ? Colors.grey.shade100 : _blue.withValues(alpha: 0.08),
                            p.isOutOfStock ? Colors.grey.shade400 : _blue,
                            p.isOutOfStock ? () {} : () => onAdd(p)),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: products.length,
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5)),
        child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  Widget _smallBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: fg),
        ),
      );
}

class _CartSheet extends StatefulWidget {
  final AppProvider prov;
  const _CartSheet({required this.prov});
  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _cashCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  String _paymentType = 'cash';
  bool _isProcessing = false;
  Customer? _selectedCustomer;

  AppProvider get prov => widget.prov;
  double get cashPaid => double.tryParse(_cashCtrl.text) ?? 0;
  double get change =>
      cashPaid > prov.cartTotal ? cashPaid - prov.cartTotal : 0;

  @override
  void initState() {
    super.initState();
    _cashCtrl.text = prov.cartTotal.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _refCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(children: [
              const Text('Cart Overview',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  prov.clearCart();
                  Navigator.pop(context);
                },
                child: Text('Clear All',
                    style: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
            ]),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                ...prov.cart.entries.map((e) => Container(
                      margin:
                          const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Icon(
                          FilipinoCategories.getIcon(e.key.category),
                          size: 20,
                          color: _blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text(e.key.name,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text(
                                CurrencyFormatter.format(
                                    e.key.sellPrice),
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12)),
                          ]),
                        ),
                        Row(children: [
                          _qtyBtn(
                            Icons.remove,
                            () => setState(() =>
                                prov.setCartQty(
                                    e.key, e.value - 1)),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12),
                            child: Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 14)),
                          ),
                          _qtyBtn(
                            Icons.add,
                            () => setState(() =>
                                prov.addToCart(e.key)),
                            filled: true,
                          ),
                        ]),
                        const SizedBox(width: 16),
                        Text(
                          CurrencyFormatter.format(
                              e.key.sellPrice * e.value),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87),
                        ),
                      ]),
                    )),
                const SizedBox(height: 8),
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
                    Text('Total Amount Due',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[700])),
                    const Spacer(),
                    Text(
                        CurrencyFormatter.format(
                            prov.cartTotal),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: _blue)),
                  ]),
                ),
                const SizedBox(height: 24),
                const Text('Customer Assignment',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  'Optional — choose or register a client name to log history',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (prov.customers.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: prov.customers.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = prov.customers[i];
                        final sel =
                            _selectedCustomer?.id == c.id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (sel) {
                              _selectedCustomer = null;
                              _customerCtrl.clear();
                            } else {
                              _selectedCustomer = c;
                              _customerCtrl.text = c.name;
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 150),
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 14,
                                vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _blue
                                  : Colors.white,
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? _blue
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(c.name,
                                style: TextStyle(
                                    fontSize: 13,
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
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: Divider(
                            color: Colors.grey.shade200)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      child: Text('OR TYPE NEW',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              letterSpacing: 0.5)),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.grey.shade200)),
                  ]),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _customerCtrl,
                  textCapitalization:
                      TextCapitalization.words,
                  onChanged: (v) => setState(
                      () => _selectedCustomer = null),
                  decoration: InputDecoration(
                    hintText: 'e.g. Maria, Juan...',
                    hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14),
                    prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.grey[400],
                        size: 18),
                    suffixIcon:
                        _customerCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    color: Colors.grey[400],
                                    size: 16),
                                onPressed: () => setState(
                                    () {
                                  _customerCtrl.clear();
                                  _selectedCustomer = null;
                                }))
                            : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            vertical: 0),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Choose Settlement Mode',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87)),
                const SizedBox(height: 12),
                _paymentBtn(
                  icon: Icons.payments_outlined,
                  label: 'Cash Settlement',
                  sublabel: 'Physical tender verification',
                  selected: _paymentType == 'cash',
                  onTap: () => setState(() {
                    _paymentType = 'cash';
                    _cashCtrl.text =
                        prov.cartTotal.toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 8),
                _paymentBtn(
                  icon: Icons.phone_android_outlined,
                  label: 'Online E-Wallet',
                  sublabel: 'GCash / Maya / Bank Transfers',
                  selected: _paymentType == 'online',
                  onTap: () => setState(() {
                    _paymentType = 'online';
                    _cashCtrl.text =
                        prov.cartTotal.toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 20),
                if (_paymentType == 'cash') ...[
                  TextField(
                    controller: _cashCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount Received From Customer',
                      labelStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13),
                      prefixText: '₱ ',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.grey.shade200)),
                    ),
                  ),
                  if (change > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50.withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.shade200.withValues(alpha: 0.5)),
                      ),
                      child: Row(children: [
                        Icon(Icons.currency_exchange,
                            color: Colors.green.shade700,
                            size: 18),
                        const SizedBox(width: 10),
                        Text('Change to Return',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        const Spacer(),
                        Text(
                            CurrencyFormatter.format(change),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.green.shade700)),
                      ]),
                    ),
                  ],
                ],
                if (_paymentType == 'online') ...[
                  TextField(
                    controller: _refCtrl,
                    decoration: InputDecoration(
                      labelText: 'Reference Confirmation Code (Optional)',
                      labelStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13),
                      prefixIcon: Icon(
                          Icons.tag_outlined,
                          color: Colors.grey[400],
                          size: 18),
                      hintText: 'e.g. 123456789',
                      hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.grey.shade200)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.info_outline,
                        color: _blue, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Please verify receipt statement screen before finalizing.',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600]),
                    ),
                  ]),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isProcessing ? null : _complete,
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
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : Text(
                            'Process Order Summary  (${CurrencyFormatter.format(prov.cartTotal)})',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap,
      {bool filled = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: filled
                  ? _blue
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon,
              size: 14,
              color:
                  filled ? Colors.white : Colors.grey[700]),
        ),
      );

  Widget _paymentBtn({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? _blue
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? _blue
                  : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Icon(icon,
                color: selected
                    ? Colors.white
                    : Colors.grey[600],
                size: 22),
            const SizedBox(width: 14),
            Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: TextStyle(
                      color: selected
                          ? Colors.white70
                          : Colors.grey[500],
                      fontSize: 12)),
            ]),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Colors.white, size: 20),
          ]),
        ),
      );

  Future<void> _complete() async {
    if (prov.cart.isEmpty) return;

    Customer? customer = _selectedCustomer;
    final typedName = _customerCtrl.text.trim();

    if (customer == null && typedName.isNotEmpty) {
      final existing = prov.customers
          .where((c) =>
              c.name.toLowerCase() ==
              typedName.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        customer = existing;
      } else {
        await prov.addCustomer(typedName);
        customer = prov.customers.firstWhere(
            (c) => c.name == typedName,
            orElse: () => prov.customers.last);
      }
    }

    if (_paymentType == 'cash' &&
        cashPaid < prov.cartTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Insufficient cash amount.'),
              backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);

    final notes = _paymentType == 'online' &&
            _refCtrl.text.isNotEmpty
        ? 'Online Payment - Ref#: ${_refCtrl.text}'
        : _paymentType == 'online'
            ? 'Online Payment'
            : null;

    final sale = await prov.completeSale(
      cashPaid: _paymentType == 'cash'
          ? cashPaid
          : prov.cartTotal,
      creditAmount: 0,
      type: _paymentType == 'cash'
          ? PaymentType.cash
          : PaymentType.online,
      notes: notes,
      customer: customer,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (sale != null) {
      final ctx = context;
      final paymentType = _paymentType;
      final refText = _refCtrl.text;
      final customerName = customer?.name;
      final saleChange = sale.change;

      Navigator.of(ctx).pop();

      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              paymentType == 'online'
                  ? 'Payment confirmed'
                  : 'Sale complete',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ]),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
            if (customerName != null) ...[
              Row(children: [
                Icon(Icons.person_outline,
                    size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(customerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87)),
              ]),
              const SizedBox(height: 6),
            ],
            Text(
                '${sale.items.length} item${sale.items.length > 1 ? 's' : ''} saved securely',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13)),
            if (paymentType == 'online' &&
                refText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Ref# $refText',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Row(children: [
              Text('Total Owed',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14)),
              const Spacer(),
              Text(
                  CurrencyFormatter.format(
                      sale.totalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.black87)),
            ]),
            if (paymentType == 'cash' &&
                saleChange > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                Text('Change Paid',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14)),
                const Spacer(),
                Text(
                    CurrencyFormatter.format(saleChange),
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ]),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogCtx).pop(),
              child: Text('Dismiss',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.of(ctx).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          ReceiptScreen(sale: sale)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('View Receipt',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ],
        ),
      );
    }
  }
}