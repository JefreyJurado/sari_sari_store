class LoyaltyAccount {
  final String customerId;
  final int totalPoints;
  final int redeemedPoints;
  final DateTime lastUpdated;

  LoyaltyAccount({
    required this.customerId,
    required this.totalPoints,
    required this.redeemedPoints,
    required this.lastUpdated,
  });

  int get availablePoints => totalPoints - redeemedPoints;
  double get pesoValue => availablePoints * 0.10;

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'totalPoints': totalPoints,
        'redeemedPoints': redeemedPoints,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory LoyaltyAccount.fromMap(Map<String, dynamic> m) => LoyaltyAccount(
        customerId: m['customerId'],
        totalPoints: m['totalPoints'] as int,
        redeemedPoints: m['redeemedPoints'] as int,
        lastUpdated: DateTime.parse(m['lastUpdated']),
      );

  LoyaltyAccount copyWith({
    int? totalPoints,
    int? redeemedPoints,
  }) =>
      LoyaltyAccount(
        customerId: customerId,
        totalPoints: totalPoints ?? this.totalPoints,
        redeemedPoints: redeemedPoints ?? this.redeemedPoints,
        lastUpdated: DateTime.now(),
      );
}

class LoyaltyTransaction {
  final String id;
  final String customerId;
  final int points;
  final String type;
  final String description;
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.customerId,
    required this.points,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  bool get isEarned => type == 'earned';

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'points': points,
        'type': type,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LoyaltyTransaction.fromMap(Map<String, dynamic> m) =>
      LoyaltyTransaction(
        id: m['id'],
        customerId: m['customerId'],
        points: m['points'] as int,
        type: m['type'],
        description: m['description'],
        createdAt: DateTime.parse(m['createdAt']),
      );
}