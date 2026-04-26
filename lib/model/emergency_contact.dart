import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final bool verified;
  final DateTime? createdAt;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.verified,
    this.createdAt,
  });

  factory EmergencyContact.fromMap(String id, Map<String, dynamic> data) {
    return EmergencyContact(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      verified: data['verified'] ?? false, // 👈 default false
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'verified': verified, // 👈 added
      'createdAt': createdAt ?? DateTime.now(),
    };
  }
}
