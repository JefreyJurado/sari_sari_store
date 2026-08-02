import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/expense.dart';
import '../models/debt.dart';
import '../models/payment.dart';
import '../models/capital_entry.dart';
import '../models/cico_transaction.dart';
import '../models/cico_rate.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;
  Future<Database> get database async => _db ??= await _init();

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'pos_system.db');
    return openDatabase(
      path,
      version: 14,
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

    await db.execute('''CREATE TABLE cico_transactions(
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      provider TEXT NOT NULL,
      amount REAL NOT NULL,
      commission REAL NOT NULL DEFAULT 0,
      notes TEXT,
      createdAt TEXT NOT NULL,
      liquidAccount TEXT NOT NULL DEFAULT 'Cash',
      accountKind TEXT NOT NULL DEFAULT 'wallet',
      customerName TEXT,
      customerPhone TEXT,
      transferAccount TEXT)''');

    await db.execute('''CREATE TABLE cico_rates(
      id TEXT PRIMARY KEY,
      provider TEXT NOT NULL,
      txnType TEXT NOT NULL,
      mode TEXT NOT NULL,
      value REAL NOT NULL,
      minAmount REAL NOT NULL DEFAULT 0,
      maxAmount REAL,
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL)''');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      } catch (_) {}
    }
    if (oldV < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS capital(
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
        await db.execute('ALTER TABLE products ADD COLUMN expiryDate TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE products ADD COLUMN supplierName TEXT');
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE products ADD COLUMN supplierContact TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE products ADD COLUMN seasonalTag TEXT');
      } catch (_) {}
    }
    if (oldV < 8) {
      try {
        await db.execute(
            'ALTER TABLE setup_cost_items ADD COLUMN category TEXT DEFAULT "Equipment"');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE setup_cost_items ADD COLUMN vendor TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE setup_cost_items ADD COLUMN paymentMethod TEXT DEFAULT "Cash"');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE setup_cost_items ADD COLUMN date TEXT');
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
        await db.execute('ALTER TABLE sales ADD COLUMN receiptNumber INTEGER');
      } catch (_) {}
      // Backfill existing sales with sequential numbers in
      // chronological order so old receipts get a stable number too.
      await db.execute('''UPDATE sales SET receiptNumber = (
        SELECT COUNT(*) FROM sales s2
        WHERE s2.createdAt < sales.createdAt
           OR (s2.createdAt = sales.createdAt AND s2.id <= sales.id)
      )''');
    }
    if (oldV < 10) {
      await db.execute('''CREATE TABLE IF NOT EXISTS cico_transactions(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        provider TEXT NOT NULL,
        amount REAL NOT NULL,
        commission REAL NOT NULL DEFAULT 0,
        notes TEXT,
        createdAt TEXT NOT NULL)''');
    }
    if (oldV < 11) {
      try {
        await db.execute(
            "ALTER TABLE cico_transactions ADD COLUMN liquidAccount TEXT NOT NULL DEFAULT 'Cash'");
      } catch (_) {}
    }
    if (oldV < 12) {
      try {
        await db.execute(
            "ALTER TABLE cico_transactions ADD COLUMN accountKind TEXT NOT NULL DEFAULT 'wallet'");
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE cico_transactions ADD COLUMN customerName TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE cico_transactions ADD COLUMN customerPhone TEXT');
      } catch (_) {}
      // Backfill topUp/withdraw rows written before "Bank" became a named
      // account: the old fixed sentinels 'Cash'/'Bank' need their kind
      // recorded explicitly now that `provider` can name any bank.
      await db.execute('''UPDATE cico_transactions SET accountKind = 'cash'
        WHERE type IN ('topUp', 'withdraw') AND provider = 'Cash' ''');
      await db.execute('''UPDATE cico_transactions SET accountKind = 'bank'
        WHERE type IN ('topUp', 'withdraw') AND provider = 'Bank' ''');
    }
    if (oldV < 13) {
      try {
        await db.execute(
            'ALTER TABLE cico_transactions ADD COLUMN transferAccount TEXT');
      } catch (_) {}
      // Left NULL for every existing row on purpose: old topUp/withdraw
      // entries were only ever single-entry adjustments, so backfilling a
      // guessed "other side" here would silently change balances that were
      // already relied on.
    }
    if (oldV < 14) {
      await db.execute('''CREATE TABLE IF NOT EXISTS cico_rates(
        id TEXT PRIMARY KEY,
        provider TEXT NOT NULL,
        txnType TEXT NOT NULL,
        mode TEXT NOT NULL,
        value REAL NOT NULL,
        minAmount REAL NOT NULL DEFAULT 0,
        maxAmount REAL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL)''');
    }
  }

  // ── CUSTOMERS ──────────────────────────────────────────
  Future<void> insertCustomer(Customer c) async =>
      (await database).insert('customers', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Customer>> getCustomers() async {
    final maps = await (await database).query('customers', orderBy: 'name ASC');
    return maps.map(Customer.fromMap).toList();
  }

  Future<void> updateCustomer(Customer c) async => (await database)
      .update('customers', c.toMap(), where: 'id=?', whereArgs: [c.id]);

  /// Deletes a customer along with their debts and payment history, so
  /// deleting a customer never leaves orphaned debt/payment rows that
  /// still count toward store-wide unpaid-debt totals.
  Future<void> deleteCustomer(String id) async {
    final db = await database;
    final debtRows =
        await db.query('debts', where: 'customerId=?', whereArgs: [id]);
    for (final row in debtRows) {
      await db.delete('payments', where: 'debtId=?', whereArgs: [row['id']]);
    }
    await db.delete('debts', where: 'customerId=?', whereArgs: [id]);
    await db.delete('customers', where: 'id=?', whereArgs: [id]);
  }

  // ── PRODUCTS ───────────────────────────────────────────
  Future<void> insertProduct(Product p) async =>
      (await database).insert('products', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  /// Bulk insert for catalog imports — a single batch/transaction instead
  /// of one [insertProduct] await per row, so importing a few hundred
  /// products doesn't serialize a few hundred separate DB round-trips.
  Future<void> importProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert('products', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> getProducts({bool activeOnly = true}) async {
    final db = await database;
    final maps = activeOnly
        ? await db.query('products', where: 'isActive=1', orderBy: 'name ASC')
        : await db.query('products', orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<void> updateProduct(Product p) async => (await database)
      .update('products', p.toMap(), where: 'id=?', whereArgs: [p.id]);

  /// Atomically applies a stock delta in SQL (`stock = stock + ?`,
  /// clamped to [0, 99999] — the same bounds the manual "adjust stock"
  /// dialogs already enforce) instead of a Dart-side read-modify-write,
  /// so two concurrent calls (e.g. two near-simultaneous sales, or a
  /// sale racing a manual restock) can never lose one's update by both
  /// computing a new value from the same stale snapshot. Also safe to
  /// call for an archived product — unlike [updateProduct], it never
  /// touches any other column, so it can't accidentally
  /// resurrect/overwrite an archived row's other fields.
  Future<void> adjustProductStock(String productId, int delta) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE products SET stock = MAX(0, MIN(99999, stock + ?)) WHERE id = ?',
        [delta, productId]);
  }

  Future<void> archiveProduct(String id) async => (await database)
      .update('products', {'isActive': 0}, where: 'id=?', whereArgs: [id]);

  Future<void> restoreProduct(String id) async => (await database)
      .update('products', {'isActive': 1}, where: 'id=?', whereArgs: [id]);

  Future<List<Product>> getArchivedProducts() async {
    final maps = await (await database)
        .query('products', where: 'isActive=0', orderBy: 'name ASC');
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

  Future<Product?> getProductByBarcode(String barcode,
      {bool includeInactive = false}) async {
    final maps = await (await database).query('products',
        where: includeInactive ? 'barcode=?' : 'barcode=? AND isActive=1',
        whereArgs: [barcode]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  // ── SALES ──────────────────────────────────────────────
  /// Inserts the sale and returns its receipt number. The number is
  /// assigned inside the same transaction as the insert (MAX+1), so two
  /// near-simultaneous sales can never be handed the same number — which
  /// could happen when the fetch was a separate query before the insert.
  Future<int> insertSale(Sale sale) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      var receiptNumber = sale.receiptNumber;
      if (receiptNumber == null) {
        final result = await txn.rawQuery(
            'SELECT COALESCE(MAX(receiptNumber), 0) + 1 AS next FROM sales');
        receiptNumber = result.first['next'] as int;
      }
      await txn.insert(
          'sales', {...sale.toMap(), 'receiptNumber': receiptNumber},
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in sale.items) {
        await txn.insert('sale_items', {'saleId': sale.id, ...item.toMap()});
      }
      return receiptNumber;
    });
  }

  Future<List<Sale>> getSales({int limit = 300}) async {
    final db = await database;
    final saleMaps =
        await db.query('sales', orderBy: 'createdAt DESC', limit: limit);
    final List<Sale> result = [];
    for (final m in saleMaps) {
      final itemMaps =
          await db.query('sale_items', where: 'saleId=?', whereArgs: [m['id']]);
      result.add(Sale.fromMap(m, itemMaps.map(TxItem.fromMap).toList()));
    }
    return result;
  }

  /// Fetches a single sale (with its items) straight from the DB, so
  /// callers restoring stock for an old sale (e.g. deleting a months-old
  /// installment plan) aren't at the mercy of the recency-limited
  /// in-memory list in AppProvider.
  Future<Sale?> getSaleById(String id) async {
    final db = await database;
    final maps =
        await db.query('sales', where: 'id=?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    final itemMaps =
        await db.query('sale_items', where: 'saleId=?', whereArgs: [id]);
    return Sale.fromMap(maps.first, itemMaps.map(TxItem.fromMap).toList());
  }

  /// Completed sales for one calendar day, computed in SQL so any past
  /// day is accurate regardless of how many sales exist in total.
  Future<List<Sale>> getSalesForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final saleMaps = await db.query('sales',
        where: "createdAt >= ? AND createdAt < ? AND status = 'completed'",
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'createdAt DESC');
    final List<Sale> result = [];
    for (final m in saleMaps) {
      final itemMaps =
          await db.query('sale_items', where: 'saleId=?', whereArgs: [m['id']]);
      result.add(Sale.fromMap(m, itemMaps.map(TxItem.fromMap).toList()));
    }
    return result;
  }

  /// All-time revenue and cost of goods sold across every completed
  /// sale, computed in SQL. The in-memory sales list is capped for UI
  /// performance, so lifetime figures (gross profit, ROI, capital) must
  /// come from here — folding the capped list silently shrinks them
  /// once the store outgrows the cap.
  Future<Map<String, double>> getAllTimeTotals() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(totalAmount), 0) FROM sales
          WHERE status = 'completed') as revenue,
        (SELECT COALESCE(SUM(si.buyPrice * si.quantity), 0)
          FROM sale_items si JOIN sales s ON si.saleId = s.id
          WHERE s.status = 'completed') as cogs
    ''');
    return {
      'revenue': (result.first['revenue'] as num).toDouble(),
      'cogs': (result.first['cogs'] as num).toDouble(),
    };
  }

  Future<void> voidSale(String id) async => (await database)
      .update('sales', {'status': 'voided'}, where: 'id=?', whereArgs: [id]);

  // ── EXPENSES ───────────────────────────────────────────
  Future<void> insertExpense(Expense e) async =>
      (await database).insert('expenses', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Expense>> getExpenses() async {
    final maps = await (await database).query('expenses', orderBy: 'date DESC');
    return maps.map(Expense.fromMap).toList();
  }

  Future<void> updateExpense(Expense e) async => (await database)
      .update('expenses', e.toMap(), where: 'id=?', whereArgs: [e.id]);

  Future<void> deleteExpense(String id) async =>
      (await database).delete('expenses', where: 'id=?', whereArgs: [id]);

  // ── CICO (E-WALLET) ────────────────────────────────────
  Future<void> insertCicoTransaction(CicoTransaction t) async =>
      (await database).insert('cico_transactions', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<CicoTransaction>> getCicoTransactions() async {
    final maps = await (await database)
        .query('cico_transactions', orderBy: 'createdAt DESC');
    return maps.map(CicoTransaction.fromMap).toList();
  }

  Future<void> updateCicoTransaction(CicoTransaction t) async =>
      (await database).update('cico_transactions', t.toMap(),
          where: 'id=?', whereArgs: [t.id]);

  Future<void> deleteCicoTransaction(String id) async => (await database)
      .delete('cico_transactions', where: 'id=?', whereArgs: [id]);

  // ── CICO RATES ─────────────────────────────────────────
  Future<void> insertRateRule(CicoRateRule r) async =>
      (await database).insert('cico_rates', r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  // Batched insert for bulk seeding (e.g. "Load Standard Rates") — one
  // transaction instead of N separate round-trips.
  Future<void> insertRateRules(List<CicoRateRule> rules) async {
    if (rules.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final r in rules) {
      batch.insert('cico_rates', r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<CicoRateRule>> getRateRules() async {
    final maps =
        await (await database).query('cico_rates', orderBy: 'minAmount ASC');
    return maps.map(CicoRateRule.fromMap).toList();
  }

  Future<void> updateRateRule(CicoRateRule r) async => (await database)
      .update('cico_rates', r.toMap(), where: 'id=?', whereArgs: [r.id]);

  Future<void> deleteRateRule(String id) async =>
      (await database).delete('cico_rates', where: 'id=?', whereArgs: [id]);

  Future<void> deleteAllRateRules() async =>
      (await database).delete('cico_rates');

  // ── DEBTS ──────────────────────────────────────────────
  Future<void> insertDebt(Debt d) async => (await database)
      .insert('debts', d.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Debt>> getDebts() async {
    final maps =
        await (await database).query('debts', orderBy: 'createdAt DESC');
    return maps.map(Debt.fromMap).toList();
  }

  Future<void> updateDebt(Debt d) async => (await database)
      .update('debts', d.toMap(), where: 'id=?', whereArgs: [d.id]);

  /// Atomically applies a payment amount to a debt's paidAmount and
  /// derives its status from the result, all in one SQL statement —
  /// instead of a Dart-side `debt.paidAmount + amount` computed from a
  /// possibly-stale in-memory `Debt` (e.g. a payment screen opened
  /// before an earlier payment on the same debt landed). Rounds to
  /// the nearest centavo and caps at `originalAmount` so an in-flight
  /// stale overpayment attempt can't push the balance negative.
  Future<void> adjustDebtPaidAmount(String debtId, double amount) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE debts
      SET paidAmount = MIN(ROUND(paidAmount + ?, 2), originalAmount),
          status = CASE
            WHEN MIN(ROUND(paidAmount + ?, 2), originalAmount) >= originalAmount
            THEN 'paid' ELSE 'partial' END
      WHERE id = ?
    ''', [amount, amount, debtId]);
  }

  /// Total already paid on any debt tied to this sale. Used to block
  /// voiding a credit sale that has payments recorded — deleting those
  /// debts would silently erase cash the store already collected.
  Future<double> getDebtPaidAmountBySale(String saleId) async {
    final result = await (await database).rawQuery(
        'SELECT COALESCE(SUM(paidAmount), 0) as paid FROM debts WHERE saleId = ?',
        [saleId]);
    return (result.first['paid'] as num).toDouble();
  }

  /// Deletes any debt(s) tied to a sale (and their payment history),
  /// used when the originating sale is voided.
  Future<void> deleteDebtsBySale(String saleId) async {
    final db = await database;
    final debtRows =
        await db.query('debts', where: 'saleId=?', whereArgs: [saleId]);
    for (final row in debtRows) {
      await db.delete('payments', where: 'debtId=?', whereArgs: [row['id']]);
    }
    await db.delete('debts', where: 'saleId=?', whereArgs: [saleId]);
  }

  // ── PAYMENTS ───────────────────────────────────────────
  Future<void> insertPayment(DebtPayment p) async =>
      (await database).insert('payments', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<DebtPayment>> getPayments() async {
    final maps =
        await (await database).query('payments', orderBy: 'createdAt DESC');
    return maps.map(DebtPayment.fromMap).toList();
  }

  // ── REPORTS ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDailyRevenue(int days) async {
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final sinceStr =
        DateTime(since.year, since.month, since.day).toIso8601String();
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

  /// Cash/online/credit split across an entire period, aggregated in SQL
  /// rather than by fetching every individual sale row — cheap even for
  /// a 365-day window. Mirrors the exact per-sale logic the single-day
  /// Daily Summary screen already computes in Dart (cash bucket also
  /// nets out installment sales' credit portion; credit bucket also
  /// covers mixed/installment types) so a period total and a same-day
  /// single-day total never disagree over how a sale type is bucketed.
  Future<Map<String, double>> getPaymentTypeBreakdown(int days) async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final result = await (await database).rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type IN ('cash','installment','mixed')
          THEN totalAmount - creditAmount ELSE 0 END), 0) as cash,
        COALESCE(SUM(CASE WHEN type = 'online'
          THEN totalAmount ELSE 0 END), 0) as online,
        COALESCE(SUM(CASE WHEN type IN ('credit','mixed','installment')
          THEN creditAmount ELSE 0 END), 0) as credit
      FROM sales
      WHERE createdAt >= ? AND status = 'completed'
    ''', [since.toIso8601String()]);
    final row = result.first;
    return {
      'cash': (row['cash'] as num).toDouble(),
      'online': (row['online'] as num).toDouble(),
      'credit': (row['credit'] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> getTopProducts(int days) async {
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

  Future<List<Map<String, dynamic>>> getHourlySales(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end =
        DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
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
              'hour': int.tryParse(r['hour'] as String? ?? '0') ?? 0,
              'revenue': r['revenue'],
              'txCount': r['txCount'],
            })
        .toList();
  }

  /// Consecutive days with at least one completed sale, counting
  /// backward from today. Computed from distinct sale dates in SQL
  /// (not by folding the capped in-memory sales list) so a busy store
  /// with more than the UI's recency cap of sales can't silently
  /// truncate its own streak.
  ///
  /// Today doesn't need a sale yet for the streak to still be "alive" —
  /// it only breaks once a full day passes with zero sales. So if
  /// today has no sale yet, the count starts from yesterday instead;
  /// if yesterday has none either, the streak is over (0).
  Future<int> getCurrentStreak() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT date(createdAt) as day
      FROM sales
      WHERE status = 'completed'
      ORDER BY day DESC
      LIMIT 1000
    ''');
    if (rows.isEmpty) return 0;

    final days = rows.map((r) => r['day'] as String).toSet();
    String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!days.contains(dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(dateKey(cursor))) return 0;
    }

    var streak = 0;
    while (days.contains(dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
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
    await db
        .delete('setup_cost_items', where: 'capitalId=?', whereArgs: [c.id]);
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
    final maps = await db.query('capital', orderBy: 'createdAt DESC', limit: 1);
    if (maps.isEmpty) return null;
    final capitalId = maps.first['id'] as String;
    final itemMaps = await db.query('setup_cost_items',
        where: 'capitalId=?', whereArgs: [capitalId]);
    final items = itemMaps.map(SetupCostItem.fromMap).toList();
    return CapitalEntry.fromMap(maps.first, items);
  }

  // ── INVENTORY SNAPSHOTS ────────────────────────────────
  static String currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String nextMonthKey(String month) {
    final parts = month.split('-');
    var year = int.parse(parts[0]);
    var mon = int.parse(parts[1]) + 1;
    if (mon > 12) {
      mon = 1;
      year++;
    }
    return '$year-${mon.toString().padLeft(2, '0')}';
  }

  static String prevMonthKey(String month) {
    final parts = month.split('-');
    var year = int.parse(parts[0]);
    var mon = int.parse(parts[1]) - 1;
    if (mon < 1) {
      mon = 12;
      year--;
    }
    return '$year-${mon.toString().padLeft(2, '0')}';
  }

  Future<void>? _monthlySnapshotInFlight;

  /// Records each active product's current stock as the "beginning of
  /// month" checkpoint, once per calendar month. This is what lets
  /// [getInventorySnapshot] show accurate figures for past months —
  /// before this existed, the screen could only ever show today's
  /// live stock regardless of which month was selected. Safe to call
  /// on every app start; a no-op after the first call each month.
  /// Guarded in-memory too — see [BackupService.autoBackupIfNeeded] for
  /// why AppProvider.initialize() can fire this twice in quick succession.
  Future<void> recordMonthlySnapshotIfNeeded() {
    return _monthlySnapshotInFlight ??=
        _doRecordMonthlySnapshot().whenComplete(() {
      _monthlySnapshotInFlight = null;
    });
  }

  Future<void> _doRecordMonthlySnapshot() async {
    final db = await database;
    final month = currentMonthKey();
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

  Future<void>? _backfillInFlight;

  /// Rescue for every month the store was already selling in before
  /// this snapshot tracking existed. Walks backward one month at a
  /// time from whichever month first runs this code — not necessarily
  /// "last month", since a Play Store update can reach a device weeks
  /// after release, well after the real previous month has passed.
  /// Each missing month's checkpoint doubles as "ending stock" for the
  /// month before it, and that month's sales are already fully
  /// recorded — so its beginning stock can be estimated as (next
  /// month's beginning stock + that month's sales). Marked with
  /// stockReceived=-1 so the UI can flag it as an estimate: it can't
  /// account for restocks that may have happened that month, since
  /// those were never logged. Stops at the first month that already
  /// has a row, or shows no sales activity (i.e. before the store
  /// started using the app at all).
  Future<void> backfillPreviousMonthSnapshotIfPossible() {
    return _backfillInFlight ??= _doBackfillPreviousMonths().whenComplete(() {
      _backfillInFlight = null;
    });
  }

  Future<void> _doBackfillPreviousMonths() async {
    final db = await database;
    var anchorMonth = currentMonthKey();
    final createdAt = DateTime.now().toIso8601String();

    // Bounded so a data issue can't turn this into a runaway loop.
    for (var i = 0; i < 60; i++) {
      final targetMonth = prevMonthKey(anchorMonth);

      final targetExisting = await db.query('inventory_snapshots',
          where: 'month=?', whereArgs: [targetMonth], limit: 1);
      if (targetExisting.isNotEmpty) break;

      final rawAnchorRows = await db.query('inventory_snapshots',
          where: 'month=?', whereArgs: [anchorMonth]);
      if (rawAnchorRows.isEmpty) break;

      final hasSales = await db.rawQuery('''
        SELECT 1 FROM sales
        WHERE strftime('%Y-%m', createdAt) = ? AND status = 'completed'
        LIMIT 1
      ''', [targetMonth]);
      if (hasSales.isEmpty) break;

      // Defensive: one row per product, even if duplicates exist.
      final seenProducts = <String>{};
      final anchorRows = rawAnchorRows
          .where((r) => seenProducts.add(r['productId'] as String))
          .toList();

      await db.transaction((txn) async {
        for (final anchor in anchorRows) {
          final productId = anchor['productId'] as String;
          final anchorEnding = (anchor['beginningStock'] as num).toInt();

          final soldResult = await txn.rawQuery('''
            SELECT COALESCE(SUM(si.quantity), 0) as sold
            FROM sale_items si
            JOIN sales s ON si.saleId = s.id
            WHERE si.productId = ?
            AND strftime('%Y-%m', s.createdAt) = ?
            AND s.status = 'completed'
          ''', [productId, targetMonth]);
          final targetSold = (soldResult.first['sold'] as num).toInt();

          await txn.insert('inventory_snapshots', {
            'productId': productId,
            'productName': anchor['productName'],
            'month': targetMonth,
            'beginningStock': anchorEnding + targetSold,
            'stockReceived': -1,
            'stockSold': targetSold,
            'unitCost': anchor['unitCost'],
            'createdAt': createdAt,
          });
        }
      });

      anchorMonth = targetMonth;
    }
  }

  Future<List<Map<String, dynamic>>> getInventorySnapshot(String month) async {
    final db = await database;
    final currentMonth = currentMonthKey();
    final isCurrentMonth = month == currentMonth;
    final nextMonth = nextMonthKey(month);

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
      // selected month, if we have one. stockReceived=-1 marks a
      // backfilled estimate (see backfillPreviousMonthSnapshotIfPossible)
      // rather than a real recorded checkpoint.
      final beginRows = await db.query('inventory_snapshots',
          where: 'productId=? AND month=?', whereArgs: [productId, month]);
      final beginningStock = beginRows.isNotEmpty
          ? (beginRows.first['beginningStock'] as num).toInt()
          : null;
      final isEstimated = beginRows.isNotEmpty &&
          (beginRows.first['stockReceived'] as num).toInt() == -1;

      // Ending stock: for the current month it's just today's live
      // stock; for a past month it's the checkpoint recorded at the
      // start of the *following* month.
      int? endingStock;
      if (isCurrentMonth) {
        endingStock = currentStock;
      } else {
        final endRows = await db.query('inventory_snapshots',
            where: 'productId=? AND month=?',
            whereArgs: [productId, nextMonth]);
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
        'isEstimated': isEstimated,
      });
    }
    return result;
  }

  // ── BACKUP ─────────────────────────────────────────────
  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    return {
      'version': 5,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': await db.query('customers'),
      'products': await db.query('products'),
      'sales': await db.query('sales'),
      'sale_items': await db.query('sale_items'),
      'expenses': await db.query('expenses'),
      'debts': await db.query('debts'),
      'payments': await db.query('payments'),
      'capital': await db.query('capital'),
      'setup_cost_items': await db.query('setup_cost_items'),
      'inventory_snapshots': await db.query('inventory_snapshots'),
      'cico_transactions': await db.query('cico_transactions'),
      'cico_rates': await db.query('cico_rates'),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in [
        'payments',
        'debts',
        'expenses',
        'sale_items',
        'sales',
        'customers',
        'products'
      ]) {
        await txn.delete(t);
      }
      Future<void> ins(String table, List rows) async {
        for (final r in rows) {
          await txn.insert(table, Map<String, dynamic>.from(r as Map),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await ins('customers', data['customers'] as List);
      await ins('products', data['products'] as List);
      await ins('sales', data['sales'] as List);
      await ins('sale_items', data['sale_items'] as List);
      await ins('expenses', data['expenses'] as List);
      await ins('debts', data['debts'] as List);
      await ins('payments', data['payments'] as List);
      // Older backups lack these sections — only replace a table when
      // the backup actually carries it, so restoring an old file never
      // wipes data it didn't know about. Capital is cleared before
      // insert because rows keep their own ids: a leftover local row
      // with a newer createdAt would otherwise shadow the restored one
      // (getCapital picks the latest).
      if (data['capital'] != null) {
        await txn.delete('capital');
        await ins('capital', data['capital'] as List);
      }
      if (data['setup_cost_items'] != null) {
        await txn.delete('setup_cost_items');
        await ins('setup_cost_items', data['setup_cost_items'] as List);
      }
      if (data['inventory_snapshots'] != null) {
        await txn.delete('inventory_snapshots');
        await ins('inventory_snapshots', data['inventory_snapshots'] as List);
      }
      if (data['cico_transactions'] != null) {
        await txn.delete('cico_transactions');
        await ins('cico_transactions', data['cico_transactions'] as List);
      }
      if (data['cico_rates'] != null) {
        await txn.delete('cico_rates');
        await ins('cico_rates', data['cico_rates'] as List);
      }
    });
  }
}
