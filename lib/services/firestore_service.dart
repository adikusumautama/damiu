// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/daily_sync_metadata_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/returned_gallon_log_model.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- FUNGSI CRUD PESANAN ---
  /// Menambah pesanan baru dan membuat/memperbarui data pelanggan.
  /// Fungsi ini dioptimalkan untuk mode offline.
  /// PERHATIAN: Untuk menghindari read-before-write yang gagal saat offline,
  /// fungsi ini tidak memeriksa apakah pelanggan sudah ada. Sebaliknya, ia menggunakan
  /// `set` dengan `merge: true` pada dokumen pelanggan.
  /// Ini mengharuskan ID dokumen pelanggan dapat diprediksi, jadi kita akan menggunakan
  /// nama pelanggan sebagai ID. Ini berarti nama pelanggan harus unik.
  Future<String?> addOrderAndUpsertCustomer(Order order) async {
    try {
      WriteBatch batch = _db.batch();

      // Jika ada nama pelanggan, lakukan upsert (update/insert).
      if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
        // Gunakan nama pelanggan sebagai ID dokumen untuk membuatnya idempotent.
        // Ini menghindari perlunya query 'get' yang akan gagal saat offline.
        final customerRef = _db.collection('customers').doc(order.customerName!.trim());
        // Buat objek Customer baru untuk mendapatkan map data yang benar.
        final customerToUpsert = Customer(name: order.customerName!.trim(), address: order.address, phoneNumber: order.phoneNumber, createdAt: DateTime.now());
        batch.set(customerRef, customerToUpsert.toFirestore(), SetOptions(merge: true));
      }

      final newOrderRef = _db.collection('orders').doc();
      batch.set(newOrderRef, order.toMapForFirestore());
      await batch.commit();
      return newOrderRef.id;
    } catch (e) {
      // --- PERBAIKAN: Lemparkan kembali error agar bisa ditangkap oleh UI ---
      // Ini akan membuat pesan error yang sebenarnya muncul di aplikasi, bukan pesan sukses palsu.
      print('Error in addOrderAndUpsertCustomer: ${e.toString()}');
      rethrow;
    }
  }

  Future<String?> updateOrder(String firestoreId, Order updatedOrder) async {
    try {
      await _db.collection('orders').doc(firestoreId).update(updatedOrder.toMapForFirestore());
      return null;
    } catch (e) {
      return 'Gagal memperbarui pesanan: ${e.toString()}';
    }
  }

  Future<String?> deleteOrder(String firestoreId) async {
    try {
      await _db.collection('orders').doc(firestoreId).delete();
      return null;
    } catch (e) {
      return 'Gagal menghapus pesanan: ${e.toString()}';
    }
  }

  Future<String?> deleteAllOrders() async {
    try {
      final snapshot = await _db.collection('orders').get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return null; // Sukses
    } catch (e) {
      return 'Gagal menghapus semua pesanan: ${e.toString()}';
    }
  }

  // --- FUNGSI CRUD PELANGGAN ---
  Future<String> addCustomer(Customer customer) async {
    final docRef = await _db.collection('customers').add(customer.toFirestore());
    return docRef.id;
  }

  Future<String?> updateCustomer(Customer customer) async {
    if (customer.firestoreId == null) return "Customer Firestore ID tidak ditemukan.";
    try {
      await _db.collection('customers').doc(customer.firestoreId).set(customer.toFirestore(), SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
  
  Future<String?> deleteCustomer(String firestoreId) async {
    try {
      await _db.collection('customers').doc(firestoreId).delete();
      return null;
    } catch (e) {
      return 'Gagal menghapus pelanggan: ${e.toString()}';
    }
  }

  Future<String?> deleteAllCustomers() async {
    try {
      final snapshot = await _db.collection('customers').get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return null; // Sukses
    } catch (e) {
      return 'Gagal menghapus semua pelanggan: ${e.toString()}';
    }
  }

  // --- FUNGSI CRUD REKAP PENJUALAN ---
  Future<String?> deleteDailySale(String firestoreId) async {
    try {
      await _db.collection('daily_sales').doc(firestoreId).delete();
      return null;
    } catch (e) {
      return 'Gagal menghapus rekap penjualan: ${e.toString()}';
    }
  }
  
  Future<String?> deleteAllDailySales() async {
    try {
      final snapshot = await _db.collection('daily_sales').get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // --- FUNGSI CRUD METADATA SINKRONISASI ---
  Future<String?> updateDailySyncMetadata(String docId, Map<String, dynamic> data) async {
    try {
      data['last_synced_at'] = Timestamp.now();
      await _db.collection('daily_sync_metadata').doc(docId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteDailySyncMetadata(String docId) async {
    try {
      await _db.collection('daily_sync_metadata').doc(docId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
  
  Future<String?> deleteAllDailySyncMetadata() async {
    try {
      final snapshot = await _db.collection('daily_sync_metadata').get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // --- FUNGSI CRUD LOG GALON KEMBALI ---
  Stream<List<ReturnedGallonLog>> getReturnedGallonLogsStream() {
    return _db
        .collection('returned_gallons_log')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReturnedGallonLog.fromFirestore(doc))
            .toList());
  }

  Future<String?> deleteReturnedGallonLog(String id) async {
    try {
      await _db.collection('returned_gallons_log').doc(id).delete();
      return null;
    } catch (e) {
      return 'Gagal menghapus log: ${e.toString()}';
    }
  }

  Future<String?> deleteAllReturnedGallonLogs() async {
    try {
      final snapshot = await _db.collection('returned_gallons_log').get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return null; // Sukses
    } catch (e) {
      return 'Gagal menghapus semua log: ${e.toString()}';
    }
  }

  // --- OPERASI LAINNYA ---
  Future<String?> updateOrderStatus(String firestoreId, String status, {bool setDeliveredTime = false}) async {
    try {
      Map<String, dynamic> dataToUpdate = {'status': status};
      if (setDeliveredTime) {
        dataToUpdate['deliveredAt'] = Timestamp.now();
      }
      await _db.collection('orders').doc(firestoreId).update(dataToUpdate);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Menyelesaikan pesanan menggunakan WriteBatch agar berfungsi online & offline.
  /// Menggantikan runTransaction yang gagal saat offline.
  Future<String?> completeOrderBatched(Order order) async {
    if (order.firestoreId == null) return "Order ID tidak ditemukan.";

    final orderRef = _db.collection('orders').doc(order.firestoreId!);
    final orderDate = order.createdAt ?? DateTime.now();
    final docId = DateFormat('yyyy-MM-dd').format(orderDate);
    final stockRef = _db.collection('daily_stock_levels').doc(docId);
    final saleRef = _db.collection('daily_sales').doc(docId);

    try {
      WriteBatch batch = _db.batch();

      // 1. Perbarui status pesanan menjadi 'Sudah Diantar'
      batch.update(orderRef, {
        'status': OrderStatus.delivered,
        'deliveredAt': FieldValue.serverTimestamp(), // Gunakan waktu server
      });

      // 2. Kurangi stok galon saat ini
      batch.set(stockRef, {
        'current_stock': FieldValue.increment(-(order.gallonQuantity ?? 0)),
        // PERUBAHAN: Tambah jumlah terjual secara eksplisit
        'total_sold': FieldValue.increment(order.gallonQuantity ?? 0),
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Tambah/perbarui rekap penjualan harian
      batch.set(saleRef, {
        'quantity': FieldValue.increment(order.gallonQuantity ?? 0),
        'delivery_count': FieldValue.increment(1),
        'date': Timestamp.fromDate(orderDate),
        'day_of_week': orderDate.weekday,
        'last_updated_by': order.employeeUid
      }, SetOptions(merge: true));

      await batch.commit();
      return null;
    } catch (e) {
      return 'Gagal melakukan transaksi pesanan: ${e.toString()}';
    }
  }

  Future<String?> addReturnedGallonLog({required int quantity, required String employeeUid}) async {
    try {
      await _db.collection('returned_gallons_log').add({'quantity': quantity, 'createdAt': Timestamp.now(), 'employeeUid': employeeUid});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> adjustCurrentStock(int quantityChange) async {
    final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _db.collection('daily_stock_levels').doc(docId);

    // --- PERBAIKAN KRITIS UNTUK OFFLINE ---
    // Menggunakan `set` dengan `merge: true` adalah operasi "upsert" yang aman untuk offline.
    // Ini akan membuat dokumen jika belum ada, atau memperbaruinya jika sudah ada,
    // tanpa perlu melakukan `get` atau `update` terlebih dahulu yang bisa gagal saat offline.
    try {
      await docRef.set({
        'current_stock': FieldValue.increment(quantityChange),
        'last_updated': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setInitialStock({required DateTime date, required int filledStock, required String updatedByUid}) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      // PERUBAHAN: Inisialisasi total_sold menjadi 0 saat stok awal diatur.
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_stock': filledStock,
        'current_stock': filledStock,
        'initial_empty_stock': 0,
        'total_sold': 0,
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> incrementEmptyStock({required int quantity, required String updatedByUid}) async {
    final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _db.collection('daily_stock_levels').doc(docId);
    try {
      // --- PERBAIKAN KRITIS UNTUK OFFLINE ---
      // Menggunakan `set` dengan `merge: true` agar aman saat offline.
      // PERUBAHAN: Logika ini tidak lagi mengubah `initial_stock`.
      await docRef.set({
        // Tambah ke stok tersedia (karena langsung diisi ulang)
        'current_stock': FieldValue.increment(quantity),
        'initial_empty_stock': FieldValue.increment(quantity),
        'last_updated': FieldValue.serverTimestamp(),
        'updated_by_uid': updatedByUid
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setInitialEmptyStock({required DateTime date, required int emptyStock, required String updatedByUid}) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({'initial_empty_stock': emptyStock, 'last_updated': Timestamp.now(), 'updated_by_uid': updatedByUid}, SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // --- STREAM DAN GETTERS ---
  Stream<List<Order>> getTodaysOrdersStream({DateTime? date}) {
    final now = date ?? DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _db.collection('orders').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)).where('createdAt', isLessThan: Timestamp.fromDate(endOfDay)).orderBy('createdAt', descending: false).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Order.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Stream<List<Order>> getOrdersStream({String? status}) {
    Query query = _db.collection('orders');

    if (status != null && status != 'Semua') {
      query = query.where('status', isEqualTo: status);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Order.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Stream<List<DailyStock>> getStocksStream() {
    return _db.collection('daily_stock_levels').snapshots().map((snapshot) => snapshot.docs.map((doc) => DailyStock.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Stream<DailyStock?> getDailyStockStream(DateTime date) {
    String docId = DateFormat('yyyy-MM-dd').format(date);
    return _db.collection('daily_stock_levels').doc(docId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return DailyStock.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
      }
      return null;
    });
  }

  Future<DailyStock?> getDailyStockOnce(DateTime date) async {
    String docId = DateFormat('yyyy-MM-dd').format(date);
    final doc = await _db.collection('daily_stock_levels').doc(docId).get();
    if (doc.exists && doc.data() != null) {
      return DailyStock.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Stream<List<Customer>> getCustomersStream() {
    return _db.collection('customers').snapshots().map((snapshot) => snapshot.docs.map((doc) => Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }
  
  Future<List<Customer>> getAllCustomersOnce() async {
    final snapshot = await _db.collection('customers').get();
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<List<Order>> getAllOrdersOnce() async {
    final snapshot = await _db.collection('orders').get();
    return snapshot.docs.map((doc) => Order.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }
  
  Stream<List<DailySale>> getDailySalesStream() {
    return _db.collection('daily_sales').orderBy('date', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => DailySale.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }
  
  Future<List<DailySale>> getDailySalesOnce() async {
    final snapshot = await _db.collection('daily_sales').orderBy('date', descending: false).get();
    return snapshot.docs.map((doc) => DailySale.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Stream<List<DailySyncMetadataModel>> getDailySyncMetadataStream() {
    return _db.collection('daily_sync_metadata').orderBy('date', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => DailySyncMetadataModel.fromFirestore(doc)).toList());
  }
}