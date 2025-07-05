// lib/services/sync_service.dart

import 'dart:async';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package.damiu/services/firestore_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  /// Mengirim data pelanggan baru atau yang diperbarui ke Firestore.
  Future<void> syncCustomers() async {
    print('[SyncService] Memeriksa data pelanggan...');
    final unsyncedCustomers = await _dbHelper.getUnsyncedCustomers();
    if (unsyncedCustomers.isEmpty) {
      print('[SyncService] Tidak ada pelanggan baru untuk disinkronkan.');
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
          // Pelanggan baru
          final newId = await _firestoreService.addCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, newId);
          print('[SyncService] Pelanggan baru "${customer.name}" berhasil disinkronkan dengan ID: $newId');
        } else {
          // Update pelanggan yang sudah ada
          await _firestoreService.updateCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, customer.firestoreId!);
          print('[SyncService] Pelanggan "${customer.name}" berhasil diupdate.');
        }
      } catch (e) {
        print('[SyncService] Error saat sinkronisasi pelanggan "${customer.name}": $e');
      }
    }
  }

  /// Mengirim pesanan baru atau perubahan status pesanan ke Firestore.
  Future<void> syncOrders() async {
    print('[SyncService] Memeriksa data pesanan...');
    final unsyncedOrders = await _dbHelper.getUnsyncedOrders();
    if (unsyncedOrders.isEmpty) {
      print('[SyncService] Tidak ada pesanan untuk disinkronkan.');
      return;
    }

    print('[SyncService] Menemukan ${unsyncedOrders.length} pesanan/perubahan status untuk disinkronkan.');

    for (var order in unsyncedOrders) {
      try {
        String? newFirestoreId = order.firestoreId;
        String? error;

        if (newFirestoreId == null || newFirestoreId.isEmpty) {
          // Ini adalah pesanan baru, buat dokumen baru di Firestore.
          print('[SyncService] Mengirim pesanan baru #${order.id} ke Firestore...');
          newFirestoreId = await _firestoreService.addOrder(order);
        } else {
          // Ini adalah pesanan lama yang statusnya berubah.
          print('[SyncService] Memperbarui status pesanan #${order.id} di Firestore...');
          error = await _firestoreService.updateOrderStatus(
            newFirestoreId, 
            order.status ?? '', 
            setDeliveredTime: order.status == OrderStatus.delivered
          );
        }

        if (error == null && newFirestoreId != null) {
          // Jika sukses, tandai sebagai sudah sinkron di database lokal
          await _dbHelper.markOrderAsSynced(order.id!, newFirestoreId);
          print('[SyncService] Pesanan #${order.id} untuk ${order.customerName ?? "-"} berhasil disinkronkan.');
        } else if (error != null) {
           print('[SyncService] Gagal sinkronisasi pesanan #${order.id}: $error');
        }
      } catch (e) {
        print('[SyncService] Error saat sinkronisasi pesanan #${order.id}: $e');
      }
    }
    print('[SyncService] Sinkronisasi pesanan selesai.');
  }

  // --- FUNGSI BARU UNTUK SINKRONISASI PENJUALAN HARIAN ---
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
        // Gunakan upsert untuk membuat atau memperbarui dokumen di Firestore
        await _firestoreService.upsertDailySale(sale);
        // Setelah berhasil, tandai sebagai sudah sinkron di database lokal
        if (sale.id != null) {
          await _dbHelper.markSaleAsSynced(sale.id!);
          print('[SyncService] Data penjualan untuk tanggal ${sale.date.toIso8601String().substring(0, 10)} berhasil disinkronkan.');
        }
      } catch (e) {
        print('[SyncService] Gagal sinkronisasi data penjualan tanggal ${sale.date.toIso8601String().substring(0, 10)}: $e');
      }
    }
  }
  
  /// Menarik data pelanggan terbaru dari Firestore ke database lokal
  Future<void> pullCustomersFromFirestore() async {
    print('[SyncService] Menarik data pelanggan dari Firestore ke lokal...');
    final customers = await _firestoreService.getAllCustomersOnce();
    for (final customer in customers) {
      await _dbHelper.upsertCustomer(customer);
    }
    print('[SyncService] Sinkronisasi pull pelanggan selesai.');
  }

  /// Menarik data pesanan terbaru dari Firestore ke database lokal
  Future<void> pullOrdersFromFirestore() async {
    print('[SyncService] Menarik data pesanan dari Firestore ke lokal...');
    final orders = await _firestoreService.getAllOrdersOnce();
    for (final order in orders) {
      await _dbHelper.upsertOrder(order);
    }
    print('[SyncService] Sinkronisasi pull pesanan selesai.');
  }

  /// Listener real-time pelanggan Firestore ke lokal (panggil saat online)
  StreamSubscription listenCustomersRealtimeToLocal() {
    return _firestoreService.getCustomersStream().listen((customers) async {
      for (final customer in customers) {
        await _dbHelper.upsertCustomer(customer);
      }
    });
  }

  /// Listener real-time pesanan Firestore ke lokal (panggil saat online)
  StreamSubscription listenOrdersRealtimeToLocal() {
    return _firestoreService.getOrdersStream().listen((orders) async {
      for (final order in orders) {
        await _dbHelper.upsertOrder(order);
      }
    });
  }

  /// Listener real-time stok Firestore ke lokal (panggil saat online)
  StreamSubscription listenStocksRealtimeToLocal() {
    return _firestoreService.getStocksStream().listen((stocks) async {
      for (final stock in stocks) {
        await _dbHelper.upsertDailyStock(stock);
      }
    });
  }

  /// Sinkronisasi dua arah: push lokal ke Firestore, lalu pull Firestore ke lokal
  Future<void> syncAllData() async {
    print('=== MEMULAI SINKRONISASI SEMUA DATA (TWO-WAY) ===');
    await syncCustomers();
    await syncOrders();
    // ---- PEMANGGILAN FUNGSI BARU DITAMBAHKAN DI SINI ----
    await syncDailySales(); 
    await pullCustomersFromFirestore();
    await pullOrdersFromFirestore();
    print('=== SINKRONISASI SEMUA DATA SELESAI ===');
  }
  
  // Fungsi syncAllUnsummarizedDeliveryLogs mungkin tidak relevan lagi jika penjualan dicatat
  // langsung dari status pesanan. Bisa dihapus atau disesuaikan jika masih ada fungsi lain.
  Future<void> syncAllUnsummarizedDeliveryLogs() async {
    // Untuk saat ini, fungsi ini bisa dikosongkan jika tidak dipakai
    // agar tidak membingungkan.
    print('[SyncService] syncAllUnsummarizedDeliveryLogs (saat ini tidak ada aksi).');
  }
}