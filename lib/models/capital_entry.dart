class SetupCostItem {
  final String label;
  final double amount;

  SetupCostItem({required this.label, required this.amount});

  Map<String, dynamic> toMap() => {
        'label': label,
        'amount': amount,
      };

  factory SetupCostItem.fromMap(Map<String, dynamic> m) =>
      SetupCostItem(
        label: m['label'] as String,
        amount: (m['amount'] as num).toDouble(),
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

  double get totalInvestment => setupCosts + inventoryValue;

  double get computedSetupCosts =>
      setupItems.isEmpty
          ? setupCosts
          : setupItems.fold(0.0, (s, i) => s + i.amount);

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
  }) =>
      CapitalEntry(
        id: id,
        setupCosts: setupCosts ?? this.setupCosts,
        inventoryValue: inventoryValue ?? this.inventoryValue,
        setupItems: setupItems ?? this.setupItems,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}