// Sentinel so copyWith can tell "not provided" (keep old value) apart from
// an explicit `address: null` / `phone: null` (clear it) — passing null
// used to be treated as "not provided" via `?? this.field`, so clearing
// Address/Phone in the edit form silently kept the old value instead.
const _unset = Object();

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
    Object? address = _unset,
    Object? phone = _unset,
    bool? isActive,
  }) =>
      Store(
        id: id,
        name: name ?? this.name,
        address: identical(address, _unset) ? this.address : address as String?,
        phone: identical(phone, _unset) ? this.phone : phone as String?,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}