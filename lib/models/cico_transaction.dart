enum CicoType { cashIn, cashOut, topUp, withdraw }

// For topUp/withdraw rows only: what `provider` refers to. cashIn/cashOut
// rows don't use this — their `provider` is always a wallet name, and their
// funding side is Cash unless `liquidAccount` names a bank instead.
enum CicoAccountKind { cash, bank, wallet }

class CicoTransaction {
  final String id;
  final CicoType type;
  final String provider;
  final double amount;
  final double commission;
  final DateTime createdAt;
  final String? notes;
  // cashIn/cashOut only: which account funded/received the customer's side
  // of the transaction — Cash (the default) or a named bank account.
  final String liquidAccount;
  // topUp/withdraw only: which kind of account `provider` names.
  final CicoAccountKind accountKind;
  // cashIn/cashOut only: optional customer details for recordkeeping.
  final String? customerName;
  final String? customerPhone;

  static const cashAccount = 'Cash';
  static const presetProviders = ['GCash', 'Maya'];

  CicoTransaction({
    required this.id,
    required this.type,
    required this.provider,
    required this.amount,
    this.commission = 0,
    required this.createdAt,
    this.notes,
    this.liquidAccount = cashAccount,
    this.accountKind = CicoAccountKind.wallet,
    this.customerName,
    this.customerPhone,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'provider': provider,
        'amount': amount,
        'commission': commission,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'liquidAccount': liquidAccount,
        'accountKind': accountKind.name,
        'customerName': customerName,
        'customerPhone': customerPhone,
      };

  factory CicoTransaction.fromMap(Map<String, dynamic> m) => CicoTransaction(
        id: m['id'] as String,
        type: CicoType.values.firstWhere((e) => e.name == m['type']),
        provider: m['provider'] as String,
        amount: (m['amount'] as num).toDouble(),
        commission: (m['commission'] as num?)?.toDouble() ?? 0,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        liquidAccount: m['liquidAccount'] as String? ?? cashAccount,
        accountKind: CicoAccountKind.values.firstWhere(
            (e) => e.name == m['accountKind'],
            orElse: () => CicoAccountKind.wallet),
        customerName: m['customerName'] as String?,
        customerPhone: m['customerPhone'] as String?,
      );

  CicoTransaction copyWith({
    CicoType? type,
    String? provider,
    double? amount,
    double? commission,
    DateTime? createdAt,
    String? notes,
    String? liquidAccount,
    CicoAccountKind? accountKind,
    String? customerName,
    String? customerPhone,
  }) =>
      CicoTransaction(
        id: id,
        type: type ?? this.type,
        provider: provider ?? this.provider,
        amount: amount ?? this.amount,
        commission: commission ?? this.commission,
        createdAt: createdAt ?? this.createdAt,
        notes: notes ?? this.notes,
        liquidAccount: liquidAccount ?? this.liquidAccount,
        accountKind: accountKind ?? this.accountKind,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
      );
}
