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
    'Stocks / Resupply',
    'Electricity',
    'Water',
    'Rent / Rental',
    'Fare / Transport',
    'Services',
    'Personal / Allowance',
    'Food / Meals',
    'Others',
  ];

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
    'Stocks / Resupply': Icons.add_business_outlined,
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
    'Stocks / Resupply': '📦',
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

  // Helper method to fetch the correct emoji string (Fixes previous screen runtime dependencies)
  static String emoji(String category) => _emojis[category] ?? '📦';
}