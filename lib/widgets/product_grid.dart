import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Map<Product, int> cart;
  final Function(Product) onAdd;
  final Function(Product) onRemove;

  const ProductGrid({
    super.key,
    required this.products,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.05,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) => _ProductCard(
        product: products[i],
        cartQty: cart[products[i]] ?? 0,
        onAdd: () => onAdd(products[i]),
        onRemove: () => onRemove(products[i]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int cartQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.cartQty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final oos = product.isOutOfStock;
    final inCart = cartQty > 0;

    return GestureDetector(
      onTap: oos ? null : onAdd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: inCart
              ? const Color(0xFF2E7D32).withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart
                ? const Color(0xFF2E7D32)
                : Colors.grey.shade200,
            width: inCart ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(FilipinoCategories.emoji(product.category),
                    style: const TextStyle(fontSize: 22)),
                const Spacer(),
                if (oos)
                  _Badge('Ubos', Colors.red)
                else if (product.isLowStock)
                  _Badge('${product.stock}', Colors.orange),
              ]),
              const SizedBox(height: 6),
              Text(product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: Text(
                    CurrencyFormatter.format(product.sellPrice),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                        fontSize: 14),
                  ),
                ),
                if (inCart) ...[
                  _SmallBtn(Icons.remove, Colors.grey.shade200,
                      const Color(0xFF424242), onRemove),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$cartQty',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _SmallBtn(Icons.add, const Color(0xFF2E7D32),
                      Colors.white, oos ? () {} : onAdd),
                ] else
                  _SmallBtn(
                      Icons.add,
                      oos ? Colors.grey.shade200 : const Color(0xFF2E7D32),
                      oos ? Colors.grey : Colors.white,
                      oos ? () {} : onAdd),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      );
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _SmallBtn(this.icon, this.bg, this.fg, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26, height: 26,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 16, color: fg),
        ),
      );
}