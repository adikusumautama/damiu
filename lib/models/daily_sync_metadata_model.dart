import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DailySyncMetadataModel {
  final String id; 
  final DateTime date;
  final int deliveryCount;
  final String? lastSyncedByUid;
  final DateTime lastSyncedAt;

  DailySyncMetadataModel({
    required this.id,
    required this.date,
    required this.deliveryCount,
    this.lastSyncedByUid,
    required this.lastSyncedAt,
  });

  factory DailySyncMetadataModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    DateTime parsedDate;
    try {
      parsedDate = DateFormat('yyyy-MM-dd').parse(doc.id);
    } catch (e) {
      parsedDate = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      print("Warning: Could not parse date from doc.id '${doc.id}', using fallback. Error: $e");
    }

    return DailySyncMetadataModel(
      id: doc.id,
      date: parsedDate,
      deliveryCount: (data['delivery_count'] as num?)?.toInt() ?? 0,
      lastSyncedByUid: data['last_synced_by_uid'] as String?,
      lastSyncedAt: (data['last_synced_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'delivery_count': deliveryCount,
      'last_synced_by_uid': lastSyncedByUid,
      'last_synced_at': Timestamp.fromDate(lastSyncedAt),
    };
  }
}
