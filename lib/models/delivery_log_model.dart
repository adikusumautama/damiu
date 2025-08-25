// lib/models/delivery_log_model.dart
class DeliveryLogItem {
  final int? id;
  final DateTime timestamp; 
  final int gallons;
  final int emptyGallonsReturned;
  final String employeeUid;
  bool isSummarized; 
  final bool isNoDeliveryMarker; 

  DeliveryLogItem({
    this.id,
    required this.timestamp,
    required this.gallons,
    this.emptyGallonsReturned = 0,
    required this.employeeUid,
    this.isSummarized = false,
    this.isNoDeliveryMarker = false, 
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gallons': gallons,
      'empty_gallons_returned': emptyGallonsReturned,
      'employee_uid': employeeUid,
      'is_summarized': isSummarized ? 1 : 0,
      'is_no_delivery_marker': isNoDeliveryMarker ? 1 : 0,
    };
  }

  factory DeliveryLogItem.fromMap(Map<String, dynamic> map) {
    return DeliveryLogItem(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      gallons: (map['gallons'] as num).toInt(), 
      emptyGallonsReturned: (map['empty_gallons_returned'] as num?)?.toInt() ?? 0,
      employeeUid: map['employee_uid'] as String,
      isSummarized: map['is_summarized'] == 1,
      isNoDeliveryMarker: map['is_no_delivery_marker'] == 1,
    );
  }
}