import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _fmt = NumberFormat.currency(
      locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  static String format(double amount) => _fmt.format(amount);
  static String noSymbol(double amount) =>
      NumberFormat('#,##0.00').format(amount);
}