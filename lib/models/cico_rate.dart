import 'cico_transaction.dart';

// Sentinel so copyWith can tell "not provided" (keep old value) apart from
// an explicit `field: null` (clear it) — same pattern as Product/
// CicoTransaction's copyWith.
const _unset = Object();

enum CicoRateMode { fixed, percentage }

/// A single fee tier for a provider (GCash, Maya, or a custom wallet) and
/// transaction direction (Cash In vs Cash Out). "Same rate for both
/// directions" is a form-only convenience handled by writing two rows —
/// nothing downstream needs to special-case a combined direction.
class CicoRateRule {
  final String id;
  final String provider;
  final CicoType txnType;
  final CicoRateMode mode;
  // Pesos when mode is fixed, percent (e.g. 1.5 meaning 1.5%) when
  // mode is percentage.
  final double value;
  final double minAmount;
  // Null means no upper bound ("and above").
  final double? maxAmount;
  final bool isActive;
  final DateTime createdAt;

  CicoRateRule({
    required this.id,
    required this.provider,
    required this.txnType,
    required this.mode,
    required this.value,
    this.minAmount = 0,
    this.maxAmount,
    this.isActive = true,
    required this.createdAt,
  });

  double commissionFor(double amount) =>
      mode == CicoRateMode.fixed ? value : amount * value / 100;

  Map<String, dynamic> toMap() => {
        'id': id,
        'provider': provider,
        'txnType': txnType.name,
        'mode': mode.name,
        'value': value,
        'minAmount': minAmount,
        'maxAmount': maxAmount,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CicoRateRule.fromMap(Map<String, dynamic> m) => CicoRateRule(
        id: m['id'] as String,
        provider: m['provider'] as String,
        txnType: CicoType.values.firstWhere((e) => e.name == m['txnType']),
        mode: CicoRateMode.values.firstWhere((e) => e.name == m['mode']),
        value: (m['value'] as num).toDouble(),
        minAmount: (m['minAmount'] as num?)?.toDouble() ?? 0,
        maxAmount: (m['maxAmount'] as num?)?.toDouble(),
        isActive: (m['isActive'] as num?) != 0,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  CicoRateRule copyWith({
    String? provider,
    CicoType? txnType,
    CicoRateMode? mode,
    double? value,
    double? minAmount,
    Object? maxAmount = _unset,
    bool? isActive,
  }) =>
      CicoRateRule(
        id: id,
        provider: provider ?? this.provider,
        txnType: txnType ?? this.txnType,
        mode: mode ?? this.mode,
        value: value ?? this.value,
        minAmount: minAmount ?? this.minAmount,
        maxAmount: identical(maxAmount, _unset)
            ? this.maxAmount
            : maxAmount as double?,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
