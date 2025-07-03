// lib/services/firestore_service.dart

import 'package:damiu/models/daily_sync_metadata_model.dart';
// --- PERHATIKAN PERUBAHAN DI BARIS INI ---
import 'package:cloud_firestore/cloud_firestore.dart' hide Order; 
// --- AKHIR PERUBAHAN ---
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ... (semua method yang sudah ada seperti getDailySalesStream, upsertDailySale, dll.)

  Future<String?> addDailySale(DailySale sale) async {
    try {
      await _db.collection('daily_sales').add({
        'date': Timestamp.fromDate(sale.date),
        'day_of_week': sale.dayOfWeek,
        'delivery_count': sale.deliveryCount,
        'quantity': sale.quantity,
        'employee_uid': sale.employeeUid,
        'synced_at': Timestamp.now(),
      });
      return null;
    } catch (e) {
      print('Error adding daily sale to Firestore: $e');
      return e.toString();
    }
  }

  Stream<List<DailySale>> getDailySalesStream() {
    return _db.collection('daily_sales').orderBy('date', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DailySale(
          date: (data['date'] as Timestamp).toDate(),
          dayOfWeek: data['day_of_week'] != null ? data['day_of_week'] as int : (data['date'] as Timestamp).toDate().weekday,
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
       final snapshot = await _db.collection('daily_sales').orderBy('date', descending: false).get();
       return snapshot.docs.map((doc) {
         final data = doc.data();
         return DailySale(
           date: (data['date'] as Timestamp).toDate(),
           deliveryCount: (data['delivery_count'] as num?)?.toInt() ?? 0,
           dayOfWeek: data['day_of_week'] != null ? data['day_of_week'] as int : (data['date'] as Timestamp).toDate().weekday,
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

  Future<int> getSyncedSalesCount() async {
     try {
       final snapshot = await _db.collection('daily_sales').count().get();
       return snapshot.count ?? 0;
     } catch (e) {
       print('Error getting synced sales count from Firestore: $e');
       return 0;
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

  Stream<DailyStock?> getDailyStockStream(DateTime date) {
    String docId = DateFormat('yyyy-MM-dd').format(date);
    return _db.collection('daily_stock_levels').doc(docId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return DailyStock.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Stream<List<DailySale>> getSalesForDateStream(DateTime date) {
    final DateTime startOfDay = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('daily_sales')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DailySale(
          date: (data['date'] as Timestamp).toDate(),
          dayOfWeek: data['day_of_week'] ?? (data['date'] as Timestamp).toDate().weekday,
          deliveryCount: (data['delivery_count'] as num?)?.toInt() ?? 0,
          quantity: data['quantity'] as int,
          employeeUid: data['employee_uid'] as String?,
          isSynced: true,
          firestoreId: doc.id,
        );
      }).toList();
    });
  }

  Future<List<DailySale>> getSyncedSalesForDateOnce(DateTime date) async {
    try {
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _db
          .collection('daily_sales')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DailySale.fromMap(data..['is_synced'] = 1..['id'] = null);
      }).toList();
    } catch (e) {
      print('Error getting synced sales for date: $e');
      return [];
    }
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
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error setting initial stock: $e');
      return e.toString();
    }
  }

  Future<String?> upsertCustomer(Customer customer) async {
    if (customer.name.trim().isEmpty) {
      print('Error: Mencoba sinkronisasi pelanggan dengan nama kosong. Dilewati.');
      return null;
    }
    try {
      await _db.collection('customers').doc(customer.name).set(customer.toFirestore(), SetOptions(merge: true));
      return null;
    } catch (e) {
      print('Error upserting customer to Firestore: $e');
      return e.toString();
    }
  }

  /// Menambahkan data pesanan baru ke Firestore.
  Future<String?> addOrder(Order order) async {
    try {
      // Kita akan membiarkan Firestore membuat ID unik untuk setiap pesanan.
      // Menggunakan toMapForFirestore untuk memastikan tipe data Timestamp benar.
      await _db.collection('orders').add(order.toMapForFirestore());
      return null; // Sukses
    } catch (e) {
      print('Error adding order to Firestore: $e');
      return e.toString(); // Mengembalikan pesan error jika gagal
    }
  }
}