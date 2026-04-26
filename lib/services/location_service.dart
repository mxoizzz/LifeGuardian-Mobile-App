import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class LocationService {
  static StreamSubscription<Position>? _positionSubscription;

  /// Get single current location (unchanged)
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  /// 🟢 START LIVE TRACKING
  static void startLiveTracking({
    required String uid,
    String role = "victim",
  }) {
    _positionSubscription?.cancel();

    final ref = FirebaseDatabase.instance.ref("live_tracking/$uid");

    // Mark sharing ON
    ref.update({
      "isSharing": true,
      "role": role,
    });

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      ref.update({
        "lat": position.latitude,
        "lng": position.longitude,
        "updatedAt": ServerValue.timestamp,
      });
    });
  }

  /// ⛔ STOP LIVE TRACKING (PAUSE ONLY)
  static Future<void> stopLiveTracking(String uid) async {
    // 1️⃣ Stop GPS stream
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // 2️⃣ Update status ONLY (do not delete node)
    await FirebaseDatabase.instance
        .ref("live_tracking/$uid")
        .update({
      "isSharing": false,
      "updatedAt": ServerValue.timestamp,
    });
  }
}
