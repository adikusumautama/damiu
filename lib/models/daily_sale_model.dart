// lib/models/daily_sale_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailySale {
  final int? id;
  final String? firestoreId;
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
    int? dayOfWeek,
    required this.deliveryCount,
    required this.quantity,
    this.isSynced = false,
    this.employeeUid,
  }) : dayOfWeek = dayOfWeek ?? date.weekday;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().substring(0, 10),
      'day_of_week': dayOfWeek,
      'delivery_count': deliveryCount,
      'quantity': quantity,
      'is_synced': isSynced ? 1 : 0,
      'employee_uid': employeeUid,
      'firestore_id': firestoreId,
    };
  }

  factory DailySale.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime saleDate;
    
    if (map['date'] is Timestamp) {
      saleDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      saleDate = DateTime.tryParse(map['date'] as String) ?? DateTime.now();
    } else {
      saleDate = DateTime.now();
    }

    return DailySale(
      id: map['id'] as int?,
      // Jika docId tersedia, gunakan itu
      firestoreId: docId ?? map['firestore_id'] as String?,
      date: saleDate,
      dayOfWeek: map['day_of_week'] as int? ?? saleDate.weekday,
      deliveryCount: (map['delivery_count'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      employeeUid: map['employee_uid'] as String?,
    );
  }
}