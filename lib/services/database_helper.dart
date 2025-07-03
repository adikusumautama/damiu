// lib/services/database_helper.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String documentsPath = await getDatabasesPath();
    String path = join(documentsPath, 'damiu_app.db');

    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE, 
        day_of_week INTEGER, 
        delivery_count INTEGER DEFAULT 0,
        quantity INTEGER,
        is_synced INTEGER DEFAULT 0,
        employee_uid TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE delivery_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        gallons INTEGER,
        empty_gallons_returned INTEGER DEFAULT 0,
        employee_uid TEXT,
        is_summarized INTEGER DEFAULT 0,
        is_no_delivery_marker INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE daily_stock(
        date TEXT PRIMARY KEY,
        initial_stock INTEGER NOT NULL,
        initial_empty_stock INTEGER NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL,
        updated_by_uid TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestore_id TEXT,
        customer_name TEXT NOT NULL,
        gallon_quantity INTEGER NOT NULL,
        other_items TEXT,
        address TEXT,
        phone_number TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        delivered_at TEXT,
        employee_uid TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        address TEXT,
        phone_number TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE delivery_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT, 
          gallons INTEGER,
          empty_gallons_returned INTEGER DEFAULT 0,
          employee_uid TEXT,
          is_summarized INTEGER DEFAULT 0,
          is_no_delivery_marker INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE daily_sales ADD COLUMN delivery_count INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE delivery_log ADD COLUMN is_no_delivery_marker INTEGER DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE daily_stock(
          date TEXT PRIMARY KEY,
          initial_stock INTEGER NOT NULL,
          last_updated TEXT NOT NULL,
          updated_by_uid TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE delivery_log ADD COLUMN empty_gallons_returned INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE daily_stock ADD COLUMN initial_empty_stock INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE orders(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_name TEXT NOT NULL,
          gallon_quantity INTEGER NOT NULL,
          other_items TEXT,
          address TEXT,
          phone_number TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          delivered_at TEXT,
          employee_uid TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          address TEXT,
          phone_number TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE customers ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE orders ADD COLUMN firestore_id TEXT');
    }
  }

  // --- Operasi CRUD untuk DailySale ---
  Future<int> upsertDailySummary(DailySale sale) async {
    Database db = await database;
    return await db.insert('daily_sales', sale.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DailySale>> getUnsyncedSales() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_sales',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) {
      return DailySale.fromMap(maps[i]);
    });
  }

  Future<List<DailySale>> getAllSalesLocal() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('daily_sales', orderBy: 'date ASC');
    return List.generate(maps.length, (i) {
      return DailySale.fromMap(maps[i]);
    });
  }

  Future<int> markSaleAsSynced(int id) async {
    Database db = await database;
    return await db.update(
      'daily_sales',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateSale(DailySale sale) async {
    Database db = await database;
    return await db.update(
      'daily_sales',
      sale.toMap(),
      where: 'id = ?',
      whereArgs: [sale.id],
      conflictAlgorithm: ConflictAlgorithm.rollback,
    );
  }

  Future<int> deleteSale(int id) async {
    Database db = await database;
    return await db.delete(
      'daily_sales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllSales() async {
    Database db = await database;
    return await db.delete('daily_sales');
  }

  Future<int> deleteSyncedSales() async {
    Database db = await database;
    return await db.delete('daily_sales', where: 'is_synced = ?', whereArgs: [1]);
  }

  // --- Operasi untuk DeliveryLogItem ---
  Future<int> insertDeliveryLog(DeliveryLogItem logItem) async {
    Database db = await database;
    return await db.insert('delivery_log', logItem.toMap());
  }

  Future<List<DeliveryLogItem>> getAllDeliveryLogsForDate(DateTime date) async {
    Database db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date);
    final List<Map<String, dynamic>> maps = await db.query(
      'delivery_log',
      where: 'date(timestamp) = ?',
      whereArgs: [dateString],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return DeliveryLogItem.fromMap(maps[i]);
    });
  }

  Future<List<DeliveryLogItem>> getAllDeliveryLogs() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'delivery_log',
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return DeliveryLogItem.fromMap(maps[i]);
    });
  }

  Future<int> deleteAllDeliveryLogs() async {
    Database db = await database;
    return await db.delete('delivery_log');
  }

  Future<int> deleteDeliveryLog(int id) async {
    Database db = await database;
    return await db.delete(
      'delivery_log',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateDeliveryLog(DeliveryLogItem log) async {
    Database db = await database;
    return await db.update(
      'delivery_log',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> markAllDeliveryLogsAsSummarizedByDate(DateTime date) async {
    Database db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date);
    return await db.update(
      'delivery_log',
      {'is_summarized': 1},
      where: 'date(timestamp) = ? AND is_summarized = ?',
      whereArgs: [dateString, 0],
    );
  }

  Future<int> deleteSummarizedDeliveryLogs() async {
    Database db = await database;
    return await db.delete(
      'delivery_log',
      where: 'is_summarized = ?',
      whereArgs: [1],
    );
  }
  
  // --- Operasi untuk DailyStock Lokal ---
  Future<int> upsertDailyStock(DailyStock stock) async {
    final db = await database;
    return await db.insert(
      'daily_stock',
      stock.toMapForDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DailyStock>> getAllLocalStocks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('daily_stock', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => DailyStock.fromDbMap(maps[i]));
  }

  Future<int> deleteDailyStock(String date) async {
    final db = await database;
    return await db.delete('daily_stock', where: 'date = ?', whereArgs: [date]);
  }

  Future<int> deleteAllDailyStocks() async {
    final db = await database;
    return await db.delete('daily_stock');
  }

  // --- Operasi untuk Order ---
  Future<int> insertOrder(Order order) async {
    final db = await database;
    return await db.insert('orders', order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Order>> getTodaysOrders() async {
    final db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'date(created_at) = ?',
      whereArgs: [dateString],
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) {
      return Order.fromMap(maps[i]);
    });
  }

  Future<void> deleteTodaysOrders() async {
    final db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await db.delete('orders', where: 'date(created_at) = ?', whereArgs: [dateString]);
  }

  Future<int> updateOrderStatus(int id, String status,
      {bool setDeliveredTime = false}) async {
    final db = await database;
    Map<String, dynamic> row = {'status': status};
    if (setDeliveredTime) {
      row['delivered_at'] = DateTime.now().toIso8601String();
    }
    return await db.update('orders', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteOrder(int id) async {
    final db = await database;
    return await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  // --- Operasi untuk Customer ---
  Future<int> upsertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('customers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<List<Customer>> getUnsyncedCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<int> markCustomerAsSynced(int id) async {
    final db = await database;
    return await db.update(
      'customers',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllCustomers() async {
    final db = await database;
    return await db.delete('customers');
  }
}