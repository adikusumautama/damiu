// lib/services/database_helper.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:damiu/models/delivery_log_model.dart'; // Impor model DeliveryLogItem
import 'package:damiu/models/daily_sale_model.dart'; // Impor model DailySale
import 'package:damiu/models/daily_stock_model.dart';
// import intl
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
    String path = join(documentsPath, 'damiu_app.db'); // Nama database Anda

    return await openDatabase(
      path,
      version: 9, // NAIKKAN VERSI DATABASE KE 9
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Tambahkan callback onUpgrade
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Buat tabel 'daily_sales'
    await db.execute('''
      CREATE TABLE daily_sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE, -- Pastikan hanya ada satu entri per tanggal
        day_of_week INTEGER, -- Tambahkan kolom day_of_week
        delivery_count INTEGER DEFAULT 0, -- Tambahkan kolom delivery_count
        quantity INTEGER,
        is_synced INTEGER DEFAULT 0, -- 0 for false, 1 for true
        employee_uid TEXT -- Siapa yang menginput/terakhir update ringkasan ini
      )
    ''');

    // Buat tabel 'delivery_log'
    await db.execute('''
      CREATE TABLE delivery_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT, -- Simpan sebagai ISO8601 String (Tanggal dan Waktu)
        gallons INTEGER,
        empty_gallons_returned INTEGER DEFAULT 0,
        employee_uid TEXT,
        is_summarized INTEGER DEFAULT 0, -- 0 jika belum diringkas ke daily_sales, 1 jika sudah
        is_no_delivery_marker INTEGER DEFAULT 0 -- 0 jika pengantaran normal, 1 jika penanda "tidak ada pengantaran"
      )
    ''');

    // Buat tabel 'daily_stock'
    await db.execute('''
      CREATE TABLE daily_stock(
        date TEXT PRIMARY KEY,
        initial_stock INTEGER NOT NULL,
        initial_empty_stock INTEGER NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL,
        updated_by_uid TEXT
      )
    ''');

    // Buat tabel 'orders'
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

    // Buat tabel 'customers'
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

  // Metode untuk menangani upgrade skema database
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
      var tableInfo = await db.rawQuery("PRAGMA table_info(daily_sales)");
      bool columnExists = tableInfo.any((column) => column['name'] == 'delivery_count');
      if (!columnExists) {
        await db.execute('ALTER TABLE daily_sales ADD COLUMN delivery_count INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 4) {
      var deliveryLogTableInfo = await db.rawQuery("PRAGMA table_info(delivery_log)");
      bool columnExists = deliveryLogTableInfo.any((column) => column['name'] == 'is_no_delivery_marker');
      if (!columnExists) {
        await db.execute('ALTER TABLE delivery_log ADD COLUMN is_no_delivery_marker INTEGER DEFAULT 0');
      }
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
      // Buat tabel 'orders' jika upgrade dari versi sebelumnya
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
      // Buat tabel 'customers' jika upgrade dari versi sebelumnya
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
      // This block runs for users upgrading from a version < 9.
      // The 'customers' table might already exist from the 'oldVersion < 8' block.
      // We just need to add the new column.
      await db.execute('ALTER TABLE customers ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
    }
  }
  // --- Operasi CRUD untuk DailySale ---

  Future<int> upsertDailySummary(DailySale sale) async {
    Database db = await database;
    return await db.insert('daily_sales', sale.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    final List<Map<String, dynamic>> maps = await db.query('daily_sales', orderBy: 'date ASC');
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
    return await db.delete(
      'daily_sales',
      where: 'is_synced = ?',
      whereArgs: [1]);
  }

  // --- Operasi untuk DeliveryLogItem ---

  Future<int> insertDeliveryLog(DeliveryLogItem logItem) async {
    Database db = await database;
    return await db.insert('delivery_log', logItem.toMap());
  }

  Future<List<DeliveryLogItem>> getTodaysDeliveryLogs(String employeeUid, DateTime date) async {
    Database db = await database;
    String dateString = date.toIso8601String().substring(0, 10);
    final List<Map<String, dynamic>> maps = await db.query(
      'delivery_log',
      where: 'employee_uid = ? AND date(timestamp) = ?',
      whereArgs: [employeeUid, dateString],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return DeliveryLogItem.fromMap(maps[i]);
    });
  }

  Future<int> getTodaysUnsummarizedGallons(String employeeUid, DateTime date) async {
    Database db = await database;
    String dateString = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      'SELECT SUM(gallons) as total FROM delivery_log WHERE employee_uid = ? AND date(timestamp) = ? AND is_summarized = 0',
      [employeeUid, dateString],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  Future<int> markDeliveriesAsSummarized(String employeeUid, DateTime date) async {
    Database db = await database;
    String dateString = date.toIso8601String().substring(0, 10);
    return await db.update(
      'delivery_log',
      {'is_summarized': 1},
      where: 'employee_uid = ? AND date(timestamp) = ? AND is_summarized = 0',
      whereArgs: [employeeUid, dateString],
    );
  }

  Future<List<DeliveryLogItem>> getTodaysUnsummarizedDeliveryLogs(String employeeUid, DateTime date) async {
    Database db = await database;
    String dateString = date.toIso8601String().substring(0, 10);
    final List<Map<String, dynamic>> maps = await db.query(
      'delivery_log',
      where: 'employee_uid = ? AND date(timestamp) = ? AND is_summarized = ?',
      whereArgs: [employeeUid, dateString, 0],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return DeliveryLogItem.fromMap(maps[i]);
    });
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

  Future<List<DeliveryLogItem>> getAllUnsummarizedDeliveryLogsByDate(DateTime date) async {
    Database db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date);
    final List<Map<String, dynamic>> maps = await db.query(
      'delivery_log',
      where: 'date(timestamp) = ? AND is_summarized = ?',
      whereArgs: [dateString, 0],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return DeliveryLogItem.fromMap(maps[i]);
    });
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

  Future<DailyStock?> getDailyStock(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_stock',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return DailyStock.fromDbMap(maps.first);
    }
    return null;
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
    return await db.insert('orders', order.toMap());
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

  Future<int> updateOrderStatus(int id, String status, {bool setDeliveredTime = false}) async {
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

  // Upsert (Update or Insert) a customer.
  // ConflictAlgorithm.ignore ensures that if a customer with the same name
  // already exists, the insert is simply ignored, preventing duplicates.
  Future<int> upsertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'name ASC');
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
}
