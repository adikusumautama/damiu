// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
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
    DocumentReference docRef =
        await _db.collection('orders').add(order.toMapForFirestore());
    return docRef.id;
  }

  Future<String?> deleteOrder(String firestoreId) async {
    try {
      await _db.collection('orders').doc(firestoreId).delete();
      return null;
    } catch (e) {
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
      return e.toString();
    }
  }

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
        final stockSnapshot = await transaction.get(stockRef);
        
        if (!stockSnapshot.exists) {
          transaction.set(stockRef, {
            'initial_stock': 0,
            'current_stock': 0,
            'initial_empty_stock': 0,
            'last_updated': Timestamp.now(),
            'updated_by_uid': order.employeeUid ?? '-',
          }, SetOptions(merge: true));
        }
        
        transaction.update(orderRef, {
          'status': OrderStatus.delivered,
          'deliveredAt': Timestamp.now(),
        });

        transaction.update(stockRef, {
          'current_stock': FieldValue.increment(-(order.gallonQuantity ?? 0)),
          'last_updated': Timestamp.now(),
        });

        transaction.set(saleRef, {
            'quantity': FieldValue.increment(order.gallonQuantity ?? 0), 
            'delivery_count': FieldValue.increment(1),
            'date': Timestamp.fromDate(orderDate),
            'day_of_week': orderDate.weekday,
            'last_updated_by': order.employeeUid,
        }, SetOptions(merge: true));
      });
      return null;
    } catch (e) {
      return 'Gagal menyelesaikan transaksi pesanan: ${e.toString()}';
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
      return e.toString();
    }
  }

  // --- Operasi untuk Pelanggan (Customer) ---

  Future<String> addCustomer(Customer customer) async {
    final docRef = await _db.collection('customers').add(customer.toFirestore());
    return docRef.id;
  }

  Future<String?> updateCustomer(Customer customer) async {
    if (customer.firestoreId == null) {
      return "Customer Firestore ID tidak ditemukan untuk diupdate.";
    }
    try {
      await _db.collection('customers').doc(customer.firestoreId).set(customer.toFirestore(), SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Stream<List<Customer>> getCustomersStream() {
    return _db.collection('customers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Customer.fromFirestore(doc.data(), doc.id)).toList();
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
      // --- PERBAIKAN: Menggunakan fromMap ---
      return DailyStock.fromMap(doc.data()!, doc.id);
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
        // --- PERBAIKAN: Menggunakan fromMap ---
        return DailyStock.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  Future<String?> setInitialStock({required DateTime date, required int filledStock, required String updatedByUid}) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_stock': filledStock,
        'current_stock': filledStock,
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setInitialEmptyStock({required DateTime date, required int emptyStock, required String updatedByUid}) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_empty_stock': emptyStock,
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
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
      if (e is FirebaseException && e.code == 'not-found') {
        await docRef.set({
          'current_stock': quantityChange,
          'initial_stock': 0,
          'initial_empty_stock': 0,
          'last_updated': FieldValue.serverTimestamp(),
        });
        return null;
      }
      return e.toString();
    }
  }

  // --- Operasi untuk Penjualan Harian (Daily Sale) ---

  Stream<List<DailySale>> getDailySalesStream() {
    return _db
        .collection('daily_sales')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DailySale.fromMap(doc.data())).toList();
    });
  }
  
  Future<List<DailySale>> getDailySalesOnce() async {
    final snapshot = await _db.collection('daily_sales').orderBy('date', descending: false).get();
    return snapshot.docs.map((doc) => DailySale.fromMap(doc.data())).toList();
  }
  
  Future<String?> upsertDailySale(DailySale sale) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(sale.date);
      await _db.collection('daily_sales').doc(docId).set(sale.toMap(), SetOptions(merge: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteDailySale(String firestoreId) async {
    try {
      await _db.collection('daily_sales').doc(firestoreId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // --- PERBAIKAN: Fungsi ini ditambahkan kembali untuk admin screen ---
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

  // --- Operasi untuk Metadata Sinkronisasi ---

  Stream<List<DailySyncMetadataModel>> getDailySyncMetadataStream() {
    return _db.collection('daily_sync_metadata').orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DailySyncMetadataModel.fromFirestore(doc)).toList();
    });
  }

  Future<String?> updateDailySyncMetadata(String docId, Map<String, dynamic> data) async {
    try {
      data['last_synced_at'] = Timestamp.now();
      await _db.collection('daily_sync_metadata').doc(docId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // --- PERBAIKAN: Fungsi ini ditambahkan kembali untuk admin screen ---
  Future<String?> deleteDailySyncMetadata(String docId) async {
    try {
      await _db.collection('daily_sync_metadata').doc(docId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
  
  // --- PERBAIKAN: Fungsi ini ditambahkan kembali untuk admin screen ---
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

  // --- Stream Lainnya ---

  Stream<List<Order>> getOrdersStream() {
    return _db.collection('orders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Order.fromFirestore(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<DailyStock>> getStocksStream() {
    return _db.collection('daily_stock_levels').snapshots().map((snapshot) {
      // --- PERBAIKAN: Menggunakan fromMap ---
      return snapshot.docs.map((doc) => DailyStock.fromMap(doc.data(), doc.id)).toList();
    });
  }
  
  Stream<DailySale?> getDailySaleStreamByDate(DateTime date) {
    final docId = DateFormat('yyyy-MM-dd').format(date);
    return _db.collection('daily_sales').doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return DailySale.fromMap(snapshot.data()!);
    });
  }
}