import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _fmt = NumberFormat.currency(
      locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  static String format(double amount) => _fmt.format(amount);
  static String noSymbol(double amount) =>
      NumberFormat('#,##0.00').format(amount);

  /// Snaps a money value to the nearest centavo. Money aggregates
  /// (sums, subtractions, chained totals) should round through this at
  /// each step so binary floating-point dust never accumulates into a
  /// visible off-by-a-centavo error.
  static double roundCents(double amount) => (amount * 100).round() / 100;
}