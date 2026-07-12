import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../theme/app_theme.dart';

const _blue = AppColors.blue;

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _filter = 'all';

  void _confirmVoid(BuildContext context, AppProvider prov, Sale sale) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Void Sale',
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
                    sale.isCreditSale
                        ? 'This will void the sale, restore the stock, cancel the customer\'s utang for this sale, and reverse any loyalty points earned. This cannot be undone.'
                        : 'This will void the sale and restore the stock. This cannot be undone.',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount:', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text(CurrencyFormatter.format(sale.totalAmount),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items:', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text('${sale.items.length} item${sale.items.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await prov.voidSale(sale);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sale voided. Stock has been restored.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Void Sale',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _reenterSale(BuildContext context, AppProvider prov, Sale sale) {
    prov.clearCart();
    int loadedCount = 0;
    for (final item in sale.items) {
      final product = prov.products
          .where((p) => p.id == item.productId)
          .firstOrNull;
      if (product != null && product.stock >= item.quantity) {
        for (int q = 0; q < item.quantity; q++) {
          prov.addToCart(product);
        }
        loadedCount += item.quantity;
      }
    }

    final totalCount = sale.items.fold(0, (s, i) => s + i.quantity);

    if (prov.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items could be loaded — all products may be out of stock or archived.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context);

    if (loadedCount < totalCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some items could not be loaded — out of stock or archived.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Items loaded to cart. Please review and re-process.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, prov, _) {
        final all = prov.sales;
        final filtered = _filter == 'all'
            ? all
            : _filter == 'completed'
                ? all.where((s) => s.status == TxStatus.completed).toList()
                : all.where((s) => s.status == TxStatus.voided).toList();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('Sales History',
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
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  _chip('All', 'all'),
                  const SizedBox(width: 8),
                  _chip('Completed', 'completed'),
                  const SizedBox(width: 8),
                  _chip('Voided', 'voided'),
                ]),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blue.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  const Icon(Icons.receipt_long_outlined, size: 16, color: _blue),
                  const SizedBox(width: 8),
                  Text('${filtered.length} transaction${filtered.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(
                      CurrencyFormatter.roundCents(filtered
                          .where((s) => s.status == TxStatus.completed)
                          .fold(0.0, (s, t) => s + t.totalAmount)),
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _blue),
                  ),
                ]),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No transactions found',
                              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final sale = filtered[i];
                          final isVoided = sale.status == TxStatus.voided;
                          final isOnline = sale.notes?.contains('Online') ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isVoided ? Colors.grey.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isVoided ? Colors.grey.shade300 : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: isVoided
                                          ? Colors.grey.shade100
                                          : isOnline
                                              ? const Color(0xFFEFF6FF)
                                              : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isVoided
                                          ? Icons.cancel_outlined
                                          : isOnline
                                              ? Icons.phone_android_rounded
                                              : Icons.payments_rounded,
                                      size: 18,
                                      color: isVoided
                                          ? Colors.grey
                                          : isOnline
                                              ? Colors.blue[700]
                                              : Colors.green[700],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(
                                            isVoided
                                                ? 'Voided Sale'
                                                : isOnline
                                                    ? 'Online Transfer'
                                                    : 'Cash Sale',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isVoided ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isVoided)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.red.shade200),
                                              ),
                                              child: const Text('VOID',
                                                  style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w800)),
                                            ),
                                        ]),
                                        Text(
                                          '${DateHelper.formatDate(sale.createdAt)}  •  ${DateHelper.formatTime(sale.createdAt)}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(sale.totalAmount),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isVoided ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                ]),
                                if (sale.items.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    sale.items.map((i) => '${i.productName} ×${i.quantity}').join(', '),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isVoided)
                                      TextButton.icon(
                                        onPressed: () => _confirmVoid(context, prov, sale),
                                        icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                                        label: const Text('Void Sale',
                                            style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          backgroundColor: Colors.red.shade50,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    if (isVoided)
                                      TextButton.icon(
                                        onPressed: () => _reenterSale(context, prov, sale),
                                        icon: const Icon(Icons.replay_outlined, size: 14, color: _blue),
                                        label: const Text('Re-enter Sale',
                                            style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w600)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          backgroundColor: Colors.blue.shade50,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : Colors.grey[600])),
      ),
    );
  }
}