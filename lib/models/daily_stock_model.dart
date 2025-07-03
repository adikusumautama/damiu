// lib/models/daily_stock_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStock {
  final String id; // yyyy-MM-dd
  final int initialStock;
  final int initialEmptyStock;
  final int currentStock; // PROPERTI BARU
  final DateTime lastUpdated;
  final String updatedByUid;

  DailyStock({
    required this.id,
    required this.initialStock,
    required this.initialEmptyStock,
    required this.currentStock, // TAMBAHKAN DI KONSTRUKTOR
    required this.lastUpdated,
    required this.updatedByUid,
  });

  factory DailyStock.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DailyStock(
      id: doc.id,
      initialStock: data['initial_stock'] ?? 0,
      initialEmptyStock: data['initial_empty_stock'] ?? 0,
      currentStock: data['current_stock'] ?? 0, // AMBIL DARI FIRESTORE
      lastUpdated: (data['last_updated'] as Timestamp).toDate(),
      updatedByUid: data['updated_by_uid'] ?? '',
    );
  }

  Map<String, dynamic> toMapForDb() {
    return {
      'date': id,
      'initial_stock': initialStock,
      'initial_empty_stock': initialEmptyStock,
      'last_updated': lastUpdated.toIso8601String(),
      'updated_by_uid': updatedByUid,
    };
  }

  factory DailyStock.fromDbMap(Map<String, dynamic> map) {
    return DailyStock(
      id: map['date'],
      initialStock: map['initial_stock'],
      initialEmptyStock: map['initial_empty_stock'],
      currentStock: 0, // Tidak disimpan di DB lokal, hanya di Firestore
      lastUpdated: DateTime.parse(map['last_updated']),
      updatedByUid: map['updated_by_uid'],
    );
  }
}