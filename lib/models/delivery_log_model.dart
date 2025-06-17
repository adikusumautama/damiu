// lib/models/delivery_log_model.dart
class DeliveryLogItem {
  final int? id;
  final DateTime timestamp; // Tanggal dan Waktu pengantaran
  final int gallons;
  final String employeeUid;
  bool isSummarized; // Status apakah log ini sudah termasuk dalam ringkasan harian
  final bool isNoDeliveryMarker; // Penanda jika ini adalah entri "tidak ada pengantaran"

  DeliveryLogItem({
    this.id,
    required this.timestamp,
    required this.gallons,
    required this.employeeUid,
    this.isSummarized = false,
    this.isNoDeliveryMarker = false, // Default ke false
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gallons': gallons,
      'employee_uid': employeeUid,
      'is_summarized': isSummarized ? 1 : 0,
      'is_no_delivery_marker': isNoDeliveryMarker ? 1 : 0,
    };
  }

  factory DeliveryLogItem.fromMap(Map<String, dynamic> map) {
    return DeliveryLogItem(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      gallons: (map['gallons'] as num).toInt(), // Handle double dari DB
      employeeUid: map['employee_uid'] as String,
      isSummarized: map['is_summarized'] == 1,
      isNoDeliveryMarker: map['is_no_delivery_marker'] == 1,
    );
  }
}