import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/expense.dart';
import '../models/debt.dart';
import '../models/payment.dart';
import '../models/capital_entry.dart';
import '../models/installment.dart';
import '../models/cico_transaction.dart';
import '../models/cico_rate.dart';
import '../models/grocery_entry.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import '../services/loyalty_service.dart';
import '../services/installment_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';

const _uuid = Uuid();

/// Thrown by the sale-writing methods below when a requested quantity
/// exceeds a product's current stock at the moment of writing. Stock can
/// move between when items were picked (cart/credit order/installment
/// picker) and when the sale is actually submitted — e.g. another sale for
/// the same product completes first — and
/// [DatabaseService.adjustProductStock] clamps at 0 rather than failing,
/// so without this check an oversell would complete silently instead of
/// surfacing an error.
class InsufficientStockException implements Exception {
  final String productName;
  InsufficientStockException(this.productName);
  @override
  String toString() => '$productName no longer has enough stock — it may '
      'have just been sold elsewhere. Please adjust and try again.';
}

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;

  List<Customer> customers = [];
  List<Sale> sales = [];
  List<Expense> expenses = [];
  List<CicoTransaction> cico = [];
  List<CicoRateRule> rates = [];
  List<Debt> debts = [];
  List<DebtPayment> payments = [];
  List<GroceryEntry> groceryEntries = [];
  CapitalEntry? capital;
  bool isLoading = false;

  List<Product> _products = [];
  List<Product> get products => _products;
  // Every reassignment refreshes any open cart entries against the new
  // list: `Map<Product, int>` equality is by id (see Product.==), so an
  // edited product's cart quantity is still found correctly, but Dart
  // doesn't replace a map's *stored key* on a matching `[]=` — leaving the
  // cart holding the pre-edit Product (and its stale price) until now.
  set products(List<Product> value) {
    _products = value;
    _refreshCartKeys();
  }

  void _refreshCartKeys() {
    if (cart.isEmpty) return;
    final refreshed = <Product, int>{};
    for (final entry in cart.entries) {
      var live = entry.key;
      for (final p in _products) {
        if (p.id == entry.key.id) {
          live = p;
          break;
        }
      }
      refreshed[live] = entry.value;
    }
    cart
      ..clear()
      ..addAll(refreshed);
  }

  final Map<Product, int> cart = {};

  // Looks up current stock straight from the in-memory product list (kept
  // fresh by every reload()) rather than trusting a Product reference a
  // caller may have been holding onto since before some other sale moved
  // its stock — throws instead of returning a bool so every call site gets
  // the same clear, specific error message for free.
  void _checkStock(String productId, int qty) {
    final live = _products.where((p) => p.id == productId).firstOrNull;
    if (live != null && qty > live.stock) {
      throw InsufficientStockException(live.name);
    }
  }

  void _safeNotifyListeners() {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  // ── Computed ───────────────────────────────────────────────────
  double get cartTotal => CurrencyFormatter.roundCents(
      cart.entries.fold(0.0, (s, e) => s + e.key.sellPrice * e.value));

  int get cartItemCount => cart.values.fold(0, (s, q) => s + q);

  List<Sale> get todaySales {
    final now = DateTime.now();
    return sales
        .where((s) =>
            s.status == TxStatus.completed &&
            s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day)
        .toList();
  }

  double get todayRevenue => CurrencyFormatter.roundCents(
      todaySales.fold(0.0, (s, t) => s + t.totalAmount));
  double get todayProfit => CurrencyFormatter.roundCents(
      todaySales.fold(0.0, (s, t) => s + t.totalProfit));

  double get yesterdayRevenue {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return CurrencyFormatter.roundCents(sales
        .where((s) =>
            s.status == TxStatus.completed &&
            s.createdAt.year == y.year &&
            s.createdAt.month == y.month &&
            s.createdAt.day == y.day)
        .fold(0.0, (s, t) => s + t.totalAmount));
  }

  double get totalUnpaidDebt => CurrencyFormatter.roundCents(debts
      .where((d) => d.status != DebtStatus.paid)
      .fold(0.0, (s, d) => s + d.remaining));

  List<Product> get lowStock =>
      products.where((p) => p.isLowStock && p.isActive).toList();
  List<Product> get outOfStock =>
      products.where((p) => p.isOutOfStock && p.isActive).toList();

  // ── Capital Computed ───────────────────────────────────────────

  // 1. Live inventory value — for stock monitoring only
  double get currentInventoryValue => CurrencyFormatter.roundCents(
      products.fold(0.0, (s, p) => s + (p.buyPrice * p.stock)));

  // 2. Alias
  double get inventoryValue => currentInventoryValue;

  // 3. Business setup costs — one-time fixed investment
  double get businessSetupCosts => capital?.setupCosts ?? 0.0;

  // 4. Total Investment = Setup Costs only (base ng ROI)
  double get totalInvestment => businessSetupCosts;

  // ── Break-Even Computed ────────────────────────────────────────
  // Real weighted profit margin from actual sales (grossProfit /
  // grossRevenue), not an average of catalog prices — a sari-sari
  // store's shelf spans ₱7 sachets to ₱500 goods, so an "average
  // unit price" across every listed product never corresponded to
  // anything real. The margin actual sales produce does.
  double get profitMarginPercent {
    if (grossRevenue <= 0) return 0;
    return (grossProfit / grossRevenue) * 100;
  }

  // Peso revenue needed (at the store's real margin) to fully cover
  // total logged expenses. 0 both when there's no sales history yet
  // and when the store is running at an overall loss (margin <= 0) —
  // callers should check grossRevenue separately to tell those apart.
  double get breakEvenRevenue {
    if (grossRevenue <= 0 || grossProfit <= 0) return 0;
    return totalExpensesAmount / (grossProfit / grossRevenue);
  }

  double get totalSalesProfit => grossProfit;

  // Expense records + grocery resupply trips combined — a grocery entry
  // is real cash leaving the register just like a "Stocks / Resupply"
  // expense, so it has to count here too or Net Profit/Current Capital/
  // Break-Even would understate cash outflow every time stock is bought
  // through Grocery instead of the Expenses screen.
  double get totalExpensesAmount => CurrencyFormatter.roundCents(
      expenses.fold(0.0, (s, e) => s + e.amount) +
      groceryEntries.fold(0.0, (s, g) => s + g.totalExpenses));

  // ── Grocery Computed ────────────────────────────────────────────
  // General Total — all-time grocery spend across every logged trip.
  double get generalGroceryTotal => CurrencyFormatter.roundCents(
      groceryEntries.fold(0.0, (s, g) => s + g.totalExpenses));

  // Total per calendar month ("MONTHLY GROCERY"), keyed by "YYYY-MM" and
  // sorted most-recent month first, so the summary can show at a glance
  // how much was spent on groceries each month rather than only the
  // lifetime figure.
  List<MapEntry<String, double>> get groceryTotalsByMonth {
    final totals = <String, double>{};
    for (final g in groceryEntries) {
      totals[g.monthKey] =
          CurrencyFormatter.roundCents((totals[g.monthKey] ?? 0) + g.totalExpenses);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  // Same idea, grouped by Mon–Sun week ("WEEKLY GROCERY") instead of by
  // calendar month — the key is the Monday of that week as "yyyy-MM-dd".
  List<MapEntry<String, double>> get groceryTotalsByWeek {
    final totals = <String, double>{};
    for (final g in groceryEntries) {
      totals[g.weekKey] =
          CurrencyFormatter.roundCents((totals[g.weekKey] ?? 0) + g.totalExpenses);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  // All-time revenue/COGS come from SQL aggregates (loaded in _loadAll),
  // not from folding `sales` — that list is capped to the most recent
  // entries for UI performance, so folding it would silently understate
  // lifetime figures (and everything derived: profit, ROI, capital)
  // once the store logs more sales than the cap.
  double _allTimeRevenue = 0;
  double _allTimeCOGS = 0;

  // Consecutive days with a completed sale, ending today (or still
  // "alive" through today if today just hasn't sold anything yet).
  int streak = 0;

  // Gross Revenue — total sales amount
  double get grossRevenue => CurrencyFormatter.roundCents(_allTimeRevenue);

  // Total COGS — total cost of all sold items
  double get totalCOGS => CurrencyFormatter.roundCents(_allTimeCOGS);

  // Gross Profit = Revenue - COGS
  double get grossProfit =>
      CurrencyFormatter.roundCents(grossRevenue - totalCOGS);

  // Net Profit = Gross Profit - Expenses
  double get netProfit =>
      CurrencyFormatter.roundCents(grossProfit - totalExpensesAmount);

  // Current Capital = Investment + Net Profit
  double get currentCapital =>
      CurrencyFormatter.roundCents(totalInvestment + netProfit);

  // Net Gain/Loss
  double get netGainLoss => netProfit;

  // ROI = Net Profit YTD / Total Startup Costs × 100
  double get roiPercent {
    if (totalInvestment <= 0) return 0;
    return (netProfit / totalInvestment) * 100;
  }

  // ── Init ───────────────────────────────────────────────────────
  Future<void> initialize() async {
    isLoading = true;
    _safeNotifyListeners();
    await _loadAll();
    try {
      await _db.recordMonthlySnapshotIfNeeded();
      await _db.backfillPreviousMonthSnapshotIfPossible();
    } catch (_) {}
    isLoading = false;
    _safeNotifyListeners();

    // Fire-and-forget: must never delay startup or crash it.
    unawaited(BackupService.instance.autoBackupIfNeeded());
    unawaited(NotificationService.instance.scheduleWeeklyBackupReminder());
    unawaited(_notifyYesterdaySummaryIfNeeded());
  }

  Future<void> _notifyYesterdaySummaryIfNeeded() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdaySales = sales.where((s) =>
        s.status == TxStatus.completed &&
        DateHelper.isSameDay(s.createdAt, yesterday));

    final revenue = CurrencyFormatter.roundCents(
        yesterdaySales.fold(0.0, (s, t) => s + t.totalAmount));
    final profit = CurrencyFormatter.roundCents(
        yesterdaySales.fold(0.0, (s, t) => s + t.totalProfit));

    try {
      await NotificationService.instance.showDailySummaryIfNeeded(
        revenue: revenue,
        profit: profit,
        transactions: yesterdaySales.length,
      );
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _db.getCustomers(),
      _db.getProducts(),
      _db.getSales(),
      _db.getExpenses(),
      _db.getDebts(),
      _db.getPayments(),
      _db.getCicoTransactions(),
      _db.getRateRules(),
      _db.getGroceryEntries(),
    ]);
    customers = results[0] as List<Customer>;
    products = results[1] as List<Product>;
    sales = results[2] as List<Sale>;
    expenses = results[3] as List<Expense>;
    debts = results[4] as List<Debt>;
    payments = results[5] as List<DebtPayment>;
    cico = results[6] as List<CicoTransaction>;
    rates = results[7] as List<CicoRateRule>;
    groceryEntries = results[8] as List<GroceryEntry>;
    capital = await _db.getCapital();
    final totals = await _db.getAllTimeTotals();
    _allTimeRevenue = totals['revenue'] ?? 0;
    _allTimeCOGS = totals['cogs'] ?? 0;
    streak = await _db.getCurrentStreak();
  }

  Future<void> reload() async {
    await _loadAll();
    _safeNotifyListeners();
  }

  // ── Cart ───────────────────────────────────────────────────────
  void addToCart(Product product) {
    final qty = cart[product] ?? 0;
    if (qty >= product.stock) return;
    cart[product] = qty + 1;
    _safeNotifyListeners();
  }

  void setCartQty(Product product, int qty) {
    if (qty <= 0) {
      cart.remove(product);
    } else if (qty <= product.stock) {
      cart[product] = qty;
    }
    _safeNotifyListeners();
  }

  void removeFromCart(Product product) {
    cart.remove(product);
    _safeNotifyListeners();
  }

  void clearCart() {
    cart.clear();
    _safeNotifyListeners();
  }

  // ── Sales ──────────────────────────────────────────────────────
  // Returns null if the cart is empty, or if a requested loyalty-points
  // redemption fails — the caller (sales_screen.dart) already validated
  // `cashPaid` against the *discounted* total before calling this, so
  // silently dropping the discount here would complete the sale at a
  // higher total than what was actually collected. Aborting entirely (no
  // sale, stock, or debt written) keeps the cart intact so the cashier can
  // retry, rather than leaving a sale on record that doesn't reconcile
  // with the cash actually taken.
  Future<Sale?> completeSale({
    required double cashPaid,
    required double creditAmount,
    required PaymentType type,
    Customer? customer,
    String? notes,
    DateTime? dueDate,
    DateTime? saleDate,
    double discount = 0,
    int pointsToRedeem = 0,
  }) async {
    if (cart.isEmpty) return null;

    // Re-validate against current stock right before writing anything — a
    // cart's quantity is only checked against stock at the moment an item
    // is added (addToCart/setCartQty), so it can go stale if another sale
    // for the same product completes while this cart sits open.
    for (final entry in cart.entries) {
      _checkStock(entry.key.id, entry.value);
    }

    final items = cart.entries
        .map((e) => TxItem(
              productId: e.key.id,
              productName: e.key.name,
              quantity: e.value,
              price: e.key.sellPrice,
              buyPrice: e.key.buyPrice,
            ))
        .toList();

    // Redeem loyalty points BEFORE pricing the sale: if the redemption
    // fails (e.g. the balance was stale and the points are gone), abort
    // the sale rather than applying the discount anyway (which would give
    // money off without any points being deducted) or dropping it and
    // charging more than the cash already collected assumed.
    final saleId = _uuid.v4();
    final appliedDiscount = discount;
    if (customer != null && pointsToRedeem > 0) {
      final redeemed = await LoyaltyService.instance.redeemPoints(
        customerId: customer.id,
        points: pointsToRedeem,
        saleId: saleId,
      );
      if (!redeemed) return null;
    }

    final discountedTotal = CurrencyFormatter.roundCents(
        (cartTotal - appliedDiscount).clamp(0, cartTotal).toDouble());

    var sale = Sale(
      id: saleId,
      items: items,
      totalAmount: discountedTotal,
      cashPaid: cashPaid,
      creditAmount: creditAmount,
      customerId: customer?.id,
      customerName: customer?.name,
      type: type,
      notes: notes,
      createdAt: saleDate ?? DateTime.now(),
    );

    sale = sale.copyWith(receiptNumber: await _db.insertSale(sale));

    for (final e in cart.entries) {
      await _db.adjustProductStock(e.key.id, -e.value);
    }

    if (creditAmount > 0 && customer != null) {
      final debtDueDate =
          dueDate ?? DateTime.now().add(const Duration(days: 30));
      await _db.insertDebt(Debt(
        id: _uuid.v4(),
        customerId: customer.id,
        customerName: customer.name,
        saleId: sale.id,
        originalAmount: creditAmount,
        paidAmount: 0,
        status: DebtStatus.unpaid,
        dueDate: debtDueDate,
        createdAt: DateTime.now(),
      ));
      await NotificationService.instance.scheduleDebtReminder(
        customerName: customer.name,
        dueDate: debtDueDate,
        amount: creditAmount,
      );
    }

    if (customer != null) {
      await LoyaltyService.instance.addPointsFromSale(
        customerId: customer.id,
        customerName: customer.name,
        saleAmount: discountedTotal,
        saleDate: sale.createdAt,
        saleId: sale.id,
      );
    }

    clearCart();
    await _loadAll();
    _safeNotifyListeners();

    final lowStockNames = lowStock.map((p) => p.name).toList();
    final outOfStockNames = outOfStock.map((p) => p.name).toList();
    await NotificationService.instance
        .scheduleStockCheck(lowStockNames, outOfStockNames);

    return sale;
  }

  /// Records a credit ("utang") sale from pre-picked items. Always a
  /// [PaymentType.credit] sale — the credit-order flow is its only caller.
  Future<Sale?> completeSaleWithItems({
    required List<dynamic> items,
    required double cashPaid,
    required double creditAmount,
    Customer? customer,
    String? notes,
    DateTime? dueDate,
    DateTime? saleDate,
  }) async {
    for (final e in items) {
      _checkStock((e['product'] as Product).id, e['qty'] as int);
    }

    final txItems = items.map((e) {
      final product = e['product'] as Product;
      final qty = e['qty'] as int;
      return TxItem(
        productId: product.id,
        productName: product.name,
        quantity: qty,
        price: product.sellPrice,
        buyPrice: product.buyPrice,
      );
    }).toList();

    final total = CurrencyFormatter.roundCents(
        txItems.fold(0.0, (s, i) => s + i.subtotal));

    var sale = Sale(
      id: _uuid.v4(),
      items: txItems,
      totalAmount: total,
      cashPaid: cashPaid,
      creditAmount: creditAmount,
      customerId: customer?.id,
      customerName: customer?.name,
      type: PaymentType.credit,
      notes: notes,
      createdAt: saleDate ?? DateTime.now(),
    );

    sale = sale.copyWith(receiptNumber: await _db.insertSale(sale));

    for (final e in items) {
      final product = e['product'] as Product;
      final qty = e['qty'] as int;
      await _db.adjustProductStock(product.id, -qty);
    }

    if (creditAmount > 0 && customer != null) {
      final debtDueDate =
          dueDate ?? DateTime.now().add(const Duration(days: 30));
      await _db.insertDebt(Debt(
        id: _uuid.v4(),
        customerId: customer.id,
        customerName: customer.name,
        saleId: sale.id,
        originalAmount: creditAmount,
        paidAmount: 0,
        status: DebtStatus.unpaid,
        dueDate: debtDueDate,
        createdAt: DateTime.now(),
      ));
      await NotificationService.instance.scheduleDebtReminder(
        customerName: customer.name,
        dueDate: debtDueDate,
        amount: creditAmount,
      );
    }

    if (customer != null) {
      await LoyaltyService.instance.addPointsFromSale(
        customerId: customer.id,
        customerName: customer.name,
        saleAmount: total,
        saleDate: sale.createdAt,
        saleId: sale.id,
      );
    }

    await _loadAll();
    _safeNotifyListeners();
    return sale;
  }

  /// Voids a sale: restores stock, removes its debts, reverses loyalty
  /// points, and deletes any installment plan created from it (the plan
  /// tracks goods this void just put back on the shelf — leaving it
  /// active would keep collecting payments against a dead sale).
  ///
  /// Returns an error message (and does nothing) when the sale's debt
  /// already has payments recorded: voiding would delete those payment
  /// rows and silently erase cash the store actually collected.
  Future<String?> voidSale(Sale sale) async {
    final alreadyPaid = await _db.getDebtPaidAmountBySale(sale.id);
    if (alreadyPaid > 0) {
      return 'Cannot void: ${CurrencyFormatter.format(alreadyPaid)} has '
          'already been paid on this credit. Settle or record it first.';
    }
    // Installment sales never get a `Debt` row (see recordInstallmentSale),
    // so the check above can't see money collected via monthly payments —
    // those only exist on the linked Installment's totalPaid. Block the
    // void the same way if any payment beyond the original down payment
    // (already baked into this sale's own totals) has been recorded.
    if (sale.type == PaymentType.installment) {
      final plan = (await InstallmentService.instance.getAll())
          .where((p) => p.saleId == sale.id)
          .firstOrNull;
      if (plan != null && plan.paidMonths > 0) {
        final collected =
            CurrencyFormatter.roundCents(plan.totalPaid - plan.downPayment);
        return 'Cannot void: ${CurrencyFormatter.format(collected)} in '
            'installment payments has already been collected. Settle or '
            'record it first.';
      }
    }
    // Adjusts stock in place by id rather than looking the product up in
    // the (active-only) in-memory list and rewriting the whole row — that
    // used to fabricate a blank stand-in for archived products and wipe
    // out their real price/category data when the update landed.
    for (final item in sale.items) {
      await _db.adjustProductStock(item.productId, item.quantity);
    }
    await _db.voidSale(sale.id);
    await _db.deleteDebtsBySale(sale.id);
    if (sale.customerId != null) {
      await LoyaltyService.instance.voidPointsFromSale(
        customerId: sale.customerId!,
        saleId: sale.id,
      );
    }
    if (sale.type == PaymentType.installment) {
      final plans = await InstallmentService.instance.getAll();
      for (final plan in plans.where((p) => p.saleId == sale.id)) {
        await InstallmentService.instance.delete(plan.id);
      }
    }
    await reload();
    return null;
  }

  /// Void by id, fetching the sale straight from the DB — the in-memory
  /// `sales` list only holds recent entries, so an old installment sale
  /// (e.g. a months-old plan being deleted) may not be in it; using the
  /// list would silently skip the void and never restore stock.
  Future<String?> voidSaleById(String saleId) async {
    final sale = await _db.getSaleById(saleId);
    if (sale == null || sale.isVoided) return null;
    return voidSale(sale);
  }

  /// Records the sale side of a new installment plan: creates a real
  /// `Sale`/`sale_items` row (so revenue, profit, and stock are correct
  /// immediately, since the goods leave the shelf right away) and
  /// decrements stock, without creating a `Debt` — the outstanding
  /// balance for an installment is tracked separately by
  /// [Installment.remainingBalance], so a parallel Debt row would just
  /// be a second, easily-desynced source of truth for the same amount.
  /// `cashPaid`/`creditAmount` reflect the actual down payment and
  /// deferred balance (not the full total as "paid"), so receipts and
  /// daily-summary tender breakdowns stay accurate.
  /// Returns the new sale's id so the caller can link it on the
  /// [Installment] record (for stock restoration if it's later deleted).
  Future<String> recordInstallmentSale({
    required Map<Product, int> items,
    required String customerId,
    required String customerName,
    required double totalAmount,
    required double downPayment,
  }) async {
    for (final e in items.entries) {
      _checkStock(e.key.id, e.value);
    }

    final txItems = items.entries
        .map((e) => TxItem(
              productId: e.key.id,
              productName: e.key.name,
              quantity: e.value,
              price: e.key.sellPrice,
              buyPrice: e.key.buyPrice,
            ))
        .toList();

    final sale = Sale(
      id: _uuid.v4(),
      items: txItems,
      totalAmount: totalAmount,
      cashPaid: downPayment,
      creditAmount: totalAmount - downPayment,
      customerId: customerId,
      customerName: customerName,
      type: PaymentType.installment,
      notes: 'Installment sale',
      createdAt: DateTime.now(),
    );

    await _db.insertSale(sale);
    for (final e in items.entries) {
      await _db.adjustProductStock(e.key.id, -e.value);
    }

    final customer = customers.where((c) => c.id == customerId).firstOrNull;
    if (customer != null) {
      await LoyaltyService.instance.addPointsFromSale(
        customerId: customer.id,
        customerName: customer.name,
        saleAmount: totalAmount,
        saleDate: sale.createdAt,
        saleId: sale.id,
      );
    }

    await reload();
    return sale.id;
  }

  // ── Customers ──────────────────────────────────────────────────
  // Returns the created Customer directly so callers don't have to
  // re-query `customers` by name afterward — that re-query used to fall
  // back to "the last customer in the list" if it somehow came up empty,
  // which could silently attach a sale/debt/installment to a completely
  // unrelated customer instead of failing loudly.
  Future<Customer> addCustomer(String name,
      {String? phone, String? address, double creditLimit = 500}) async {
    final customer = Customer(
        id: _uuid.v4(),
        name: name,
        phone: phone,
        address: address,
        creditLimit: creditLimit,
        createdAt: DateTime.now());
    await _db.insertCustomer(customer);
    await reload();
    return customer;
  }

  Future<void> updateCustomer(Customer c) async {
    await _db.updateCustomer(c);
    await reload();
  }

  /// Deletes a customer's installment plans too, since they live in
  /// SharedPreferences (installments never got a debts-table row) and
  /// would otherwise keep showing up in the Installment tab pointing at
  /// a customer that no longer exists anywhere else in the app. Any
  /// still-unpaid plan also has its sold stock restored — a completed
  /// one is left alone, since those goods were already fully paid for.
  Future<void> deleteCustomer(String id) async {
    final theirInstallments = (await InstallmentService.instance.getAll())
        .where((i) => i.customerId == id);
    for (final inst in theirInstallments) {
      if (inst.status != InstallmentStatus.completed && inst.saleId != null) {
        await voidSaleById(inst.saleId!);
      }
      await InstallmentService.instance.delete(inst.id);
    }

    await _db.deleteCustomer(id);
    await reload();
  }

  // ── Products ───────────────────────────────────────────────────
  Future<void> addProduct(Product p) async {
    await _db.insertProduct(p);
    products = await _db.getProducts();
    _safeNotifyListeners();
  }

  Future<void> updateProduct(Product p) async {
    await _db.updateProduct(p);
    products = await _db.getProducts();
    _safeNotifyListeners();
  }

  /// Bulk catalog import — one batch insert plus a single reload/notify,
  /// instead of looping [addProduct] which would reload+notify once per
  /// row and be far slower for a few hundred products.
  Future<void> importProducts(List<Product> newProducts) async {
    if (newProducts.isEmpty) return;
    await _db.importProducts(newProducts);
    products = await _db.getProducts();
    _safeNotifyListeners();
  }

  /// Toggles the active/archive state of a product to hide it without hard deleting data
  Future<void> archiveProduct(String id) async {
    await _db.archiveProduct(id);
    products = await _db.getProducts();
    _safeNotifyListeners();
  }

  // Bulk version of archiveProduct for "Clear All Products" — one DB
  // statement and one reload/rebuild instead of one of each per product.
  Future<void> archiveAllProducts() async {
    await _db.archiveAllProducts();
    products = await _db.getProducts();
    _safeNotifyListeners();
  }

  Future<void> restoreProduct(String id) async {
    await _db.restoreProduct(id);
    products = await _db.getProducts();
    _safeNotifyListeners();
  }

  // ── Capital ────────────────────────────────────────────────────
  Future<void> saveCapital({
    required double setupCosts,
    required double inventoryValue,
    List<SetupCostItem>? setupItems,
  }) async {
    final entry = CapitalEntry(
      id: capital?.id ?? _uuid.v4(),
      setupCosts: setupCosts,
      inventoryValue: inventoryValue,
      setupItems: setupItems ?? capital?.setupItems ?? [],
      createdAt: capital?.createdAt ?? DateTime.now(),
      updatedAt: capital != null ? DateTime.now() : null,
    );

    await _db.upsertCapital(entry);
    await reload();
  }

  // ── Expenses ───────────────────────────────────────────────────
  Future<void> addExpense(String desc, String cat, double amount,
      {String? notes, DateTime? date}) async {
    await _db.insertExpense(Expense(
        id: _uuid.v4(),
        description: desc,
        category: cat,
        amount: amount,
        date: date ?? DateTime.now(),
        notes: notes));
    await reload();
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    await reload();
  }

  Future<void> deleteExpense(String id) async {
    await _db.deleteExpense(id);
    await reload();
  }

  // ── Grocery ────────────────────────────────────────────────────
  // A grocery entry is a store resupply trip — logging one adds its
  // quantity straight to the picked product's stock via the same atomic
  // SQL adjustment sales/voids use, so two near-simultaneous stock
  // changes can never clobber each other.
  Future<void> addGroceryEntry({
    required String productId,
    required String productName,
    required int quantity,
    required double budget,
    required double expensesForProducts,
    required double transpo,
    DateTime? date,
    String? notes,
  }) async {
    await _db.insertGroceryEntry(GroceryEntry(
        id: _uuid.v4(),
        productId: productId,
        productName: productName,
        quantity: quantity,
        budget: budget,
        expensesForProducts: expensesForProducts,
        transpo: transpo,
        date: date ?? DateTime.now(),
        notes: notes));
    if (productId.isNotEmpty) {
      await _db.adjustProductStock(productId, quantity);
    }
    await reload();
  }

  // Reverses the original entry's stock effect before applying the
  // updated one — same product just nets the quantity difference, a
  // changed product reverses the old one and credits the new one —
  // so editing a trip (e.g. fixing a mistyped quantity) never leaves
  // stock double-counted or stuck at the old figure.
  Future<void> updateGroceryEntry(GroceryEntry updated) async {
    final old = groceryEntries.where((g) => g.id == updated.id).firstOrNull;
    if (old != null) {
      if (old.productId == updated.productId) {
        final delta = updated.quantity - old.quantity;
        if (delta != 0 && updated.productId.isNotEmpty) {
          await _db.adjustProductStock(updated.productId, delta);
        }
      } else {
        if (old.productId.isNotEmpty) {
          await _db.adjustProductStock(old.productId, -old.quantity);
        }
        if (updated.productId.isNotEmpty) {
          await _db.adjustProductStock(updated.productId, updated.quantity);
        }
      }
    }
    await _db.updateGroceryEntry(updated);
    await reload();
  }

  Future<void> deleteGroceryEntry(String id) async {
    final entry = groceryEntries.where((g) => g.id == id).firstOrNull;
    if (entry != null && entry.productId.isNotEmpty) {
      await _db.adjustProductStock(entry.productId, -entry.quantity);
    }
    await _db.deleteGroceryEntry(id);
    await reload();
  }

  // ── CICO (E-Wallet) ─────────────────────────────────────────────
  Future<void> addCicoTransaction({
    required CicoType type,
    required String provider,
    required double amount,
    double commission = 0,
    String? notes,
    DateTime? date,
    String liquidAccount = CicoTransaction.cashAccount,
    CicoAccountKind accountKind = CicoAccountKind.wallet,
    String? customerName,
    String? customerPhone,
    String? transferAccount,
  }) async {
    await _db.insertCicoTransaction(CicoTransaction(
        id: _uuid.v4(),
        type: type,
        provider: provider,
        amount: amount,
        commission: commission,
        notes: notes,
        createdAt: date ?? DateTime.now(),
        liquidAccount: liquidAccount,
        accountKind: accountKind,
        customerName: customerName,
        customerPhone: customerPhone,
        transferAccount: transferAccount));
    await reload();
  }

  Future<void> updateCicoTransaction(CicoTransaction t) async {
    await _db.updateCicoTransaction(t);
    await reload();
  }

  Future<void> deleteCicoTransaction(String id) async {
    await _db.deleteCicoTransaction(id);
    await reload();
  }

  // ── CICO Rates ─────────────────────────────────────────────────
  Future<void> addRateRule(CicoRateRule rule) async {
    await _db.insertRateRule(rule);
    await reload();
  }

  // Bulk add (e.g. "Load Standard Rates") — one batched insert and one
  // reload instead of one of each per rule.
  Future<void> addRateRules(List<CicoRateRule> newRules) async {
    if (newRules.isEmpty) return;
    await _db.insertRateRules(newRules);
    await reload();
  }

  Future<void> updateRateRule(CicoRateRule rule) async {
    await _db.updateRateRule(rule);
    await reload();
  }

  Future<void> deleteRateRule(String id) async {
    await _db.deleteRateRule(id);
    await reload();
  }

  Future<void> deleteAllRateRules() async {
    await _db.deleteAllRateRules();
    await reload();
  }

  /// In-memory lookup over the already-loaded [rates] list (same style as
  /// cicoWalletBalance/cicoBankBalance below, which fold over the loaded
  /// [cico] list rather than hitting the DB). If tiers overlap, the one
  /// with the lowest minAmount wins.
  CicoRateRule? resolveRate({
    required CicoType type,
    required String provider,
    required double amount,
  }) {
    final matches = rates
        .where((r) =>
            r.isActive &&
            r.txnType == type &&
            r.provider == provider &&
            amount >= r.minAmount &&
            (r.maxAmount == null || amount <= r.maxAmount!))
        .toList()
      ..sort((a, b) => a.minAmount.compareTo(b.minAmount));
    return matches.firstOrNull;
  }

  /// The full rate ladder for a provider+direction, sorted by minAmount —
  /// shared by the Add Transaction form's and the Padala Calculator's rate
  /// ladder previews so they don't each re-filter/sort [rates] themselves.
  List<CicoRateRule> rateTiersFor(
      {required String provider, required CicoType type}) {
    final tiers = rates
        .where((r) => r.provider == provider && r.txnType == type)
        .toList()
      ..sort((a, b) => a.minAmount.compareTo(b.minAmount));
    return tiers;
  }

  // topUp/withdraw only: `transferAccount` optionally names the other side
  // of the adjustment (Cash, a bank, or a wallet) so it nets against a
  // second account instead of only touching `provider`. Null (including
  // every transaction written before this field existed) means "no other
  // side" and contributes nothing here.
  double _cicoTransferDelta(CicoTransaction t, String accountName) {
    if (t.transferAccount != accountName) return 0;
    return switch (t.type) {
      CicoType.topUp => -t.amount,
      CicoType.withdraw => t.amount,
      _ => 0,
    };
  }

  // cashIn/cashOut: `liquidAccount` names the funding side (Cash or a bank).
  // topUp/withdraw: `provider` names the target, and only counts toward
  // this account when `accountKind` says it's the cash float; `transferAccount`
  // separately counts the other side of the transfer, if one was recorded.
  double _cicoCashDelta(CicoTransaction t) {
    switch (t.type) {
      case CicoType.cashIn:
        return t.liquidAccount == CicoTransaction.cashAccount ? t.amount : 0;
      case CicoType.cashOut:
        return t.liquidAccount == CicoTransaction.cashAccount ? -t.amount : 0;
      case CicoType.topUp:
        return (t.accountKind == CicoAccountKind.cash ? t.amount : 0) +
            _cicoTransferDelta(t, CicoTransaction.cashAccount);
      case CicoType.withdraw:
        return (t.accountKind == CicoAccountKind.cash ? -t.amount : 0) +
            _cicoTransferDelta(t, CicoTransaction.cashAccount);
    }
  }

  // cashIn/cashOut: funds a named bank when `liquidAccount` matches it.
  // topUp/withdraw: targets a named bank when `accountKind` is bank and
  // `provider` matches it; `transferAccount` separately counts this bank as
  // the other side of the transfer, if one was recorded.
  double _cicoBankDelta(CicoTransaction t, String bankName) {
    switch (t.type) {
      case CicoType.cashIn:
        return t.liquidAccount == bankName ? t.amount : 0;
      case CicoType.cashOut:
        return t.liquidAccount == bankName ? -t.amount : 0;
      case CicoType.topUp:
        return (t.accountKind == CicoAccountKind.bank && t.provider == bankName
                ? t.amount
                : 0) +
            _cicoTransferDelta(t, bankName);
      case CicoType.withdraw:
        return (t.accountKind == CicoAccountKind.bank && t.provider == bankName
                ? -t.amount
                : 0) +
            _cicoTransferDelta(t, bankName);
    }
  }

  // cashIn/cashOut: `provider` is always the e-wallet name.
  // topUp/withdraw: targets a named wallet only when `accountKind` is wallet;
  // `transferAccount` separately counts this wallet as the other side of the
  // transfer, if one was recorded.
  double _cicoWalletDelta(CicoTransaction t, String provider) {
    double delta = 0;
    if (t.provider == provider) {
      switch (t.type) {
        case CicoType.cashIn:
          delta -= t.amount;
        case CicoType.cashOut:
          delta += t.amount;
        case CicoType.topUp:
          if (t.accountKind == CicoAccountKind.wallet) delta += t.amount;
        case CicoType.withdraw:
          if (t.accountKind == CicoAccountKind.wallet) delta -= t.amount;
      }
    }
    return delta + _cicoTransferDelta(t, provider);
  }

  double get cicoCashFloatBalance => CurrencyFormatter.roundCents(
      cico.fold(0.0, (s, t) => s + _cicoCashDelta(t)));

  double cicoBankBalance(String bankName) => CurrencyFormatter.roundCents(
      cico.fold(0.0, (s, t) => s + _cicoBankDelta(t, bankName)));

  double cicoWalletBalance(String provider) => CurrencyFormatter.roundCents(
      cico.fold(0.0, (s, t) => s + _cicoWalletDelta(t, provider)));

  List<String> get cicoKnownProviders => {
        ...CicoTransaction.presetProviders,
        ...cico
            .where((t) =>
                t.type == CicoType.cashIn ||
                t.type == CicoType.cashOut ||
                t.accountKind == CicoAccountKind.wallet)
            .map((t) => t.provider),
      }.toList();

  List<String> get cicoKnownBanks => {
        ...cico
            .where((t) =>
                (t.type == CicoType.cashIn || t.type == CicoType.cashOut) &&
                t.liquidAccount != CicoTransaction.cashAccount)
            .map((t) => t.liquidAccount),
        ...cico
            .where((t) =>
                (t.type == CicoType.topUp || t.type == CicoType.withdraw) &&
                t.accountKind == CicoAccountKind.bank)
            .map((t) => t.provider),
      }.toList();

  double get cicoTotalCommission =>
      CurrencyFormatter.roundCents(cico.fold(0.0, (s, t) => s + t.commission));

  double get cicoTodayCommission {
    final now = DateTime.now();
    return CurrencyFormatter.roundCents(cico
        .where((t) =>
            t.createdAt.year == now.year &&
            t.createdAt.month == now.month &&
            t.createdAt.day == now.day)
        .fold(0.0, (s, t) => s + t.commission));
  }

  // ── Debts / Payments ───────────────────────────────────────────
  List<Debt> debtsFor(String customerId) =>
      debts.where((d) => d.customerId == customerId).toList();

  double unpaidDebtFor(String customerId) =>
      CurrencyFormatter.roundCents(debtsFor(customerId)
          .where((d) => d.status != DebtStatus.paid)
          .fold(0.0, (s, d) => s + d.remaining));

  Future<void> recordPayment(Debt debt, double amount, {String? notes}) async {
    await _db.insertPayment(DebtPayment(
      id: _uuid.v4(),
      debtId: debt.id,
      customerId: debt.customerId,
      customerName: debt.customerName,
      amount: amount,
      notes: notes,
      createdAt: DateTime.now(),
    ));
    await _db.adjustDebtPaidAmount(debt.id, amount);
    await reload();
  }

  /// Public wrapper so screens (which only ever talk to AppProvider,
  /// never DatabaseService directly) can apply a stock delta through
  /// the atomic, race-safe path instead of a Dart-side
  /// `updateProduct(product.copyWith(stock: ...))` computed from a
  /// possibly-stale snapshot.
  Future<void> adjustProductStock(String productId, int delta) async {
    await _db.adjustProductStock(productId, delta);
    await reload();
  }
}
