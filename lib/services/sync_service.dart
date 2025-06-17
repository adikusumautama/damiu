// lib/services/sync_service.dart
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:intl/intl.dart'; // Impor intl

// Definisikan SyncResult jika belum ada
class SyncResult {
  final bool success;
  final String message;
  SyncResult({required this.success, required this.message});
}

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // ... (metode syncData yang sudah ada) ...
  Future<SyncResult> syncData() async {
    // ... implementasi syncData yang sudah ada ...
    // Contoh placeholder jika belum ada:
    try {
      List<DailySale> unsyncedSales = await _dbHelper.getUnsyncedSales();
      if (unsyncedSales.isEmpty) {
        return SyncResult(success: true, message: 'Tidak ada data penjualan ringkas lokal yang perlu disinkronkan.');
      }

      for (DailySale sale in unsyncedSales) {
        // Menggunakan upsertDailySale agar data di Firestore terupdate jika sudah ada untuk tanggal tersebut
        String? error = await _firestoreService.upsertDailySale(sale.copyWith(isSynced: true));
        if (error == null) {
          if (sale.id != null) {
            await _dbHelper.markSaleAsSynced(sale.id!);
          }
        } else {
          // Hentikan jika ada error dan laporkan
          return SyncResult(success: false, message: 'Gagal sinkronisasi penjualan tanggal ${DateFormat('yyyy-MM-dd').format(sale.date)}: $error');
        }
      }
      return SyncResult(success: true, message: 'Semua data penjualan ringkas lokal berhasil disinkronkan.');
    } catch (e) {
      return SyncResult(success: false, message: 'Error saat sinkronisasi: $e');
    }
  }


  // Mengganti nama metode dan logikanya untuk menyinkronkan semua log yang belum diringkas
  Future<SyncResult> syncAllUnsummarizedDeliveryLogs() async {
    final String? currentEmployeeUid = _authService.getCurrentUser()?.uid;
    if (currentEmployeeUid == null) {
      return SyncResult(success: false, message: 'Pengguna tidak login.');
    }

    try {
      // 1. Dapatkan semua log pengantaran dari database lokal
      final List<DeliveryLogItem> allLogs = await _dbHelper.getAllDeliveryLogs();
      // 2. Filter untuk mendapatkan hanya yang belum diringkas
      final List<DeliveryLogItem> unsummarizedLogs = allLogs.where((log) => !log.isSummarized).toList();

      if (unsummarizedLogs.isEmpty) {
        return SyncResult(success: true, message: 'Tidak ada data pengantaran baru untuk disinkronkan.');
      }

      // 3. Kelompokkan log yang belum diringkas berdasarkan tanggalnya
      final Map<DateTime, List<DeliveryLogItem>> logsByDate = {};
      for (var log in unsummarizedLogs) {
        final DateTime dateOnly = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
        if (logsByDate[dateOnly] == null) {
          logsByDate[dateOnly] = [];
        }
        logsByDate[dateOnly]!.add(log);
      }

      int datesProcessed = 0;
      int totalGallonsSyncedAllDates = 0;
      int totalDeliveriesSyncedAllDates = 0;

      // 4. Proses setiap grup tanggal
      for (var entry in logsByDate.entries) {
        final DateTime dateToProcess = entry.key;
        final List<DeliveryLogItem> logsForThisDate = entry.value;

        int totalGallonsForDate = 0;
        for (var log in logsForThisDate) {
          totalGallonsForDate += log.gallons;
        }
        final List<DeliveryLogItem> actualDeliveriesForDate = logsForThisDate.where((log) => !log.isNoDeliveryMarker).toList();
        int deliveryCountForDate = actualDeliveriesForDate.length;

        final DailySale dailySummary = DailySale(
          date: dateToProcess,
          dayOfWeek: dateToProcess.weekday,
          deliveryCount: deliveryCountForDate,
          quantity: totalGallonsForDate,
          employeeUid: currentEmployeeUid, // Karyawan yang melakukan operasi sinkronisasi ini
          isSynced: true, // Langsung ditandai sinkron karena dikirim ke Firestore
        );

        // a. Upsert ringkasan penjualan ke Firestore
        String? firestoreError = await _firestoreService.upsertDailySale(dailySummary);
        if (firestoreError != null) {
          return SyncResult(success: false, message: 'Gagal sinkronisasi penjualan tanggal ${DateFormat('yyyy-MM-dd').format(dateToProcess)} ke Firestore: $firestoreError');
        }

        // b. Upsert metadata sinkronisasi ke Firestore
        String? metadataError = await _firestoreService.upsertDailySyncMetadata(
          date: dateToProcess,
          deliveryCount: deliveryCountForDate,
          employeeUid: currentEmployeeUid,
        );
        if (metadataError != null) {
          return SyncResult(success: false, message: 'Gagal sinkronisasi metadata tanggal ${DateFormat('yyyy-MM-dd').format(dateToProcess)} ke Firestore: $metadataError');
        }

        // c. Upsert ringkasan ke tabel daily_sales lokal
        await _dbHelper.upsertDailySummary(dailySummary);

        // d. Tandai log pengantaran untuk tanggal ini sebagai sudah diringkas
        await _dbHelper.markAllDeliveryLogsAsSummarizedByDate(dateToProcess);

        datesProcessed++;
        totalGallonsSyncedAllDates += totalGallonsForDate;
        totalDeliveriesSyncedAllDates += deliveryCountForDate;
      }

      return SyncResult(success: true, message: 'Sinkronisasi berhasil untuk $datesProcessed hari. Total $totalDeliveriesSyncedAllDates pengantaran ($totalGallonsSyncedAllDates galon) telah diproses.');

    } catch (e) {
      print("Error during syncTodaysDeliverySummary: $e");
      return SyncResult(success: false, message: 'Terjadi kesalahan saat sinkronisasi: $e');
    }
  }
}
