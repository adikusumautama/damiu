// lib/models/order_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final int? id; // Kunci utama untuk SQLite
  final String? firestoreId; // ID unik dari dokumen di Firestore
  final String customerName;
  final int gallonQuantity;
  final String? otherItems;
  final String? address;
  final String? phoneNumber;
  final String status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String employeeUid;
  final bool isSynced; // Penanda untuk sinkronisasi

  Order({
    this.id,
    this.firestoreId,
    required this.customerName,
    required this.gallonQuantity,
    this.otherItems,
    this.address,
    this.phoneNumber,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    required this.employeeUid,
    this.isSynced = false, // Defaultnya adalah false (belum sinkron)
  });

  // Konversi ke Map untuk database lokal (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestore_id': firestoreId,
      'customer_name': customerName,
      'gallon_quantity': gallonQuantity,
      'other_items': otherItems,
      'address': address,
      'phone_number': phoneNumber,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'employee_uid': employeeUid,
      'is_synced': isSynced ? 1 : 0, // Simpan sebagai integer (0 atau 1)
    };
  }

  // Membuat objek dari Map database lokal (SQLite)
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      customerName: map['customer_name'] as String,
      gallonQuantity: map['gallon_quantity'] as int,
      otherItems: map['other_items'] as String?,
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      deliveredAt: map['delivered_at'] != null
          ? DateTime.parse(map['delivered_at'] as String)
          : null,
      employeeUid: map['employee_uid'] as String,
      isSynced: (map['is_synced'] as int? ?? 0) == 1, // Baca dari integer
    );
  }

  // Konversi ke Map untuk Firestore
  Map<String, dynamic> toMapForFirestore() {
    return {
      'customerName': customerName,
      'gallonQuantity': gallonQuantity,
      'otherItems': otherItems,
      'address': address,
      'phoneNumber': phoneNumber,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'employeeUid': employeeUid,
    };
  }

  // Membuat objek dari data Firestore
  factory Order.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Order(
      firestoreId: documentId,
      customerName: data['customerName'] as String,
      gallonQuantity: data['gallonQuantity'] as int,
      otherItems: data['otherItems'] as String?,
      address: data['address'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      status: data['status'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
      employeeUid: data['employeeUid'] as String,
      isSynced: true, // Data dari Firestore selalu dianggap sudah sinkron
    );
  }
}

// Kelas helper untuk konsistensi status
class OrderStatus {
  static const String pending = 'Belum Diantar';
  static const String inDelivery = 'Sedang Dalam Pengantaran';
  static const String delivered = 'Sudah Diantar';
}