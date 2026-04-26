import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'location_service.dart';

class SosService {
  static const String baseUrl =
      'https://lifeguardian-sos-backend.onrender.com';

  Future<void> triggerSos({
    required String userId,      // Firebase UID
    required String userName,
    required double latitude,
    required double longitude,
    required List<String> contacts,
  }) async {
    // 1️⃣ Send SOS to backend (WhatsApp message)
    final response = await http.post(
      Uri.parse('$baseUrl/api/sos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': userId,           // ✅ SEND UID
        'userName': userName,
        'latitude': latitude,
        'longitude': longitude,
        'contacts': contacts,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send SOS');
    }

    // 2️⃣ 🔥 UPDATE USER FLAG IN FIRESTORE
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'isLocationSharingEnabled': true,
    });
    // 3️⃣ Start live location tracking (Firebase Realtime DB)
    LocationService.startLiveTracking(
      uid: userId,
      role: "victim",
    );
  }
}
