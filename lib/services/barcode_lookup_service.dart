import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/filipino_categories.dart';

class BarcodeLookupResult {
  final String name;
  final String category;
  BarcodeLookupResult({required this.name, required this.category});
}

/// Best-effort online product lookup for barcodes not yet in the
/// local inventory. Uses the free, keyless Open Food Facts API.
/// The app is offline-first: any failure (no internet, timeout,
/// unknown barcode) simply returns null so the caller falls back
/// to manual entry.
class BarcodeLookupService {
  static Future<BarcodeLookupResult?> lookup(String barcode) async {
    try {
      final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/${Uri.encodeComponent(barcode)}.json'
          '?fields=product_name,product_name_en,brands,categories_tags,quantity');
      final response = await http
          .get(uri, headers: {'User-Agent': 'StorePH-SariSariApp/1.0'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final rawName = (product['product_name'] as String?)?.trim();
      final rawNameEn = (product['product_name_en'] as String?)?.trim();
      final brands = (product['brands'] as String?)?.trim();
      final quantity = (product['quantity'] as String?)?.trim();

      var name = (rawName?.isNotEmpty == true ? rawName : rawNameEn) ?? '';
      if (name.isEmpty) return null;
      if (brands != null && brands.isNotEmpty && !name.toLowerCase().contains(brands.toLowerCase())) {
        name = '$brands $name';
      }
      if (quantity != null && quantity.isNotEmpty && !name.toLowerCase().contains(quantity.toLowerCase())) {
        name = '$name $quantity';
      }

      final tags = (product['categories_tags'] as List?)?.cast<String>() ?? [];
      final category = _guessCategory(tags);

      return BarcodeLookupResult(name: name.trim(), category: category);
    } catch (_) {
      return null;
    }
  }

  static String _guessCategory(List<String> offTags) {
    final joined = offTags.join(' ').toLowerCase();
    const keywordMap = {
      'Drinks / Beverages': ['beverage', 'drink', 'soda', 'juice', 'water', 'coffee', 'tea'],
      'Snacks': ['snack', 'chip', 'crisp', 'cracker'],
      'Candies / Sweets': ['candy', 'candies', 'chocolate', 'confectionery', 'sweet'],
      'Bakery / Bread': ['bread', 'bakery', 'pastry'],
      'Rice and Pasta': ['rice', 'pasta', 'noodle'],
      'Condiments': ['condiment', 'sauce', 'seasoning', 'spice'],
      'Cleaning Supplies': ['cleaning', 'detergent', 'soap-cleaning'],
      'Personal Care': ['personal-care', 'shampoo', 'toothpaste', 'hygiene'],
      'Alcohol / Beer': ['beer', 'alcoholic', 'wine', 'liquor'],
      'Frozen / Chilled': ['frozen', 'chilled', 'dairy'],
      'Food (Canned)': ['canned', 'preserved'],
    };
    for (final entry in keywordMap.entries) {
      if (entry.value.any((kw) => joined.contains(kw))) return entry.key;
    }
    return FilipinoCategories.productCategories.first;
  }
}
