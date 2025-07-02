// lib/models/order_model.dart

class Order {
  final int? id; // Kunci utama untuk SQLite
  final String customerName;
  final int gallonQuantity;
  final String? otherItems; // Teks sederhana untuk item lain, contoh: "Gas 3kg: 1"
  final String? address;
  final String? phoneNumber;
  final String status; // 'Belum Diantar', 'Sedang Dalam Pengantaran', 'Sudah Diantar'
  final DateTime createdAt;
  final DateTime? deliveredAt; // Waktu saat pengantaran selesai
  final String employeeUid;

  Order({
    this.id,
    required this.customerName,
    required this.gallonQuantity,
    this.otherItems,
    this.address,
    this.phoneNumber,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    required this.employeeUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'gallon_quantity': gallonQuantity,
      'other_items': otherItems,
      'address': address,
      'phone_number': phoneNumber,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'employee_uid': employeeUid,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String,
      gallonQuantity: map['gallon_quantity'] as int,
      otherItems: map['other_items'] as String?,
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at'] as String) : null,
      employeeUid: map['employee_uid'] as String,
    );
  }
}

// Kelas helper untuk konsistensi status
class OrderStatus {
  static const String pending = 'Belum Diantar';
  static const String inDelivery = 'Sedang Dalam Pengantaran';
  static const String delivered = 'Sudah Diantar';
}