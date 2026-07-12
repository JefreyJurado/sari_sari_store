import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';
import '../utils/filipino_categories.dart';
import '../theme/app_theme.dart';

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
        childAspectRatio: 0.92,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
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
    final accent = FilipinoCategories.getColor(product.category);

    return GestureDetector(
      onTap: oos ? null : onAdd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: inCart ? accent : Colors.grey.shade200,
            width: inCart ? 1.6 : 1,
          ),
          boxShadow: inCart ? AppShadows.colored(accent) : AppShadows.soft,
        ),
        child: Opacity(
          opacity: oos ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                        FilipinoCategories.getIcon(product.category),
                        color: accent,
                        size: 18),
                  ),
                  const Spacer(),
                  if (oos)
                    const _Badge('OOS', AppColors.red)
                  else if (product.isLowStock)
                    _Badge('${product.stock}', AppColors.amber)
                  else if (inCart)
                    _Badge('$cartQty', accent),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Text(
                      CurrencyFormatter.format(product.sellPrice),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accent,
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
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    _SmallBtn(Icons.add, accent, Colors.white,
                        oos ? () {} : onAdd),
                  ] else
                    _SmallBtn(
                        Icons.add,
                        oos ? Colors.grey.shade100 : accent,
                        oos ? Colors.grey.shade400 : Colors.white,
                        oos ? () {} : onAdd),
                ]),
              ],
            ),
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
            borderRadius: BorderRadius.circular(AppRadius.sm)),
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
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, size: 16, color: fg),
        ),
      );
}
