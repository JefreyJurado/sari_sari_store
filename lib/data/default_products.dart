import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../services/database_service.dart';

const _uuid = Uuid();

class DefaultProducts {
  static Future<void> seedIfEmpty() async {
    final existing = await DatabaseService.instance.getProducts(activeOnly: false);
    if (existing.isNotEmpty) return;
    for (final p in _defaults) {
      await DatabaseService.instance.insertProduct(p);
    }
  }

  static Product _p(String name, String cat, double buy, double sell, int stock,
          {String unit = 'pcs'}) =>
      Product(
          id: _uuid.v4(),
          name: name,
          category: cat,
          buyPrice: buy,
          sellPrice: sell,
          stock: stock,
          unit: unit,
          createdAt: DateTime.now());

  static final List<Product> _defaults = [
    // Inumin
    _p('Coke Mismo 237ml', 'Inumin', 13, 15, 24),
    _p('Royal Tru-Orange 237ml', 'Inumin', 13, 15, 24),
    _p('C2 Apple 230ml', 'Inumin', 16, 18, 30),
    _p('Mineral Water 500ml', 'Inumin', 9, 12, 48),
    _p('Sting Energy Drink', 'Inumin', 25, 30, 24),
    _p('Zesto Orange Juice', 'Inumin', 7, 10, 36),
    // Pagkain Canned
    _p('Sardinas Ligo 155g', 'Pagkain (Canned)', 15, 18, 24),
    _p('Corned Beef Argentina 150g', 'Pagkain (Canned)', 30, 35, 12),
    _p('Maling Pork Luncheon 170g', 'Pagkain (Canned)', 42, 48, 12),
    _p('Tuna Flakes CDO 155g', 'Pagkain (Canned)', 22, 27, 18),
    _p('Purefoods Liver Spread 165g', 'Pagkain (Canned)', 28, 33, 18),
    // Snacks
    _p('Chippy BBQ', 'Merienda / Snacks', 8, 10, 36),
    _p('Nova Country Cheddar', 'Merienda / Snacks', 8, 10, 36),
    _p('Piattos Cheese', 'Merienda / Snacks', 13, 15, 24),
    _p('Skyflakes Cracker', 'Merienda / Snacks', 8, 10, 24),
    _p('Rebisco Crackers', 'Merienda / Snacks', 5, 7, 30),
    _p('Boy Bawang Cornick', 'Merienda / Snacks', 10, 13, 24),
    // Bigas at Pasta
    _p('Bigas Sinandomeng 1kg', 'Bigas at Pasta', 52, 58, 50, unit: 'kg'),
    _p('Lucky Me Pancit Canton 80g', 'Bigas at Pasta', 8, 11, 60),
    _p('Nissin Instant Noodles', 'Bigas at Pasta', 7, 10, 60),
    _p('Pasta La Vista Spaghetti 400g', 'Bigas at Pasta', 35, 42, 20),
    // Kondimento
    _p('Magic Sarap 8g sachet', 'Kondimento', 5, 7, 48),
    _p('Knorr Liquid Seasoning 250ml', 'Kondimento', 22, 28, 12),
    _p('Silver Swan Soy Sauce 385ml', 'Kondimento', 28, 35, 12),
    _p('UFC Banana Ketchup 320g', 'Kondimento', 30, 38, 12),
    _p('Del Monte Tomato Sauce 250g', 'Kondimento', 22, 28, 18),
    _p('Mama Sita Vinegar 250ml', 'Kondimento', 18, 23, 12),
    // Candies
    _p('Cloud 9 Chocolate', 'Candies / Sweets', 10, 13, 48),
    _p('Hany Chocolate', 'Candies / Sweets', 7, 10, 48),
    _p('Mentos Candy Roll', 'Candies / Sweets', 10, 12, 30),
    _p('Ricoa Tablea', 'Candies / Sweets', 5, 7, 36),
    // Personal Care
    _p('Safeguard Bar Soap 65g', 'Personal Care', 22, 28, 24),
    _p('Head & Shoulders Shampoo sachet', 'Personal Care', 5, 7, 48),
    _p('Colgate Toothpaste 40ml', 'Personal Care', 20, 25, 24),
    _p('Rexona Deo sachet', 'Personal Care', 5, 7, 36),
    _p('Modess Napkin Regular', 'Personal Care', 12, 15, 24),
    // Cleaning
    _p('Ariel Powder 25g sachet', 'Cleaning Supplies', 5, 7, 48),
    _p('Joy Dishwashing 25ml sachet', 'Cleaning Supplies', 5, 7, 48),
    _p('Zonrox Bleach 250ml', 'Cleaning Supplies', 20, 25, 12),
    _p('Downy Fabric Conditioner sachet', 'Cleaning Supplies', 5, 7, 48),
    // Panaderya
    _p('Tasty Bread loaf', 'Panaderya', 45, 55, 10),
    _p('Pan de Sal (bilog)', 'Panaderya', 2, 3, 100),
    // Sigarilyo
    _p('Marlboro Red (tingi)', 'Sigarilyo', 4, 5, 100),
    _p('Philip Morris Menthol (tingi)', 'Sigarilyo', 4, 5, 100),
  ];
}