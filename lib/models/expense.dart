

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
    String? notes,
  }) =>
      Expense(
        id: id,
        description: description ?? this.description,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        notes: notes ?? this.notes,
      );
}