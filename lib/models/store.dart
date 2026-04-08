class Store {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Store.fromMap(Map<String, dynamic> m) => Store(
        id: m['id'],
        name: m['name'],
        address: m['address'],
        phone: m['phone'],
        isActive: m['isActive'] == 1,
        createdAt: DateTime.parse(m['createdAt']),
      );

  Store copyWith({
    String? name,
    String? address,
    String? phone,
    bool? isActive,
  }) =>
      Store(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}