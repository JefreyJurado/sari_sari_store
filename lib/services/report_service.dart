import '../models/transaction.dart';
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
    required List<Sale> sales,
    required List<Expense> expenses,
    required int days,
  }) async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final filteredSales = sales
        .where((s) =>
            s.status == TxStatus.completed &&
            !s.createdAt.isBefore(since))
        .toList();
    final filteredExpenses =
        expenses.where((e) => !e.date.isBefore(since)).toList();

    final revenue = CurrencyFormatter.roundCents(
        filteredSales.fold(0.0, (s, t) => s + t.totalAmount));
    final profit = CurrencyFormatter.roundCents(
        filteredSales.fold(0.0, (s, t) => s + t.totalProfit));
    final expTotal = CurrencyFormatter.roundCents(
        filteredExpenses.fold(0.0, (s, e) => s + e.amount));

    final daily = await _db.getDailyRevenue(days);
    final top = await _db.getTopProducts(days);

    return ReportData(
      totalRevenue: revenue,
      totalProfit: profit,
      totalExpenses: expTotal,
      netIncome: CurrencyFormatter.roundCents(profit - expTotal),
      transactionCount: filteredSales.length,
      dailyRevenue: daily,
      topProducts: top,
    );
  }
}