import '../models/expense.dart';
import '../models/grocery_entry.dart';
import '../models/cico_transaction.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';

class ReportData {
  final double totalRevenue;
  final double totalProfit;
  // Expense records + the *transport* portion of grocery resupply trips —
  // both are real cash leaving the register that never comes back, so Net
  // Income/Break-Even/reports treat them the same way. The item-cost
  // portion of a grocery trip is deliberately excluded: that money buys
  // inventory (capital going back out to come back in as revenue), and its
  // cost is already subtracted once when the item sells (see [totalProfit],
  // which nets out each sale's buyPrice) — folding it in here too would
  // deduct the same peso twice. [groceryTotal] (full item+transport spend)
  // is exposed separately for "how much did I spend restocking" displays.
  final double totalExpenses;
  final double groceryTotal;
  final double netIncome;
  final int transactionCount;
  final List<Map<String, dynamic>> dailyRevenue;
  final List<Map<String, dynamic>> topProducts;
  final double cashSales;
  final double onlineSales;
  final double creditSales;
  // The exact expense entries the period window included — exposed (not
  // just their sum) so a detail screen can break Total Expenses down by
  // category without re-deriving its own, possibly different, date window.
  final List<Expense> expenses;
  // Same idea for grocery trips logged within the period.
  final List<GroceryEntry> groceryEntries;
  // Cash-in/cash-out (E-wallet) agent side-business, kept separate from
  // product-sale profit above — see cicoCommission for the commission
  // earned specifically, not folded into netIncome.
  final double cicoCommission;
  final double cicoCashInVolume;
  final double cicoCashOutVolume;
  final int cicoTransactionCount;

  ReportData({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalExpenses,
    required this.groceryTotal,
    required this.netIncome,
    required this.transactionCount,
    required this.dailyRevenue,
    required this.topProducts,
    required this.cashSales,
    required this.onlineSales,
    required this.creditSales,
    required this.expenses,
    required this.groceryEntries,
    required this.cicoCommission,
    required this.cicoCashInVolume,
    required this.cicoCashOutVolume,
    required this.cicoTransactionCount,
  });
}

class ReportService {
  static final ReportService instance = ReportService._();
  ReportService._();

  final _db = DatabaseService.instance;

  /// [since]/[until] bound the period (inclusive); both are normalized to
  /// day boundaries so a custom range's start and end days are fully
  /// included regardless of what time-of-day the caller passed in.
  Future<ReportData> generateReport({
    required List<Expense> expenses,
    required List<GroceryEntry> groceryEntries,
    required List<CicoTransaction> cico,
    required DateTime since,
    required DateTime until,
  }) async {
    final sinceDay = DateTime(since.year, since.month, since.day);
    final untilDay =
        DateTime(until.year, until.month, until.day, 23, 59, 59, 999);
    final filteredExpenses = expenses
        .where((e) => !e.date.isBefore(sinceDay) && !e.date.isAfter(untilDay))
        .toList();
    final filteredGrocery = groceryEntries
        .where((g) => !g.date.isBefore(sinceDay) && !g.date.isAfter(untilDay))
        .toList();
    final filteredCico = cico
        .where((t) =>
            !t.createdAt.isBefore(sinceDay) && !t.createdAt.isAfter(untilDay))
        .toList();
    final cicoCommission = CurrencyFormatter.roundCents(
        filteredCico.fold(0.0, (s, t) => s + t.commission));
    final cicoCashInVolume = CurrencyFormatter.roundCents(filteredCico
        .where((t) => t.type == CicoType.cashIn)
        .fold(0.0, (s, t) => s + t.amount));
    final cicoCashOutVolume = CurrencyFormatter.roundCents(filteredCico
        .where((t) => t.type == CicoType.cashOut)
        .fold(0.0, (s, t) => s + t.amount));
    final cicoTransactionCount = filteredCico
        .where((t) => t.type == CicoType.cashIn || t.type == CicoType.cashOut)
        .length;

    final expTotal = CurrencyFormatter.roundCents(
        filteredExpenses.fold(0.0, (s, e) => s + e.amount));
    final groceryTotal = CurrencyFormatter.roundCents(
        filteredGrocery.fold(0.0, (s, g) => s + g.totalExpenses));
    // Only the transport portion of a grocery trip is a real expense — the
    // item cost is capital that comes back as COGS when the item sells.
    final groceryExpensePortion = CurrencyFormatter.roundCents(
        filteredGrocery.fold(0.0, (s, g) => s + g.transpo));
    final combinedExpenses =
        CurrencyFormatter.roundCents(expTotal + groceryExpensePortion);

    final daily = await _db.getDailyRevenue(sinceDay, untilDay);
    final top = await _db.getTopProducts(sinceDay, untilDay);
    final paymentSplit = await _db.getPaymentTypeBreakdown(sinceDay, untilDay);

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
      totalExpenses: combinedExpenses,
      groceryTotal: groceryTotal,
      netIncome: CurrencyFormatter.roundCents(profit - combinedExpenses),
      transactionCount: txCount,
      dailyRevenue: daily,
      topProducts: top,
      cashSales: CurrencyFormatter.roundCents(paymentSplit['cash'] ?? 0),
      onlineSales: CurrencyFormatter.roundCents(paymentSplit['online'] ?? 0),
      creditSales: CurrencyFormatter.roundCents(paymentSplit['credit'] ?? 0),
      expenses: filteredExpenses,
      groceryEntries: filteredGrocery,
      cicoCommission: cicoCommission,
      cicoCashInVolume: cicoCashInVolume,
      cicoCashOutVolume: cicoCashOutVolume,
      cicoTransactionCount: cicoTransactionCount,
    );
  }
}