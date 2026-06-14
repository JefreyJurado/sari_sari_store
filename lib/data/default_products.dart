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
    // Drinks
    _p('Coke Mismo 237ml', 'Drinks / Beverages', 13, 15, 24),
    _p('Royal Tru-Orange 237ml', 'Drinks / Beverages', 13, 15, 24),
    _p('C2 Apple 230ml', 'Drinks / Beverages', 16, 18, 30),
    _p('Mineral Water 500ml', 'Drinks / Beverages', 9, 12, 48),
    _p('Sting Energy Drink', 'Drinks / Beverages', 25, 30, 24),
    _p('Zesto Orange Juice', 'Drinks / Beverages', 7, 10, 36),
    // Food Canned
    _p('Sardinas Ligo 155g', 'Food (Canned)', 15, 18, 24),
    _p('Corned Beef Argentina 150g', 'Food (Canned)', 30, 35, 12),
    _p('Maling Pork Luncheon 170g', 'Food (Canned)', 42, 48, 12),
    _p('Tuna Flakes CDO 155g', 'Food (Canned)', 22, 27, 18),
    _p('Purefoods Liver Spread 165g', 'Food (Canned)', 28, 33, 18),
    // Snacks
    _p('Chippy BBQ', 'Snacks', 8, 10, 36),
    _p('Nova Country Cheddar', 'Snacks', 8, 10, 36),
    _p('Piattos Cheese', 'Snacks', 13, 15, 24),
    _p('Skyflakes Cracker', 'Snacks', 8, 10, 24),
    _p('Rebisco Crackers', 'Snacks', 5, 7, 30),
    _p('Boy Bawang Cornick', 'Snacks', 10, 13, 24),
    // Rice and Pasta
    _p('Bigas Sinandomeng 1kg', 'Rice and Pasta', 52, 58, 50, unit: 'kg'),
    _p('Lucky Me Pancit Canton 80g', 'Rice and Pasta', 8, 11, 60),
    _p('Nissin Instant Noodles', 'Rice and Pasta', 7, 10, 60),
    _p('Pasta La Vista Spaghetti 400g', 'Rice and Pasta', 35, 42, 20),
    // Condiments
    _p('Magic Sarap 8g sachet', 'Condiments', 5, 7, 48),
    _p('Knorr Liquid Seasoning 250ml', 'Condiments', 22, 28, 12),
    _p('Silver Swan Soy Sauce 385ml', 'Condiments', 28, 35, 12),
    _p('UFC Banana Ketchup 320g', 'Condiments', 30, 38, 12),
    _p('Del Monte Tomato Sauce 250g', 'Condiments', 22, 28, 18),
    _p('Mama Sita Vinegar 250ml', 'Condiments', 18, 23, 12),
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
    // Bakery
    _p('Tasty Bread loaf', 'Bakery / Bread', 45, 55, 10),
    _p('Pan de Sal (bilog)', 'Bakery / Bread', 2, 3, 100),
    // Cigarettes
    _p('Marlboro Red (tingi)', 'Cigarettes', 4, 5, 100),
    _p('Philip Morris Menthol (tingi)', 'Cigarettes', 4, 5, 100),
  ];
}