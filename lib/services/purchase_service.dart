import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static final PurchaseService instance = PurchaseService._();
  PurchaseService._();

  static const _key = 'is_premium';
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_key) ?? false;
  }

  Future<void> unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    _isPremium = true;
  }
}