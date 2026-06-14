import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import 'barcode_scanner_screen.dart';
import 'inventory_log_screen.dart';
import '../services/database_service.dart';

const _uuid = Uuid();
const _blue = Color(0xFF1E3A8A);

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String _sortBy = 'name';

  void _confirmClearDefaults(BuildContext context, AppProvider prov) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear Default Products',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_outlined, color: Colors.red.shade600, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This will archive all current products. This cannot be undone.',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              for (final product in prov.products) {
                await prov.archiveProduct(product.id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All products cleared successfully.'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Clear All',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _getFilteredAndSortedProducts(List<Product> sourceProducts) {
    final query = _search.trim().toLowerCase();
    final list = query.isEmpty
        ? List<Product>.from(sourceProducts)
        : sourceProducts.where((p) => p.name.toLowerCase().contains(query)).toList();
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Selector<AppProvider, ({ List<Product> list, int lowCount, int outCount })>(
          selector: (_, prov) => (
            list: prov.products,
            lowCount: prov.lowStock.length,
            outCount: prov.outOfStock.length,
          ),
          builder: (context, data, _) {
            final products = _getFilteredAndSortedProducts(data.list);
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Products',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          Text('Manage store items and real-time stock',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ],
                      ),
                      Row(children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner_outlined,
                              color: Colors.black54, size: 22),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const BarcodeScannerScreen())),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) => setState(() => _sortBy = v),
                          icon: const Icon(Icons.sort_outlined, color: Colors.black54, size: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'name', child: Text('Sort by Name', style: TextStyle(fontSize: 13))),
                            PopupMenuItem(value: 'stock', child: Text('Sort by Stock', style: TextStyle(fontSize: 13))),
                            PopupMenuItem(value: 'price', child: Text('Sort by Price', style: TextStyle(fontSize: 13))),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_outlined, color: Colors.black54, size: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'inventory_log',
                              child: Row(children: [
                                Icon(Icons.table_chart_outlined, size: 16, color: _blue),
                                SizedBox(width: 8),
                                Text('Inventory Control Log', style: TextStyle(fontSize: 13, color: _blue)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'clear_defaults',
                              child: Row(children: [
                                Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Clear Default Products', style: TextStyle(fontSize: 13, color: Colors.red)),
                              ]),
                            ),
                          ],
                          onSelected: (v) {
                            if (v == 'clear_defaults') {
                              _confirmClearDefaults(context, context.read<AppProvider>());
                            } else if (v == 'inventory_log') {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const InventoryLogScreen()));
                            }
                          },
                        ),
                      ])
                    ],
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _statChip('${products.length}', 'Products'),
                      const SizedBox(width: 8),
                      _statChip('${data.lowCount}', 'Low Stock'),
                      const SizedBox(width: 8),
                      _statChip('${data.outCount}', 'Out of Stock'),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: Icon(Icons.search_outlined, color: Colors.grey[400], size: 20),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (products.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No products found',
                              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                        ]),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      itemBuilder: (listCtx, i) {
                        final item = products[i];
                        return _ProductTile(
                          product: item,
                          prov: context.read<AppProvider>(),
                          onEdit: () => _showForm(context, context.read<AppProvider>(), item),
                          onArchive: () => _confirmArchive(context, context.read<AppProvider>(), item),
                          onAdjust: () => _adjustStock(context, context.read<AppProvider>(), item),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add',
        onPressed: () => _showForm(context, context.read<AppProvider>(), null),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Product',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _statChip(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _blue.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, color: _blue, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: _blue.withValues(alpha: 0.8), fontSize: 11)),
        ]),
      );

  void _showForm(BuildContext context, AppProvider prov, Product? existing) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final buyCtrl = TextEditingController(
        text: existing != null ? existing.buyPrice.toStringAsFixed(2) : '');
    final sellCtrl = TextEditingController(
        text: existing != null ? existing.sellPrice.toStringAsFixed(2) : '');
    final stockCtrl = TextEditingController(text: existing?.stock.toString() ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'pcs');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ProductFormSheet(
        existing: existing,
        prov: prov,
        nameCtrl: nameCtrl,
        buyCtrl: buyCtrl,
        sellCtrl: sellCtrl,
        stockCtrl: stockCtrl,
        unitCtrl: unitCtrl,
        initialCategory:
            existing?.category ?? FilipinoCategories.productCategories.first,
      ),
    ).then((saved) {
      nameCtrl.dispose();
      buyCtrl.dispose();
      sellCtrl.dispose();
      stockCtrl.dispose();
      unitCtrl.dispose();
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _adjustStock(BuildContext screenCtx, AppProvider prov, Product product) {
    showDialog(
        context: screenCtx,
        builder: (dialogCtx) => _StockAdjustDialog(product: product, prov: prov));
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
              
              ScaffoldMessenger.of(screenCtx).showSnackBar(
                SnackBar(
                  content: Text('"${product.name}" archived successfully.'),
                  backgroundColor: Colors.grey[800],
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Archive',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Product Form Sheet ─────────────────────────────────────────
class _ProductFormSheet extends StatefulWidget {
  final Product? existing;
  final AppProvider prov;
  final TextEditingController nameCtrl;
  final TextEditingController buyCtrl;
  final TextEditingController sellCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController unitCtrl;
  final String initialCategory;

  const _ProductFormSheet({
    required this.existing,
    required this.prov,
    required this.nameCtrl,
    required this.buyCtrl,
    required this.sellCtrl,
    required this.stockCtrl,
    required this.unitCtrl,
    required this.initialCategory,
  });

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late String _category;
  String _markupType = '%';
  String _seasonalTag = 'None';
  DateTime? _expiryDate;
  final _markupCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  final _supplierNameCtrl = TextEditingController();
  final _supplierContactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _seasonalTag = widget.existing?.seasonalTag ?? 'None';
    _expiryDate = widget.existing?.expiryDate;
    _reorderCtrl.text = (widget.existing?.reorderPoint ?? 5).toString();
    _supplierNameCtrl.text = widget.existing?.supplierName ?? '';
    _supplierContactCtrl.text = widget.existing?.supplierContact ?? '';
    widget.buyCtrl.addListener(_applyMarkup);
    _markupCtrl.addListener(_applyMarkup);
  }

  @override
  void dispose() {
    widget.buyCtrl.removeListener(_applyMarkup);
    _markupCtrl.removeListener(_applyMarkup);
    _markupCtrl.dispose();
    _reorderCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierContactCtrl.dispose();
    super.dispose();
  }

  void _applyMarkup() {
    final buy = double.tryParse(widget.buyCtrl.text) ?? 0;
    final markup = double.tryParse(_markupCtrl.text) ?? 0;
    if (buy <= 0 || markup <= 0) return;
    double sell;
    if (_markupType == '%') {
      sell = buy + (buy * markup / 100);
    } else {
      sell = buy + markup;
    }
    final newSell = sell.toStringAsFixed(2);
    if (widget.sellCtrl.text != newSell) {
      widget.sellCtrl.text = newSell;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(widget.existing == null ? 'Add Product' : 'Edit Product',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 16),

          _field(widget.nameCtrl, 'Product name *', Icons.label_outline),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            borderRadius: BorderRadius.circular(10),
            items: FilipinoCategories.productCategories
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(FilipinoCategories.getIcon(c), size: 16, color: _blue),
                      const SizedBox(width: 8),
                      Text(c, style: const TextStyle(fontSize: 13)),
                    ])))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _field(widget.buyCtrl, 'Cost price', Icons.arrow_downward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
            const SizedBox(width: 12),
            Expanded(child: _field(widget.sellCtrl, 'Sell price', Icons.arrow_upward_outlined, keyboardType: TextInputType.number, prefix: '₱ ')),
          ]),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _blue.withValues(alpha: 0.12)),
            ),
            child: Row(children: [
              const Icon(Icons.trending_up_outlined, size: 16, color: _blue),
              const SizedBox(width: 8),
              const Text('Markup:', style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _markupType = _markupType == '%' ? '₱' : '%';
                  _applyMarkup();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(6)),
                  child: Text(_markupType,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _markupCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: _markupType == '%' ? 'e.g. 15' : 'e.g. 2.00',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    suffixText: _markupType,
                    suffixStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('→ auto sell price', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ]),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _field(widget.stockCtrl, 'Stock qty', Icons.inventory_2_outlined, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _field(widget.unitCtrl, 'Unit (pcs, kg...)', Icons.straighten_outlined)),
          ]),
          const SizedBox(height: 12),

          _field(_reorderCtrl, 'Reorder Point (alert when stock ≤)', Icons.notification_important_outlined, keyboardType: TextInputType.number),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _expiryDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                Icon(Icons.calendar_month_outlined, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _expiryDate != null
                        ? 'Expiry: ${_expiryDate!.month}/${_expiryDate!.day}/${_expiryDate!.year}'
                        : 'Expiry Date (optional)',
                    style: TextStyle(
                        fontSize: 13,
                        color: _expiryDate != null ? Colors.black87 : Colors.grey[400]),
                  ),
                ),
                if (_expiryDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _expiryDate = null),
                    child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          _field(_supplierNameCtrl, 'Supplier Name (optional)', Icons.store_outlined),
          const SizedBox(height: 8),
          _field(_supplierContactCtrl, 'Supplier Contact (optional)', Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _seasonalTag,
            decoration: InputDecoration(
              labelText: 'Seasonal Tag',
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              prefixIcon: Icon(Icons.local_offer_outlined, size: 18, color: Colors.grey[500]),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            borderRadius: BorderRadius.circular(10),
            items: Product.seasonalTags
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _seasonalTag = v);
            },
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (widget.nameCtrl.text.trim().isEmpty) return;
                final p = Product(
                  id: widget.existing?.id ?? _uuid.v4(),
                  name: widget.nameCtrl.text.trim(),
                  category: _category,
                  buyPrice: double.tryParse(widget.buyCtrl.text) ?? 0,
                  sellPrice: double.tryParse(widget.sellCtrl.text) ?? 0,
                  stock: int.tryParse(widget.stockCtrl.text) ?? 0,
                  unit: widget.unitCtrl.text.trim().isEmpty ? 'pcs' : widget.unitCtrl.text.trim(),
                  createdAt: widget.existing?.createdAt ?? DateTime.now(),
                  reorderPoint: int.tryParse(_reorderCtrl.text) ?? 5,
                  expiryDate: _expiryDate,
                  supplierName: _supplierNameCtrl.text.trim().isEmpty ? null : _supplierNameCtrl.text.trim(),
                  supplierContact: _supplierContactCtrl.text.trim().isEmpty ? null : _supplierContactCtrl.text.trim(),
                  seasonalTag: _seasonalTag == 'None' ? null : _seasonalTag,
                );
                final isNew = widget.existing == null;
                Navigator.of(context, rootNavigator: true).pop(true);
                if (isNew) {
                  widget.prov.addProduct(p);
                } else {
                  widget.prov.updateProduct(p);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(widget.existing == null ? 'Save Product' : 'Update Product',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text, String? prefix}) =>
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
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      );
}

