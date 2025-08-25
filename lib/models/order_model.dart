import 'package:cloud_firestore/cloud_firestore.dart';

class OrderStatus {
  static const String pending = 'Belum Diantar';
  static const String inDelivery = 'Sedang Diantar';
  static const String delivered = 'Sudah Diantar';
}

class Order {
  final int? id; 
  final String? firestoreId; 
  final String? customerName;
  final int? gallonQuantity;
  final String? otherItems;
  final String? address;
  final String? phoneNumber;
  final String? status;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final String? employeeUid;
  final bool isSynced;

  Order({
    this.id,
    this.firestoreId,
    this.customerName,
    this.gallonQuantity,
    this.otherItems,
    this.address,
    this.phoneNumber,
    this.status,
    this.createdAt,
    this.deliveredAt,
    this.employeeUid,
    this.isSynced = false,
  });

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
      'created_at': createdAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'employee_uid': employeeUid,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      customerName: map['customer_name'] as String?,
      gallonQuantity: map['gallon_quantity'] as int?,
      otherItems: map['other_items'] as String?,
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      status: map['status'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      deliveredAt: map['delivered_at'] != null ? DateTime.tryParse(map['delivered_at'] as String) : null,
      employeeUid: map['employee_uid'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMapForFirestore() {
    return {
      'customerName': customerName ?? 'Tanpa Nama',
      'gallonQuantity': gallonQuantity ?? 0,
      'otherItems': otherItems,
      'address': address,
      'phoneNumber': phoneNumber,
      'status': status ?? OrderStatus.pending,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'employeeUid': employeeUid,
    };
  }

  factory Order.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Order(
      firestoreId: documentId,
      customerName: data['customerName'] as String?,
      gallonQuantity: (data['gallonQuantity'] as num?)?.toInt(),
      otherItems: data['otherItems'] as String?,
      address: data['address'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      status: data['status'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      employeeUid: data['employeeUid'] as String?,
      isSynced: true,
    );
  }
}