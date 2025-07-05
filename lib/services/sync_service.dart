// lib/services/sync_service.dart

import 'dart.async';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/daily_stock_model.dart'; // Impor DailyStock
import 'package:damiu/services/database_helper.dart';
import 'package.damiu/services/firestore_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  /// Mengirim data pelanggan baru atau yang diperbarui dari lokal ke Firestore.
  Future<void> syncCustomers() async {
    print('[SyncService] Memeriksa data pelanggan untuk disinkronkan...');
    final unsyncedCustomers = await _dbHelper.getUnsyncedCustomers();
    if (unsyncedCustomers.isEmpty) {
      print('[SyncService] Tidak ada data pelanggan baru untuk disinkronkan.');
      return;
    }

    print('[SyncService] Menemukan ${unsyncedCustomers.length} pelanggan untuk disinkronkan.');
    for (Customer customer in unsyncedCustomers) {
      if (customer.name.trim().isEmpty) {
        print('[SyncService] Melewati pelanggan dengan nama kosong.');
        continue;
      }
      try {
        if (customer.firestoreId == null || customer.firestoreId!.isEmpty) {
          // Pelanggan baru, tambahkan ke Firestore
          final newId = await _firestoreService.addCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, newId);
          print('[SyncService] Pelanggan baru "${customer.name}" berhasil disinkronkan dengan ID: $newId');
        } else {
          // Pelanggan lama, perbarui data di Firestore
          await _firestoreService.updateCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, customer.firestoreId!);
          print('[SyncService] Pelanggan "${customer.name}" berhasil diupdate.');
        }
      } catch (e) {
        print('[SyncService] Gagal sinkronisasi pelanggan "${customer.name}": $e');
      }
    }
  }

  /// Mengirim pesanan baru atau perubahan status pesanan dari lokal ke Firestore.
  Future<void> syncOrders() async {
    print('[SyncService] Memeriksa data pesanan untuk disinkronkan...');
    final unsyncedOrders = await _dbHelper.getUnsyncedOrders();
    if (unsyncedOrders.isEmpty) {
      print('[SyncService] Tidak ada pesanan untuk disinkronkan.');
      return;
    }

    print('[SyncService] Menemukan ${unsyncedOrders.length} pesanan untuk disinkronkan.');

    for (var order in unsyncedOrders) {
      try {
        // Jika pesanan belum memiliki firestoreId, berarti ini pesanan baru.
        if (order.firestoreId == null || order.firestoreId!.isEmpty) {
          print('[SyncService] Mengirim pesanan baru #${order.id} ke Firestore...');
          final newFirestoreId = await _firestoreService.addOrder(order);

          // Tandai sebagai sudah sinkron di lokal
          await _dbHelper.markOrderAsSynced(order.id!, newFirestoreId);
          print('[SyncService] Pesanan baru #${order.id} berhasil disinkronkan.');

        } else {
          // Jika sudah ada firestoreId, berarti ini adalah pembaruan status.
          // Logika pembaruan stok dan penjualan sudah ditangani oleh `completeOrderTransaction`,
          // jadi kita hanya perlu memastikan statusnya ter-update di Firestore.
          print('[SyncService] Memperbarui status pesanan #${order.id} di Firestore...');
          final error = await _firestoreService.updateOrderStatus(
            order.firestoreId!, 
            order.status ?? '', 
            setDeliveredTime: order.status == OrderStatus.delivered
          );

           if (error == null) {
            // Jika sukses, tandai sebagai sudah sinkron di database lokal
            await _dbHelper.markOrderAsSynced(order.id!, order.firestoreId!);
            print('[SyncService] Status pesanan #${order.id} berhasil disinkronkan.');
          } else {
            print('[SyncService] Gagal sinkronisasi status pesanan #${order.id}: $error');
          }
        }
      } catch (e) {
        print('[SyncService] Error saat sinkronisasi pesanan #${order.id}: $e');
      }
    }
  }

  /// Mengirim data penjualan harian dari lokal ke Firestore.
  Future<void> syncDailySales() async {
    print('[SyncService] Memeriksa data penjualan harian lokal...');
    final unsyncedSales = await _dbHelper.getUnsyncedSales();

    if (unsyncedSales.isEmpty) {
      print('[SyncService] Tidak ada data penjualan harian untuk disinkronkan.');
      return;
    }

    print('[SyncService] Menemukan ${unsyncedSales.length} data penjualan untuk disinkronkan.');
    for (final sale in unsyncedSales) {
      try {
        await _firestoreService.upsertDailySale(sale);
        if (sale.id != null) {
          await _dbHelper.markSaleAsSynced(sale.id!);
          print('[SyncService] Data penjualan untuk tanggal ${sale.date.toIso8601String().substring(0, 10)} berhasil disinkronkan.');
        }
      } catch (e) {
        print('[SyncService] Gagal sinkronisasi data penjualan tanggal ${sale.date.toIso8601String().substring(0, 10)}: $e');
      }
    }
  }
  
  /// Menarik data terbaru dari Firestore ke database lokal.
  Future<void> pullAllDataFromFirestore() async {
    print('[SyncService] Menarik semua data dari Firestore ke lokal...');
    // Menarik data pelanggan
    final customers = await _firestoreService.getAllCustomersOnce();
    for (final customer in customers) {
      await _dbHelper.upsertCustomer(customer);
    }
    print('[SyncService] Sinkronisasi pull pelanggan selesai.');

    // Menarik data pesanan
    final orders = await _firestoreService.getAllOrdersOnce();
    for (final order in orders) {
      await _dbHelper.upsertOrder(order);
    }
    print('[SyncService] Sinkronisasi pull pesanan selesai.');
  }

  /// Listener real-time untuk memperbarui data lokal saat online.
  StreamSubscription listenToFirestoreChanges() {
    // Menggabungkan beberapa stream menjadi satu untuk didengarkan
    return Stream.fromFutures([
      _firestoreService.getCustomersStream().first,
      _firestoreService.getOrdersStream().first,
      _firestoreService.getStocksStream().first,
    ]).listen((_) async {
      // Setiap kali ada perubahan di salah satu koleksi, tarik semua data lagi.
      // Ini adalah pendekatan sederhana namun efektif untuk menjaga konsistensi.
      await pullAllDataFromFirestore();
      print('[SyncService] Data lokal diperbarui dari listener real-time.');
    });
  }

  /// Fungsi utama untuk sinkronisasi dua arah.
  Future<void> syncAllData() async {
    print('=== MEMULAI SINKRONISASI DUA ARAH ===');
    
    // 1. Kirim data lokal yang belum sinkron ke Firestore (Push)
    await syncCustomers();
    await syncOrders();
    await syncDailySales(); 
    
    // 2. Tarik data terbaru dari Firestore ke lokal (Pull)
    await pullAllDataFromFirestore();
    
    print('=== SINKRONISASI DUA ARAH SELESAI ===');
  }
}