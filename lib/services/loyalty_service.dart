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
    String? saleId,
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
          saleId: saleId,
        ));

    await _saveAccounts(accounts);
    await _saveTransactions(transactions);
  }

  Future<LoyaltyAccount?> getAccount(String customerId) async {
    final accounts = await _loadAccounts();
    return accounts[customerId];
  }

  /// Applies `points` of a customer's available balance as a redemption,
  /// e.g. toward a discount at checkout.
  Future<bool> redeemPoints({
    required String customerId,
    required int points,
    String? saleId,
  }) async {
    if (points <= 0) return false;

    final accounts = await _loadAccounts();
    final transactions = await _loadTransactions();

    final existing = accounts[customerId];
    if (existing == null || existing.availablePoints < points) {
      return false;
    }

    accounts[customerId] = existing.copyWith(
        redeemedPoints: existing.redeemedPoints + points);

    transactions[customerId] ??= [];
    transactions[customerId]!.insert(
        0,
        LoyaltyTransaction(
          id: _uuid.v4(),
          customerId: customerId,
          points: points,
          type: 'redeemed',
          description:
              'Redeemed for ${CurrencyFormatter.format(points * LoyaltyAccount.pesoPerPoint)} off',
          createdAt: DateTime.now(),
          saleId: saleId,
        ));

    await _saveAccounts(accounts);
    await _saveTransactions(transactions);
    return true;
  }

  /// Reverses points earned or redeemed from a specific voided sale.
  Future<void> voidPointsFromSale({
    required String customerId,
    required String saleId,
  }) async {
    final accounts = await _loadAccounts();
    final transactions = await _loadTransactions();

    final custTransactions = transactions[customerId];
    if (custTransactions == null) return;

    final earned = custTransactions
        .where((t) => t.isEarned && t.saleId == saleId)
        .toList();
    final redeemed = custTransactions
        .where((t) => t.type == 'redeemed' && t.saleId == saleId)
        .toList();
    if (earned.isEmpty && redeemed.isEmpty) return;

    final pointsEarnedToReverse =
        earned.fold(0, (s, t) => s + t.points);
    final pointsRedeemedToReverse =
        redeemed.fold(0, (s, t) => s + t.points);

    custTransactions.removeWhere((t) =>
        (t.isEarned || t.type == 'redeemed') &&
        t.saleId == saleId);

    final existing = accounts[customerId];
    if (existing != null) {
      final desiredTotal =
          existing.totalPoints - pointsEarnedToReverse;
      final desiredRedeemed =
          existing.redeemedPoints - pointsRedeemedToReverse;
      final newRedeemed = desiredRedeemed < 0 ? 0 : desiredRedeemed;
      final newTotal = desiredTotal < newRedeemed
          ? newRedeemed
          : desiredTotal;
      accounts[customerId] = existing.copyWith(
          totalPoints: newTotal, redeemedPoints: newRedeemed);
    }

    await _saveAccounts(accounts);
    await _saveTransactions(transactions);
  }
}