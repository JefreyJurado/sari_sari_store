import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart'; // Ensure this class exposes 'getIcon'

// Your app's signature blue color
const _blue = Color(0xFF1E3A8A);

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
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: inCart
              ? Border.all(color: _blue, width: 2) // Changed from green to blue
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
                color: inCart
                    ? _blue.withValues(alpha: 0.1) // Changed from green to blue
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Swapped Text emoji element with your outline icon mapping
                Icon(
                  FilipinoCategories.getIcon(product.category),
                  color: _blue,
                  size: 22,
                ),
                const Spacer(),
                if (oos)
                  const _Badge('OOS', Colors.red) // Translated from 'Ubos'
                else if (product.isLowStock)
                  _Badge('${product.stock}', Colors.orange)
                else if (inCart)
                  _Badge('$cartQty', _blue), // Changed from green to blue
              ]),
              const SizedBox(height: 6),
              Expanded(
                child: Text(product.name,
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
                    CurrencyFormatter.format(product.sellPrice),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _blue, // Changed from green to blue
                        fontSize: 14),
                  ),
                ),
                if (inCart) ...[
                  _SmallBtn(
                      Icons.remove,
                      Colors.grey.shade100,
                      Colors.grey.shade700,
                      onRemove),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$cartQty',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  _SmallBtn(
                      Icons.add,
                      _blue, // Changed from green to blue
                      Colors.white,
                      oos ? () {} : onAdd),
                ] else
                  _SmallBtn(
                      Icons.add,
                      oos ? Colors.grey.shade100 : _blue, // Changed from green to blue
                      oos ? Colors.grey.shade400 : Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
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
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: fg),
        ),
      );
}