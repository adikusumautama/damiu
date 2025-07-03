// lib/services/sync_service.dart

import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_sale_model.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> syncAllUnsummarizedDeliveryLogs() async {
    print('Memulai sinkronisasi log pengantaran yang belum diringkas...');
    final unsyncedSales = await _dbHelper.getUnsyncedSales();
    if (unsyncedSales.isEmpty) {
      print('Tidak ada data penjualan lokal yang perlu disinkronkan.');
      return;
    }

    print('Menemukan ${unsyncedSales.length} data penjualan untuk disinkronkan.');

    for (var sale in unsyncedSales) {
      try {
        String? error = await _firestoreService.upsertDailySale(sale);
        if (error == null) {
          await _dbHelper.markSaleAsSynced(sale.id!);
          print('Penjualan tanggal ${sale.date} berhasil disinkronkan.');
        } else {
          print('Gagal sinkronisasi penjualan tanggal ${sale.date}: $error');
        }
      } catch (e) {
        print('Error saat sinkronisasi penjualan tanggal ${sale.date}: $e');
      }
    }
    print('Sinkronisasi log pengantaran selesai.');
  }

  Future<void> syncCustomers() async {
    print('Memulai sinkronisasi data pelanggan...');
    final unsyncedCustomers = await _dbHelper.getUnsyncedCustomers();
    if (unsyncedCustomers.isEmpty) {
      print('Tidak ada data pelanggan baru untuk disinkronkan.');
      return;
    }

    print('Menemukan ${unsyncedCustomers.length} pelanggan untuk disinkronkan.');

    for (Customer customer in unsyncedCustomers) {
      try {
        final error = await _firestoreService.upsertCustomer(customer);
        if (error == null) {
          await _dbHelper.markCustomerAsSynced(customer.id!);
          print('Pelanggan "${customer.name}" berhasil disinkronkan.');
        } else {
          print('Gagal sinkronisasi pelanggan "${customer.name}": $error');
        }
      } catch (e) {
        print('Error saat sinkronisasi pelanggan "${customer.name}": $e');
      }
    }
    print('Sinkronisasi data pelanggan selesai.');
  }
}