// ── Stock Adjust Dialog ────────────────────────────────────────
class _StockAdjustDialog extends StatefulWidget {
  final Product product;
  final AppProvider prov;
  const _StockAdjustDialog({required this.product, required this.prov});
  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Adjust Stock',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            Icon(FilipinoCategories.getIcon(widget.product.category), size: 20, color: _blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                Text('Current: ${widget.product.stock} ${widget.product.unit}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(
            labelText: 'Add / Remove',
            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            hintText: 'e.g. +10 or -5',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        TextButton(
          onPressed: () {
            final adj = int.tryParse(_ctrl.text);
            if (adj == null) return;
            final newStock = (widget.product.stock + adj).clamp(0, 99999);
            widget.prov.updateProduct(widget.product.copyWith(stock: newStock));
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stock adjusted to $newStock for "${widget.product.name}".'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('Apply',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}

// ── Product Tile ───────────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onAdjust;
  final AppProvider prov;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onArchive,
    required this.onAdjust,
    required this.prov,
  });

  String _seasonalEmoji(String tag) {
    switch (tag) {
      case 'Typhoon Season': return '🌧️ Typhoon';
      case 'Christmas': return '🎄 Christmas';
      case 'Back to School': return '✏️ School';
      case 'Fiesta': return '🎉 Fiesta';
      case 'Summer': return '☀️ Summer';
      default: return tag;
    }
  }

  Widget _infoRow(String label, String value, {Color? valueColor, bool bold = false}) =>
      Row(children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? Colors.black87)),
      ]);

  void _showProductDetails(BuildContext context) async {
    final income = await DatabaseService.instance.getProductIncome(product.id);
    if (!context.mounted) return;

    final totalQty = (income['totalQty'] as num?)?.toInt() ?? 0;
    final totalRevenue = (income['totalRevenue'] as num?)?.toDouble() ?? 0;
    final totalCost = (income['totalCost'] as num?)?.toDouble() ?? 0;
    final totalProfit = (income['totalProfit'] as num?)?.toDouble() ?? 0;
    final margin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(FilipinoCategories.getIcon(product.category),
                    size: 22, color: _blue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                Text(product.category,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
            ),
          ]),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: [
              _infoRow('Cost Price', CurrencyFormatter.format(product.buyPrice)),
              const SizedBox(height: 8),
              _infoRow('Sell Price', CurrencyFormatter.format(product.sellPrice)),
              const SizedBox(height: 8),
              _infoRow('Profit per Unit', CurrencyFormatter.format(product.profit),
                  valueColor: Colors.green.shade600),
              const SizedBox(height: 8),
              _infoRow('Margin', '${product.margin.toStringAsFixed(1)}%',
                  valueColor: Colors.green.shade600),
              Divider(height: 20, color: Colors.grey.shade200),
              _infoRow('Current Stock', '${product.stock} ${product.unit ?? 'pcs'}'),
              const SizedBox(height: 8),
              _infoRow('Reorder Point', '≤ ${product.reorderPoint} ${product.unit ?? 'pcs'}'),
              if (product.expiryDate != null) ...[
                const SizedBox(height: 8),
                _infoRow(
                  'Expiry Date',
                  '${product.expiryDate!.month}/${product.expiryDate!.day}/${product.expiryDate!.year}',
                  valueColor: product.isExpired
                      ? Colors.red
                      : product.isNearExpiry
                          ? Colors.orange
                          : null,
                ),
              ],
              if (product.supplierName != null) ...[
                const SizedBox(height: 8),
                _infoRow('Supplier', product.supplierName!),
              ],
              if (product.supplierContact != null) ...[
                const SizedBox(height: 8),
                _infoRow('Contact', product.supplierContact!),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _blue.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.analytics_outlined, size: 16, color: _blue),
                const SizedBox(width: 8),
                const Text('Sales Income Summary',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
              ]),
              const SizedBox(height: 12),
              _infoRow('Total Units Sold', '$totalQty ${product.unit ?? 'pcs'}'),
              const SizedBox(height: 8),
              _infoRow('Total Revenue', CurrencyFormatter.format(totalRevenue)),
              const SizedBox(height: 8),
              _infoRow('Total Cost', CurrencyFormatter.format(totalCost),
                  valueColor: Colors.red.shade400),
              Divider(height: 20, color: _blue.withValues(alpha: 0.15)),
              _infoRow('Total Profit', CurrencyFormatter.format(totalProfit),
                  valueColor: Colors.green.shade600, bold: true),
              const SizedBox(height: 8),
              _infoRow('Profit Margin', '${margin.toStringAsFixed(1)}%',
                  valueColor: Colors.green.shade600, bold: true),
            ]),
          ),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onEdit();
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: BorderSide(color: _blue.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAdjust();
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Adjust Stock', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOut = product.stock <= 0;
    final isLow = product.isLowStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isOut
                ? Colors.red.shade100
                : isLow
                    ? Colors.orange.shade100
                    : Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showProductDetails(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          child: Center(
              child: Icon(FilipinoCategories.getIcon(product.category), size: 20, color: _blue)),
        ),
        title: Row(children: [
          Expanded(
            child: Text(product.name,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isOut ? Colors.grey[400] : Colors.black87)),
          ),
          if (product.seasonalTag != null)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                _seasonalEmoji(product.seasonalTag!),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          if (product.isExpired)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text('EXPIRED', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
            )
          else if (product.isNearExpiry)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('EXP SOON', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost: ${CurrencyFormatter.format(product.buyPrice)}  •  Sell: ${CurrencyFormatter.format(product.sellPrice)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            if (product.supplierName != null)
              Text(
                '🏪 ${product.supplierName}',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            if (product.expiryDate != null && !product.isExpired && !product.isNearExpiry)
              Text(
                'Exp: ${product.expiryDate!.month}/${product.expiryDate!.day}/${product.expiryDate!.year}',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
          ],
        ),
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_outlined, color: Colors.grey[400], size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Edit', style: TextStyle(fontSize: 13, color: Colors.grey[700]))
                  ])),
              PopupMenuItem(
                  value: 'stock',
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Adjust Stock', style: TextStyle(fontSize: 13, color: Colors.grey[700]))
                  ])),
              const PopupMenuItem(
                  value: 'archive',
                  child: Row(children: [
                    Icon(Icons.archive_outlined, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Archive', style: TextStyle(fontSize: 13, color: Colors.red))
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