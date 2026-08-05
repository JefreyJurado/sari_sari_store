import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import '../theme/app_theme.dart';
import '../widgets/center_toast.dart';
import '../widgets/search_field.dart';

const _blue = AppColors.blue;

class StockAlertScreen extends StatefulWidget {
  const StockAlertScreen({super.key});
  @override
  State<StockAlertScreen> createState() => _StockAlertScreenState();
}

class _StockAlertScreenState extends State<StockAlertScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, prov, _) {
      var outOfStock = prov.outOfStock;
      var lowStock = prov.lowStock;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        outOfStock = outOfStock.where((p) => p.name.toLowerCase().contains(q)).toList();
        lowStock = lowStock.where((p) => p.name.toLowerCase().contains(q)).toList();
      }

      // FIXED: Used DefaultTabController to eliminate manually tracking mixin lifecycles
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('Stock Alerts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: Colors.grey.shade200),
            ),
          ),
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Monitor inventory levels',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  hintText: 'Search products...',
                ),
              ),
              const SizedBox(height: 8),

              // ── Tab Bar ──────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1)),
                ),
                child: const TabBar(
                  labelColor: _blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _blue,
                  indicatorWeight: 2,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  unselectedLabelStyle:
                      TextStyle(fontSize: 12),
                  tabs: [
                    Tab(text: 'Out of Stock'),
                    Tab(text: 'Low Stock'),
                  ],
                ),
              ),

              // ── Tab Content ──────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    _buildList(context, outOfStock, prov,
                        isOutOfStock: true),
                    _buildList(context, lowStock, prov,
                        isOutOfStock: false),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _buildList(BuildContext context, List<Product> products, AppProvider prov,
      {required bool isOutOfStock}) {
    if (products.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(
            isOutOfStock ? Icons.check_circle_outline : Icons.inventory_2_outlined,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            isOutOfStock ? 'No out of stock items!' : 'All items have sufficient stock.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: products.length,
      itemBuilder: (listCtx, i) {
        final p = products[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOutOfStock ? Colors.red.shade100 : Colors.orange.shade100,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    FilipinoCategories.emoji(p.category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                      '${p.category}  •  ${CurrencyFormatter.format(p.sellPrice)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutOfStock ? Colors.red.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: isOutOfStock ? Colors.red.shade200 : Colors.orange.shade200),
                  ),
                  child: Text(
                    isOutOfStock ? 'Out' : '${p.stock} ${p.unit ?? 'pcs'}',
                    style: TextStyle(
                        color: isOutOfStock ? Colors.red.shade600 : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _adjustStock(context, prov, p),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _blue.withValues(alpha: 0.2)),
                    ),
                    child: const Text('+ Restock',
                        style: TextStyle(
                            color: _blue,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  void _adjustStock(BuildContext screenCtx, AppProvider prov, Product product) {
    final ctrl = TextEditingController();
    showDialog(
      context: screenCtx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Restock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Text(FilipinoCategories.emoji(product.category), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                  Text('Current: ${product.stock} ${product.unit ?? 'pcs'}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            autofocus: true,
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
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          TextButton(
            onPressed: () {
              final adj = int.tryParse(ctrl.text);
              if (adj == null) return;
              
              final newStock = (product.stock + adj).clamp(0, 99999);
              prov.adjustProductStock(product.id, adj);

              // FIXED: Use localized dialog context to pop, check screen safety before showing SnackBar
              Navigator.pop(dialogCtx);
              
              if (screenCtx.mounted) {
                CenterToast.showSuccess(
                    screenCtx, '${product.name} updated: $newStock ${product.unit ?? 'pcs'}');
              }
            },
            child: const Text('Apply',
                style: TextStyle(color: _blue, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}