import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/expense.dart';
import '../models/debt.dart';
import '../models/payment.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;

  List<Customer> customers = [];
  List<Product> products = [];
  List<Sale> sales = [];
  List<Expense> expenses = [];
  List<Debt> debts = [];
  List<DebtPayment> payments = [];
  bool isLoading = false;

  final Map<Product, int> cart = {};

  // ── Computed ───────────────────────────────────────────────────
  double get cartTotal =>
      cart.entries.fold(0, (s, e) => s + e.key.sellPrice * e.value);

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

  double get todayRevenue =>
      todaySales.fold(0, (s, t) => s + t.totalAmount);
  double get todayProfit =>
      todaySales.fold(0, (s, t) => s + t.totalProfit);

  double get totalUnpaidDebt => debts
      .where((d) => d.status != DebtStatus.paid)
      .fold(0, (s, d) => s + d.remaining);

  List<Product> get lowStock =>
      products.where((p) => p.isLowStock && p.isActive).toList();
  List<Product> get outOfStock =>
      products.where((p) => p.isOutOfStock && p.isActive).toList();

  // ── Init ───────────────────────────────────────────────────────
  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    await _loadAll();
    isLoading = false;
    notifyListeners();
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
  }

  Future<void> reload() async {
    await _loadAll();
    notifyListeners();
  }

  // ── Cart ───────────────────────────────────────────────────────
  void addToCart(Product product) {
    final qty = cart[product] ?? 0;
    if (qty >= product.stock) return;
    cart[product] = qty + 1;
    notifyListeners();
  }

  void setCartQty(Product product, int qty) {
    if (qty <= 0) {
      cart.remove(product);
    } else if (qty <= product.stock) {
      cart[product] = qty;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    cart.remove(product);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  // ── Sales ──────────────────────────────────────────────────────
  Future<Sale?> completeSale({
    required double cashPaid,
    required double creditAmount,
    required PaymentType type,
    Customer? customer,
    String? notes,
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

    final sale = Sale(
      id: _uuid.v4(),
      items: items,
      totalAmount: cartTotal,
      cashPaid: cashPaid,
      creditAmount: creditAmount,
      customerId: customer?.id,
      customerName: customer?.name,
      type: type,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _db.insertSale(sale);

    for (final e in cart.entries) {
      await _db.updateProduct(
          e.key.copyWith(stock: e.key.stock - e.value));
    }

    if (creditAmount > 0 && customer != null) {
      await _db.insertDebt(Debt(
        id: _uuid.v4(),
        customerId: customer.id,
        customerName: customer.name,
        saleId: sale.id,
        originalAmount: creditAmount,
        paidAmount: 0,
        status: DebtStatus.unpaid,
        dueDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
      ));
    }

    clearCart();
    await _loadAll();
    notifyListeners();

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

    final total = txItems.fold(0.0, (s, i) => s + i.subtotal);

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
      createdAt: DateTime.now(),
    );

    await _db.insertSale(sale);

    for (final e in items) {
      final product = e['product'] as Product;
      final qty = e['qty'] as int;
      await _db.updateProduct(
          product.copyWith(stock: product.stock - qty));
    }

    if (creditAmount > 0 && customer != null) {
      await _db.insertDebt(Debt(
        id: _uuid.v4(),
        customerId: customer.id,
        customerName: customer.name,
        saleId: sale.id,
        originalAmount: creditAmount,
        paidAmount: 0,
        status: DebtStatus.unpaid,
        dueDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
      ));
    }

    await _loadAll();
    notifyListeners();
    return sale;
  }

  Future<void> voidSale(Sale sale) async {
    for (final item in sale.items) {
      final p = products.firstWhere((p) => p.id == item.productId,
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
    await reload();
  }

  Future<void> updateProduct(Product p) async {
    await _db.updateProduct(p);
    await reload();
  }

  Future<void> archiveProduct(String id) async {
    await _db.archiveProduct(id);
    await reload();
  }

  // ── Expenses ───────────────────────────────────────────────────
  Future<void> addExpense(String desc, String cat, double amount,
      {String? notes}) async {
    await _db.insertExpense(Expense(
        id: _uuid.v4(),
        description: desc,
        category: cat,
        amount: amount,
        date: DateTime.now(),
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