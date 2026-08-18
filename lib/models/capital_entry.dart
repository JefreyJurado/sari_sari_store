import '../utils/currency_formatter.dart';

class SetupCostItem {
  final String label;
  final double amount;
  final String category;
  final String? vendor;
  final String paymentMethod;
  final DateTime date;

SetupCostItem({
  required this.label,
  required this.amount,
  this.category = 'Equipment',
  this.vendor,
  this.paymentMethod = 'Cash',
  DateTime? date,
}) : date = date ?? DateTime.now();

  static const categories = [
    // Was "Product & Restoration Expenses" — the "Product" wording read as
    // an invitation to log initial stock purchases here, which are
    // already counted automatically via Starting Inventory Value (see
    // AppProvider.currentInventoryValue), so a Setup Cost item under that
    // category silently double-counted the same stock spend.
    'Equipment', 'Legal', 'Marketing',
    'Rent', 'Utilities', 'Repairs & Restoration', 'Others'
  ];

  static const paymentMethods = [
    'Cash', 'Credit Card', 'Bank Transfer', 'GCash'
  ];

  Map<String, dynamic> toMap() => {
    'label': label,
    'amount': amount,
    'category': category,
    'vendor': vendor,
    'paymentMethod': paymentMethod,
    'date': date.toIso8601String(),
  };

factory SetupCostItem.fromMap(Map<String, dynamic> m) => SetupCostItem(
  label: m['label'] as String,
  amount: (m['amount'] as num).toDouble(),
  category: m['category'] as String? ?? 'Equipment',
  vendor: m['vendor'] as String?,
  paymentMethod: m['paymentMethod'] as String? ?? 'Cash',
  date: m['date'] != null
      ? DateTime.parse(m['date'] as String)
      : DateTime.now(),
);
}

class CapitalEntry {
  final String id;
  final double setupCosts;
  final double inventoryValue;
  final List<SetupCostItem> setupItems;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CapitalEntry({
    required this.id,
    required this.setupCosts,
    required this.inventoryValue,
    this.setupItems = const [],
    required this.createdAt,
    this.updatedAt,
  });

  double get computedSetupCosts => setupItems.isEmpty
      ? setupCosts
      : CurrencyFormatter.roundCents(
          setupItems.fold(0.0, (s, i) => s + i.amount));

  Map<String, dynamic> toMap() => {
    'id': id,
    'cashInvestment': computedSetupCosts,
    'inventoryValue': inventoryValue,
    'overhead': 0.0,
    'overheadMonths': 1,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory CapitalEntry.fromMap(
      Map<String, dynamic> m, List<SetupCostItem> items) =>
      CapitalEntry(
        id: m['id'] as String,
        setupCosts: (m['cashInvestment'] as num).toDouble(),
        inventoryValue: (m['inventoryValue'] as num).toDouble(),
        setupItems: items,
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: m['updatedAt'] != null
            ? DateTime.parse(m['updatedAt'] as String)
            : null,
      );

  CapitalEntry copyWith({
    double? setupCosts,
    double? inventoryValue,
    List<SetupCostItem>? setupItems,
    DateTime? updatedAt,
  }) => CapitalEntry(
    id: id,
    setupCosts: setupCosts ?? this.setupCosts,
    inventoryValue: inventoryValue ?? this.inventoryValue,
    setupItems: setupItems ?? this.setupItems,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}