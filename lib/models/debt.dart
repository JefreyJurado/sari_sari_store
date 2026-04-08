enum DebtStatus { unpaid, partial, paid }

class Debt {
  final String id;
  final String customerId;
  final String customerName;
  final String saleId;
  final double originalAmount;
  final double paidAmount;
  final DebtStatus status;
  final DateTime dueDate;
  final DateTime createdAt;

  Debt({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.saleId,
    required this.originalAmount,
    required this.paidAmount,
    required this.status,
    required this.dueDate,
    required this.createdAt,
  });

  double get remaining => originalAmount - paidAmount;
  bool get isOverdue =>
      status != DebtStatus.paid && DateTime.now().isAfter(dueDate);

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'saleId': saleId,
        'originalAmount': originalAmount,
        'paidAmount': paidAmount,
        'status': status.name,
        'dueDate': dueDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Debt.fromMap(Map<String, dynamic> m) => Debt(
        id: m['id'],
        customerId: m['customerId'],
        customerName: m['customerName'],
        saleId: m['saleId'],
        originalAmount: (m['originalAmount'] as num).toDouble(),
        paidAmount: (m['paidAmount'] as num).toDouble(),
        status: DebtStatus.values.firstWhere((e) => e.name == m['status'],
            orElse: () => DebtStatus.unpaid),
        dueDate: DateTime.parse(m['dueDate']),
        createdAt: DateTime.parse(m['createdAt']),
      );

  Debt copyWith({double? paidAmount, DebtStatus? status}) => Debt(
        id: id,
        customerId: customerId,
        customerName: customerName,
        saleId: saleId,
        originalAmount: originalAmount,
        paidAmount: paidAmount ?? this.paidAmount,
        status: status ?? this.status,
        dueDate: dueDate,
        createdAt: createdAt,
      );
}