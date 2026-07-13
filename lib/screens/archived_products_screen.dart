import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import '../widgets/center_toast.dart';

class ArchivedProductsScreen extends StatefulWidget {
  const ArchivedProductsScreen({super.key});
  @override
  State<ArchivedProductsScreen> createState() => _ArchivedProductsScreenState();
}

class _ArchivedProductsScreenState extends State<ArchivedProductsScreen> {
  List<Product> _archived = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseService.instance.getArchivedProducts();
    setState(() {
      _archived = list;
      _loading = false;
    });
  }

  void _confirmRestore(Product product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Restore Product',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        content: Text('Restore "${product.name}"? It will appear again in your inventory and sales.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppProvider>().restoreProduct(product.id);
              await _load();
              if (mounted) {
                CenterToast.showSuccess(context, '"${product.name}" restored successfully.');
              }
            },
            child: const Text('Restore',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Archived Products',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _archived.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No archived products',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _archived.length,
                  itemBuilder: (_, i) {
                    final p = _archived[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(FilipinoCategories.getIcon(p.category),
                                size: 20, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87)),
                              const SizedBox(height: 2),
                              Text(
                                '${p.category}  •  Cost: ${CurrencyFormatter.format(p.buyPrice)}  •  Sell: ${CurrencyFormatter.format(p.sellPrice)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _confirmRestore(p),
                          icon: const Icon(Icons.restore_outlined, size: 16, color: Colors.green),
                          label: const Text('Restore',
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            backgroundColor: Colors.green.shade50,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}