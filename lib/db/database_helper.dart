import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/cart.dart';
import '../models/medicine.dart';
import '../models/report.dart';
import '../models/sale.dart';
import '../models/stock_transaction.dart';

/// Local SQLite storage for Strings Pharmacy. All data stays on the device.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'strings_pharmacy.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<String> get path async => p.join(await getDatabasesPath(), _dbName);

  Future<Database> _open() async {
    return openDatabase(
      await path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createV1(db);
        await _createV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(db);
      },
    );
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        generic_name TEXT,
        category TEXT,
        batch_no TEXT,
        supplier TEXT,
        unit TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        reorder_level INTEGER NOT NULL DEFAULT 0,
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        expiry_date TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER REFERENCES medicines(id) ON DELETE SET NULL,
        medicine_name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        balance_after INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_medicines_name ON medicines(name)');
    await db.execute(
        'CREATE INDEX idx_tx_medicine ON stock_transactions(medicine_id)');
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer TEXT,
        payment_method TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        cost_total REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    // Name, category, price and cost are snapshotted so reports stay correct
    // after a medicine is edited or deleted.
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        medicine_id INTEGER REFERENCES medicines(id) ON DELETE SET NULL,
        medicine_name TEXT NOT NULL,
        category TEXT,
        unit TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL,
        line_total REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
    await db
        .execute('CREATE INDEX idx_sale_items_med ON sale_items(medicine_id)');
  }

  // ---------- Medicines ----------

  Future<List<Medicine>> getMedicines({String search = ''}) async {
    final db = await database;
    final q = search.trim();
    final rows = q.isEmpty
        ? await db.query('medicines', orderBy: 'name COLLATE NOCASE')
        : await db.query(
            'medicines',
            where: 'name LIKE ? OR generic_name LIKE ? OR category LIKE ? '
                'OR batch_no LIKE ? OR supplier LIKE ?',
            whereArgs: List.filled(5, '%$q%'),
            orderBy: 'name COLLATE NOCASE',
          );
    return rows.map(Medicine.fromMap).toList();
  }

  Future<Medicine?> getMedicine(int id) async {
    final db = await database;
    final rows = await db.query('medicines', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Medicine.fromMap(rows.first);
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final rows = await db.rawQuery(
        "SELECT DISTINCT category FROM medicines WHERE category IS NOT NULL "
        "AND category != '' ORDER BY category COLLATE NOCASE");
    return rows.map((r) => r['category'] as String).toList();
  }

  /// Inserts a new medicine and records its opening stock as a Stock In.
  Future<int> insertMedicine(Medicine m) async {
    final db = await database;
    final now = DateTime.now();
    return db.transaction((txn) async {
      final map = m.copyWith(createdAt: now, updatedAt: now).toMap()
        ..remove('id');
      final id = await txn.insert('medicines', map);
      if (m.quantity > 0) {
        await _logTx(
          txn,
          StockTransaction(
            medicineId: id,
            medicineName: m.name,
            type: TransactionType.stockIn,
            quantity: m.quantity,
            balanceAfter: m.quantity,
            note: 'Opening stock',
            createdAt: now,
          ),
        );
      }
      return id;
    });
  }

  /// Updates medicine details. If the quantity was changed directly in the
  /// form, an adjustment transaction is logged.
  Future<void> updateMedicine(Medicine m) async {
    final db = await database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      final old = await txn.query('medicines',
          columns: ['quantity'], where: 'id = ?', whereArgs: [m.id]);
      final oldQty = old.isEmpty ? m.quantity : old.first['quantity'] as int;
      final map = m.copyWith(updatedAt: now).toMap()
        ..remove('id')
        ..remove('created_at');
      await txn.update('medicines', map, where: 'id = ?', whereArgs: [m.id]);
      if (oldQty != m.quantity) {
        await _logTx(
          txn,
          StockTransaction(
            medicineId: m.id,
            medicineName: m.name,
            type: TransactionType.adjust,
            quantity: m.quantity,
            balanceAfter: m.quantity,
            note: 'Edited from $oldQty to ${m.quantity}',
            createdAt: now,
          ),
        );
      }
    });
  }

  Future<void> deleteMedicine(int id) async {
    final db = await database;
    await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  /// Applies a manual stock movement atomically. For stock-in, [unitCost]
  /// optionally updates the medicine's cost price. Throws [StateError] if a
  /// stock-out would take the quantity below zero.
  Future<Medicine> adjustStock({
    required int medicineId,
    required TransactionType type,
    required int quantity,
    String note = '',
    double? unitCost,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn
          .query('medicines', where: 'id = ?', whereArgs: [medicineId]);
      if (rows.isEmpty) throw StateError('Medicine not found');
      final med = Medicine.fromMap(rows.first);

      final int newQty = switch (type) {
        TransactionType.stockIn ||
        TransactionType.saleReturn =>
          med.quantity + quantity,
        TransactionType.stockOut ||
        TransactionType.sale =>
          med.quantity - quantity,
        TransactionType.adjust => quantity,
      };
      if (newQty < 0) {
        throw StateError(
            'Not enough stock. Only ${med.quantity} ${med.unit} available.');
      }

      final now = DateTime.now();
      await txn.update(
        'medicines',
        {
          'quantity': newQty,
          'updated_at': now.toIso8601String(),
          if (type == TransactionType.stockIn && unitCost != null)
            'cost_price': unitCost,
        },
        where: 'id = ?',
        whereArgs: [medicineId],
      );
      await _logTx(
        txn,
        StockTransaction(
          medicineId: medicineId,
          medicineName: med.name,
          type: type,
          quantity: quantity,
          balanceAfter: newQty,
          note: note,
          createdAt: now,
        ),
      );
      return med.copyWith(quantity: newQty, updatedAt: now);
    });
  }

  Future<void> _logTx(Transaction txn, StockTransaction t) =>
      txn.insert('stock_transactions', t.toMap()..remove('id'));

  // ---------- Stock transactions ----------

  Future<List<StockTransaction>> getTransactions(
      {int? medicineId, int? limit}) async {
    final db = await database;
    final rows = await db.query(
      'stock_transactions',
      where: medicineId == null ? null : 'medicine_id = ?',
      whereArgs: medicineId == null ? null : [medicineId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(StockTransaction.fromMap).toList();
  }

  // ---------- Sales ----------

  /// Records a sale, deducting stock for every line. All-or-nothing: if any
  /// line lacks stock the whole sale is rolled back with a [StateError].
  /// [at] overrides the timestamp (used for sample data).
  Future<int> createSale({
    required List<CartItem> items,
    double discount = 0,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    String customer = '',
    double? amountPaid,
    String note = '',
    DateTime? at,
  }) async {
    if (items.isEmpty) throw StateError('The cart is empty.');
    final db = await database;
    final now = at ?? DateTime.now();

    return db.transaction((txn) async {
      final saleId = await txn.insert('sales', {
        'customer': customer,
        'payment_method': paymentMethod.code,
        'status': SaleStatus.completed.code,
        'note': note,
        'created_at': now.toIso8601String(),
      });

      double subtotal = 0, cost = 0;
      for (final item in items) {
        final rows = await txn.query('medicines',
            where: 'id = ?', whereArgs: [item.medicine.id]);
        if (rows.isEmpty) {
          throw StateError('${item.medicine.name} no longer exists.');
        }
        final med = Medicine.fromMap(rows.first);
        if (med.quantity < item.quantity) {
          throw StateError('Not enough ${med.name}: only ${med.quantity} '
              '${med.unit} in stock.');
        }
        final newQty = med.quantity - item.quantity;
        final lineTotal = item.quantity * item.unitPrice;
        subtotal += lineTotal;
        cost += item.quantity * med.costPrice;

        await txn.update(
          'medicines',
          {'quantity': newQty, 'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [med.id],
        );
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'medicine_id': med.id,
          'medicine_name': med.name,
          'category': med.category,
          'unit': med.unit,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'unit_cost': med.costPrice,
          'line_total': lineTotal,
        });
        await _logTx(
          txn,
          StockTransaction(
            medicineId: med.id,
            medicineName: med.name,
            type: TransactionType.sale,
            quantity: item.quantity,
            balanceAfter: newQty,
            note: 'Receipt ${Sale.receiptNoFor(saleId)}',
            createdAt: now,
          ),
        );
      }

      final disc = discount.clamp(0, subtotal).toDouble();
      final total = subtotal - disc;
      await txn.update(
        'sales',
        {
          'subtotal': subtotal,
          'discount': disc,
          'total': total,
          'cost_total': cost,
          'profit': total - cost,
          'amount_paid': amountPaid ?? total,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
      return saleId;
    });
  }

  /// Voids a completed sale and returns its items to stock (where the
  /// medicine still exists).
  Future<void> voidSale(int saleId, {String reason = ''}) async {
    final db = await database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      final rows =
          await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (rows.isEmpty) throw StateError('Sale not found.');
      final sale = Sale.fromMap(rows.first);
      if (sale.isVoided) throw StateError('Sale is already voided.');

      final items = await txn
          .query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      for (final row in items.map(SaleItem.fromMap)) {
        if (row.medicineId == null) continue;
        final med = await txn.query('medicines',
            columns: ['quantity'],
            where: 'id = ?',
            whereArgs: [row.medicineId]);
        if (med.isEmpty) continue;
        final newQty = (med.first['quantity'] as int) + row.quantity;
        await txn.update(
          'medicines',
          {'quantity': newQty, 'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [row.medicineId],
        );
        await _logTx(
          txn,
          StockTransaction(
            medicineId: row.medicineId,
            medicineName: row.medicineName,
            type: TransactionType.saleReturn,
            quantity: row.quantity,
            balanceAfter: newQty,
            note: 'Voided ${sale.receiptNo}'
                '${reason.isEmpty ? '' : ': $reason'}',
            createdAt: now,
          ),
        );
      }
      await txn.update(
        'sales',
        {
          'status': SaleStatus.voided.code,
          if (reason.isNotEmpty)
            'note': sale.note.isEmpty
                ? 'Voided: $reason'
                : '${sale.note}\nVoided: $reason',
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  static const _saleWithCount = '''
    SELECT s.*, (SELECT COALESCE(SUM(quantity), 0) FROM sale_items
                 WHERE sale_id = s.id) AS item_count
    FROM sales s
  ''';

  Future<List<Sale>> getSales(
      {DateTime? from, DateTime? to, int? limit}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('s.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('s.created_at < ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.rawQuery(
      '$_saleWithCount'
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY s.created_at DESC, s.id DESC'
      '${limit == null ? '' : ' LIMIT $limit'}',
      args,
    );
    return rows.map(Sale.fromMap).toList();
  }

  Future<Sale?> getSale(int id) async {
    final db = await database;
    final rows = await db.rawQuery('$_saleWithCount WHERE s.id = ?', [id]);
    return rows.isEmpty ? null : Sale.fromMap(rows.first);
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final rows = await db.query('sale_items',
        where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id');
    return rows.map(SaleItem.fromMap).toList();
  }

  // ---------- Reports ----------
  // All report queries count completed sales only, in [from, to).

  static const _completedInRange =
      "s.status = 'COMPLETED' AND s.created_at >= ? AND s.created_at < ?";

  List<String> _range(DateTime from, DateTime to) =>
      [from.toIso8601String(), to.toIso8601String()];

  Future<SalesSummary> getSalesSummary(DateTime from, DateTime to) async {
    final db = await database;
    final s = (await db.rawQuery('''
      SELECT COUNT(*) AS n, COALESCE(SUM(subtotal), 0) AS subtotal,
             COALESCE(SUM(discount), 0) AS discount,
             COALESCE(SUM(total), 0) AS revenue,
             COALESCE(SUM(cost_total), 0) AS cost,
             COALESCE(SUM(profit), 0) AS profit
      FROM sales s WHERE $_completedInRange
    ''', _range(from, to))).first;
    final units = (await db.rawQuery('''
      SELECT COALESCE(SUM(si.quantity), 0) AS units
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE $_completedInRange
    ''', _range(from, to))).first;
    double d(String k) => (s[k] as num).toDouble();
    return SalesSummary(
      salesCount: s['n'] as int,
      unitsSold: (units['units'] as num).toInt(),
      subtotal: d('subtotal'),
      discount: d('discount'),
      revenue: d('revenue'),
      cost: d('cost'),
      profit: d('profit'),
    );
  }

  /// One entry per calendar day in the range, including days with no sales.
  Future<List<DailySales>> getDailySales(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT substr(created_at, 1, 10) AS day, COUNT(*) AS n,
             SUM(total) AS revenue, SUM(cost_total) AS cost,
             SUM(profit) AS profit
      FROM sales s WHERE $_completedInRange
      GROUP BY day ORDER BY day
    ''', _range(from, to));
    final byDay = {for (final r in rows) r['day'] as String: r};

    final days = <DailySales>[];
    for (var d = DateTime(from.year, from.month, from.day);
        d.isBefore(to);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final key = d.toIso8601String().substring(0, 10);
      final r = byDay[key];
      days.add(r == null
          ? DailySales(day: d)
          : DailySales(
              day: d,
              salesCount: r['n'] as int,
              revenue: (r['revenue'] as num).toDouble(),
              cost: (r['cost'] as num).toDouble(),
              profit: (r['profit'] as num).toDouble(),
            ));
    }
    return days;
  }

  /// Line-level gross profit (before sale-level discounts).
  Future<List<SalesBreakdown>> getTopProducts(DateTime from, DateTime to,
      {int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT si.medicine_name AS label, SUM(si.quantity) AS n,
             SUM(si.line_total) AS revenue,
             SUM(si.line_total - si.quantity * si.unit_cost) AS profit
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE $_completedInRange
      GROUP BY si.medicine_name ORDER BY revenue DESC LIMIT $limit
    ''', _range(from, to));
    return rows.map(_breakdown).toList();
  }

  Future<List<SalesBreakdown>> getCategorySales(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT CASE WHEN si.category IS NULL OR si.category = ''
                  THEN 'Uncategorised' ELSE si.category END AS label,
             SUM(si.quantity) AS n, SUM(si.line_total) AS revenue,
             SUM(si.line_total - si.quantity * si.unit_cost) AS profit
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE $_completedInRange
      GROUP BY label ORDER BY revenue DESC
    ''', _range(from, to));
    return rows.map(_breakdown).toList();
  }

  Future<List<SalesBreakdown>> getPaymentBreakdown(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT payment_method AS label, COUNT(*) AS n, SUM(total) AS revenue,
             SUM(profit) AS profit
      FROM sales s WHERE $_completedInRange
      GROUP BY payment_method ORDER BY revenue DESC
    ''', _range(from, to));
    return rows
        .map((r) => SalesBreakdown(
              label: PaymentMethod.fromCode(r['label'] as String?).label,
              count: (r['n'] as num).toInt(),
              revenue: (r['revenue'] as num).toDouble(),
              profit: (r['profit'] as num).toDouble(),
            ))
        .toList();
  }

  /// All-time sales stats for one medicine.
  Future<SalesBreakdown> getMedicineSales(int medicineId) async {
    final db = await database;
    final r = (await db.rawQuery('''
      SELECT '' AS label, COALESCE(SUM(si.quantity), 0) AS n,
             COALESCE(SUM(si.line_total), 0) AS revenue,
             COALESCE(SUM(si.line_total - si.quantity * si.unit_cost), 0)
               AS profit
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'COMPLETED' AND si.medicine_id = ?
    ''', [medicineId])).first;
    return _breakdown(r);
  }

  SalesBreakdown _breakdown(Map<String, Object?> r) => SalesBreakdown(
        label: r['label'] as String,
        count: (r['n'] as num).toInt(),
        revenue: (r['revenue'] as num).toDouble(),
        profit: ((r['profit'] as num?) ?? 0).toDouble(),
      );

  // ---------- Settings ----------

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return {
      for (final r in rows) r['key'] as String: (r['value'] as String?) ?? ''
    };
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
