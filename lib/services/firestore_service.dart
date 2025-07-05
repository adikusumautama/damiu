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
      rethrow; // Lemparkan kembali error agar bisa ditangani oleh SyncService
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

  Future<String?> completeOrderTransaction(Order order) async {
    if (order.firestoreId == null) {
      return "Order ID tidak ditemukan.";
    }

    final orderRef = _db.collection('orders').doc(order.firestoreId!);
    final orderDate = order.createdAt ?? DateTime.now();
    final stockDocId = DateFormat('yyyy-MM-dd').format(orderDate);
    final stockRef = _db.collection('daily_stock_levels').doc(stockDocId);
    final saleDocId = DateFormat('yyyy-MM-dd').format(orderDate);
    final saleRef = _db.collection('daily_sales').doc(saleDocId);

    try {
      await _db.runTransaction((transaction) async {
        // 1. Dapatkan dokumen stok saat ini untuk memastikan keberadaannya.
        final stockSnapshot = await transaction.get(stockRef);
        if (!stockSnapshot.exists) {
          // Jika dokumen stok belum ada, buat dokumen stok default untuk tanggal pesanan
          transaction.set(stockRef, {
            'initial_stock': 0,
            'current_stock': 0,
            'last_updated': Timestamp.now(),
            'updated_by_uid': order.employeeUid ?? '-',
          }, SetOptions(merge: true));
        }
        
        // 2. Perbarui status pesanan
        transaction.update(orderRef, {
          'status': OrderStatus.delivered,
          'deliveredAt': Timestamp.now(),
        });

        // 3. Sesuaikan stok saat ini (berkurang)
        transaction.update(stockRef, {
          'current_stock': FieldValue.increment(-(order.gallonQuantity ?? 0)),
        });

        // 4. Catat penjualan (tambahkan kuantitas dan jumlah pengiriman)
        //    PASTIKAN SEMUA FIELD YANG DIPERLUKAN DIKIRIM KE 'daily_sales'
        transaction.set(saleRef, {
            'quantity': FieldValue.increment(order.gallonQuantity ?? 0), 
            'delivery_count': FieldValue.increment(1),
            // ---- PERBAIKAN UTAMA ADA DI SINI ----
            'date': Timestamp.fromDate(orderDate), // Pastikan field 'date' dikirim
            'day_of_week': orderDate.weekday,     // Pastikan field 'day_of_week' dikirim
            'employee_uid': order.employeeUid,
        }, SetOptions(merge: true));

      });
      return null; // Sukses
    } catch (e) {
      print('Error completing order transaction: $e');
      return e.toString();
    }
  }

  // --- Operasi untuk Galon Kembali ---
  
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

  Stream<int> getTodaysReturnedGallonsStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('returned_gallons_log')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return 0;
      }
      return snapshot.docs.fold<int>(0, (sum, doc) => sum + (doc.data()['quantity'] as int));
    });
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
      return null; // Sukses
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

  Future<String?> setInitialStock({
    required DateTime date,
    required int filledStock,
    required String updatedByUid,
  }) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_stock': filledStock,
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
        'current_stock': filledStock,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error setting initial stock: $e');
      return e.toString();
    }
  }

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
      print('Error adjusting current stock: $e');
      return e.toString();
    }
  }

  // --- Operasi untuk Penjualan Harian (Daily Sale) ---

  Future<String?> recordSale(int quantity, int deliveryCount, {required DateTime date}) async {
    final docId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db.collection('daily_sales').doc(docId);

    try {
      // Pastikan semua field dikirim untuk konsistensi
      await docRef.set({
        'date': Timestamp.fromDate(date),
        'day_of_week': date.weekday,
        'quantity': FieldValue.increment(quantity),
        'delivery_count': FieldValue.increment(deliveryCount),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error recording sale: $e');
      return e.toString();
    }
  }

  Stream<DailySale> getTodaysDailySaleStream() {
    final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _db.collection('daily_sales').doc(docId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return DailySale.fromMap(snapshot.data() as Map<String, dynamic>);
      }
      return DailySale(
        date: DateTime.now(),
        quantity: 0,
        deliveryCount: 0,
      );
    });
  }

  Stream<List<DailySale>> getDailySalesStream() {
    return _db
        .collection('daily_sales')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DailySale(
          date: (data['date'] as Timestamp).toDate(),
          dayOfWeek: data['day_of_week'] != null
              ? data['day_of_week'] as int
              : (data['date'] as Timestamp).toDate().weekday,
          deliveryCount: (data['delivery_count'] as num?)?.toInt() ?? 0,
          quantity: data['quantity'] as int,
          employeeUid: data['employee_uid'] as String?,
          isSynced: true,
          firestoreId: doc.id,
        );
      }).toList();
    });
  }
  
  Future<List<DailySale>> getDailySalesOnce() async {
    try {
      final snapshot = await _db
          .collection('daily_sales')
          .orderBy('date', descending: false)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DailySale(
          date: (data['date'] as Timestamp).toDate(),
          deliveryCount: (data['delivery_count'] as num?)?.toInt() ?? 0,
          dayOfWeek: data['day_of_week'] != null
              ? data['day_of_week'] as int
              : (data['date'] as Timestamp).toDate().weekday,
          quantity: data['quantity'] as int,
          employeeUid: data['employee_uid'] as String?,
          isSynced: true,
          firestoreId: doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error getting daily sales once from Firestore: $e');
      return [];
    }
  }
  
  Future<String?> upsertDailySale(DailySale sale) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(sale.date);
      // Pastikan semua field dikirim untuk konsistensi
      await _db.collection('daily_sales').doc(docId).set({
        'date': Timestamp.fromDate(sale.date),
        'day_of_week': sale.dayOfWeek,
        'quantity': sale.quantity,
        'delivery_count': sale.deliveryCount
      }, SetOptions(merge: true));
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
      print('Error deleting all daily sales from Firestore: $e');
      return e.toString();
    }
  }

  // --- Operasi untuk Metadata Sinkronisasi (Sync Metadata) ---

  Future<String?> upsertDailySyncMetadata({
    required DateTime date,
    required int deliveryCount,
    required String? employeeUid,
  }) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_sync_metadata').doc(docId).set({
        'date': Timestamp.fromDate(date),
        'delivery_count': deliveryCount,
        'last_synced_by_uid': employeeUid,
        'last_synced_at': Timestamp.now(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error upserting daily sync metadata to Firestore: $e');
      return e.toString();
    }
  }

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

  Future<String?> updateDailySyncMetadata(
      String docId, Map<String, dynamic> data) async {
    try {
      data['last_synced_at'] = Timestamp.now();
      await _db.collection('daily_sync_metadata').doc(docId).update(data);
      return null;
    } catch (e) {
      print('Error updating daily sync metadata: $e');
      return e.toString();
    }
  }

  Future<String?> deleteDailySyncMetadata(String docId) async {
    try {
      await _db.collection('daily_sync_metadata').doc(docId).delete();
      return null;
    } catch (e) {
      print('Error deleting daily sync metadata: $e');
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
      print('Error deleting all daily sync metadata: $e');
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
      return DailySale(
        date: (data['date'] as Timestamp).toDate(),
        dayOfWeek: data['day_of_week'] ?? 1,
        deliveryCount: data['delivery_count'] ?? 0,
        quantity: data['quantity'] ?? 0,
        isSynced: true,
        employeeUid: data['employee_uid'],
        firestoreId: snapshot.id,
      );
    });
  }
}