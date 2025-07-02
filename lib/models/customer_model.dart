// lib/models/customer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final int? id; // Kunci utama untuk SQLite
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

  // Konversi ke Map untuk SQLite
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

  // Buat objek dari Map (dari SQLite)
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

  // Konversi ke Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      // 'id' lokal tidak disimpan, Firestore akan menggunakan namanya sebagai ID
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'created_at': createdAt, // Firestore menggunakan Timestamp
    };
  }

  // Buat objek dari Map (dari Firestore)
  factory Customer.fromFirestore(Map<String, dynamic> map, String documentId) {
    return Customer(
      id: null, // ID lokal tidak relevan saat membaca dari Firestore
      name: map['name'] as String,
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      isSynced: true, // Data dari Firestore selalu dianggap sudah sinkron
    );
  }
}