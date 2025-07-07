// lib/models/returned_gallon_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnedGallonLog {
  final String id; // Firestore document ID
  final int quantity;
  final DateTime createdAt;
  final String employeeUid;

  ReturnedGallonLog({
    required this.id,
    required this.quantity,
    required this.createdAt,
    required this.employeeUid,
  });

  factory ReturnedGallonLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReturnedGallonLog(
      id: doc.id,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      employeeUid: data['employeeUid'] as String? ?? 'Unknown',
    );
  }
}
