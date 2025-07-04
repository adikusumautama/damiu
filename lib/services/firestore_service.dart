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

  Stream<List<Order>> getTodaysOrdersStream() {
    final now = DateTime.now();
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

  Future<String?> addOrder(Order order) async {
    try {
      await _db.collection('orders').add(order.toMapForFirestore());
      return null;
    } catch (e) {
      print('Error adding order to Firestore: $e');
      return e.toString();
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

  Future<String?> upsertCustomer(Customer customer) async {
    if (customer.name.trim().isEmpty) {
      print('Error: Mencoba sinkronisasi pelanggan dengan nama kosong. Dilewati.');
      return null;
    }
    try {
      await _db
          .collection('customers')
          .doc(customer.name)
          .set(customer.toFirestore(), SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error upserting customer to Firestore: $e');
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
  
  // --- Operasi untuk Stok (Stock) ---
  
  // --- FUNGSI BARU ---
  // Fungsi untuk mengambil data stok sekali (bukan stream)
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
    required int emptyStock,
    required String updatedByUid,
  }) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_stock': filledStock,
        'initial_empty_stock': emptyStock,
        'current_stock': filledStock, // Langsung set stok saat ini
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error setting initial stock: $e');
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

  Future<String?> recordSale(int quantity, int deliveryCount) async {
    final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _db.collection('daily_sales').doc(docId);

    try {
      await docRef.set({
        'date': Timestamp.now(),
        'day_of_week': DateTime.now().weekday,
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
      // Jika belum ada penjualan hari ini, kembalikan data kosong yang valid
      return DailySale(
        date: DateTime.now(),
        quantity: 0,
        deliveryCount: 0,
        // dayOfWeek akan dihitung otomatis oleh constructor
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
      await _db.collection('daily_sales').doc(docId).set({
        'date': Timestamp.fromDate(sale.date),
        'day_of_week': sale.dayOfWeek,
        'quantity': sale.quantity,
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
}