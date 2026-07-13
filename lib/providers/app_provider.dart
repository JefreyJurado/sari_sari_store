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
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import '../services/loyalty_service.dart';
import '../utils/currency_formatter.dart';

const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;

  List<Customer> customers = [];
  List<Product> products = [];
  List<Sale> sales = [];
  List<Expense> expenses = [];
  List<Debt> debts = [];
  List<DebtPayment> payments = [];
  CapitalEntry? capital;
  bool isLoading = false;

  final Map<Product, int> cart = {};

  void _safeNotifyListeners() {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  // ── Computed ───────────────────────────────────────────────────
  double get cartTotal => CurrencyFormatter.roundCents(cart.entries
      .fold(0.0, (s, e) => s + e.key.sellPrice * e.value));

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
  double get avgSellPrice {
    if (products.isEmpty) return 0;
    final active = products.where((p) => p.isActive).toList();
    if (active.isEmpty) return 0;
    return CurrencyFormatter.roundCents(
        active.fold(0.0, (s, p) => s + p.sellPrice) / active.length);
  }

  double get avgUnitCost {
    if (products.isEmpty) return 0;
    final active = products.where((p) => p.isActive).toList();
    if (active.isEmpty) return 0;
    return CurrencyFormatter.roundCents(
        active.fold(0.0, (s, p) => s + p.buyPrice) / active.length);
  }

  double get breakEvenUnits {
    final margin = avgSellPrice - avgUnitCost;
    if (margin <= 0) return 0;
    return totalExpensesAmount / margin;
  }

  double get totalSalesProfit => grossProfit;

  double get totalExpensesAmount => CurrencyFormatter.roundCents(
      expenses.fold(0.0, (s, e) => s + e.amount));

  // Gross Revenue — total sales amount
  double get grossRevenue => CurrencyFormatter.roundCents(sales
      .where((s) => s.status == TxStatus.completed)
      .fold(0.0, (s, t) => s + t.totalAmount));

  // Total COGS — total cost of all sold items
  double get totalCOGS => CurrencyFormatter.roundCents(sales
      .where((s) => s.status == TxStatus.completed)
      .fold(0.0, (s, t) => s + t.items.fold(0.0, (si, i) => si + (i.buyPrice * i.quantity))));

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
    isLoading = false;
    _safeNotifyListeners();

    // Fire-and-forget: must never delay startup or crash it.
    unawaited(BackupService.instance.autoBackupIfNeeded());
    unawaited(NotificationService.instance.scheduleWeeklyBackupReminder());
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _db.getCustomers(),
      _db.getProducts(),
      _db.getSales(),
      _db.getExpenses(),
      _db.getDebts(),
      _db.getPayments(),
    ]);
    customers = results[0] as List<Customer>;
    products = results[1] as List<Product>;
    sales = results[2] as List<Sale>;
    expenses = results[3] as List<Expense>;
    debts = results[4] as List<Debt>;
    payments = results[5] as List<DebtPayment>;
    capital = await _db.getCapital();
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

    final items = cart.entries
        .map((e) => TxItem(
              productId: e.key.id,
              productName: e.key.name,
              quantity: e.value,
              price: e.key.sellPrice,
              buyPrice: e.key.buyPrice,
            ))
        .toList();

    final discountedTotal =
        (cartTotal - discount).clamp(0, cartTotal).toDouble();

    final sale = Sale(
      id: _uuid.v4(),
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

    await _db.insertSale(sale);

    for (final e in cart.entries) {
      await _db.updateProduct(
          e.key.copyWith(stock: e.key.stock - e.value));
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
      if (pointsToRedeem > 0) {
        await LoyaltyService.instance.redeemPoints(
          customerId: customer.id,
          points: pointsToRedeem,
          saleId: sale.id,
        );
      }
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

  Future<Sale?> completeSaleWithItems({
    required List<dynamic> items,
    required double cashPaid,
    required double creditAmount,
    required dynamic type,
    Customer? customer,
    String? notes,
    DateTime? dueDate,
    DateTime? saleDate,
  }) async {
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

    final total =
        CurrencyFormatter.roundCents(txItems.fold(0.0, (s, i) => s + i.subtotal));

    final sale = Sale(
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

    await _db.insertSale(sale);

    for (final e in items) {
      final product = e['product'] as Product;
      final qty = e['qty'] as int;
      await _db.updateProduct(
          product.copyWith(stock: product.stock - qty));
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

  Future<void> voidSale(Sale sale) async {
    for (final item in sale.items) {
      final p = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
                id: item.productId,
                name: item.productName,
                category: '',
                buyPrice: 0,
                sellPrice: 0,
                stock: 0,
                createdAt: DateTime.now(),
              ));
      await _db.updateProduct(
          p.copyWith(stock: p.stock + item.quantity));
    }
    await _db.voidSale(sale.id);
    await _db.deleteDebtsBySale(sale.id);
    if (sale.customerId != null) {
      await LoyaltyService.instance.voidPointsFromSale(
        customerId: sale.customerId!,
        saleId: sale.id,
      );
    }
    await reload();
  }

  // ── Customers ──────────────────────────────────────────────────
  Future<void> addCustomer(String name,
      {String? phone,
      String? address,
      double creditLimit = 500}) async {
    await _db.insertCustomer(Customer(
        id: _uuid.v4(),
        name: name,
        phone: phone,
        address: address,
        creditLimit: creditLimit,
        createdAt: DateTime.now()));
    await reload();
  }

  Future<void> updateCustomer(Customer c) async {
    await _db.updateCustomer(c);
    await reload();
  }

  Future<void> deleteCustomer(String id) async {
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

  /// Toggles the active/archive state of a product to hide it without hard deleting data
  Future<void> archiveProduct(String id) async {
    final index = products.indexWhere((p) => p.id == id);
    if (index != -1) {
      // Flips the status flag. Assumes your Product model has an `isActive` property.
      // If it uses another variable name like `isArchived`, change it here.
      final updatedProduct = products[index].copyWith(isActive: false);
      await _db.updateProduct(updatedProduct);
      
      products = await _db.getProducts();
      _safeNotifyListeners();
    }
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

  // ── Debts / Payments ───────────────────────────────────────────
  List<Debt> debtsFor(String customerId) =>
      debts.where((d) => d.customerId == customerId).toList();

  double unpaidDebtFor(String customerId) =>
      CurrencyFormatter.roundCents(debtsFor(customerId)
          .where((d) => d.status != DebtStatus.paid)
          .fold(0.0, (s, d) => s + d.remaining));

  Future<void> recordPayment(Debt debt, double amount,
      {String? notes}) async {
    await _db.insertPayment(DebtPayment(
      id: _uuid.v4(),
      debtId: debt.id,
      customerId: debt.customerId,
      customerName: debt.customerName,
      amount: amount,
      notes: notes,
      createdAt: DateTime.now(),
    ));
    final newPaid = debt.paidAmount + amount;
    final newStatus = newPaid >= debt.originalAmount
        ? DebtStatus.paid
        : DebtStatus.partial;
    await _db.updateDebt(
        debt.copyWith(paidAmount: newPaid, status: newStatus));
    await reload();
  }
}