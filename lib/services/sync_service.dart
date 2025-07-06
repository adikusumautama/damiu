// lib/services/sync_service.dart

import 'dart:async';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  /// Mengirim data pelanggan baru atau yang diperbarui dari lokal ke Firestore.
  Future<void> syncCustomers() async {
    final unsyncedCustomers = await _dbHelper.getUnsyncedCustomers();
    if (unsyncedCustomers.isEmpty) return;

    for (Customer customer in unsyncedCustomers) {
      if (customer.name.trim().isEmpty) continue;
      try {
        if (customer.firestoreId == null || customer.firestoreId!.isEmpty) {
          final newId = await _firestoreService.addCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, newId);
        } else {
          await _firestoreService.updateCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, customer.firestoreId!);
        }
      } catch (e) {
        // Sebaiknya gunakan logger di sini
      }
    }
  }

  // ======================================================================
  // PERBAIKAN FINAL: Logika sinkronisasi pesanan yang lebih cerdas
  // ======================================================================
  /// Mengirim pesanan baru atau perubahan status pesanan dari lokal ke Firestore.
  Future<void> syncOrders() async {
    final unsyncedOrders = await _dbHelper.getUnsyncedOrders();
    if (unsyncedOrders.isEmpty) return;

    for (var order in unsyncedOrders) {
      try {
        // KASUS 1: Pesanan benar-benar baru (dibuat saat offline)
        if (order.firestoreId == null || order.firestoreId!.isEmpty) {
          final newFirestoreId = await _firestoreService.addOrder(order);
          await _dbHelper.markOrderAsSynced(order.id!, newFirestoreId);

        // KASUS 2: Pesanan sudah ada, tetapi statusnya diubah menjadi "Sudah Diantar" saat offline
        } else if (order.status == OrderStatus.delivered) {
          // Panggil transaksi penuh untuk memastikan stok & penjualan ter-update
          final error = await _firestoreService.completeOrderTransaction(order);
          if (error == null) {
            await _dbHelper.markOrderAsSynced(order.id!, order.firestoreId!);
          }

        // KASUS 3: Pesanan sudah ada, status diubah menjadi "Sedang Diantar" (atau status lain) saat offline
        } else {
          final error = await _firestoreService.updateOrderStatus(order.firestoreId!, order.status ?? '');
          if (error == null) {
            await _dbHelper.markOrderAsSynced(order.id!, order.firestoreId!);
          }
        }
      } catch (e) {
        // Sebaiknya gunakan logger
      }
    }
  }

  /// Mengirim data penjualan harian dari lokal ke Firestore.
  Future<void> syncDailySales() async {
    final unsyncedSales = await _dbHelper.getUnsyncedSales();
    if (unsyncedSales.isEmpty) return;
    for (final sale in unsyncedSales) {
      try {
        await _firestoreService.upsertDailySale(sale);
        if (sale.id != null) {
          await _dbHelper.markSaleAsSynced(sale.id!);
        }
      } catch (e) {
        // Sebaiknya gunakan logger
      }
    }
  }
  
  /// Menarik data terbaru dari Firestore ke database lokal.
  Future<void> pullAllDataFromFirestore() async {
    final customers = await _firestoreService.getAllCustomersOnce();
    for (final customer in customers) {
      await _dbHelper.upsertCustomer(customer);
    }
    final orders = await _firestoreService.getAllOrdersOnce();
    for (final order in orders) {
      await _dbHelper.upsertOrder(order);
    }
  }

  /// Listener real-time untuk memperbarui data lokal saat online.
  StreamSubscription listenToFirestoreChanges() {
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
    await syncCustomers();
    await syncOrders();
    await syncDailySales(); 
    await pullAllDataFromFirestore();
  }
}