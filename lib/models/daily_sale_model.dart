// lib/models/daily_sale_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailySale {
  final int? id;
  final DateTime date;
  final int dayOfWeek; 
  final int deliveryCount;
  final int quantity;
  final bool isSynced;
  final String? employeeUid;
  final String? firestoreId;

  DailySale({
    this.id,
    required this.date,
    int? dayOfWeek, 
    required this.deliveryCount,
    required this.quantity,
    this.isSynced = false,
    this.employeeUid,
    this.firestoreId,
  }) : dayOfWeek = dayOfWeek ?? date.weekday; 

  DailySale copyWith({
    int? id,
    DateTime? date,
    int? dayOfWeek,
    int? deliveryCount,
    int? quantity,
    bool? isSynced,
    String? employeeUid,
    String? firestoreId,
  }) {
    return DailySale(
      id: id ?? this.id,
      date: date ?? this.date,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      deliveryCount: deliveryCount ?? this.deliveryCount,
      quantity: quantity ?? this.quantity,
      isSynced: isSynced ?? this.isSynced,
      employeeUid: employeeUid ?? this.employeeUid,
      firestoreId: firestoreId ?? this.firestoreId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().substring(0, 10),
      'day_of_week': dayOfWeek,
      'delivery_count': deliveryCount,
      'quantity': quantity,
      'is_synced': isSynced ? 1 : 0,
      'employee_uid': employeeUid,
    };
  }

  // ---- PERBAIKAN UTAMA ADA DI FUNGSI INI ----
  factory DailySale.fromMap(Map<String, dynamic> map) {
    DateTime saleDate;
    
    // Cek apakah data berasal dari Firestore (Timestamp) atau lokal (String)
    if (map['date'] is Timestamp) {
      saleDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      saleDate = DateTime.parse(map['date'] as String);
    } else {
      // Fallback jika format tidak dikenali, meskipun seharusnya tidak terjadi
      saleDate = DateTime.now();
    }

    return DailySale(
      id: map['id'] as int?,
      date: saleDate,
      dayOfWeek: map['day_of_week'] as int? ?? saleDate.weekday,
      deliveryCount: (map['delivery_count'] as num?)?.toInt() ?? 0,
      quantity: map['quantity'] as int,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      employeeUid: map['employee_uid'] as String?,
      firestoreId: map['firestoreId'] as String?,
    );
  }
}