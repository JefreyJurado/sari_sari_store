import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/loyalty.dart';
import '../utils/currency_formatter.dart';

const _uuid = Uuid();

class LoyaltyService {
  static final LoyaltyService instance = LoyaltyService._();
  LoyaltyService._();

  int _pointsFor(double amount) => (amount / 10).floor();

  Future<Map<String, LoyaltyAccount>> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('loyalty_accounts') ?? '{}';
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
          k, LoyaltyAccount.fromMap(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, List<LoyaltyTransaction>>>
      _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('loyalty_transactions') ?? '{}';
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
          k,
          (v as List)
              .map((t) => LoyaltyTransaction.fromMap(
                  t as Map<String, dynamic>))
              .toList()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAccounts(
      Map<String, LoyaltyAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loyalty_accounts',
        jsonEncode(accounts.map((k, v) => MapEntry(k, v.toMap()))));
  }

  Future<void> _saveTransactions(
      Map<String, List<LoyaltyTransaction>> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'loyalty_transactions',
        jsonEncode(transactions.map((k, v) =>
            MapEntry(k, v.map((t) => t.toMap()).toList()))));
  }

  Future<void> addPointsFromSale({
    required String customerId,
    required String customerName,
    required double saleAmount,
    DateTime? saleDate,
  }) async {
    final points = _pointsFor(saleAmount);
    if (points <= 0) return;

    final accounts = await _loadAccounts();
    final transactions = await _loadTransactions();

    final existing = accounts[customerId] ??
        LoyaltyAccount(
          customerId: customerId,
          totalPoints: 0,
          redeemedPoints: 0,
          lastUpdated: DateTime.now(),
        );

        accounts[customerId] = existing.copyWith(
        totalPoints: existing.totalPoints + points);

    transactions[customerId] ??= [];
    transactions[customerId]!.insert(
        0,
        LoyaltyTransaction(
          id: _uuid.v4(),
          customerId: customerId,
          points: points,
          type: 'earned',
          description:
              'Binili ng ${CurrencyFormatter.format(saleAmount)}',
          createdAt: saleDate ?? DateTime.now(),
        ));

    await _saveAccounts(accounts);
    await _saveTransactions(transactions);
  }
}