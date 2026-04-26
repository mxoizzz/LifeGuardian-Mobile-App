import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String title;
  final String type; // 'sos', 'scan', 'share'
  final DateTime timestamp;

  ActivityModel({
    required this.title,
    required this.type,
    required this.timestamp,
  });

  // Convert for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(), // Let Firebase handle the time
    };
  }

  // Create from Firestore
  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      title: map['title'] ?? '',
      type: map['type'] ?? 'scan',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}