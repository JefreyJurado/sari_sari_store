import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import 'barcode_scanner_screen.dart';
import 'receipt_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _search = '';
  String _category = 'Lahat';
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
        final mc = _category == 'Lahat' || p.category == _category;
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
          title: const Text('Benta'),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: 'Barcode Scanner',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const BarcodeScannerScreen())),
            ),
            if (prov.cartItemCount > 0)
              Badge(
                label: Text('${prov.cartItemCount}'),
                child: IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () => _showCart(context, prov)),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.shopping_cart_outlined),
              ),
          ],
        ),
        body: Column(children: [
          // Search bar
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
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Hanapin ang produkto...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
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
          const SizedBox(height: 10),

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
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF2E7D32)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
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

          // Products
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
                : _ProductGrid(
                    products: filtered,
                    cart: prov.cart,
                    onAdd: prov.addToCart,
                    onRemove: (p) {
                      final qty = prov.cart[p] ?? 0;
                      prov.setCartQty(p, qty - 1);
                    },
                  ),
          ),
        ]),

        // Checkout button
        bottomNavigationBar: prov.cartItemCount > 0
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _showCart(context, prov),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16)),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${prov.cartItemCount} item  •  ${CurrencyFormatter.format(prov.cartTotal)}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Text('I-checkout →',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
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
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CartSheet(prov: prov),
    );
  }
}

// ── Product Grid ──────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Map<Product, int> cart;
  final void Function(Product) onAdd;
  final void Function(Product) onRemove;

  const _ProductGrid({
    required this.products,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.05,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        final qty = cart[p] ?? 0;
        final inCart = qty > 0;

        return GestureDetector(
          onTap: p.isOutOfStock ? null : () => onAdd(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: inCart
                  ? Border.all(
                      color: const Color(0xFF2E7D32), width: 2)
                  : Border.all(
                      color: Colors.transparent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: inCart
                      ? const Color(0xFF2E7D32)
                          .withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      FilipinoCategories.emoji(p.category),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const Spacer(),
                    if (p.isOutOfStock)
                      _badge('Ubos', Colors.red)
                    else if (p.isLowStock)
                      _badge('${p.stock}', Colors.orange)
                    else if (inCart)
                      _badge('$qty', const Color(0xFF2E7D32)),
                  ]),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: Text(
                        CurrencyFormatter.format(p.sellPrice),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                            fontSize: 14),
                      ),
                    ),
                    if (inCart) ...[
                      _smallBtn(
                          Icons.remove,
                          Colors.grey.shade100,
                          Colors.grey.shade700,
                          () => onRemove(p)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6),
                        child: Text('$qty',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      _smallBtn(
                          Icons.add,
                          const Color(0xFF2E7D32),
                          Colors.white,
                          () => onAdd(p)),
                    ] else
                      _smallBtn(
                          Icons.add,
                          p.isOutOfStock
                              ? Colors.grey.shade100
                              : const Color(0xFF2E7D32),
                          p.isOutOfStock
                              ? Colors.grey.shade400
                              : Colors.white,
                          p.isOutOfStock ? () {} : () => onAdd(p)),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
              color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: fg),
        ),
      );
}

