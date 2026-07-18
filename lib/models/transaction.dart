import '../utils/currency_formatter.dart';

enum PaymentType { cash, credit, mixed, online, installment }
enum TxStatus { completed, voided }

class TxItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double buyPrice;

  TxItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.buyPrice,
  });

  double get subtotal => price * quantity;
  double get profit => (price - buyPrice) * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'price': price,
        'buyPrice': buyPrice,
      };

  factory TxItem.fromMap(Map<String, dynamic> m) => TxItem(
        productId: m['productId'],
        productName: m['productName'],
        quantity: m['quantity'],
        price: (m['price'] as num).toDouble(),
        buyPrice: (m['buyPrice'] as num).toDouble(),
      );
}

class Sale {
  final String id;
  final List<TxItem> items;
  final double totalAmount;
  final double cashPaid;
  final double creditAmount;
  final String? customerId;
  final String? customerName;
  final PaymentType type;
  final TxStatus status;
  final String? notes;
  final DateTime createdAt;
  final int? receiptNumber;

  Sale({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.cashPaid,
    required this.creditAmount,
    this.customerId,
    this.customerName,
    required this.type,
    this.status = TxStatus.completed,
    this.notes,
    required this.createdAt,
    this.receiptNumber,
  });

  // Not items.fold(profit) — that sums each item's (price-buyPrice)*qty at
  // full sellPrice, ignoring any loyalty discount applied as a lump-sum
  // reduction to totalAmount rather than distributed across item prices.
  // totalAmount - COGS nets that discount out automatically, the same way
  // AppProvider.grossProfit (totalRevenue - totalCOGS) already does.
  double get totalProfit => CurrencyFormatter.roundCents(totalAmount -
      items.fold(0.0, (s, i) => s + i.buyPrice * i.quantity));
  double get change =>
      cashPaid > totalAmount ? cashPaid - totalAmount : 0;
  bool get isVoided => status == TxStatus.voided;
  bool get isCreditSale => creditAmount > 0;

  Sale copyWith({int? receiptNumber}) => Sale(
        id: id,
        items: items,
        totalAmount: totalAmount,
        cashPaid: cashPaid,
        creditAmount: creditAmount,
        customerId: customerId,
        customerName: customerName,
        type: type,
        status: status,
        notes: notes,
        createdAt: createdAt,
        receiptNumber: receiptNumber ?? this.receiptNumber,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'totalAmount': totalAmount,
        'cashPaid': cashPaid,
        'creditAmount': creditAmount,
        'customerId': customerId,
        'customerName': customerName,
        'type': type.name,
        'status': status.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'receiptNumber': receiptNumber,
      };

  factory Sale.fromMap(
          Map<String, dynamic> m, List<TxItem> items) =>
      Sale(
        id: m['id'],
        items: items,
        totalAmount: (m['totalAmount'] as num).toDouble(),
        cashPaid: (m['cashPaid'] as num).toDouble(),
        creditAmount: (m['creditAmount'] as num).toDouble(),
        customerId: m['customerId'],
        customerName: m['customerName'],
        type: PaymentType.values.firstWhere(
            (e) => e.name == m['type'],
            orElse: () => PaymentType.cash),
        status: TxStatus.values.firstWhere(
            (e) => e.name == m['status'],
            orElse: () => TxStatus.completed),
        notes: m['notes'],
        createdAt: DateTime.parse(m['createdAt']),
        receiptNumber: m['receiptNumber'] as int?,
      );
}