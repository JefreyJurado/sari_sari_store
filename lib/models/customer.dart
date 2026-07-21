// Sentinel so copyWith can tell "not provided" (keep old value) apart from
// an explicit `phone: null` / `address: null` (clear it) — passing null
// used to be treated as "not provided" via `?? this.field`.
const _unset = Object();

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double creditLimit;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.creditLimit = 500.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'creditLimit': creditLimit,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'],
        name: map['name'],
        phone: map['phone'],
        address: map['address'],
        creditLimit: (map['creditLimit'] as num?)?.toDouble() ?? 500.0,
        createdAt: DateTime.parse(map['createdAt']),
      );

  Customer copyWith({
    String? name,
    Object? phone = _unset,
    Object? address = _unset,
    double? creditLimit,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: identical(phone, _unset) ? this.phone : phone as String?,
        address: identical(address, _unset) ? this.address : address as String?,
        creditLimit: creditLimit ?? this.creditLimit,
        createdAt: createdAt,
      );
}