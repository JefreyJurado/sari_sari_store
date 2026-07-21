// Sentinel so copyWith can tell "not provided" (keep old value) apart from
// an explicit `field: null` (clear it) — passing null used to be treated
// as "not provided" via `?? this.field`, so clearing notes/customer/
// transfer-account fields through copyWith would silently keep the old
// value instead.
const _unset = Object();

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
  // topUp/withdraw only: the other side of the adjustment (Cash, a bank, or
  // a wallet) so it nets against a second account instead of only touching
  // `provider`/`accountKind`. Null means a standalone adjustment with no
  // other side (e.g. reconciling a manual recount) — this is also what
  // every transaction written before this field existed defaults to, so
  // historical balances are unaffected.
  final String? transferAccount;

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
    this.transferAccount,
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
        'transferAccount': transferAccount,
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
        transferAccount: m['transferAccount'] as String?,
      );

  CicoTransaction copyWith({
    CicoType? type,
    String? provider,
    double? amount,
    double? commission,
    DateTime? createdAt,
    Object? notes = _unset,
    String? liquidAccount,
    CicoAccountKind? accountKind,
    Object? customerName = _unset,
    Object? customerPhone = _unset,
    Object? transferAccount = _unset,
  }) =>
      CicoTransaction(
        id: id,
        type: type ?? this.type,
        provider: provider ?? this.provider,
        amount: amount ?? this.amount,
        commission: commission ?? this.commission,
        createdAt: createdAt ?? this.createdAt,
        notes: identical(notes, _unset) ? this.notes : notes as String?,
        liquidAccount: liquidAccount ?? this.liquidAccount,
        accountKind: accountKind ?? this.accountKind,
        customerName: identical(customerName, _unset)
            ? this.customerName
            : customerName as String?,
        customerPhone: identical(customerPhone, _unset)
            ? this.customerPhone
            : customerPhone as String?,
        transferAccount: identical(transferAccount, _unset)
            ? this.transferAccount
            : transferAccount as String?,
      );
}
