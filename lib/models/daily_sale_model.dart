// lib/models/daily_sale_model.dart
class DailySale {
  final int? id; // Untuk SQLite primary key
  final DateTime date; // Tanggal aktual penjualan
  final int dayOfWeek; // Hari dalam angka (1-7), bisa di-derive dari date.weekday
  final int deliveryCount; // Tambahkan field untuk jumlah pengantaran
  final int quantity;
  final bool isSynced; // Status sinkronisasi ke Firestore
  final String? employeeUid; // UID karyawan yang menginput
  final String? firestoreId; // ID dokumen di Firestore

  DailySale({
    this.id,
    required this.date,
    required this.dayOfWeek,
    required this.deliveryCount, // Tambahkan ini
    required this.quantity,
    this.isSynced = false,
    this.employeeUid,
    this.firestoreId, // Tambahkan firestoreId
  });

  // Konversi ke Map untuk SQLite dan Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'day_of_week': dayOfWeek, // Menyimpan day_of_week ke SQLite
      'delivery_count': deliveryCount, // Tambahkan ini
      'quantity': quantity,
      'is_synced': isSynced ? 1 : 0,
      'employee_uid': employeeUid,
    };
  }

  // Membuat objek dari Map (dari SQLite dan Firestore)
  factory DailySale.fromMap(Map<String, dynamic> map) {
    return DailySale(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      dayOfWeek: map['day_of_week'] != null ? map['day_of_week'] as int : DateTime.parse(map['date'] as String).weekday, // Handle jika null dari DB lama
      deliveryCount: (map['delivery_count'] as num?)?.toInt() ?? 0, // Baca delivery_count, default 0 jika null (untuk data lama)
      quantity: (map['quantity'] as num).toInt(),
      isSynced: map['is_synced'] == 1,
      employeeUid: map['employee_uid'] as String?,
      // firestoreId tidak ada di SQLite, hanya di-set saat membaca dari Firestore
    );
  }

  // Metode copyWith untuk membuat instance baru dengan nilai yang diperbarui
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
}