// ── Cart Sheet ────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  final AppProvider prov;
  const _CartSheet({required this.prov});
  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _cashCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _paymentType = 'cash';
  bool _isProcessing = false;

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
          // Handle
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('Cart',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  prov.clearCart();
                  Navigator.pop(context);
                },
                child: const Text('I-clear',
                    style: TextStyle(color: Colors.red)),
              ),
            ]),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                // Cart items
                ...prov.cart.entries.map((e) => Container(
                      margin:
                          const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32)
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              FilipinoCategories.emoji(
                                  e.key.category),
                              style: const TextStyle(
                                  fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text(e.key.name,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                                CurrencyFormatter.format(
                                    e.key.sellPrice),
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12)),
                          ]),
                        ),
                        Row(children: [
                          GestureDetector(
                            onTap: () => setState(() =>
                                prov.setCartQty(
                                    e.key, e.value - 1)),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.remove,
                                  size: 16,
                                  color: Colors.grey),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10),
                            child: Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                          GestureDetector(
                            onTap: () => setState(
                                () => prov.addToCart(e.key)),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add,
                                  size: 16,
                                  color: Colors.white),
                            ),
                          ),
                        ]),
                        const SizedBox(width: 10),
                        Text(
                          CurrencyFormatter.format(
                              e.key.sellPrice * e.value),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ]),
                    )),

                const SizedBox(height: 8),

                // Total
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Text('KABUUAN',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF2E7D32))),
                    const Spacer(),
                    Text(
                        CurrencyFormatter.format(
                            prov.cartTotal),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Color(0xFF2E7D32))),
                  ]),
                ),
                const SizedBox(height: 20),

                // Payment type label
                const Text('Uri ng Bayad',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 10),

                // CASH
                _paymentBtn(
                  icon: Icons.payments_outlined,
                  label: 'Cash',
                  sublabel: 'Bayad sa kamay',
                  color: const Color(0xFF2E7D32),
                  selected: _paymentType == 'cash',
                  onTap: () => setState(() {
                    _paymentType = 'cash';
                    _cashCtrl.text =
                        prov.cartTotal.toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 8),

                // ONLINE
                _paymentBtn(
                  icon: Icons.phone_android_outlined,
                  label: 'Online Payment',
                  sublabel: 'GCash / PayMaya / Bank',
                  color: Colors.blue,
                  selected: _paymentType == 'online',
                  onTap: () => setState(() {
                    _paymentType = 'online';
                    _cashCtrl.text =
                        prov.cartTotal.toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 16),

                // Cash input
                if (_paymentType == 'cash') ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _cashCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Ibinigay na Cash (₱)',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  if (change > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blue
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.currency_exchange,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 10),
                        const Text('Sukli:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.blue)),
                        const Spacer(),
                        Text(CurrencyFormatter.format(change),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                                color: Colors.blue)),
                      ]),
                    ),
                  ],
                ],

                // Online ref
                if (_paymentType == 'online') ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _refCtrl,
                      decoration: InputDecoration(
                        labelText: 'Reference Number (optional)',
                        prefixIcon: const Icon(
                            Icons.confirmation_number_outlined),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'hal: 123456789',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'I-check ang GCash/PayMaya mo bago i-confirm ang bayad.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue),
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // Pay button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _complete,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16)),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : Text(
                            'Bayad  —  ${CurrencyFormatter.format(prov.cartTotal)}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
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

  Widget _paymentBtn({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color
                  : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? color : Colors.black87,
                      fontSize: 14)),
              Text(sublabel,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12)),
            ]),
            const Spacer(),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    color: Colors.white, size: 14),
              ),
          ]),
        ),
      );

  Future<void> _complete() async {
    if (prov.cart.isEmpty) return;

    if (_paymentType == 'cash' && cashPaid < prov.cartTotal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hindi sapat ang cash!'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);

    final notes =
        _paymentType == 'online' && _refCtrl.text.isNotEmpty
            ? 'Online Payment - Ref#: ${_refCtrl.text}'
            : _paymentType == 'online'
                ? 'Online Payment'
                : null;

    final sale = await prov.completeSale(
      cashPaid: prov.cartTotal,
      creditAmount: 0,
      type: PaymentType.cash,
      notes: notes,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (sale != null) {
      final ctx = context;
      final paymentType = _paymentType;
      final refText = _refCtrl.text;

      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(
            paymentType == 'online'
                ? 'Online Payment Confirmed!'
                : 'Bayad na!',
            style: const TextStyle(fontSize: 18),
          ),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('${sale.items.length} produkto',
                style: TextStyle(color: Colors.grey[600])),
            if (paymentType == 'online' && refText.isNotEmpty)
              Text('Ref#: $refText',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600)),
            const Divider(),
            Row(children: [
              const Text('Total:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                  CurrencyFormatter.format(sale.totalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF2E7D32))),
            ]),
            if (paymentType == 'cash' && sale.change > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Text('Sukli:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                      CurrencyFormatter.format(sale.change),
                      style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ]),
              ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Isara'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) =>
                          ReceiptScreen(sale: sale)),
                );
              },
              child: const Text('Tingnan Receipt'),
            ),
          ],
        ),
      );
    }
  }
}