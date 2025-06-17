// lib/services/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:damiu/models/delivery_log_model.dart'; // Impor model DeliveryLogItem
import 'package:damiu/models/daily_sale_model.dart'; // Impor model DailySale
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
      version: 4, // Naikkan versi database ke 4
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
        employee_uid TEXT,
        is_summarized INTEGER DEFAULT 0, -- 0 jika belum diringkas ke daily_sales, 1 jika sudah
        is_no_delivery_marker INTEGER DEFAULT 0 -- 0 jika pengantaran normal, 1 jika penanda "tidak ada pengantaran"
      )
    ''');
  }

  // Metode untuk menangani upgrade skema database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Jika upgrade dari versi < 2 (misalnya versi 1 yang belum punya tabel delivery_log)
      // Buat tabel 'delivery_log'
      await db.execute('''
        CREATE TABLE delivery_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT, 
          gallons INTEGER,
          employee_uid TEXT,
          is_summarized INTEGER DEFAULT 0,
          is_no_delivery_marker INTEGER DEFAULT 0
        )
      ''');
      print("DATABASE HELPER: Executed upgrade for oldVersion < 2 (created delivery_log).");
    }
    if (oldVersion < 3) {
      // Jika upgrade dari versi < 3 (misalnya versi 2 yang belum punya delivery_count di daily_sales)
      // Periksa apakah kolom sudah ada sebelum mencoba menambahkannya
      var tableInfo = await db.rawQuery("PRAGMA table_info(daily_sales)");
      bool columnExists = tableInfo.any((column) => column['name'] == 'delivery_count');

      if (!columnExists) {
        // Tambahkan kolom delivery_count ke tabel daily_sales
        await db.execute('ALTER TABLE daily_sales ADD COLUMN delivery_count INTEGER DEFAULT 0');
        print("DATABASE HELPER: Executed upgrade for oldVersion < 3 (added delivery_count to daily_sales).");
      } else {
        print("DATABASE HELPER: Skipped adding delivery_count to daily_sales (oldVersion < 3) because it already exists.");
      }
    }
    if (oldVersion < 4) {
      // Tambahkan kolom is_no_delivery_marker ke tabel delivery_log
      var deliveryLogTableInfo = await db.rawQuery("PRAGMA table_info(delivery_log)");
      bool columnExists = deliveryLogTableInfo.any((column) => column['name'] == 'is_no_delivery_marker');
      if (!columnExists) {
        await db.execute('ALTER TABLE delivery_log ADD COLUMN is_no_delivery_marker INTEGER DEFAULT 0');
        print("DATABASE HELPER: Executed upgrade for oldVersion < 4 (added is_no_delivery_marker to delivery_log).");
      } else {
        print("DATABASE HELPER: Skipped adding is_no_delivery_marker to delivery_log (oldVersion < 4) because it already exists.");
      }
    }
  }
  // --- Operasi CRUD untuk DailySale ---

  // Mengganti insertSale menjadi upsertDailySummary untuk tabel daily_sales
  Future<int> upsertDailySummary(DailySale sale) async {
    Database db = await database;
    // Menggunakan ConflictAlgorithm.replace untuk menimpa data jika tanggal sudah ada
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
      sale.toMap(), // Pastikan toMap() tidak menyertakan ID jika kolom ID tidak diupdate
      where: 'id = ?',
      whereArgs: [sale.id],
      conflictAlgorithm: ConflictAlgorithm.rollback, // Atau ignore/fail jika ada unique constraint pada date
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
    // Menghapus semua baris dari tabel daily_sales
    return await db.delete('daily_sales');
  }

  Future<int> deleteSyncedSales() async {
    Database db = await database;
    // Menghapus baris di mana is_synced = 1
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
    // Mengambil log untuk tanggal tertentu (mengabaikan waktu)
    String dateString = date.toIso8601String().substring(0, 10); // YYYY-MM-DD
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

  // Mendapatkan log pengantaran yang belum diringkas untuk tanggal tertentu
  Future<List<DeliveryLogItem>> getTodaysUnsummarizedDeliveryLogs(String employeeUid, DateTime date) async {
    Database db = await database;
    String dateString = date.toIso8601String().substring(0, 10); // YYYY-MM-DD
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

  // --- Mendapatkan semua log pengantaran ---
  Future<List<DeliveryLogItem>> getAllDeliveryLogs() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'delivery_log',
      orderBy: 'timestamp ASC', // Urutkan berdasarkan waktu
    );
    return List.generate(maps.length, (i) {
      return DeliveryLogItem.fromMap(maps[i]);
    });
  }

  // --- Menghapus semua log pengantaran ---
  Future<int> deleteAllDeliveryLogs() async {
    Database db = await database;
    return await db.delete('delivery_log');
  }

  // --- Menghapus satu log pengantaran berdasarkan ID ---
  Future<int> deleteDeliveryLog(int id) async {
    Database db = await database;
    return await db.delete(
      'delivery_log',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Memperbarui satu log pengantaran ---
  Future<int> updateDeliveryLog(DeliveryLogItem log) async {
    Database db = await database;
    return await db.update(
      'delivery_log',
      log.toMap(), // Pastikan toMap() menghasilkan map yang benar
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  // --- Mendapatkan semua log pengantaran yang belum diringkas untuk tanggal tertentu ---
  Future<List<DeliveryLogItem>> getAllUnsummarizedDeliveryLogsByDate(DateTime date) async {
    Database db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date); // YYYY-MM-DD
    final List<Map<String, dynamic>> maps = await db.query(
      'delivery_log',
      where: 'date(timestamp) = ? AND is_summarized = ?',
      whereArgs: [dateString, 0], // 0 for false (belum diringkas)
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return DeliveryLogItem.fromMap(maps[i]);
    });
  }

  // --- Menandai semua log pengantaran yang belum diringkas untuk tanggal tertentu sebagai sudah diringkas ---
  Future<int> markAllDeliveryLogsAsSummarizedByDate(DateTime date) async {
    Database db = await database;
    String dateString = DateFormat('yyyy-MM-dd').format(date);
    return await db.update(
      'delivery_log',
      {'is_summarized': 1}, // 1 for true (sudah diringkas)
      where: 'date(timestamp) = ? AND is_summarized = ?',
      whereArgs: [dateString, 0], // 0 for false (belum diringkas)
    );
  }

  // --- Menghapus semua log pengantaran yang sudah diringkas ---
  Future<int> deleteSummarizedDeliveryLogs() async {
    Database db = await database;
    return await db.delete(
      'delivery_log',
      where: 'is_summarized = ?',
      whereArgs: [1], // 1 for true (sudah diringkas)
    );
  }
}
