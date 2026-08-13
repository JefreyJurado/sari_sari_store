import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/grocery_entry.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/filipino_categories.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/search_field.dart';
import '../widgets/help_sheet.dart';

const _blue = AppColors.blue;
const _green = AppColors.green;
const _uuid = Uuid();

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});
  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static final _monthYearFormat = DateFormat('MMMM yyyy');
  static final _shortMonthDayFormat = DateFormat('MMM d');

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-').map(int.parse).toList();
    return _monthYearFormat.format(DateTime(parts[0], parts[1]));
  }

  String _weekLabel(String weekKey) {
    final parts = weekKey.split('-').map(int.parse).toList();
    final monday = DateTime(parts[0], parts[1], parts[2]);
    final sunday = monday.add(const Duration(days: 6));
    final sameMonth =
        monday.month == sunday.month && monday.year == sunday.year;
    final start = _shortMonthDayFormat.format(monday);
    final end = sameMonth
        ? '${sunday.day}'
        : _shortMonthDayFormat.format(sunday);
    return '$start–$end, ${sunday.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      var entries = prov.groceryEntries;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        entries = entries
            .where((g) =>
                g.productName.toLowerCase().contains(q) ||
                (g.notes?.toLowerCase().contains(q) ?? false))
            .toList();
      }
      final monthTotals = prov.groceryTotalsByMonth;
      final weekTotals = prov.groceryTotalsByWeek;

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Grocery Budget',
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
              title: 'Understanding Grocery Budget',
              points: [
                'Use this for store resupply trips — pick the product you bought and how many, and its stock in Inventory updates automatically.',
                'Budget is what you planned to spend; Expenses for Products is what the items actually cost; Transpo is fare/delivery to get them.',
                'Total Expenses = Expenses for Products + Transpo. Change (Sukli) = Budget − Total Expenses — it goes negative if the trip ran over budget.',
                'Editing or deleting an entry automatically corrects the stock it added, so it never gets double-counted or stuck.',
                'General Total adds up every grocery trip ever logged. Weekly Grocery and Monthly Grocery break that down per week and per month so you can see how much resupply cost over time.',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Store resupply trips — adds stock to Inventory automatically',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(children: [
                // General Total card
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blue.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Icon(Icons.shopping_basket_outlined,
                        color: _blue.withValues(alpha: 0.6), size: 18),
                    const SizedBox(width: 10),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('General Total',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                          Text(
                              CurrencyFormatter.format(prov.generalGroceryTotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87)),
                        ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _blue.withValues(alpha: 0.2)),
                      ),
                      child: Text('${entries.length} trips',
                          style: TextStyle(
                              fontSize: 11,
                              color: _blue.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
                if (weekTotals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weekly Grocery',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        ...weekTotals.take(6).map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Expanded(
                                  child: Text(_weekLabel(e.key),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.black87)),
                                ),
                                Text(CurrencyFormatter.format(e.value),
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87)),
                              ]),
                            )),
                      ],
                    ),
                  ),
                ],
                if (monthTotals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Grocery',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        ...monthTotals.take(6).map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Expanded(
                                  child: Text(_monthLabel(e.key),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.black87)),
                                ),
                                Text(CurrencyFormatter.format(e.value),
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87)),
                              ]),
                            )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SearchField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  hintText: 'Search grocery entries...',
                ),
                const SizedBox(height: 10),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.shopping_basket_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No grocery entries yet',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 14)),
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _GroceryTile(
                        entry: entries[i],
                        onDelete: () =>
                            _confirmDelete(context, prov, entries[i]),
                        onEdit: () => _showForm(context, prov, entries[i]),
                      ),
                    ),
            ),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'grocery_fab',
          onPressed: prov.products.isEmpty
              ? () => CenterToast.showError(context,
                  'Add a product in Inventory first before logging a grocery trip.')
              : () => _showForm(context, prov, null),
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Grocery',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    });
  }

  Future<Product?> _pickProduct(BuildContext context, AppProvider prov) {
    final searchCtrl = TextEditingController();
    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          var products = prov.products;
          final q = searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            products =
                products.where((p) => p.name.toLowerCase().contains(q)).toList();
          }
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.7,
              child: Column(children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Text('Select Product',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 14),
                SearchField(
                  controller: searchCtrl,
                  onChanged: (_) => setS(() {}),
                  hintText: 'Search products...',
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final newProduct =
                          await _showQuickAddProduct(context, prov);
                      if (newProduct != null && sheetCtx.mounted) {
                        Navigator.pop(sheetCtx, newProduct);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _blue.withValues(alpha: 0.2)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.add_circle_outline, color: _blue, size: 18),
                        SizedBox(width: 10),
                        Text('Add New Product',
                            style: TextStyle(
                                color: _blue,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Text('No products found',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)))
                      : ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (_, i) {
                            final p = products[i];
                            return ListTile(
                              onTap: () => Navigator.pop(sheetCtx, p),
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87)),
                              subtitle: Text(
                                  'Stock: ${p.stock}${p.unit != null ? ' ${p.unit}' : ''}',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 11.5)),
                              trailing: Icon(Icons.chevron_right,
                                  color: Colors.grey[400], size: 18),
                            );
                          },
                        ),
                ),
              ]),
            ),
          );
        },
      ),
    ).whenComplete(() {
      // Deferred a frame: this sheet and _showQuickAddProduct's sheet can
      // both pop back-to-back in the same tick (create product → auto-
      // select → close both), so their exit transitions overlap. Disposing
      // synchronously here raced that still-animating transition trying to
      // rebuild this now-gone TextField's controller.
      WidgetsBinding.instance.addPostFrameCallback((_) => searchCtrl.dispose());
    });
  }

  // Normalized-substring + shared-significant-word heuristic: catches
  // "Coke 1.5L" vs "Coca-Cola 1.5 Liters" style near-duplicates that a
  // plain substring search wouldn't surface, without needing a full
  // fuzzy-matching library for what's just a typing-mistake safety net.
  bool _looksSimilar(String a, String b) {
    String normalize(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb || na.contains(nb) || nb.contains(na)) return true;
    bool significant(String w) => w.length >= 3;
    final wordsA =
        a.toLowerCase().split(RegExp(r'\s+')).where(significant).toSet();
    final wordsB =
        b.toLowerCase().split(RegExp(r'\s+')).where(significant).toSet();
    return wordsA.intersection(wordsB).isNotEmpty;
  }

  /// Quick product creation from within the Grocery flow, so a resupply
  /// trip for something new doesn't force a detour to the Products
  /// screen and back. Mirrors the minimum fields inventory_screen.dart's
  /// full add-product form requires (name, category, buy/sell price) —
  /// stock starts at 0 since the grocery entry itself adds the quantity
  /// right after this returns. Flags likely-duplicate existing products
  /// as you type the name, so a slightly different spelling of something
  /// already in Inventory doesn't quietly create a second, near-identical
  /// product.
  Future<Product?> _showQuickAddProduct(BuildContext context, AppProvider prov) {
    final nameCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    String category = FilipinoCategories.productCategories.first;
    bool isSaving = false;

    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          final typed = nameCtrl.text.trim();
          final similar = typed.isEmpty
              ? const <Product>[]
              : prov.products
                  .where((p) => _looksSimilar(p.name, typed))
                  .take(3)
                  .toList();

          return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
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
              const Text('Add New Product',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 16),
              _field(nameCtrl, 'Product Name *', Icons.inventory_2_outlined,
                  onChanged: (_) => setS(() {})),
              if (similar.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.warning_amber_outlined,
                            size: 15, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Text('Already in Inventory?',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade900)),
                      ]),
                      const SizedBox(height: 6),
                      ...similar.map((p) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: GestureDetector(
                              onTap: () => Navigator.pop(sheetCtx, p),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                      '${p.name}  (Stock: ${p.stock}${p.unit != null ? ' ${p.unit}' : ''})',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.amber.shade900,
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w600)),
                                ),
                                Icon(Icons.chevron_right,
                                    size: 16, color: Colors.amber.shade800),
                              ]),
                            ),
                          )),
                      const SizedBox(height: 4),
                      Text('Tap one to use it instead of creating a new product.',
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.amber.shade800)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: category,
                    isDense: true,
                    isExpanded: true,
                    items: FilipinoCategories.productCategories
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setS(() => category = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _amountField(buyCtrl, 'Buy Price *')),
                const SizedBox(width: 10),
                Expanded(
                    child: _amountField(sellCtrl, 'Sell Price *')),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            CenterToast.showError(
                                context, 'Product name is required.');
                            return;
                          }
                          final buyPrice = double.tryParse(buyCtrl.text);
                          final sellPrice = double.tryParse(sellCtrl.text);
                          if (buyPrice == null || buyPrice < 0) {
                            CenterToast.showError(
                                context, 'Enter a valid buy price.');
                            return;
                          }
                          if (sellPrice == null || sellPrice < 0) {
                            CenterToast.showError(
                                context, 'Enter a valid sell price.');
                            return;
                          }
                          setS(() => isSaving = true);
                          final product = Product(
                            id: _uuid.v4(),
                            name: nameCtrl.text.trim(),
                            category: category,
                            buyPrice: buyPrice,
                            sellPrice: sellPrice,
                            stock: 0,
                            unit: 'pcs',
                            createdAt: DateTime.now(),
                          );
                          await prov.addProduct(product);
                          if (sheetCtx.mounted) {
                            Navigator.pop(sheetCtx, product);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Product',
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
    ).whenComplete(() {
      // See _pickProduct's whenComplete for why this is deferred a frame
      // rather than disposed synchronously.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        buyCtrl.dispose();
        sellCtrl.dispose();
      });
    });
  }

  void _showForm(BuildContext context, AppProvider prov, GroceryEntry? existing) {
    String? selectedProductId = existing?.productId.isNotEmpty == true
        ? existing!.productId
        : null;
    String selectedProductName = existing?.productName ?? '';
    final quantityCtrl = TextEditingController(
        text: existing != null ? existing.quantity.toString() : '');
    final budgetCtrl = TextEditingController(
        text: existing != null ? existing.budget.toStringAsFixed(2) : '');
    final expensesCtrl = TextEditingController(
        text: existing != null
            ? existing.expensesForProducts.toStringAsFixed(2)
            : '');
    final transpoCtrl = TextEditingController(
        text: existing != null ? existing.transpo.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime entryDate = existing?.date ?? DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final budget = double.tryParse(budgetCtrl.text) ?? 0;
          final expenses = double.tryParse(expensesCtrl.text) ?? 0;
          final transpo = double.tryParse(transpoCtrl.text) ?? 0;
          final total = CurrencyFormatter.roundCents(expenses + transpo);
          final change = CurrencyFormatter.roundCents(budget - total);

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
                Text(
                  existing == null ? 'Add Grocery Entry' : 'Edit Grocery Entry',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickProduct(context, prov);
                    if (picked != null) {
                      setS(() {
                        selectedProductId = picked.id;
                        selectedProductName = picked.name;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selectedProductId == null
                              ? Colors.grey.shade300
                              : _blue),
                    ),
                    child: Row(children: [
                      Icon(Icons.shopping_basket_outlined,
                          size: 18,
                          color: selectedProductId == null
                              ? Colors.grey[500]
                              : _blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedProductId == null
                              ? 'Select Product *'
                              : selectedProductName,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selectedProductId == null
                                  ? Colors.grey[500]
                                  : Colors.black87),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey[400]),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityCtrl,
                  onChanged: (_) => setS(() {}),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Quantity *',
                    hintText: 'e.g. 12',
                    labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Icon(Icons.numbers_outlined,
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
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _amountField(budgetCtrl, 'Budget *',
                        onChanged: (_) => setS(() {})),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _amountField(
                        expensesCtrl, 'Expenses for Products *',
                        onChanged: (_) => setS(() {})),
                  ),
                ]),
                const SizedBox(height: 12),
                _amountField(transpoCtrl, 'Transpo',
                    onChanged: (_) => setS(() {})),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Text('Total Expenses',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey[600])),
                      const Spacer(),
                      Text(CurrencyFormatter.format(total),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('Change (Sukli)',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey[600])),
                      const Spacer(),
                      Text(CurrencyFormatter.format(change),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: change < 0
                                  ? Colors.red.shade600
                                  : _green)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                _field(notesCtrl, 'Notes (optional)', Icons.notes_outlined),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (_, setDate) => GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: entryDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setS(() => entryDate = picked);
                      }
                    },
                    child: Builder(builder: (_) {
                      final isToday =
                          DateHelper.isSameDay(entryDate, DateTime.now());
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday ? Colors.grey.shade300 : _blue,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18,
                              color: isToday ? Colors.grey[500] : _blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isToday
                                  ? 'Today — ${DateHelper.formatDate(entryDate)}'
                                  : 'Past Date — ${DateHelper.formatDate(entryDate)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isToday ? Colors.black87 : _blue),
                            ),
                          ),
                          if (!isToday)
                            GestureDetector(
                              onTap: () =>
                                  setS(() => entryDate = DateTime.now()),
                              child: Icon(Icons.close,
                                  size: 16, color: Colors.grey[400]),
                            ),
                        ]),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (selectedProductId == null) {
                              CenterToast.showError(
                                  context, 'Select a product.');
                              return;
                            }
                            final quantity = int.tryParse(quantityCtrl.text);
                            if (quantity == null || quantity <= 0) {
                              CenterToast.showError(
                                  context, 'Enter a valid quantity.');
                              return;
                            }
                            if (budget <= 0) {
                              CenterToast.showError(
                                  context, 'Enter a valid budget.');
                              return;
                            }
                            if (expenses <= 0) {
                              CenterToast.showError(context,
                                  'Enter valid expenses for products.');
                              return;
                            }
                            setS(() => isSaving = true);
                            if (existing == null) {
                              await prov.addGroceryEntry(
                                productId: selectedProductId!,
                                productName: selectedProductName,
                                quantity: quantity,
                                budget: budget,
                                expensesForProducts: expenses,
                                transpo: transpo,
                                date: entryDate,
                                notes: notesCtrl.text.isEmpty
                                    ? null
                                    : notesCtrl.text,
                              );
                            } else {
                              await prov.updateGroceryEntry(
                                existing.copyWith(
                                  productId: selectedProductId,
                                  productName: selectedProductName,
                                  quantity: quantity,
                                  budget: budget,
                                  expensesForProducts: expenses,
                                  transpo: transpo,
                                  date: entryDate,
                                  notes: notesCtrl.text.isEmpty
                                      ? null
                                      : notesCtrl.text,
                                ),
                              );
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (context.mounted) {
                              CenterToast.showSuccess(
                                  context,
                                  existing == null
                                      ? 'Grocery entry added — stock updated!'
                                      : 'Grocery entry updated!');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            existing == null
                                ? 'Save Grocery Entry'
                                : 'Update Grocery Entry',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          );
        },
      ),
    ).whenComplete(() {
      // See _pickProduct's whenComplete for why this is deferred a frame
      // rather than disposed synchronously.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        quantityCtrl.dispose();
        budgetCtrl.dispose();
        expensesCtrl.dispose();
        transpoCtrl.dispose();
        notesCtrl.dispose();
      });
    });
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
          {String? hint, ValueChanged<String>? onChanged}) =>
      TextField(
        controller: ctrl,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
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

  Widget _amountField(TextEditingController ctrl, String label,
          {ValueChanged<String>? onChanged}) =>
      TextField(
        controller: ctrl,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
          prefixText: '₱ ',
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

  void _confirmDelete(BuildContext context, AppProvider prov, GroceryEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Grocery Entry?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.productName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87)),
              const SizedBox(height: 4),
              Text(CurrencyFormatter.format(entry.totalExpenses),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'This cannot be undone. The ${entry.quantity} units it added to stock will be subtracted back.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () async {
              await prov.deleteGroceryEntry(entry.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Grocery Tile ──────────────────────────────────────────────
class _GroceryTile extends StatelessWidget {
  final GroceryEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _GroceryTile({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final overBudget = entry.change < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _blue.withValues(alpha: 0.15))),
                    child: const Icon(Icons.shopping_basket_outlined,
                        color: _blue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.productName}  ×${entry.quantity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.black87)),
                        Text(DateHelper.formatDate(entry.date),
                            style:
                                TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(CurrencyFormatter.format(entry.totalExpenses),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 14)),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert_outlined,
                        color: Colors.grey[400], size: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text('Edit',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[700])),
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(fontSize: 13, color: Colors.red)),
                          ])),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _chip('Budget', CurrencyFormatter.format(entry.budget),
                      Colors.grey.shade100, Colors.grey.shade700),
                  const SizedBox(width: 6),
                  _chip('Transpo', CurrencyFormatter.format(entry.transpo),
                      Colors.grey.shade100, Colors.grey.shade700),
                  const SizedBox(width: 6),
                  _chip(
                      'Sukli',
                      CurrencyFormatter.format(entry.change),
                      overBudget ? Colors.red.shade50 : Colors.green.shade50,
                      overBudget ? Colors.red.shade700 : Colors.green.shade700),
                ]),
                if (entry.notes != null) ...[
                  const SizedBox(height: 6),
                  Text(entry.notes!,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$label: $value',
            style: TextStyle(
                fontSize: 10.5, color: fg, fontWeight: FontWeight.w600)),
      );
}
