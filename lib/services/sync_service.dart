// lib/services/sync_service.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  /// FUNGSI UTAMA: Menjalankan semua tugas sinkronisasi yang tertunda.
  Future<void> syncAllData() async {
    print('=== MEMULAI SINKRONISASI SEMUA DATA ===');
    await syncCustomers();
    await syncOrders();
    // Jika ada data lain yang perlu disinkronkan di masa depan, tambahkan di sini.
    print('=== SINKRONISASI SEMUA DATA SELESAI ===');
  }

  /// Mengirim data pelanggan baru ke Firestore.
  Future<void> syncCustomers() async {
    print('[SyncService] Memeriksa data pelanggan...');
    final unsyncedCustomers = await _dbHelper.getUnsyncedCustomers();
    if (unsyncedCustomers.isEmpty) {
      print('[SyncService] Tidak ada pelanggan baru untuk disinkronkan.');
      return;
    }

    print('[SyncService] Menemukan ${unsyncedCustomers.length} pelanggan untuk disinkronkan.');
    for (Customer customer in unsyncedCustomers) {
      try {
        final error = await _firestoreService.upsertCustomer(customer);
        if (error == null) {
          await _dbHelper.markCustomerAsSynced(customer.id!);
          print('[SyncService] Pelanggan "${customer.name}" berhasil disinkronkan.');
        } else {
          print('[SyncService] Gagal sinkronisasi pelanggan "${customer.name}": $error');
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
  
  // Fungsi syncAllUnsummarizedDeliveryLogs mungkin tidak relevan lagi jika penjualan dicatat
  // langsung dari status pesanan. Bisa dihapus atau disesuaikan jika masih ada fungsi lain.
  Future<void> syncAllUnsummarizedDeliveryLogs() async {
    // Untuk saat ini, fungsi ini bisa dikosongkan jika tidak dipakai
    // agar tidak membingungkan.
    print('[SyncService] syncAllUnsummarizedDeliveryLogs (saat ini tidak ada aksi).');
  }
}