// lib/services/firestore_service.dart

import 'package:damiu/models/daily_sync_metadata_model.dart'; // Impor model baru
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/daily_sale_model.dart';

import 'package:intl/intl.dart'; // Impor intl
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Menambahkan data penjualan ke Firestore
  Future<String?> addDailySale(DailySale sale) async {
    try {
      // Firestore menggunakan Timestamp, konversi DateTime
      await _db.collection('daily_sales').add({
        'date': Timestamp.fromDate(sale.date), // Simpan sebagai Timestamp
        'day_of_week': sale.dayOfWeek, // Simpan dayOfWeek jika perlu
        'delivery_count': sale.deliveryCount, // Tambahkan ini
        'quantity': sale.quantity,
        'employee_uid': sale.employeeUid,
        // isSynced tidak perlu disimpan di Firestore, itu status lokal
        // synced_at bisa ditambahkan di sini jika perlu
        'synced_at': Timestamp.now(),
      });
      return null; // Sukses
    } catch (e) {
      print('Error adding daily sale to Firestore: $e');
      return e.toString(); // Pesan error
    }
  }

  // Mendapatkan semua data penjualan dari Firestore (untuk Admin)
  Stream<List<DailySale>> getDailySalesStream() {
    return _db.collection('daily_sales').orderBy('date', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // Konversi Timestamp kembali ke DateTime
        final data = doc.data();
        // Tambahkan documentId dari Firestore ke model DailySale
        return DailySale(
          // ID dari Firestore tidak perlu untuk model ini jika hanya membaca
          date: (data['date'] as Timestamp).toDate(),
          dayOfWeek: data['day_of_week'] != null ? data['day_of_week'] as int : (data['date'] as Timestamp).toDate().weekday,
          deliveryCount: (data['delivery_count'] as num?)?.toInt() ?? 0, // Baca dari Firestore, default 0 jika tidak ada
          quantity: data['quantity'] as int,
          employeeUid: data['employee_uid'] as String?,
          isSynced: true, // Data dari Firestore dianggap sudah disinkronkan
          firestoreId: doc.id, // Simpan ID dokumen Firestore
        );
      }).toList();
    });
  }

  // Anda mungkin juga butuh fungsi untuk mendapatkan data sekali (Future)
  Future<List<DailySale>> getDailySalesOnce() async {
     try {
       final snapshot = await _db.collection('daily_sales').orderBy('date', descending: false).get();
       return snapshot.docs.map((doc) {
         final data = doc.data();
         return DailySale(
           // Tambahkan documentId dari Firestore ke model DailySale
           date: (data['date'] as Timestamp).toDate(),
           deliveryCount: (data['delivery_count'] as num?)?.toInt() ?? 0, // Baca dari Firestore
           dayOfWeek: data['day_of_week'] != null ? data['day_of_week'] as int : (data['date'] as Timestamp).toDate().weekday,
           quantity: data['quantity'] as int,
           employeeUid: data['employee_uid'] as String?,
           isSynced: true,
           firestoreId: doc.id, // Simpan ID dokumen Firestore
         );
       }).toList();
     } catch (e) {
       print('Error getting daily sales once from Firestore: $e');
       return [];
     }
  }

  // Menghapus satu data penjualan dari Firestore berdasarkan ID dokumen
  Future<String?> deleteDailySale(String firestoreId) async {
    try {
      await _db.collection('daily_sales').doc(firestoreId).delete();
      return null; // Sukses
    } catch (e) {
      print('Error deleting daily sale from Firestore: $e');
      return e.toString(); // Pesan error
    }
  }

  // Menghapus semua data penjualan dari Firestore
  // PERHATIAN: Ini akan menghapus SEMUA dokumen di koleksi 'daily_sales'.
  // Untuk koleksi besar, pertimbangkan penghapusan batch atau dari backend.
  Future<String?> deleteAllDailySales() async {
     try {
       // Ambil semua dokumen (ini bisa memakan waktu dan biaya untuk koleksi besar)
       final snapshot = await _db.collection('daily_sales').get();
       final batch = _db.batch();

       for (var doc in snapshot.docs) {
         batch.delete(doc.reference);
       }

       await batch.commit();
       return null; // Sukses
     } catch (e) {
       print('Error deleting all daily sales from Firestore: $e');
       return e.toString(); // Pesan error
     }
  }

  // Mendapatkan jumlah data yang sudah disinkronkan (untuk tombol hapus sinkron lokal)
  Future<int> getSyncedSalesCount() async {
     try {
       final snapshot = await _db.collection('daily_sales').count().get();
       return snapshot.count ?? 0;
     } catch (e) {
       print('Error getting synced sales count from Firestore: $e');
       return 0; // Asumsikan 0 jika ada error
     }
  }

  // Upsert (update atau insert) data penjualan harian (hanya date, day_of_week, quantity) ke koleksi 'daily_sales'
  Future<String?> upsertDailySale(DailySale sale) async {
    try {
      // Format tanggal sebagai YYYY-MM-DD untuk digunakan sebagai ID dokumen
      String docId = DateFormat('yyyy-MM-dd').format(sale.date);
      await _db.collection('daily_sales').doc(docId).set({
        'date': Timestamp.fromDate(sale.date),
        'day_of_week': sale.dayOfWeek,
        'quantity': sale.quantity,
        // 'delivery_count', 'employee_uid', 'last_synced_at' tidak lagi disimpan di sini
      }, SetOptions(merge: true)); // merge: true akan update field jika dokumen ada, atau buat baru jika tidak
      return null; // Sukses
    } catch (e) {
      print('Error upserting daily sale to Firestore: $e');
      return e.toString(); // Pesan error
    }
  }

  // Upsert metadata sinkronisasi harian (delivery_count, employee_uid, last_synced_at) ke koleksi 'daily_sync_metadata'
  Future<String?> upsertDailySyncMetadata({
    required DateTime date,
    required int deliveryCount,
    required String? employeeUid,
  }) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_sync_metadata').doc(docId).set({
        'date': Timestamp.fromDate(date), // Opsional, karena sudah ada di ID
        'delivery_count': deliveryCount,
        'last_synced_by_uid': employeeUid,
        'last_synced_at': Timestamp.now(),
      }, SetOptions(merge: true));
      return null; // Sukses
    } catch (e) {
      print('Error upserting daily sync metadata to Firestore: $e');
      return e.toString(); // Pesan error
    }
  }

  // --- Operasi untuk DailySyncMetadata ---

  // Mendapatkan stream semua data metadata sinkronisasi
  Stream<List<DailySyncMetadataModel>> getDailySyncMetadataStream() {
    return _db.collection('daily_sync_metadata').orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DailySyncMetadataModel.fromFirestore(doc)).toList();
    });
  }

  // Memperbarui data metadata sinkronisasi
  Future<String?> updateDailySyncMetadata(String docId, Map<String, dynamic> data) async {
    try {
      // Tambahkan field last_synced_at yang diperbarui secara otomatis
      data['last_synced_at'] = Timestamp.now();
      await _db.collection('daily_sync_metadata').doc(docId).update(data);
      return null; // Sukses
    } catch (e) {
      print('Error updating daily sync metadata: $e');
      return e.toString();
    }
  }

  // Menghapus satu data metadata sinkronisasi
  Future<String?> deleteDailySyncMetadata(String docId) async {
    try {
      await _db.collection('daily_sync_metadata').doc(docId).delete();
      return null; // Sukses
    } catch (e) {
      print('Error deleting daily sync metadata: $e');
      return e.toString();
    }
  }

  // Menghapus semua data metadata sinkronisasi
  Future<String?> deleteAllDailySyncMetadata() async {
    try {
      final snapshot = await _db.collection('daily_sync_metadata').get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return null; // Sukses
    } catch (e) {
      print('Error deleting all daily sync metadata: $e');
      return e.toString();
    }
  }

  // --- Operasi untuk Stok Galon Harian ---

  /// Mendapatkan stream data stok untuk tanggal tertentu.
  /// Mengembalikan null jika dokumen tidak ada.
  Stream<DailyStock?> getDailyStockStream(DateTime date) {
    String docId = DateFormat('yyyy-MM-dd').format(date);
    return _db.collection('daily_stock_levels').doc(docId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return DailyStock.fromFirestore(snapshot);
      }
      return null;
    });
  }

  /// Mendapatkan stream data penjualan untuk tanggal tertentu.
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

  /// Mendapatkan data penjualan yang sudah disinkronkan untuk tanggal tertentu (Future).
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
        // Asumsi data dari Firestore selalu 'synced'
        return DailySale.fromMap(data..['is_synced'] = 1..['id'] = null);
      }).toList();
    } catch (e) {
      print('Error getting synced sales for date: $e');
      return [];
    }
  }

  /// Menetapkan atau memperbarui stok awal untuk tanggal tertentu.
  Future<String?> setInitialStock({
    required DateTime date,
    required int filledStock,
    required int emptyStock, // Tetap ada, tapi akan selalu diisi 0 dari app
    required String updatedByUid,
  }) async {
    try {
      String docId = DateFormat('yyyy-MM-dd').format(date);
      await _db.collection('daily_stock_levels').doc(docId).set({
        'initial_stock': filledStock,
        'initial_empty_stock': emptyStock, // Simpan sebagai 0
        'last_updated': Timestamp.now(),
        'updated_by_uid': updatedByUid,
      }, SetOptions(merge: true));
      return null; // Sukses
    } catch (e) {
      print('Error setting initial stock: $e');
      return e.toString();
    }
  }

  // --- Operasi untuk Pelanggan (Customer) ---

  /// Menyimpan atau memperbarui data pelanggan di Firestore.
  /// Menggunakan nama pelanggan sebagai ID dokumen untuk mencegah duplikasi.
  Future<String?> upsertCustomer(Customer customer) async {
    // Pengaman: Path dokumen Firestore tidak boleh kosong.
    if (customer.name.trim().isEmpty) {
      print('Error: Mencoba sinkronisasi pelanggan dengan nama kosong. Dilewati.');
      // Kembalikan null agar proses sinkronisasi tidak berhenti karena error ini.
      return null;
    }
    try {
      await _db.collection('customers').doc(customer.name).set(customer.toFirestore(), SetOptions(merge: true));
      return null; // Sukses
    } catch (e) {
      print('Error upserting customer to Firestore: $e');
      return e.toString();
    }
  }

}
