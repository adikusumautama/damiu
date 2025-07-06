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

  // --- FUNGSI CRUD UNTUK PESANAN ---

  Future<String?> addOrderAndUpsertCustomer(Order order) async {
    try {
      final querySnapshot = await _db
          .collection('customers')
          .where('name', isEqualTo: order.customerName)
          .limit(1)
          .get();

      WriteBatch batch = _db.batch();

      if (querySnapshot.docs.isEmpty && order.customerName != null && order.customerName!.isNotEmpty) {
        final newCustomerRef = _db.collection('customers').doc();
        final newCustomer = Customer(
          firestoreId: newCustomerRef.id,
          name: order.customerName!,
          address: order.address,
          phoneNumber: order.phoneNumber,
          createdAt: DateTime.now(),
          isSynced: true,
        );
        batch.set(newCustomerRef, newCustomer.toFirestore());
      }

      final newOrderRef = _db.collection('orders').doc();
      batch.set(newOrderRef, order.toMapForFirestore());
      
      await batch.commit();
      return newOrderRef.id;
    } catch (e) {
      return null;
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

  // --- FUNGSI CRUD UNTUK REKAP PENJUALAN HARIAN ---

  Stream<List<DailySale>> getDailySalesStream() {
    return _db
        .collection('daily_sales')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DailySale.fromMap(doc.data(), doc.id)).toList();
    });
  }

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

  // Sisa fungsi tidak ada perubahan
  Stream<List<Order>> getTodaysOrdersStream({DateTime? date}) {
    final now = date ?? DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _db.collection('orders').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)).where('createdAt', isLessThan: Timestamp.fromDate(endOfDay)).orderBy('createdAt', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Order.fromFirestore(doc.data(), doc.id)).toList();
    });
  }
  Future<List<Order>> getAllOrdersOnce() async {
    final snapshot = await _db.collection('orders').get();
    return snapshot.docs.map((doc) => Order.fromFirestore(doc.data(), doc.id)).toList();
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
}