class CashDrawer {
  final String id;
  final double openingFloat;
  final double closingFloat;
  final double totalSales;
  final double totalExpenses;
  final double expectedCash;
  final double actualCash;
  final double variance;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? notes;

  CashDrawer({
    required this.id,
    required this.openingFloat,
    required this.closingFloat,
    required this.totalSales,
    required this.totalExpenses,
    required this.expectedCash,
    required this.actualCash,
    required this.variance,
    required this.openedAt,
    this.closedAt,
    this.notes,
  });

  bool get isOpen => closedAt == null;
  bool get hasVariance => variance.abs() > 0.01;
  bool get isShort => variance < 0;
  bool get isOver => variance > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'openingFloat': openingFloat,
        'closingFloat': closingFloat,
        'totalSales': totalSales,
        'totalExpenses': totalExpenses,
        'expectedCash': expectedCash,
        'actualCash': actualCash,
        'variance': variance,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'notes': notes,
      };

  factory CashDrawer.fromMap(Map<String, dynamic> m) => CashDrawer(
        id: m['id'],
        openingFloat: (m['openingFloat'] as num).toDouble(),
        closingFloat: (m['closingFloat'] as num).toDouble(),
        totalSales: (m['totalSales'] as num).toDouble(),
        totalExpenses: (m['totalExpenses'] as num).toDouble(),
        expectedCash: (m['expectedCash'] as num).toDouble(),
        actualCash: (m['actualCash'] as num).toDouble(),
        variance: (m['variance'] as num).toDouble(),
        openedAt: DateTime.parse(m['openedAt']),
        closedAt: m['closedAt'] != null ? DateTime.parse(m['closedAt']) : null,
        notes: m['notes'],
      );
}