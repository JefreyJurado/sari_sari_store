import '../models/expense.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';

class ReportData {
  final double totalRevenue;
  final double totalProfit;
  final double totalExpenses;
  final double netIncome;
  final int transactionCount;
  final List<Map<String, dynamic>> dailyRevenue;
  final List<Map<String, dynamic>> topProducts;

  ReportData({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalExpenses,
    required this.netIncome,
    required this.transactionCount,
    required this.dailyRevenue,
    required this.topProducts,
  });
}

class ReportService {
  static final ReportService instance = ReportService._();
  ReportService._();

  final _db = DatabaseService.instance;

  Future<ReportData> generateReport({
    required List<Expense> expenses,
    required int days,
  }) async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final filteredExpenses =
        expenses.where((e) => !e.date.isBefore(since)).toList();

    final expTotal = CurrencyFormatter.roundCents(
        filteredExpenses.fold(0.0, (s, e) => s + e.amount));

    final daily = await _db.getDailyRevenue(days);
    final top = await _db.getTopProducts(days);

    // Period totals are summed from the SQL per-day rows rather than the
    // provider's in-memory sales list — that list is capped to recent
    // entries, so folding it would undercount longer periods (1 month+)
    // once the store has more sales than the cap.
    final revenue = CurrencyFormatter.roundCents(daily.fold(
        0.0, (s, d) => s + ((d['revenue'] as num?)?.toDouble() ?? 0)));
    final profit = CurrencyFormatter.roundCents(daily.fold(
        0.0, (s, d) => s + ((d['profit'] as num?)?.toDouble() ?? 0)));
    final txCount = daily.fold(
        0, (s, d) => s + ((d['txCount'] as num?)?.toInt() ?? 0));

    return ReportData(
      totalRevenue: revenue,
      totalProfit: profit,
      totalExpenses: expTotal,
      netIncome: CurrencyFormatter.roundCents(profit - expTotal),
      transactionCount: txCount,
      dailyRevenue: daily,
      topProducts: top,
    );
  }
}