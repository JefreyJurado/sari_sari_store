import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/expense.dart';
import '../models/debt.dart';
import '../models/payment.dart';
import '../models/capital_entry.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;
  Future<Database> get database async =>
      _db ??= await _init();

  Future<Database> _init() async {
    final path =
        join(await getDatabasesPath(), 'pos_system.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''CREATE TABLE customers(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT,
      address TEXT, creditLimit REAL DEFAULT 500.0,
      createdAt TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE products(
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      category TEXT NOT NULL,
      buyPrice REAL NOT NULL, sellPrice REAL NOT NULL,
      stock INTEGER NOT NULL DEFAULT 0, unit TEXT,
      barcode TEXT, isActive INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE sales(
      id TEXT PRIMARY KEY, totalAmount REAL NOT NULL,
      cashPaid REAL NOT NULL DEFAULT 0,
      creditAmount REAL NOT NULL DEFAULT 0,
      customerId TEXT, customerName TEXT,
      type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'completed',
      notes TEXT, createdAt TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE sale_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      saleId TEXT NOT NULL,
      productId TEXT NOT NULL,
      productName TEXT NOT NULL,
      quantity INTEGER NOT NULL, price REAL NOT NULL,
      buyPrice REAL NOT NULL)''');

    await db.execute('''CREATE TABLE expenses(
      id TEXT PRIMARY KEY, description TEXT NOT NULL,
      category TEXT NOT NULL, amount REAL NOT NULL,
      date TEXT NOT NULL, notes TEXT)''');

    await db.execute('''CREATE TABLE debts(
      id TEXT PRIMARY KEY, customerId TEXT NOT NULL,
      customerName TEXT NOT NULL, saleId TEXT NOT NULL,
      originalAmount REAL NOT NULL,
      paidAmount REAL NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'unpaid',
      dueDate TEXT NOT NULL, createdAt TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE payments(
      id TEXT PRIMARY KEY, debtId TEXT NOT NULL,
      customerId TEXT NOT NULL,
      customerName TEXT NOT NULL,
      amount REAL NOT NULL, notes TEXT,
      createdAt TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE capital(
      id TEXT PRIMARY KEY,
      cashInvestment REAL NOT NULL DEFAULT 0,
      inventoryValue REAL NOT NULL DEFAULT 0,
      overhead REAL NOT NULL DEFAULT 0,
      overheadMonths INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL,
      updatedAt TEXT)''');

    await db.execute('''CREATE TABLE setup_cost_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      capitalId TEXT NOT NULL,
      label TEXT NOT NULL,
      amount REAL NOT NULL)''');
  }

  Future<void> _onUpgrade(Database db, int oldV,
      int newV) async {
    if (oldV < 2) {
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN barcode TEXT');
      } catch (_) {}
    }
    if (oldV < 3) {
      await db.execute(
          '''CREATE TABLE IF NOT EXISTS capital(
        id TEXT PRIMARY KEY,
        cashInvestment REAL NOT NULL DEFAULT 0,
        inventoryValue REAL NOT NULL DEFAULT 0,
        overhead REAL NOT NULL DEFAULT 0,
        overheadMonths INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT)''');
    }
    if (oldV < 4) {
      try {
        await db.execute(
            'ALTER TABLE capital ADD COLUMN overheadMonths INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
    }
    if (oldV < 5) {
      await db.execute('''CREATE TABLE IF NOT EXISTS setup_cost_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capitalId TEXT NOT NULL,
        label TEXT NOT NULL,
        amount REAL NOT NULL)''');
    }
  }

  // ── CUSTOMERS ──────────────────────────────────────────
  Future<void> insertCustomer(Customer c) async =>
      (await database).insert('customers', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Customer>> getCustomers() async {
    final maps = await (await database)
        .query('customers', orderBy: 'name ASC');
    return maps.map(Customer.fromMap).toList();
  }

  Future<void> updateCustomer(Customer c) async =>
      (await database).update('customers', c.toMap(),
          where: 'id=?', whereArgs: [c.id]);

  Future<void> deleteCustomer(String id) async =>
      (await database).delete('customers',
          where: 'id=?', whereArgs: [id]);

  // ── PRODUCTS ───────────────────────────────────────────
  Future<void> insertProduct(Product p) async =>
      (await database).insert('products', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Product>> getProducts(
      {bool activeOnly = true}) async {
    final db = await database;
    final maps = activeOnly
        ? await db.query('products',
            where: 'isActive=1', orderBy: 'name ASC')
        : await db.query('products',
            orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<void> updateProduct(Product p) async =>
      (await database).update('products', p.toMap(),
          where: 'id=?', whereArgs: [p.id]);

  Future<void> archiveProduct(String id) async =>
      (await database).update('products', {'isActive': 0},
          where: 'id=?', whereArgs: [id]);

  Future<Product?> getProductByBarcode(
      String barcode) async {
    final maps = await (await database).query('products',
        where: 'barcode=? AND isActive=1',
        whereArgs: [barcode]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  // ── SALES ──────────────────────────────────────────────
  Future<void> insertSale(Sale sale) async {
    final db = await database;
    await db.insert('sales', sale.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    for (final item in sale.items) {
      await db.insert('sale_items',
          {'saleId': sale.id, ...item.toMap()});
    }
  }

  Future<List<Sale>> getSales({int limit = 300}) async {
    final db = await database;
    final saleMaps = await db.query('sales',
        orderBy: 'createdAt DESC', limit: limit);
    final List<Sale> result = [];
    for (final m in saleMaps) {
      final itemMaps = await db.query('sale_items',
          where: 'saleId=?', whereArgs: [m['id']]);
      result.add(Sale.fromMap(
          m, itemMaps.map(TxItem.fromMap).toList()));
    }
    return result;
  }

  Future<void> voidSale(String id) async =>
      (await database).update('sales', {'status': 'voided'},
          where: 'id=?', whereArgs: [id]);

  // ── EXPENSES ───────────────────────────────────────────
  Future<void> insertExpense(Expense e) async =>
      (await database).insert('expenses', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Expense>> getExpenses() async {
    final maps = await (await database)
        .query('expenses', orderBy: 'date DESC');
    return maps.map(Expense.fromMap).toList();
  }

  Future<void> updateExpense(Expense e) async =>
      (await database).update('expenses', e.toMap(),
          where: 'id=?', whereArgs: [e.id]);

  Future<void> deleteExpense(String id) async =>
      (await database).delete('expenses',
          where: 'id=?', whereArgs: [id]);

  // ── DEBTS ──────────────────────────────────────────────
  Future<void> insertDebt(Debt d) async =>
      (await database).insert('debts', d.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Debt>> getDebts() async {
    final maps = await (await database)
        .query('debts', orderBy: 'createdAt DESC');
    return maps.map(Debt.fromMap).toList();
  }

  Future<void> updateDebt(Debt d) async =>
      (await database).update('debts', d.toMap(),
          where: 'id=?', whereArgs: [d.id]);

  // ── PAYMENTS ───────────────────────────────────────────
  Future<void> insertPayment(DebtPayment p) async =>
      (await database).insert('payments', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<DebtPayment>> getPayments() async {
    final maps = await (await database)
        .query('payments', orderBy: 'createdAt DESC');
    return maps.map(DebtPayment.fromMap).toList();
  }

  // ── REPORTS ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDailyRevenue(
      int days) async {
    final since =
        DateTime.now().subtract(Duration(days: days - 1));
    final sinceStr =
        DateTime(since.year, since.month, since.day)
            .toIso8601String();
    return (await database).rawQuery('''
      SELECT date(createdAt) as day,
        SUM(totalAmount) as revenue,
        COUNT(*) as txCount
      FROM sales WHERE createdAt >= ? AND status='completed'
      GROUP BY date(createdAt) ORDER BY day ASC
    ''', [sinceStr]);
  }

  Future<List<Map<String, dynamic>>> getTopProducts(
      int days) async {
    final since =
        DateTime.now().subtract(Duration(days: days));
    return (await database).rawQuery('''
      SELECT si.productName,
        SUM(si.quantity) as totalQty,
        SUM(si.price * si.quantity) as totalRevenue,
        SUM((si.price - si.buyPrice) * si.quantity) as totalProfit
      FROM sale_items si JOIN sales s ON si.saleId = s.id
      WHERE s.createdAt >= ? AND s.status='completed'
      GROUP BY si.productId, si.productName
      ORDER BY totalQty DESC LIMIT 10
    ''', [since.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getHourlySales(
      DateTime date) async {
    final start =
        DateTime(date.year, date.month, date.day)
            .toIso8601String();
    final end =
        DateTime(date.year, date.month, date.day, 23, 59, 59)
            .toIso8601String();
    final rows = await (await database).rawQuery('''
      SELECT strftime('%H', createdAt) as hour,
        SUM(totalAmount) as revenue,
        COUNT(*) as txCount
      FROM sales
      WHERE createdAt >= ? AND createdAt <= ?
        AND status='completed'
      GROUP BY strftime('%H', createdAt)
      ORDER BY hour ASC
    ''', [start, end]);
    return rows
        .map((r) => {
              'hour': int.tryParse(
                      r['hour'] as String? ?? '0') ??
                  0,
              'revenue': r['revenue'],
              'txCount': r['txCount'],
            })
        .toList();
  }

  Future<void> clearAllData() async {
    await clearSales();
    await clearDebts();
    await clearExpenses();
    await clearCustomers();
  }

  Future<void> clearSales() async {
    final db = await database;
    await db.delete('sales');
    await db.delete('sale_items');
  }

  Future<void> clearDebts() async {
    final db = await database;
    await db.delete('debts');
    await db.delete('payments');
  }

  Future<void> clearExpenses() async {
    final db = await database;
    await db.delete('expenses');
  }

  Future<void> clearCustomers() async {
    final db = await database;
    await db.delete('customers');
  }

  // ── CAPITAL ────────────────────────────────────────────
  Future<void> upsertCapital(CapitalEntry c) async {
    final db = await database;
    await db.insert('capital', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete('setup_cost_items',
        where: 'capitalId=?', whereArgs: [c.id]);
    for (final item in c.setupItems) {
      await db.insert('setup_cost_items', {
        'capitalId': c.id,
        'label': item.label,
        'amount': item.amount,
      });
    }
  }

  Future<CapitalEntry?> getCapital() async {
    final db = await database;
    final maps = await db.query('capital',
        orderBy: 'createdAt DESC', limit: 1);
    if (maps.isEmpty) return null;
    final capitalId = maps.first['id'] as String;
    final itemMaps = await db.query('setup_cost_items',
        where: 'capitalId=?', whereArgs: [capitalId]);
    final items = itemMaps.map(SetupCostItem.fromMap).toList();
    return CapitalEntry.fromMap(maps.first, items);
  }

  // ── BACKUP ─────────────────────────────────────────────
  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    return {
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': await db.query('customers'),
      'products': await db.query('products'),
      'sales': await db.query('sales'),
      'sale_items': await db.query('sale_items'),
      'expenses': await db.query('expenses'),
      'debts': await db.query('debts'),
      'payments': await db.query('payments'),
      'capital': await db.query('capital'),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in [
        'payments', 'debts', 'expenses', 'sale_items',
        'sales', 'customers', 'products'
      ]) {
        await txn.delete(t);
      }
      Future<void> ins(String table, List rows) async {
        for (final r in rows) {
          await txn.insert(
              table,
              Map<String, dynamic>.from(r as Map),
              conflictAlgorithm:
                  ConflictAlgorithm.replace);
        }
      }
      await ins('customers', data['customers'] as List);
      await ins('products', data['products'] as List);
      await ins('sales', data['sales'] as List);
      await ins('sale_items', data['sale_items'] as List);
      await ins('expenses', data['expenses'] as List);
      await ins('debts', data['debts'] as List);
      await ins('payments', data['payments'] as List);
      if (data['capital'] != null) {
        await ins('capital', data['capital'] as List);
      }
    });
  }
}