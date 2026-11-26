// Unit tests for the money logic from the 2026-11-26 code review (M1-M3).
// Runs on the desktop SQLite engine (sqflite_common_ffi), fresh DB per test.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:store_ph/models/debt.dart';
import 'package:store_ph/models/expense.dart';
import 'package:store_ph/models/grocery_entry.dart';
import 'package:store_ph/models/payment.dart';
import 'package:store_ph/models/product.dart';
import 'package:store_ph/models/transaction.dart';
import 'package:store_ph/services/database_service.dart';
import 'package:store_ph/services/report_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final db = DatabaseService.instance;
final now = DateTime.now();

Future<Product> product(String id, {double buy = 10, int stock = 0}) async {
  final p = Product(
      id: id,
      name: id,
      category: 'Others',
      buyPrice: buy,
      sellPrice: 15,
      stock: stock,
      createdAt: now);
  await db.insertProduct(p);
  return p;
}

Future<Map<String, Object?>> row(String id) async =>
    (await (await db.database)
            .query('products', where: 'id=?', whereArgs: [id]))
        .single;

GroceryEntry trip(String productId, int qty, double cost, double transpo) =>
    GroceryEntry(
        id: 'g-$productId-$qty',
        productId: productId,
        productName: productId,
        quantity: qty,
        expensesForProducts: cost,
        transpo: transpo,
        date: now);

Sale sale(String id, Product p, int qty, PaymentType type) => Sale(
    id: id,
    items: [
      TxItem(
          productId: p.id,
          productName: p.name,
          quantity: qty,
          price: p.sellPrice,
          buyPrice: p.buyPrice)
    ],
    totalAmount: p.sellPrice * qty,
    cashPaid: type == PaymentType.cash ? p.sellPrice * qty : 0,
    creditAmount: type == PaymentType.credit ? p.sellPrice * qty : 0,
    type: type,
    createdAt: now);

Debt debt(String id, String saleId, double amount) => Debt(
    id: id,
    customerId: 'c1',
    customerName: 'Aling Nena',
    saleId: saleId,
    originalAmount: amount,
    paidAmount: 0,
    status: DebtStatus.unpaid,
    dueDate: now,
    createdAt: now);

DebtPayment pay(String id, String debtId, double amount) => DebtPayment(
    id: id,
    debtId: debtId,
    customerId: 'c1',
    customerName: 'Aling Nena',
    amount: amount,
    createdAt: now);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await db.closeForTest();
    await databaseFactory
        .deleteDatabase(join(await getDatabasesPath(), 'pos_system.db'));
  });

  test('M1: restock moves buyPrice to the weighted average', () async {
    await product('rice', buy: 10, stock: 10);
    // 10 on hand at 10.00 + 10 new at 12.00 -> 20 at 11.00
    await db.addGroceryEntryWithStock(trip('rice', 10, 120, 0));
    var r = await row('rice');
    expect(r['stock'], 20);
    expect(r['buyPrice'], 11.0);

    // A product with no cost yet takes the trip's unit cost outright.
    await product('soap', buy: 0, stock: 0);
    await db.addGroceryEntryWithStock(trip('soap', 4, 50, 0));
    r = await row('soap');
    expect(r['stock'], 4);
    expect(r['buyPrice'], 12.5);
  });

  test('Reports: grocery item cost counted once, transport as expense',
      () async {
    final p = await product('sardines', buy: 10, stock: 0);
    await db.addGroceryEntryWithStock(trip('sardines', 10, 100, 30));
    await db.insertSale(sale('s1', p, 4, PaymentType.cash));
    final groceries = await db.getGroceryEntries();
    final expenses = [
      Expense(
          id: 'e1',
          description: 'Kuryente',
          category: 'Utilities',
          amount: 100,
          date: now)
    ];
    final r = await ReportService.instance.generateReport(
        expenses: expenses,
        groceryEntries: groceries,
        cico: const [],
        since: now.subtract(const Duration(days: 1)),
        until: now);
    expect(r.totalRevenue, 60); // 4 x 15
    expect(r.totalProfit, 20); // 4 x (15 - 10): item cost leaves via COGS
    expect(r.totalExpenses, 130); // 100 expense + 30 transport, no item cost
    expect(r.groceryTotal, 130); // 100 items + 30 transport (display only)
  });

  test('Debt: paidAmount is capped at the original amount', () async {
    await db.insertDebt(debt('d1', 's1', 100));
    await db.recordPaymentAtomic(pay('p1', 'd1', 60));
    await db.recordPaymentAtomic(pay('p2', 'd1', 60));
    final d = (await db.getDebts()).single;
    expect(d.paidAmount, 100);
    expect(d.status, DebtStatus.paid);
    expect((await db.getPayments()).length, 2);
  });

  test('Void: restores stock, voids the sale and drops its debts at once',
      () async {
    final p = await product('noodles', buy: 8, stock: 5);
    final s = sale('s2', p, 3, PaymentType.credit);
    await db.insertSale(s);
    await db.insertDebt(debt('d2', 's2', 45));
    await db.voidSaleWithStock(s);
    expect((await row('noodles'))['stock'], 8);
    expect((await db.getSaleById('s2'))!.isVoided, isTrue);
    expect(await db.getDebts(), isEmpty);
    // A payment on the debt is what blocks voiding in AppProvider.voidSale.
    await db.insertDebt(debt('d3', 's3', 30));
    await db.recordPaymentAtomic(pay('p3', 'd3', 10));
    expect(await db.getDebtPaidAmountBySale('s3'), 10);
  });

  test('Restore: export -> wipe -> import round-trips the data', () async {
    final p = await product('coffee', buy: 5, stock: 7);
    await db.insertSale(sale('s4', p, 2, PaymentType.cash));
    await db.addGroceryEntryWithStock(trip('coffee', 3, 18, 5));
    final backup = jsonDecode(jsonEncode(await db.exportAll()))
        as Map<String, dynamic>;
    final before = await row('coffee');

    await db.closeForTest();
    await databaseFactory
        .deleteDatabase(join(await getDatabasesPath(), 'pos_system.db'));
    await db.importAll(backup);

    expect(await row('coffee'), before);
    expect((await db.getSaleById('s4'))!.items.single.quantity, 2);
    expect((await db.getGroceryEntries()).single.transpo, 5);
  });
}
