// lib/models/daily_sale_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailySale {
  final int? id; // ID untuk database lokal (SQLite)
  final String? firestoreId; // ID dokumen dari Firestore (format YYYY-MM-DD)
  final DateTime date;
  final int dayOfWeek; 
  final int deliveryCount;
  final int quantity;
  final bool isSynced;
  final String? employeeUid;

  DailySale({
    this.id,
    this.firestoreId,
    required this.date,
    int? dayOfWeek, // Dibuat opsional karena bisa dihitung dari 'date'
    required this.deliveryCount,
    required this.quantity,
    this.isSynced = false,
    this.employeeUid,
  }) : dayOfWeek = dayOfWeek ?? date.weekday; // Jika dayOfWeek null, hitung dari tanggal

  /// Membuat salinan objek dengan nilai yang diperbarui.
  DailySale copyWith({
    int? id,
    String? firestoreId,
    DateTime? date,
    int? dayOfWeek,
    int? deliveryCount,
    int? quantity,
    bool? isSynced,
    String? employeeUid,
  }) {
    return DailySale(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      date: date ?? this.date,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      deliveryCount: deliveryCount ?? this.deliveryCount,
      quantity: quantity ?? this.quantity,
      isSynced: isSynced ?? this.isSynced,
      employeeUid: employeeUid ?? this.employeeUid,
    );
  }

  /// Konversi ke Map untuk database lokal (SQLite).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // Simpan tanggal sebagai String dengan format YYYY-MM-DD di SQLite
      'date': date.toIso8601String().substring(0, 10),
      'day_of_week': dayOfWeek,
      'delivery_count': deliveryCount,
      'quantity': quantity,
      'is_synced': isSynced ? 1 : 0,
      'employee_uid': employeeUid,
      'firestore_id': firestoreId, // Pastikan firestoreId juga disimpan lokal
    };
  }

  // ======================================================================
  // PERUBAHAN UTAMA: Logika parsing tanggal yang lebih solid dan aman.
  // ======================================================================
  /// Membuat objek DailySale dari Map (baik dari Firestore maupun SQLite).
  factory DailySale.fromMap(Map<String, dynamic> map) {
    DateTime saleDate;
    
    // Cek jika sumber data adalah Firestore (menggunakan Timestamp)
    if (map['date'] is Timestamp) {
      saleDate = (map['date'] as Timestamp).toDate();
    } 
    // Cek jika sumber data adalah SQLite (menggunakan String)
    else if (map['date'] is String) {
      try {
        saleDate = DateTime.parse(map['date'] as String);
      } catch (e) {
        // Fallback jika format string tidak valid
        print("Warning: Gagal parse tanggal dari string '${map['date']}'. Menggunakan waktu sekarang.");
        saleDate = DateTime.now();
      }
    } else {
      // Fallback jika tipe data tidak dikenali
      print("Warning: Tipe data tanggal tidak dikenali. Menggunakan waktu sekarang.");
      saleDate = DateTime.now();
    }

    return DailySale(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      date: saleDate,
      dayOfWeek: map['day_of_week'] as int? ?? saleDate.weekday,
      deliveryCount: (map['delivery_count'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0, // Dibuat lebih aman
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      employeeUid: map['employee_uid'] as String?,
    );
  }
}