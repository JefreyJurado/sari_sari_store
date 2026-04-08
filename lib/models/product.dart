class Product {
  final String id;
  final String name;
  final String category;
  final double buyPrice;
  final double sellPrice;
  final int stock;
  final String? unit;
  final String? barcode;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    this.unit,
    this.barcode,
    this.isActive = true,
    required this.createdAt,
  });

  double get profit => sellPrice - buyPrice;
  double get margin => buyPrice > 0 ? (profit / buyPrice) * 100 : 0;
  bool get isLowStock => stock > 0 && stock <= 5;
  bool get isOutOfStock => stock <= 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'stock': stock,
        'unit': unit,
        'barcode': barcode,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'],
        name: map['name'],
        category: map['category'],
        buyPrice: (map['buyPrice'] as num).toDouble(),
        sellPrice: (map['sellPrice'] as num).toDouble(),
        stock: map['stock'] as int,
        unit: map['unit'],
        barcode: map['barcode'],
        isActive: map['isActive'] == 1,
        createdAt: DateTime.parse(map['createdAt']),
      );

  Product copyWith({
    String? name,
    String? category,
    double? buyPrice,
    double? sellPrice,
    int? stock,
    String? unit,
    String? barcode,
    bool? isActive,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        buyPrice: buyPrice ?? this.buyPrice,
        sellPrice: sellPrice ?? this.sellPrice,
        stock: stock ?? this.stock,
        unit: unit ?? this.unit,
        barcode: barcode ?? this.barcode,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}