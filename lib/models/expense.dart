// Sentinel so copyWith can tell "not provided" (keep old value) apart from
// an explicit `notes: null` (clear it) — passing null used to be treated
// as "not provided" via `notes ?? this.notes`, so clearing the Notes field
// in the edit form silently kept the old note instead of clearing it.
const _unset = Object();

class Expense {
  final String id;
  final String description;
  final String category;
  final double amount;
  final DateTime date;
  final String? notes;

  Expense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'],
        description: m['description'],
        category: m['category'],
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date']),
        notes: m['notes'],
      );

  Expense copyWith({
    String? description,
    String? category,
    double? amount,
    DateTime? date,
    Object? notes = _unset,
  }) =>
      Expense(
        id: id,
        description: description ?? this.description,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        notes: identical(notes, _unset) ? this.notes : notes as String?,
      );
}