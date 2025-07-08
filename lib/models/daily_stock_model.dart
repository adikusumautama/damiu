// lib/models/daily_stock_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStock {
  final String id; // Document ID (format YYYY-MM-DD)
  final int initialStock;
  final int initialEmptyStock;
  final int currentStock;
  final int totalSold; // <-- Tambahkan field ini
  final DateTime lastUpdated;
  final String updatedByUid;

  DailyStock({
    required this.id,
    required this.initialStock,
    required this.initialEmptyStock,
    required this.currentStock,
    required this.totalSold,
    required this.lastUpdated,
    required this.updatedByUid,
  });

  /// Membuat salinan objek dengan nilai yang bisa diperbarui.
  DailyStock copyWith({
    String? id,
    int? initialStock,
    int? initialEmptyStock,
    int? currentStock,
    int? totalSold,
    DateTime? lastUpdated,
    String? updatedByUid,
  }) {
    return DailyStock(
      id: id ?? this.id,
      initialStock: initialStock ?? this.initialStock,
      initialEmptyStock: initialEmptyStock ?? this.initialEmptyStock,
      currentStock: currentStock ?? this.currentStock,
      totalSold: totalSold ?? this.totalSold,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }

  // ======================================================================
  // PERUBAHAN UTAMA: Menggabungkan fromFirestore dan fromDbMap menjadi fromMap
  // ======================================================================
  
  /// Membuat objek DailyStock dari Map (baik dari Firestore maupun SQLite).
  factory DailyStock.fromMap(Map<String, dynamic> map, String docId) {
    return DailyStock(
      id: docId, // Menggunakan ID dokumen sebagai ID utama
      initialStock: (map['initial_stock'] as num?)?.toInt() ?? 0,
      initialEmptyStock: (map['initial_empty_stock'] as num?)?.toInt() ?? 0,
      currentStock: (map['current_stock'] as num?)?.toInt() ?? 0,
      totalSold: (map['total_sold'] as num?)?.toInt() ?? 0, // <-- Baca dari map
      // Menangani Timestamp dari Firestore atau String dari sumber lain
      lastUpdated: map['last_updated'] is Timestamp
          ? (map['last_updated'] as Timestamp).toDate()
          : (map['last_updated'] is String
              ? DateTime.tryParse(map['last_updated'] as String) ?? DateTime.now()
              : DateTime.now()),
      updatedByUid: map['updated_by_uid'] as String? ?? '',
    );
  }

  /// Konversi objek ke Map untuk disimpan di Firestore.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'initial_stock': initialStock,
      'initial_empty_stock': initialEmptyStock,
      'current_stock': currentStock,
      'total_sold': totalSold, // <-- Simpan ke Firestore
      'last_updated': Timestamp.fromDate(lastUpdated),
      'updated_by_uid': updatedByUid,
    };
  }

  /// Konversi objek ke Map untuk disimpan di database lokal (SQLite).
  Map<String, dynamic> toLocalDbMap() {
    return {
      // Di database lokal, 'id' adalah 'date'
      'date': id, 
      'initial_stock': initialStock,
      'initial_empty_stock': initialEmptyStock,
      // current_stock tidak disimpan di DB lokal karena nilainya dinamis
      'last_updated': lastUpdated.toIso8601String(),
      'updated_by_uid': updatedByUid,
    };
  }
}