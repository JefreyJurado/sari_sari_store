import '../models/transaction.dart';
import '../models/expense.dart';
import 'currency_formatter.dart';

class InsightsHelper {
  static List<String> generate(List<Sale> sales, List<Expense> expenses) {
    final insights = <String>[];
    final now = DateTime.now();

    final today = sales.where((s) =>
        s.status == TxStatus.completed &&
        s.createdAt.year == now.year &&
        s.createdAt.month == now.month &&
        s.createdAt.day == now.day).toList();

    final todayRev = today.fold(0.0, (s, t) => s + t.totalAmount);
    final todayProf = today.fold(0.0, (s, t) => s + t.totalProfit);
    final todayExp = expenses
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .fold(0.0, (s, e) => s + e.amount);

    if (todayRev > 0) insights.add('Benta ngayon: ${CurrencyFormatter.format(todayRev)}');
    if (todayProf > 0) insights.add('Tubo ngayon: ${CurrencyFormatter.format(todayProf)}');
    final net = todayProf - todayExp;
    if (net < 0) insights.add('Mas malaki ang gastos kaysa kita ngayon ⚠️');

    return insights;
  }
}