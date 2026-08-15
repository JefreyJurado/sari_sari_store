import '../utils/currency_formatter.dart';

class GroceryEntry {
  final String id;
  final String productId;
  // Snapshot of the product's name at the time of purchase, so the entry
  // still reads correctly even if the product is later renamed or archived.
  final String productName;
  final int quantity;
  final double expensesForProducts;
  final double transpo;
  final DateTime date;
  final String? notes;

  GroceryEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.expensesForProducts,
    required this.transpo,
    required this.date,
    this.notes,
  });

  double get totalExpenses =>
      CurrencyFormatter.roundCents(expensesForProducts + transpo);

  String get monthKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  // Monday of the entry's week, as "yyyy-MM-dd" — a stable, sortable key
  // for grouping into Mon–Sun weeks regardless of locale week-start rules.
  String get weekKey {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'expensesForProducts': expensesForProducts,
        'transpo': transpo,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory GroceryEntry.fromMap(Map<String, dynamic> m) => GroceryEntry(
        id: m['id'] as String,
        productId: m['productId'] as String? ?? '',
        productName: m['productName'] as String? ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        expensesForProducts: (m['expensesForProducts'] as num).toDouble(),
        transpo: (m['transpo'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        notes: m['notes'] as String?,
      );

  GroceryEntry copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? expensesForProducts,
    double? transpo,
    DateTime? date,
    Object? notes = _unset,
  }) =>
      GroceryEntry(
        id: id,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        expensesForProducts: expensesForProducts ?? this.expensesForProducts,
        transpo: transpo ?? this.transpo,
        date: date ?? this.date,
        notes: identical(notes, _unset) ? this.notes : notes as String?,
      );
}

const _unset = Object();
