import 'package:flutter/material.dart';

class FilipinoCategories {
  static const List<String> productCategories = [
    'Food (Canned)',
    'Drinks / Beverages',
    'Snacks',
    'Bakery / Bread',
    'Rice and Pasta',
    'Condiments',
    'Cleaning Supplies',
    'Personal Care',
    'Cigarettes',
    'Alcohol / Beer',
    'Candies / Sweets',
    'Frozen / Chilled',
    'School Supplies',
    'Others',
  ];

  static const List<String> expenseCategories = [
    // Same label Grocery entries get in reports/PDF — kept identical on
    // purpose so a stock-related cost logged here (rather than through
    // Grocery) rolls up into the same category total instead of quietly
    // splitting into a differently-spelled bucket.
    'Grocery / Resupply',
    'Electricity',
    'Water',
    'Rent / Rental',
    'Fare / Transport',
    'Services',
    'Personal / Allowance',
    'Food / Meals',
    'Others',
  ];

  // Map categories to distinct colors for visual scanning
  static const Map<String, Color> _colors = {
    // Product Categories
    'Food (Canned)': Color(0xFFEA580C),        // orange
    'Drinks / Beverages': Color(0xFF0891B2),   // teal
    'Snacks': Color(0xFFD97706),               // amber
    'Bakery / Bread': Color(0xFFB45309),       // brown-amber
    'Rice and Pasta': Color(0xFFCA8A04),       // yellow-gold
    'Condiments': Color(0xFFDC2626),           // red
    'Cleaning Supplies': Color(0xFF0EA5E9),    // sky blue
    'Personal Care': Color(0xFFDB2777),        // pink
    'Cigarettes': Color(0xFF57534E),           // stone gray
    'Alcohol / Beer': Color(0xFFB45309),       // amber-brown
    'Candies / Sweets': Color(0xFFEC4899),     // hot pink
    'Frozen / Chilled': Color(0xFF0284C7),     // ice blue
    'School Supplies': Color(0xFF7C3AED),      // purple

    // Expense Categories
    'Grocery / Resupply': Color(0xFF1E3A8A),   // brand blue
    'Electricity': Color(0xFFD97706),          // amber
    'Water': Color(0xFF0891B2),                // teal
    'Rent / Rental': Color(0xFF7C3AED),        // purple
    'Fare / Transport': Color(0xFF059669),     // green
    'Services': Color(0xFF64748B),             // slate
    'Personal / Allowance': Color(0xFF059669), // green
    'Food / Meals': Color(0xFFEA580C),         // orange

    // Fallback
    'Others': Color(0xFF64748B),               // slate gray
  };

  // Map categories to clean Material outline icons
  static const Map<String, IconData> _icons = {
    // Product Categories
    'Food (Canned)': Icons.takeout_dining_outlined,
    'Drinks / Beverages': Icons.local_drink_outlined,
    'Snacks': Icons.fastfood_outlined,
    'Bakery / Bread': Icons.bakery_dining_outlined,
    'Rice and Pasta': Icons.rice_bowl_outlined,
    'Condiments': Icons.soup_kitchen_outlined,
    'Cleaning Supplies': Icons.cleaning_services_outlined,
    'Personal Care': Icons.sanitizer_outlined,
    'Cigarettes': Icons.smoking_rooms_outlined,
    'Alcohol / Beer': Icons.sports_bar_outlined,
    'Candies / Sweets': Icons.icecream_outlined,
    'Frozen / Chilled': Icons.ac_unit_outlined,
    'School Supplies': Icons.menu_book_outlined,
    
    // Expense Categories
    'Grocery / Resupply': Icons.add_business_outlined,
    'Electricity': Icons.electric_bolt_outlined,
    'Water': Icons.water_drop_outlined,
    'Rent / Rental': Icons.maps_home_work_outlined,
    'Fare / Transport': Icons.directions_bus_filled_outlined,
    'Services': Icons.build_outlined,
    'Personal / Allowance': Icons.account_balance_wallet_outlined,
    'Food / Meals': Icons.restaurant_outlined,
    
    // Fallback
    'Others': Icons.inventory_2_outlined,
  };

  // Map categories to expressive Emojis for quick visual scanning
  static const Map<String, String> _emojis = {
    // Product Categories
    'Food (Canned)': '🥫',
    'Drinks / Beverages': '🥤',
    'Snacks': '🍿',
    'Bakery / Bread': '🍞',
    'Rice and Pasta': '🍚',
    'Condiments': '🌶️',
    'Cleaning Supplies': '🧼',
    'Personal Care': '🪥',
    'Cigarettes': '🚬',
    'Alcohol / Beer': '🍺',
    'Candies / Sweets': '🍬',
    'Frozen / Chilled': '🥶',
    'School Supplies': '✏️',
    
    // Expense Categories
    'Grocery / Resupply': '📦',
    'Electricity': '⚡',
    'Water': '💧',
    'Rent / Rental': '🏠',
    'Fare / Transport': '🚌',
    'Services': '🛠️',
    'Personal / Allowance': '💵',
    'Food / Meals': '🍔',
    
    // Fallback
    'Others': '🛍️',
  };

  // Helper method to fetch the correct outline icon
  static IconData getIcon(String category) => _icons[category] ?? Icons.inventory_2_outlined;

  // Helper method to fetch the correct color for a category
  static Color getColor(String category) => _colors[category] ?? const Color(0xFF64748B);

  // Helper method to fetch the correct emoji string (Fixes previous screen runtime dependencies)
  static String emoji(String category) => _emojis[category] ?? '📦';
}