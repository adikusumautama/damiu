// lib/models/customer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final int? id;
  final String name;
  final String? address;
  final String? phoneNumber;
  final DateTime createdAt;
  final bool isSynced;

  Customer({
    this.id,
    required this.name,
    this.address,
    this.phoneNumber,
    required this.createdAt,
    this.isSynced = false,
  });

  // --- TAMBAHKAN METHOD BARU DI SINI ---
  Customer copyWith({
    int? id,
    String? name,
    String? address,
    String? phoneNumber,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
  // --- AKHIR METHOD BARU ---

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'created_at': createdAt,
    };
  }

  factory Customer.fromFirestore(Map<String, dynamic> map, String documentId) {
    return Customer(
      id: null,
      name: map['name'] as String,
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      isSynced: true,
    );
  }
}