// lib/services/sync_service.dart

import 'dart:async'; // PERBAIKAN: Menggunakan 'dart:async'
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart'; // PERBAIKAN: Menggunakan 'package:'

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  /// Mengirim data pelanggan baru atau yang diperbarui dari lokal ke Firestore.
  Future<void> syncCustomers() async {
    final unsyncedCustomers = await _dbHelper.getUnsyncedCustomers();
    if (unsyncedCustomers.isEmpty) {
      return;
    }

    for (Customer customer in unsyncedCustomers) {
      if (customer.name.trim().isEmpty) {
        continue;
      }
      try {
        if (customer.firestoreId == null || customer.firestoreId!.isEmpty) {
          final newId = await _firestoreService.addCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, newId);
        } else {
          await _firestoreService.updateCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, customer.firestoreId!);
        }
      } catch (e) {
        // Disarankan menggunakan logger di sini
      }
    }
  }

  /// Mengirim pesanan baru atau perubahan status pesanan dari lokal ke Firestore.
  Future<void> syncOrders() async {
    final unsyncedOrders = await _dbHelper.getUnsyncedOrders();
    if (unsyncedOrders.isEmpty) {
      return;
    }

    for (var order in unsyncedOrders) {
      try {
        if (order.firestoreId == null || order.firestoreId!.isEmpty) {
          final newFirestoreId = await _firestoreService.addOrder(order);
          await _dbHelper.markOrderAsSynced(order.id!, newFirestoreId);
        } else {
          final error = await _firestoreService.updateOrderStatus(
            order.firestoreId!, 
            order.status ?? '', 
            setDeliveredTime: order.status == OrderStatus.delivered
          );
          if (error == null) {
            await _dbHelper.markOrderAsSynced(order.id!, order.firestoreId!);
          }
        }
      } catch (e) {
        // Disarankan menggunakan logger
      }
    }
  }

  /// Mengirim data penjualan harian dari lokal ke Firestore.
  Future<void> syncDailySales() async {
    final unsyncedSales = await _dbHelper.getUnsyncedSales();

    if (unsyncedSales.isEmpty) {
      return;
    }

    for (final sale in unsyncedSales) {
      try {
        await _firestoreService.upsertDailySale(sale);
        if (sale.id != null) {
          await _dbHelper.markSaleAsSynced(sale.id!);
        }
      } catch (e) {
        // Disarankan menggunakan logger
      }
    }
  }
  
  /// Menarik data terbaru dari Firestore ke database lokal.
  Future<void> pullAllDataFromFirestore() async {
    // Menarik data pelanggan
    final customers = await _firestoreService.getAllCustomersOnce();
    for (final customer in customers) {
      await _dbHelper.upsertCustomer(customer);
    }

    // Menarik data pesanan
    final orders = await _firestoreService.getAllOrdersOnce();
    for (final order in orders) {
      await _dbHelper.upsertOrder(order);
    }
  }

  /// Listener real-time untuk memperbarui data lokal saat online.
  StreamSubscription listenToFirestoreChanges() {
    // Menggabungkan beberapa stream menjadi satu untuk didengarkan
    return Stream.fromFutures([
      _firestoreService.getCustomersStream().first,
      _firestoreService.getOrdersStream().first,
      _firestoreService.getStocksStream().first,
    ]).listen((_) async {
      await pullAllDataFromFirestore();
    });
  }

  /// Fungsi utama untuk sinkronisasi dua arah.
  Future<void> syncAllData() async {
    // 1. Kirim data lokal yang belum sinkron ke Firestore (Push)
    await syncCustomers();
    await syncOrders();
    await syncDailySales(); 
    
    // 2. Tarik data terbaru dari Firestore ke lokal (Pull)
    await pullAllDataFromFirestore();
  }
}