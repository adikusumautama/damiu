// lib/models/customer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final int? id; // Kunci utama untuk database lokal (SQLite)
  final String? firestoreId; // ID unik dari dokumen di Firestore
  final String name;
  final String? address;
  final String? phoneNumber;
  final DateTime createdAt;
  final bool isSynced; // Penanda untuk sinkronisasi offline

  Customer({
    this.id,
    this.firestoreId,
    required this.name,
    this.address,
    this.phoneNumber,
    required this.createdAt,
    this.isSynced = false,
  });

  /// Membuat salinan objek Customer dengan nilai yang bisa diubah.
  /// Ini sangat berguna untuk memperbarui objek tanpa memodifikasi state aslinya.
  Customer copyWith({
    int? id,
    String? firestoreId,
    String? name,
    String? address,
    String? phoneNumber,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return Customer(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Konversi objek Customer ke Map untuk disimpan di database lokal (SQLite).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestore_id': firestoreId,
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(), // Simpan sebagai string ISO 8601
      'is_synced': isSynced ? 1 : 0, // SQLite tidak punya tipe boolean, gunakan integer
    };
  }

  /// Membuat objek Customer dari Map yang berasal dari database lokal (SQLite).
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      name: map['name'] as String? ?? '', // Fallback ke string kosong jika null
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      // Parsing tanggal dengan aman dari string
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  /// Konversi objek Customer ke Map untuk disimpan di Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'created_at': Timestamp.fromDate(createdAt), // Firestore menggunakan Timestamp
    };
  }

  /// Membuat objek Customer dari data snapshot Firestore.
  factory Customer.fromFirestore(Map<String, dynamic> map, String documentId) {
    return Customer(
      firestoreId: documentId, // ID dokumen langsung dari Firestore
      name: map['name'] as String? ?? '', // Fallback ke string kosong jika null
      address: map['address'] as String?,
      phoneNumber: map['phone_number'] as String?,
      // Konversi Timestamp dari Firestore ke DateTime
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSynced: true, // Data dari Firestore selalu dianggap sudah sinkron
    );
  }
}