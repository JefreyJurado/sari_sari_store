class DebtPayment {
  final String id;
  final String debtId;
  final String customerId;
  final String customerName;
  final double amount;
  final String? notes;
  final DateTime createdAt;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.customerId,
    required this.customerName,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'debtId': debtId,
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DebtPayment.fromMap(Map<String, dynamic> m) => DebtPayment(
        id: m['id'],
        debtId: m['debtId'],
        customerId: m['customerId'],
        customerName: m['customerName'],
        amount: (m['amount'] as num).toDouble(),
        notes: m['notes'],
        createdAt: DateTime.parse(m['createdAt']),
      );
}