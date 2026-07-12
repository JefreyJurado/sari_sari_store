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
  final int reorderPoint;
  final DateTime? expiryDate;
  final String? supplierName;
  final String? supplierContact;
  final String? seasonalTag;

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
    this.reorderPoint = 5,
    this.expiryDate,
    this.supplierName,
    this.supplierContact,
    this.seasonalTag,
  });

  double get profit => sellPrice - buyPrice;
  double get margin => sellPrice > 0 ? (profit / sellPrice) * 100 : 0;
  double get markup => buyPrice > 0 ? (profit / buyPrice) * 100 : 0;
  bool get isLowStock => stock > 0 && stock <= reorderPoint;
  bool get isOutOfStock => stock <= 0;
  bool get isNearExpiry {
    if (expiryDate == null) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  static const List<String> seasonalTags = [
    'None',
    'Typhoon Season',
    'Christmas',
    'Back to School',
    'Fiesta',
    'Summer',
  ];

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
        'reorderPoint': reorderPoint,
        'expiryDate': expiryDate?.toIso8601String(),
        'supplierName': supplierName,
        'supplierContact': supplierContact,
        'seasonalTag': seasonalTag,
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
        reorderPoint: map['reorderPoint'] as int? ?? 5,
        expiryDate: map['expiryDate'] != null
            ? DateTime.tryParse(map['expiryDate'] as String)
            : null,
        supplierName: map['supplierName'],
        supplierContact: map['supplierContact'],
        seasonalTag: map['seasonalTag'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;

  Product copyWith({
    String? name,
    String? category,
    double? buyPrice,
    double? sellPrice,
    int? stock,
    String? unit,
    String? barcode,
    bool? isActive,
    int? reorderPoint,
    DateTime? expiryDate,
    bool clearExpiry = false,
    String? supplierName,
    String? supplierContact,
    String? seasonalTag,
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
        reorderPoint: reorderPoint ?? this.reorderPoint,
        expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
        supplierName: supplierName ?? this.supplierName,
        supplierContact: supplierContact ?? this.supplierContact,
        seasonalTag: seasonalTag ?? this.seasonalTag,
      );
}