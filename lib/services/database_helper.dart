// lib/services/database_helper.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 1, // Reset versi ke 1 karena skema sudah final
      onCreate: _onCreate,
      // onUpgrade tidak lagi diperlukan jika kita memulai dengan skema yang bersih
    );
  }

  // ======================================================================
  // PERUBAHAN UTAMA: Skema database yang disederhanakan dan distandarisasi
  // ======================================================================
  Future<void> _onCreate(Database db, int version) async {
    // Tabel Pesanan (orders) - Sekarang menjadi sumber utama data transaksi
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestore_id TEXT UNIQUE,
        customer_name TEXT NOT NULL,
        gallon_quantity INTEGER NOT NULL,
        other_items TEXT,
        address TEXT,
        phone_number TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        delivered_at TEXT,
        employee_uid TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabel Pelanggan (customers)
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestore_id TEXT UNIQUE,
        name TEXT NOT NULL UNIQUE,
        address TEXT,
        phone_number TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Tabel Stok Harian (daily_stock)
    await db.execute('''
      CREATE TABLE daily_stock(
        date TEXT PRIMARY KEY,
        initial_stock INTEGER NOT NULL,
        initial_empty_stock INTEGER NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL,
        updated_by_uid TEXT
      )
    ''');

    // Tabel Rekap Penjualan Harian (daily_sales)
    await db.execute('''
      CREATE TABLE daily_sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestore_id TEXT,
        date TEXT UNIQUE, 
        day_of_week INTEGER, 
        delivery_count INTEGER DEFAULT 0,
        quantity INTEGER,
        is_synced INTEGER DEFAULT 0,
        employee_uid TEXT
      )
    ''');
  }

  // --- Operasi CRUD untuk Order ---
  
  Future<int> insertOrder(Order order) async {
    final db = await database;
    return await db.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    return List.generate(maps.length, (i) => Order.fromMap(maps[i]));
  }

  Future<int> updateOrderStatus(int id, String status, {bool setDeliveredTime = false}) async {
    final db = await database;
    Map<String, dynamic> row = {'status': status, 'is_synced': 0};
    if (setDeliveredTime) {
      row['delivered_at'] = DateTime.now().toIso8601String();
    }
    return await db.update('orders', row, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<List<Order>> getUnsyncedOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('orders', where: 'is_synced = ?', whereArgs: [0]);
    return List.generate(maps.length, (i) => Order.fromMap(maps[i]));
  }

  Future<int> markOrderAsSynced(int id, String firestoreId) async {
    final db = await database;
    return await db.update(
      'orders',
      {'is_synced': 1, 'firestore_id': firestoreId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsertOrder(Order order) async {
    final db = await database;
    // Gunakan upsert dengan firestoreId sebagai kunci unik jika tersedia
    if (order.firestoreId != null && order.firestoreId!.isNotEmpty) {
      await db.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.insert('orders', order.toMap());
    }
  }

  Future<Order?> getOrderByFirestoreId(String firestoreId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'firestore_id = ?',
      whereArgs: [firestoreId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Order.fromMap(maps.first);
    }
    return null;
  }
  // --- Operasi CRUD untuk Customer ---

  Future<void> upsertCustomer(Customer customer) async {
    final db = await database;
    await db.insert('customers', customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }
  
  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> getUnsyncedCustomers() async {
    final db = await database;
    final maps = await db.query('customers', where: 'is_synced = 0');
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<int> markCustomerAsSynced(int id, String firestoreId) async {
    final db = await database;
    return await db.update('customers', {'is_synced': 1, 'firestore_id': firestoreId}, where: 'id = ?', whereArgs: [id]);
  }
  
  // --- Operasi CRUD untuk DailyStock ---

  Future<void> upsertDailyStock(DailyStock stock) async {
    final db = await database;
    await db.insert('daily_stock', stock.toLocalDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailyStock?> getDailyStock(DateTime date) async {
    final db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date);
    final List<Map<String, dynamic>> maps = await db.query('daily_stock', where: 'date = ?', whereArgs: [dateString]);
    if (maps.isNotEmpty) {
      return DailyStock.fromMap(maps.first, maps.first['date']);
    }
    return null;
  }
  
  // --- Operasi CRUD untuk DailySale ---
  
  Future<void> upsertDailySummary(DailySale sale) async {
    final db = await database;
    await db.insert('daily_sales', sale.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<DailySale?> getDailySaleByDate(DateTime date) async {
    final db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date);
    final List<Map<String, dynamic>> maps = await db.query('daily_sales', where: 'date = ?', whereArgs: [dateString]);
    if (maps.isNotEmpty) {
      return DailySale.fromMap(maps.first);
    }
    return null;
  }
  
  Future<List<DailySale>> getUnsyncedSales() async {
    final db = await database;
    final maps = await db.query('daily_sales', where: 'is_synced = 0');
    return maps.map((map) => DailySale.fromMap(map)).toList();
  }

  Future<int> markSaleAsSynced(int id) async {
    final db = await database;
    return await db.update('daily_sales', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
  
  // --- Metode Helper untuk Stok ---

  Future<int> setInitialStock({required DateTime date, required int filledStock, required String updatedByUid}) async {
    final oldStock = await getDailyStock(date);
    final dailyStock = DailyStock(
      id: _formatDate(date),
      initialStock: filledStock,
      initialEmptyStock: oldStock?.initialEmptyStock ?? 0,
      currentStock: filledStock, // Saat set, current stock = initial stock
      lastUpdated: DateTime.now(),
      updatedByUid: updatedByUid,
    );
    await upsertDailyStock(dailyStock);
    return 1;
  }

  Future<int> setInitialEmptyStock({required DateTime date, required int emptyStock, required String updatedByUid}) async {
    final oldStock = await getDailyStock(date);
    final dailyStock = DailyStock(
      id: _formatDate(date),
      initialStock: oldStock?.initialStock ?? 0,
      initialEmptyStock: emptyStock,
      currentStock: oldStock?.currentStock ?? oldStock?.initialStock ?? 0,
      lastUpdated: DateTime.now(),
      updatedByUid: updatedByUid,
    );
    await upsertDailyStock(dailyStock);
    return 1;
  }

  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  /// Menghapus semua data transaksional dari database lokal.
  /// Berguna untuk reset atau troubleshooting.
  Future<void> clearAllLocalData() async {
    final db = await database;
    final batch = db.batch();
    batch.delete('orders');
    batch.delete('customers');
    batch.delete('daily_stock');
    batch.delete('daily_sales');
    await batch.commit(noResult: true);
  }
}