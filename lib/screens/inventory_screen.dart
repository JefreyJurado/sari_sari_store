import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';

const _uuid = Uuid();

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
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('Mga Produkto'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => _sortBy = v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'name',
                    child: Text('Ayusin: Pangalan')),
                PopupMenuItem(
                    value: 'stock',
                    child: Text('Ayusin: Stock')),
                PopupMenuItem(
                    value: 'price',
                    child: Text('Ayusin: Presyo')),
              ],
              icon: const Icon(Icons.sort_outlined),
            ),
          ],
        ),
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
                const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                _statBadge('${products.length}', 'Produkto',
                    Colors.white),
                _divider(),
                _statBadge('${prov.lowStock.length}',
                    'Mababa', Colors.yellow),
                _divider(),
                _statBadge('${prov.outOfStock.length}',
                    'Ubos', Colors.red[200]!),
              ],
            ),
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
                    color:
                        Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Hanapin ang produkto...',
                  hintStyle:
                      TextStyle(color: Colors.grey[400]),
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
          ),
          const SizedBox(height: 8),

          // Product list
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Walang produkto',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16)),
                    ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        16, 4, 16, 16),
                    itemCount: products.length,
                    itemBuilder: (_, i) => _ProductTile(
                      product: products[i],
                      onEdit: () => _showForm(
                          context, prov, products[i]),
                      onArchive: () => _confirmArchive(
                          context, prov, products[i]),
                      onAdjust: () => _adjustStock(
                          context, prov, products[i]),
                    ),
                  ),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showForm(context, prov, null),
          icon: const Icon(Icons.add),
          label: const Text('Dagdag Produkto'),
        ),
      );
    });
  }

  Widget _statBadge(String value, String label, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.white70)),
      ]);

  Widget _divider() => Container(
        height: 32,
        width: 1,
        color: Colors.white.withValues(alpha: 0.3),
      );

  void _showForm(
      BuildContext context, AppProvider prov, Product? existing) {
    final nameCtrl =
        TextEditingController(text: existing?.name);
    final buyCtrl = TextEditingController(
        text: existing != null
            ? existing.buyPrice.toStringAsFixed(2)
            : '');
    final sellCtrl = TextEditingController(
        text: existing != null
            ? existing.sellPrice.toStringAsFixed(2)
            : '');
    final stockCtrl = TextEditingController(
        text: existing?.stock.toString() ?? '');
    final unitCtrl =
        TextEditingController(text: existing?.unit ?? 'pcs');
    String category = existing?.category ??
        FilipinoCategories.productCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F6FA),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius:
                          BorderRadius.circular(2)),
                ),
              ),
              Text(
                  existing == null
                      ? 'Dagdag Produkto'
                      : 'I-edit ang Produkto',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _field(nameCtrl, 'Pangalan ng Produkto *',
                  Icons.label_outlined),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'Kategorya',
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                borderRadius: BorderRadius.circular(12),
                items: FilipinoCategories.productCategories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                            '${FilipinoCategories.emoji(c)} $c')))
                    .toList(),
                onChanged: (v) =>
                    setS(() => category = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _field(buyCtrl, 'Presyo ng Bili',
                      Icons.arrow_downward_outlined,
                      keyboardType: TextInputType.number,
                      prefix: '₱ '),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                      sellCtrl,
                      'Presyo ng Benta',
                      Icons.arrow_upward_outlined,
                      keyboardType: TextInputType.number,
                      prefix: '₱ '),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _field(
                      stockCtrl, 'Stock', Icons.inventory_outlined,
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(unitCtrl, 'Unit (pcs, kg...)',
                      Icons.straighten_outlined),
                ),
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
                      buyPrice:
                          double.tryParse(buyCtrl.text) ?? 0,
                      sellPrice:
                          double.tryParse(sellCtrl.text) ??
                              0,
                      stock:
                          int.tryParse(stockCtrl.text) ?? 0,
                      unit: unitCtrl.text.trim().isEmpty
                          ? 'pcs'
                          : unitCtrl.text.trim(),
                      createdAt: existing?.createdAt ??
                          DateTime.now(),
                    );
                    if (existing == null) {
                      await prov.addProduct(p);
                    } else {
                      await prov.updateProduct(p);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14)),
                  child: Text(
                      existing == null
                          ? 'I-save ang Produkto'
                          : 'I-update ang Produkto',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
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
          prefixIcon: Icon(icon, size: 20),
          prefixText: prefix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  void _adjustStock(
      BuildContext context, AppProvider prov, Product product) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Adjust Stock'),
        content:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  Text(
                      'Kasalukuyang: ${product.stock} ${product.unit ?? 'pcs'}',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(
                    signed: true),
            decoration: InputDecoration(
              labelText: 'Dagdag/Bawas',
              hintText: 'hal: +10 o -5',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () {
              final adj = int.tryParse(ctrl.text);
              if (adj == null) return;
              final newStock =
                  (product.stock + adj).clamp(0, 99999);
              prov.updateProduct(
                  product.copyWith(stock: newStock));
              Navigator.pop(context);
            },
            child: const Text('I-apply'),
          ),
        ],
      ),
    );
  }

  void _confirmArchive(
      BuildContext context, AppProvider prov, Product product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('I-archive ang Produkto'),
        content: Text(
            'I-archive ang "${product.name}"?\nHindi na ito lalabas sa benta.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kanselahin')),
          ElevatedButton(
            onPressed: () {
              prov.archiveProduct(product.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('I-archive'),
          ),
        ],
      ),
    );
  }
}

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
    Color sc = const Color(0xFF2E7D32);
    if (product.isOutOfStock) sc = Colors.red;
    else if (product.isLowStock) sc = Colors.orange;

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
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: Text(
                  FilipinoCategories.emoji(product.category),
                  style: const TextStyle(fontSize: 22))),
        ),
        title: Text(product.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
            'Bili: ${CurrencyFormatter.format(product.buyPrice)}  •  Benta: ${CurrencyFormatter.format(product.sellPrice)}',
            style: TextStyle(
                fontSize: 12, color: Colors.grey[500])),
        trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
          GestureDetector(
            onTap: onAdjust,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${product.stock}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: sc,
                      fontSize: 14)),
            ),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert,
                color: Colors.grey[400], size: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined,
                        size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('I-edit'),
                  ])),
              PopupMenuItem(
                  value: 'stock',
                  child: Row(children: [
                    Icon(Icons.inventory_outlined,
                        size: 18,
                        color: Color(0xFF2E7D32)),
                    SizedBox(width: 8),
                    Text('Adjust Stock'),
                  ])),
              PopupMenuItem(
                  value: 'archive',
                  child: Row(children: [
                    Icon(Icons.archive_outlined,
                        size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('I-archive',
                        style:
                            TextStyle(color: Colors.red)),
                  ])),
            ],
            onSelected: (v) {
              if (v == 'edit') onEdit();
              else if (v == 'stock') onAdjust();
              else if (v == 'archive') onArchive();
            },
          ),
        ]),
      ),
    );
  }
}