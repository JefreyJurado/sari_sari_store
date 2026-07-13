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
      version: 9,
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
      createdAt TEXT NOT NULL,
      reorderPoint INTEGER NOT NULL DEFAULT 5,
      expiryDate TEXT,
      supplierName TEXT,
      supplierContact TEXT,
      seasonalTag TEXT)''');

    await db.execute('''CREATE TABLE sales(
      id TEXT PRIMARY KEY, totalAmount REAL NOT NULL,
      cashPaid REAL NOT NULL DEFAULT 0,
      creditAmount REAL NOT NULL DEFAULT 0,
      customerId TEXT, customerName TEXT,
      type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'completed',
      notes TEXT, createdAt TEXT NOT NULL,
      receiptNumber INTEGER)''');

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
      amount REAL NOT NULL,
      category TEXT DEFAULT 'Equipment',
      vendor TEXT,
      paymentMethod TEXT DEFAULT 'Cash',
      date TEXT)''');

    await db.execute('''CREATE TABLE inventory_snapshots(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      productId TEXT NOT NULL,
      productName TEXT NOT NULL,
      month TEXT NOT NULL,
      beginningStock INTEGER NOT NULL DEFAULT 0,
      stockReceived INTEGER NOT NULL DEFAULT 0,
      stockSold INTEGER NOT NULL DEFAULT 0,
      unitCost REAL NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL)''');
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
    if (oldV < 6) {
      final categoryMap = {
        'Inumin': 'Drinks / Beverages',
        'Pagkain (Canned)': 'Food (Canned)',
        'Merienda / Snacks': 'Snacks',
        'Bigas at Pasta': 'Rice and Pasta',
        'Kondimento': 'Condiments',
        'Panaderya': 'Bakery / Bread',
        'Sigarilyo': 'Cigarettes',
      };
      for (final entry in categoryMap.entries) {
        await db.execute(
          "UPDATE products SET category = ? WHERE category = ?",
          [entry.value, entry.key],
        );
      }
    }
    if (oldV < 7) {
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN reorderPoint INTEGER NOT NULL DEFAULT 5');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN expiryDate TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN supplierName TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN supplierContact TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN seasonalTag TEXT');
      } catch (_) {}
    }
    if (oldV < 8) {
      try {
        await db.execute(
            'ALTER TABLE setup_cost_items ADD COLUMN category TEXT DEFAULT "Equipment"');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE setup_cost_items ADD COLUMN vendor TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE setup_cost_items ADD COLUMN paymentMethod TEXT DEFAULT "Cash"');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE setup_cost_items ADD COLUMN date TEXT');
      } catch (_) {}
      // Monthly inventory snapshot table
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS inventory_snapshots(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productId TEXT NOT NULL,
          productName TEXT NOT NULL,
          month TEXT NOT NULL,
          beginningStock INTEGER NOT NULL DEFAULT 0,
          stockReceived INTEGER NOT NULL DEFAULT 0,
          stockSold INTEGER NOT NULL DEFAULT 0,
          unitCost REAL NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL)''');
      } catch (_) {}
    }
    if (oldV < 9) {
      try {
        await db.execute(
            'ALTER TABLE sales ADD COLUMN receiptNumber INTEGER');
      } catch (_) {}
      // Backfill existing sales with sequential numbers in
      // chronological order so old receipts get a stable number too.
      await db.execute('''UPDATE sales SET receiptNumber = (
        SELECT COUNT(*) FROM sales s2
        WHERE s2.createdAt < sales.createdAt
           OR (s2.createdAt = sales.createdAt AND s2.id <= sales.id)
      )''');
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

  /// Deletes a customer along with their debts and payment history, so
  /// deleting a customer never leaves orphaned debt/payment rows that
  /// still count toward store-wide unpaid-debt totals.
  Future<void> deleteCustomer(String id) async {
    final db = await database;
    final debtRows = await db.query('debts',
        where: 'customerId=?', whereArgs: [id]);
    for (final row in debtRows) {
      await db.delete('payments',
          where: 'debtId=?', whereArgs: [row['id']]);
    }
    await db.delete('debts',
        where: 'customerId=?', whereArgs: [id]);
    await db.delete('customers',
        where: 'id=?', whereArgs: [id]);
  }

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

  Future<void> restoreProduct(String id) async =>
      (await database).update('products', {'isActive': 1},
          where: 'id=?', whereArgs: [id]);

  Future<List<Product>> getArchivedProducts() async {
    final maps = await (await database).query('products',
        where: 'isActive=0', orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<Map<String, dynamic>> getProductIncome(String productId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(si.quantity), 0) as totalQty,
        COALESCE(SUM(si.price * si.quantity), 0) as totalRevenue,
        COALESCE(SUM(si.buyPrice * si.quantity), 0) as totalCost,
        COALESCE(SUM((si.price - si.buyPrice) * si.quantity), 0) as totalProfit
      FROM sale_items si
      JOIN sales s ON si.saleId = s.id
      WHERE si.productId = ? AND s.status = 'completed'
    ''', [productId]);
    return result.first;
  }

  Future<Product?> getProductByBarcode(
      String barcode) async {
    final maps = await (await database).query('products',
        where: 'barcode=? AND isActive=1',
        whereArgs: [barcode]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  // ── SALES ──────────────────────────────────────────────
  Future<int> getNextReceiptNumber() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(MAX(receiptNumber), 0) + 1 AS next FROM sales');
    return result.first['next'] as int;
  }

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

  /// Deletes any debt(s) tied to a sale (and their payment history),
  /// used when the originating sale is voided.
  Future<void> deleteDebtsBySale(String saleId) async {
    final db = await database;
    final debtRows = await db.query('debts',
        where: 'saleId=?', whereArgs: [saleId]);
    for (final row in debtRows) {
      await db.delete('payments',
          where: 'debtId=?', whereArgs: [row['id']]);
    }
    await db.delete('debts',
        where: 'saleId=?', whereArgs: [saleId]);
  }

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
    // Profit is computed via a correlated subquery (rather than a JOIN on
    // sale_items) so it doesn't multiply/duplicate the revenue SUM when a
    // sale has more than one line item.
    return (await database).rawQuery('''
      SELECT date(createdAt) as day,
        SUM(totalAmount) as revenue,
        COUNT(*) as txCount,
        (SELECT COALESCE(SUM((si.price - si.buyPrice) * si.quantity), 0)
         FROM sale_items si
         JOIN sales s2 ON si.saleId = s2.id
         WHERE date(s2.createdAt) = date(sales.createdAt)
           AND s2.status = 'completed') as profit
      FROM sales WHERE createdAt >= ? AND status='completed'
      GROUP BY date(createdAt) ORDER BY day ASC
    ''', [sinceStr]);
  }

  Future<List<Map<String, dynamic>>> getTopProducts(
      int days) async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
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
        'category': item.category,
        'vendor': item.vendor,
        'paymentMethod': item.paymentMethod,
        'date': item.date.toIso8601String(),
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

  // ── INVENTORY SNAPSHOTS ────────────────────────────────
  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String _nextMonthKey(String month) {
    final parts = month.split('-');
    var year = int.parse(parts[0]);
    var mon = int.parse(parts[1]) + 1;
    if (mon > 12) {
      mon = 1;
      year++;
    }
    return '$year-${mon.toString().padLeft(2, '0')}';
  }

  /// Records each active product's current stock as the "beginning of
  /// month" checkpoint, once per calendar month. This is what lets
  /// [getInventorySnapshot] show accurate figures for past months —
  /// before this existed, the screen could only ever show today's
  /// live stock regardless of which month was selected. Safe to call
  /// on every app start; a no-op after the first call each month.
  Future<void> recordMonthlySnapshotIfNeeded() async {
    final db = await database;
    final month = _currentMonthKey();
    final existing = await db.query('inventory_snapshots',
        where: 'month=?', whereArgs: [month], limit: 1);
    if (existing.isNotEmpty) return;

    final products = await db.query('products', where: 'isActive=1');
    final createdAt = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final p in products) {
        await txn.insert('inventory_snapshots', {
          'productId': p['id'],
          'productName': p['name'],
          'month': month,
          'beginningStock': p['stock'],
          'stockReceived': 0,
          'stockSold': 0,
          'unitCost': p['buyPrice'],
          'createdAt': createdAt,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getInventorySnapshot(String month) async {
    final db = await database;
    final currentMonth = _currentMonthKey();
    final isCurrentMonth = month == currentMonth;
    final nextMonth = _nextMonthKey(month);

    final products = await db.query('products', where: 'isActive=1');
    final List<Map<String, dynamic>> result = [];

    for (final p in products) {
      final productId = p['id'] as String;
      final productName = p['name'] as String;
      final unitCost = (p['buyPrice'] as num).toDouble();
      final currentStock = (p['stock'] as num).toInt();

      // Stock sold in the selected month — always accurate, since
      // sales are timestamped and never rewritten.
      final soldResult = await db.rawQuery('''
        SELECT COALESCE(SUM(si.quantity), 0) as sold
        FROM sale_items si
        JOIN sales s ON si.saleId = s.id
        WHERE si.productId = ?
        AND strftime('%Y-%m', s.createdAt) = ?
        AND s.status = 'completed'
      ''', [productId, month]);
      final stockSold = (soldResult.first['sold'] as num).toInt();

      // Beginning stock: the checkpoint recorded at the start of the
      // selected month, if we have one.
      final beginRows = await db.query('inventory_snapshots',
          where: 'productId=? AND month=?', whereArgs: [productId, month]);
      final beginningStock = beginRows.isNotEmpty
          ? (beginRows.first['beginningStock'] as num).toInt()
          : null;

      // Ending stock: for the current month it's just today's live
      // stock; for a past month it's the checkpoint recorded at the
      // start of the *following* month.
      int? endingStock;
      if (isCurrentMonth) {
        endingStock = currentStock;
      } else {
        final endRows = await db.query('inventory_snapshots',
            where: 'productId=? AND month=?', whereArgs: [productId, nextMonth]);
        endingStock = endRows.isNotEmpty
            ? (endRows.first['beginningStock'] as num).toInt()
            : null;
      }

      // No recorded checkpoint for this month — nothing accurate to show.
      if (beginningStock == null || endingStock == null) continue;

      result.add({
        'productId': productId,
        'productName': productName,
        'month': month,
        'beginningStock': beginningStock,
        'stockSold': stockSold,
        'endingStock': endingStock,
        'unitCost': unitCost,
        'totalInventoryValue': endingStock * unitCost,
      });
    }
    return result;
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