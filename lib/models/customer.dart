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
    String? phone,
    String? address,
    double? creditLimit,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        creditLimit: creditLimit ?? this.creditLimit,
        createdAt: createdAt,
      );
}