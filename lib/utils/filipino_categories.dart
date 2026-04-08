class FilipinoCategories {
  static const List<String> productCategories = [
    'Pagkain (Canned)',
    'Inumin',
    'Merienda / Snacks',
    'Panaderya',
    'Bigas at Pasta',
    'Kondimento',
    'Cleaning Supplies',
    'Personal Care',
    'Sigarilyo',
    'Alak / Beer',
    'Candies / Sweets',
    'Frozen / Chilled',
    'School Supplies',
    'Iba pa',
  ];

  static const List<String> expenseCategories = [
    'Stocks / Resupply',
    'Kuryente',
    'Tubig',
    'Renta / Rental',
    'Pamasahe / Transport',
    'Serbisyo',
    'Personal / Allowance',
    'Pagkain',
    'Iba pa',
  ];

  static const Map<String, String> _emoji = {
    'Pagkain (Canned)': '🥫',
    'Inumin': '🥤',
    'Merienda / Snacks': '🍟',
    'Panaderya': '🍞',
    'Bigas at Pasta': '🍚',
    'Kondimento': '🧂',
    'Cleaning Supplies': '🧹',
    'Personal Care': '🧴',
    'Sigarilyo': '🚬',
    'Alak / Beer': '🍺',
    'Candies / Sweets': '🍬',
    'Frozen / Chilled': '🧊',
    'School Supplies': '📚',
    'Iba pa': '📦',
  };

  static String emoji(String category) => _emoji[category] ?? '📦';
}