enum InstallmentStatus { ongoing, completed, defaulted }

class Installment {
  final String id;
  final String customerId;
  final String customerName;
  final String itemDescription;
  final double totalAmount;
  final double downPayment;
  final double monthlyPayment;
  final int totalMonths;
  final int paidMonths;
  final double totalPaid;
  final InstallmentStatus status;
  final DateTime startDate;
  final DateTime nextDueDate;
  final String? notes;
  /// Links to the Sale created when this plan was set up (null for
  /// plans saved before that linkage existed), so deleting the plan
  /// can restore the stock it took via [AppProvider.voidSale].
  final String? saleId;

  Installment({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.itemDescription,
    required this.totalAmount,
    required this.downPayment,
    required this.monthlyPayment,
    required this.totalMonths,
    required this.paidMonths,
    required this.totalPaid,
    required this.status,
    required this.startDate,
    required this.nextDueDate,
    this.notes,
    this.saleId,
  });

  double get remainingBalance => totalAmount - totalPaid;
  double get remainingMonths => (totalMonths - paidMonths).toDouble();
  bool get isOverdue =>
      status == InstallmentStatus.ongoing &&
      DateTime.now().isAfter(nextDueDate);
  bool get isCompleted => status == InstallmentStatus.completed;
  double get progressPercent =>
      totalAmount > 0 ? (totalPaid / totalAmount).clamp(0.0, 1.0) : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'itemDescription': itemDescription,
        'totalAmount': totalAmount,
        'downPayment': downPayment,
        'monthlyPayment': monthlyPayment,
        'totalMonths': totalMonths,
        'paidMonths': paidMonths,
        'totalPaid': totalPaid,
        'status': status.name,
        'startDate': startDate.toIso8601String(),
        'nextDueDate': nextDueDate.toIso8601String(),
        'notes': notes,
        'saleId': saleId,
      };

  factory Installment.fromMap(Map<String, dynamic> m) => Installment(
        id: m['id'],
        customerId: m['customerId'],
        customerName: m['customerName'],
        itemDescription: m['itemDescription'],
        totalAmount: (m['totalAmount'] as num).toDouble(),
        downPayment: (m['downPayment'] as num).toDouble(),
        monthlyPayment: (m['monthlyPayment'] as num).toDouble(),
        totalMonths: m['totalMonths'] as int,
        paidMonths: m['paidMonths'] as int,
        totalPaid: (m['totalPaid'] as num).toDouble(),
        status: InstallmentStatus.values.firstWhere(
            (e) => e.name == m['status'],
            orElse: () => InstallmentStatus.ongoing),
        startDate: DateTime.parse(m['startDate']),
        nextDueDate: DateTime.parse(m['nextDueDate']),
        notes: m['notes'],
        saleId: m['saleId'] as String?,
      );

  Installment copyWith({
    int? paidMonths,
    double? totalPaid,
    InstallmentStatus? status,
    DateTime? nextDueDate,
  }) =>
      Installment(
        id: id,
        customerId: customerId,
        customerName: customerName,
        itemDescription: itemDescription,
        totalAmount: totalAmount,
        downPayment: downPayment,
        monthlyPayment: monthlyPayment,
        totalMonths: totalMonths,
        paidMonths: paidMonths ?? this.paidMonths,
        totalPaid: totalPaid ?? this.totalPaid,
        status: status ?? this.status,
        startDate: startDate,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        notes: notes,
        saleId: saleId,
      );
}