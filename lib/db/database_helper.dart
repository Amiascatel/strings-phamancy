import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/medicine.dart';
import '../models/stock_transaction.dart';

/// Local SQLite storage for Strings Pharmacy. All data stays on the device.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'strings_pharmacy.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
        await txn.insert(
          'stock_transactions',
          StockTransaction(
            medicineId: id,
            medicineName: m.name,
            type: TransactionType.stockIn,
            quantity: m.quantity,
            balanceAfter: m.quantity,
            note: 'Opening stock',
            createdAt: now,
          ).toMap()
            ..remove('id'),
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
        await txn.insert(
          'stock_transactions',
          StockTransaction(
            medicineId: m.id,
            medicineName: m.name,
            type: TransactionType.adjust,
            quantity: m.quantity,
            balanceAfter: m.quantity,
            note: 'Edited from $oldQty to ${m.quantity}',
            createdAt: now,
          ).toMap()
            ..remove('id'),
        );
      }
    });
  }

  Future<void> deleteMedicine(int id) async {
    final db = await database;
    await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  /// Applies a stock movement atomically. Throws [StateError] if a stock-out
  /// would take the quantity below zero.
  Future<Medicine> adjustStock({
    required int medicineId,
    required TransactionType type,
    required int quantity,
    String note = '',
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn
          .query('medicines', where: 'id = ?', whereArgs: [medicineId]);
      if (rows.isEmpty) throw StateError('Medicine not found');
      final med = Medicine.fromMap(rows.first);

      final int newQty = switch (type) {
        TransactionType.stockIn => med.quantity + quantity,
        TransactionType.stockOut => med.quantity - quantity,
        TransactionType.adjust => quantity,
      };
      if (newQty < 0) {
        throw StateError(
            'Not enough stock. Only ${med.quantity} ${med.unit} available.');
      }

      final now = DateTime.now();
      await txn.update(
        'medicines',
        {'quantity': newQty, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [medicineId],
      );
      await txn.insert(
        'stock_transactions',
        StockTransaction(
          medicineId: medicineId,
          medicineName: med.name,
          type: type,
          quantity: quantity,
          balanceAfter: newQty,
          note: note,
          createdAt: now,
        ).toMap()
          ..remove('id'),
      );
      return med.copyWith(quantity: newQty, updatedAt: now);
    });
  }

  // ---------- Transactions ----------

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
}
