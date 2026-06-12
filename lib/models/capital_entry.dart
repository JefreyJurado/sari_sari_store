class CapitalEntry {
  final String id;
  final double setupCosts;
  final double inventoryValue;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CapitalEntry({
    required this.id,
    required this.setupCosts,
    required this.inventoryValue,
    required this.createdAt,
    this.updatedAt,
  });

  double get totalInvestment => setupCosts + inventoryValue;

  Map<String, dynamic> toMap() => {
        'id': id,
        'cashInvestment': setupCosts,
        'inventoryValue': inventoryValue,
        'overhead': 0.0,
        'overheadMonths': 1,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CapitalEntry.fromMap(Map<String, dynamic> m) =>
      CapitalEntry(
        id: m['id'] as String,
        setupCosts:
            (m['cashInvestment'] as num).toDouble(),
        inventoryValue:
            (m['inventoryValue'] as num).toDouble(),
        createdAt:
            DateTime.parse(m['createdAt'] as String),
        updatedAt: m['updatedAt'] != null
            ? DateTime.parse(m['updatedAt'] as String)
            : null,
      );

  CapitalEntry copyWith({
    double? setupCosts,
    double? inventoryValue,
    DateTime? updatedAt,
  }) =>
      CapitalEntry(
        id: id,
        setupCosts: setupCosts ?? this.setupCosts,
        inventoryValue:
            inventoryValue ?? this.inventoryValue,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}