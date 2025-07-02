// lib/models/daily_stock_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStock {
  final String id; // YYYY-MM-DD
  final int initialStock;
  final int initialEmptyStock;
  final DateTime lastUpdated;
  final String? updatedByUid;

  DailyStock({
    required this.id,
    required this.initialStock,
    this.initialEmptyStock = 0,
    required this.lastUpdated,
    this.updatedByUid,
  });

  factory DailyStock.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DailyStock(
      id: doc.id,
      initialStock: (data['initial_stock'] as num?)?.toInt() ?? 0,
      initialEmptyStock: (data['initial_empty_stock'] as num?)?.toInt() ?? 0,
      lastUpdated: (data['last_updated'] as Timestamp).toDate(),
      updatedByUid: data['updated_by_uid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'initial_stock': initialStock,
      'initial_empty_stock': initialEmptyStock,
      'last_updated': Timestamp.fromDate(lastUpdated),
      'updated_by_uid': updatedByUid,
    };
  }

  // --- Methods for local DB (SQLite) ---

  Map<String, dynamic> toMapForDb() {
    return {
      'date': id, // Gunakan id (YYYY-MM-DD) sebagai primary key
      'initial_stock': initialStock,
      'initial_empty_stock': initialEmptyStock,
      'last_updated': lastUpdated.toIso8601String(),
      'updated_by_uid': updatedByUid,
    };
  }

  factory DailyStock.fromDbMap(Map<String, dynamic> map) {
    return DailyStock(
      id: map['date'] as String,
      initialStock: map['initial_stock'] as int,
      initialEmptyStock: (map['initial_empty_stock'] as int?) ?? 0,
      lastUpdated: DateTime.parse(map['last_updated'] as String),
      updatedByUid: map['updated_by_uid'] as String?,
    );
  }
}