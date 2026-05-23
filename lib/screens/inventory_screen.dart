import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import 'barcode_scanner_screen.dart';

const _uuid = Uuid();
const _blue = Color(0xFF1E3A8A);

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';
  String _sortBy = 'name';

  List<Product> _filtered(List<Product> products) {
    var list = products
        .where((p) =>
            _search.isEmpty ||
            p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    switch (_sortBy) {
      case 'stock':
        list.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'price':
        list.sort((a, b) => b.sellPrice.compareTo(a.sellPrice));
        break;
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      final products = _filtered(prov.products);

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: const Text('Products',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined,
                  color: Colors.black54, size: 22),
              tooltip: 'Scan Barcode',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BarcodeScannerScreen())),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => _sortBy = v),
              icon: const Icon(Icons.sort_outlined,
                  color: Colors.black54, size: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'name',
                    child: Text('Sort by Name',
                        style: TextStyle(fontSize: 13))),
                PopupMenuItem(
                    value: 'stock',
                    child: Text('Sort by Stock',
                        style: TextStyle(fontSize: 13))),
                PopupMenuItem(
                    value: 'price',
                    child: Text('Sort by Price',
                        style: TextStyle(fontSize: 13))),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: Column(children: [
          // ── Search + Stats ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              // Stats row
              Row(children: [
                _statChip('${products.length}', 'Products', Colors.black87),
                const SizedBox(width: 8),
                _statChip('${prov.lowStock.length}', 'Low Stock', Colors.orange),
                const SizedBox(width: 8),
                _statChip('${prov.outOfStock.length}', 'Out of Stock', Colors.red),
              ]),
              const SizedBox(height: 10),

              // Search bar
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_outlined, color: Colors.grey[400], size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 10),

              // Barcode banner
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BarcodeScannerScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.qr_code_scanner_outlined, color: Colors.grey[500], size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Scan Barcode',
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
                        Text('Add products faster',
                            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ]),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 12),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // ── Product List ───────────────────────────────
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No products found',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: products.length,
                    itemBuilder: (listCtx, i) => _ProductTile(
                      product: products[i],
                      onEdit: () => _showForm(context, prov, products[i]),
                      onArchive: () => _confirmArchive(context, prov, products[i]),
                      onAdjust: () => _adjustStock(context, prov, products[i]),
                    ),
                  ),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add',
          onPressed: () => _showForm(context, prov, null),
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Product',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    });
  }

  // FIXED: Removed invalid const keyword prefixing dynamic string injection evaluation
  Widget _statChip(String value, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _blue.withOpacity(0.2), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _blue,
                  fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: _blue.withOpacity(0.8),
                  fontSize: 11)),
        ]),
      );

  void _showForm(BuildContext context, AppProvider prov, Product? existing) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final buyCtrl = TextEditingController(text: existing != null ? existing.buyPrice.toStringAsFixed(2) : '');
    final sellCtrl = TextEditingController(text: existing != null ? existing.sellPrice.toStringAsFixed(2) : '');
    final stockCtrl = TextEditingController(text: existing?.stock.toString() ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'pcs');
    String category = existing?.category ?? FilipinoCategories.productCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(existing == null ? 'Add Product' : 'Edit Product',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 16),
            _field(nameCtrl, 'Product name *', Icons.label_outline),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true, fillColor: Colors.grey.shade50,
              ),
              borderRadius: BorderRadius.circular(10),
              items: FilipinoCategories.productCategories
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FilipinoCategories.getIcon(c), size: 16, color: _blue),
                          const SizedBox(width: 8),
                          Text(c, style: const TextStyle(fontSize: 13)),
                        ],
                      )))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(buyCtrl, 'Cost price', Icons.arrow_downward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
              const SizedBox(width: 12),
              Expanded(child: _field(sellCtrl, 'Sell price', Icons.arrow_upward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(stockCtrl, 'Stock qty', Icons.inventory_2_outlined, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field(unitCtrl, 'Unit (pcs, kg...)', Icons.straighten_outlined)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final p = Product(
                    id: existing?.id ?? _uuid.v4(),
                    name: nameCtrl.text.trim(),
                    category: category,
                    buyPrice: double.tryParse(buyCtrl.text) ?? 0,
                    sellPrice: double.tryParse(sellCtrl.text) ?? 0,
                    stock: int.tryParse(stockCtrl.text) ?? 0,
                    unit: unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  );
                  if (existing == null) {
                    await prov.addProduct(p);
                  } else {
                    await prov.updateProduct(p);
                  }
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(existing == null ? 'Save Product' : 'Update Product',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[500]),
          prefixText: prefix,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      );

  void _adjustStock(BuildContext screenCtx, AppProvider prov, Product product) {
    final ctrl = TextEditingController();
    showDialog(
      context: screenCtx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Adjust Stock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Icon(FilipinoCategories.getIcon(product.category), size: 20, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                  Text('Current: ${product.stock} ${product.unit ?? 'pcs'}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: 'Add / Remove',
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              hintText: 'e.g. +10 or -5',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () {
              final adj = int.tryParse(ctrl.text);
              if (adj == null) return;
              final newStock = (product.stock + adj).clamp(0, 99999);
              prov.updateProduct(product.copyWith(stock: newStock));
              Navigator.pop(dialogCtx);
            },
            child: const Text('Apply',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _confirmArchive(BuildContext screenCtx, AppProvider prov, Product product) {
    showDialog(
      context: screenCtx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Archive Product',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        content: Text('Archive "${product.name}"? It will no longer appear in sales.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () {
              prov.archiveProduct(product.id);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Archive',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Product Tile ──────────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onAdjust;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onArchive,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = product.isOutOfStock;
    final isLow = product.isLowStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOut
              ? Colors.red.shade100
              : isLow
                  ? Colors.orange.shade100
                  : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          child: Center(
              child: Icon(
            FilipinoCategories.getIcon(product.category),
            size: 20,
            color: _blue,
          )),
        ),
        title: Text(product.name,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isOut ? Colors.grey[400] : Colors.black87)),
        subtitle: Text(
            'Cost: ${CurrencyFormatter.format(product.buyPrice)}  •  Sell: ${CurrencyFormatter.format(product.sellPrice)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: onAdjust,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: isOut
                      ? Colors.red.shade50
                      : isLow
                          ? Colors.orange.shade50
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: isOut
                          ? Colors.red.shade200
                          : isLow
                              ? Colors.orange.shade200
                              : Colors.grey.shade300)),
              child: Text('${product.stock}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOut
                          ? Colors.red
                          : isLow
                              ? Colors.orange
                              : Colors.black54,
                      fontSize: 13)),
            ),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert_outlined, color: Colors.grey[400], size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Edit', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ])),
              PopupMenuItem(
                  value: 'stock',
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Adjust Stock', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ])),
              PopupMenuItem(
                  value: 'archive',
                  child: Row(children: [
                    const Icon(Icons.archive_outlined, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Archive', style: TextStyle(fontSize: 13, color: Colors.red)),
                  ])),
            ],
            onSelected: (v) {
              if (v == 'edit') {
                onEdit();
              } else if (v == 'stock') {
                onAdjust();
              } else if (v == 'archive') {
                onArchive();
              }
            },
          ),
        ]),
      ),
    );
  }
}