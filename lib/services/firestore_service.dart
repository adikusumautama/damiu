// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/daily_sync_metadata_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Operasi untuk Pesanan (Order) ---

  Stream<List<Order>> getTodaysOrdersStream({DateTime? date}) {
    final now = date ?? DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Order.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<String> addOrder(Order order) async {
    try {
      DocumentReference docRef =
          await _db.collection('orders').add(order.toMapForFirestore());
      return docRef.id;
    } catch (e) {
      print('Error adding order to Firestore: $e');
      rethrow;
    }
  }

  Future<String?> deleteOrder(String firestoreId) async {
    try {
      await _db.collection('orders').doc(firestoreId).delete();
      return null;
    } catch (e) {
      print('Error deleting order from Firestore: $e');
      return e.toString();
    }
  }

  Future<String?> updateOrderStatus(String firestoreId, String status, {bool setDeliveredTime = false}) async {
    try {
      Map<String, dynamic> dataToUpdate = {'status': status};
      if (setDeliveredTime) {
        dataToUpdate['deliveredAt'] = Timestamp.now();
      }
      await _db.collection('orders').doc(firestoreId).update(dataToUpdate);
      return null;
    } catch (e) {
      print('Error updating order status in Firestore: $e');
      return e.toString();
    }
  }

  // ======================================================================
  // PEROMBAKAN UTAMA: FUNGSI INI SEKARANG MENJADI SUMBER KEBENARAN TUNGGAL
  // ======================================================================
  /// Menyelesaikan pesanan dalam satu transaksi atomik untuk memastikan konsistensi data.
  /// Fungsi ini akan:
  /// 1. Mengubah status pesanan menjadi 'Sudah Diantar'.
  /// 2. Mengurangi stok galon isi (`current_stock`).
  /// 3. Menambah/memperbarui rekap penjualan harian (`daily_sales`).
  Future<String?> completeOrderTransaction(Order order) async {
    if (order.firestoreId == null) {
      return "Order ID tidak ditemukan.";
    }

    final orderRef = _db.collection('orders').doc(order.firestoreId!);
    final orderDate = order.createdAt ?? DateTime.now();
    final docId = DateFormat('yyyy-MM-dd').format(orderDate);
    final stockRef = _db.collection('daily_stock_levels').doc(docId);
    final saleRef = _db.collection('daily_sales').doc(docId);

    try {
      await _db.runTransaction((transaction) async {
        // 1. Dapatkan dokumen stok saat ini.
        final stockSnapshot = await transaction.get(stockRef);
        
        // Jika dokumen stok belum ada, buat dokumen stok default untuk hari itu.
        // Ini mencegah error jika ini adalah transaksi pertama pada hari tersebut.
        if (!stockSnapshot.exists) {
          transaction.set(stockRef, {
            'initial_stock': 0,
            'current_stock': 0,
            'initial_empty_stock': 0,
            'last_updated': Timestamp.now(),
            'updated_by_uid': order.employeeUid ?? '-',
          }, SetOptions(merge: true));
        }
        
        // 2. Perbarui status pesanan.
        transaction.update(orderRef, {
          'status': OrderStatus.delivered,
          'deliveredAt': Timestamp.now(),
        });

        // 3. Kurangi stok galon isi saat ini menggunakan FieldValue.increment.
        transaction.update(stockRef, {
          'current_stock': FieldValue.increment(-(order.gallonQuantity ?? 0)),
          'last_updated': Timestamp.now(),
        });

        // 4. Catat atau perbarui rekap penjualan harian.
        // `SetOptions(merge: true)` akan membuat dokumen jika belum ada, atau memperbarui jika sudah ada.
        transaction.set(saleRef, {
            'quantity': FieldValue.increment(order.gallonQuantity ?? 0), 
            'delivery_count': FieldValue.increment(1),
            'date': Timestamp.fromDate(orderDate), // Pastikan field tanggal dikirim
            'day_of_week': orderDate.weekday,     // Pastikan field hari dikirim
            'last_updated_by': order.employeeUid,
        }, SetOptions(merge: true));

      });
      return null; // Sukses
    } catch (e) {
      print('Error completing order transaction: $e');
      return 'Gagal menyelesaikan transaksi pesanan: ${e.toString()}';
    }
  }

  // --- Operasi untuk Galon Kembali ---
  
  // FUNGSI INI MASIH DIPERLUKAN UNTUK MELACAK LOG GALON KOSONG SECARA SPESIFIK
  Future<String?> addReturnedGallonLog({required int quantity, required String employeeUid}) async {
    try {
      await _db.collection('returned_gallons_log').add({
        'quantity': quantity,
        'createdAt': Timestamp.now(),
        'employeeUid': employeeUid,
      });
      return null;
    } catch (e) {
      print('Error adding returned gallon log: $e');
      return e.toString();
    }
  }

  // --- Operasi untuk Pelanggan (Customer) ---

  Future<String> addCustomer(Customer customer) async {
    try {
      final docRef = await _db
          .collection('customers')
          .add(customer.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error adding customer to Firestore: $e');
      rethrow;
    }
  }

  Future<String?> updateCustomer(Customer customer) async {
    if (customer.firestoreId == null) {
      return "Customer Firestore ID tidak ditemukan untuk diupdate.";
    }
    try {
      await _db
          .collection('customers')
          .doc(customer.firestoreId)
          .set(customer.toFirestore(), SetOptions(merge: true));
      return null; 
    } catch (e) {
      print('Error updating customer to Firestore: $e');
      return e.toString();
    }
  }

  Stream<List<Customer>> getCustomersStream() {
    return _db.collection('customers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Customer.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }
  
  Future<List<Customer>> getAllCustomersOnce() async {
    final snapshot = await _db.collection('customers').get();
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc.data(), doc.id)).toList();
  }

  Future<List<Order>> getAllOrdersOnce() async {
    final snapshot = await _db.collection('orders').get();
    return snapshot.docs.map((doc) => Order.fromFirestore(doc.data(), doc.id)).toList();
  }

  // --- Operasi untuk Stok (Stock) ---
  
  Future<DailyStock?> getDailyStockOnce(DateTime date) async {
    String docId = DateFormat('yyyy-MM-dd').format(date);
    final doc = await _db.collection('daily_stock_levels').doc(docId).get();
    if (doc.exists) {
      return DailyStock.fromFirestore(doc);
    }
    return null;
  }

  Stream<DailyStock?> getDailyStockStream(DateTime date) {
    String docId = DateFormat('yyyy-MM-dd').format(date);
    return _db
        .collection('daily_stock_levels')
        .doc(docId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return DailyStock.fromFirestore(snapshot);
      }
      return null;
    });
  }

  /// Menetapkan atau memperbarui stok awal untuk suatu hari.
  /// Ini menimpa nilai `initial_stock` dan `current_stock`.
  Future<String?> setInitialStock({
    required DateTime date,
    required int filledStock,
    required String updatedByUid,
  }) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_stock': filledStock,
        'current_stock': filledStock, // Saat set awal, stok saat ini = stok awal
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error setting initial stock: $e');
      return e.toString();
    }
  }

  /// Menetapkan atau memperbarui stok galon kosong untuk suatu hari.
  Future<String?> setInitialEmptyStock({
    required DateTime date,
    required int emptyStock,
    required String updatedByUid,
  }) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_empty_stock': emptyStock,
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error setting initial empty stock: $e');
      return e.toString();
    }
  }

  /// Menambah atau mengurangi stok galon isi saat ini.
  /// Gunakan angka positif untuk menambah, negatif untuk mengurangi.
  Future<String?> adjustCurrentStock(int quantityChange) async {
    final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _db.collection('daily_stock_levels').doc(docId);

    try {
      await docRef.update({
        'current_stock': FieldValue.increment(quantityChange),
        'last_updated': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      // Jika dokumen belum ada, buat dulu
      if (e is FirebaseException && e.code == 'not-found') {
        await docRef.set({
          'current_stock': quantityChange,
          'initial_stock': 0,
          'initial_empty_stock': 0,
          'last_updated': FieldValue.serverTimestamp(),
        });
        return null;
      }
      print('Error adjusting current stock: $e');
      return e.toString();
    }
  }

  // --- Operasi untuk Penjualan Harian (Daily Sale) ---

  // Fungsi recordSale tidak lagi diperlukan karena sudah ditangani oleh completeOrderTransaction
  // Future<String?> recordSale(...)

  Stream<List<DailySale>> getDailySalesStream() {
    return _db
        .collection('daily_sales')
        .orderBy('date', descending: true) // Urutkan dari yang terbaru
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DailySale.fromMap(data); // Factory sudah menangani konversi
      }).toList();
    });
  }
  
  Future<List<DailySale>> getDailySalesOnce() async {
    try {
      final snapshot = await _db
          .collection('daily_sales')
          .orderBy('date', descending: false)
          .get();
      return snapshot.docs.map((doc) => DailySale.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting daily sales once from Firestore: $e');
      return [];
    }
  }
  
  // (Fungsi lain seperti delete, upsert, dll, bisa dibiarkan seperti adanya untuk keperluan admin)
  
  Future<String?> upsertDailySale(DailySale sale) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(sale.date);
      await _db.collection('daily_sales').doc(docId).set(
        sale.toMap(), // Menggunakan toMap dari model
        SetOptions(merge: true)
      );
      return null;
    } catch (e) {
      print('Error upserting daily sale to Firestore: $e');
      return e.toString();
    }
  }

  Future<String?> deleteDailySale(String firestoreId) async {
    try {
      await _db.collection('daily_sales').doc(firestoreId).delete();
      return null;
    } catch (e) {
      print('Error deleting daily sale from Firestore: $e');
      return e.toString();
    }
  }

  // --- Sisa fungsi lainnya ---
  // (Fungsi untuk Sync Metadata dan stream lainnya bisa dibiarkan seperti sedia kala)
  Stream<List<DailySyncMetadataModel>> getDailySyncMetadataStream() {
    return _db
        .collection('daily_sync_metadata')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DailySyncMetadataModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<String?> updateDailySyncMetadata(String docId, Map<String, dynamic> data) async {
    try {
      data['last_synced_at'] = Timestamp.now();
      await _db.collection('daily_sync_metadata').doc(docId).update(data);
      return null;
    } catch (e) {
      print('Error updating daily sync metadata: $e');
      return e.toString();
    }
  }

  Stream<List<Order>> getOrdersStream() {
    return _db.collection('orders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Order.fromFirestore(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<DailyStock>> getStocksStream() {
    return _db.collection('daily_stock_levels').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DailyStock.fromFirestore(doc)).toList();
    });
  }
  
  Stream<DailySale?> getDailySaleStreamByDate(DateTime date) {
    final docId = DateFormat('yyyy-MM-dd').format(date);
    return _db.collection('daily_sales').doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final data = snapshot.data()!;
      return DailySale.fromMap(data);
    });
  }
}