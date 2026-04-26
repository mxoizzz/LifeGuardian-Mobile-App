import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Position? userPosition;
  bool _isInitialLoad = true;
  bool _showAllGlobal = false;
  List<Map<String, dynamic>> _weatherAlerts = [];

  // ── Design Tokens ──────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF5F7FA);
  static const Color _surface = Colors.white;
  static const Color _accent  = Color(0xFF00C896);
  static const Color _textPri = Color(0xFF0D1B2A);
  static const Color _textSec = Color(0xFF7A8FA6);
  static const Color _danger  = Color(0xFFFF4D6A);
  static const Color _border  = Color(0xFFE8EDF3);
  static const Color _weather = Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _getLocation();
    if (userPosition != null) {
      await _fetchOpenMeteoAlerts();
    } else {
      if (mounted) setState(() => _isInitialLoad = false);
    }
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => userPosition = position);
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  Future<void> _fetchOpenMeteoAlerts() async {
    if (userPosition == null) return;
    final lat = userPosition!.latitude;
    final lon = userPosition!.longitude;

    // Standardized URL used across the app
    final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=weather_code,precipitation,wind_gusts_10m&current_weather=true&timezone=auto&forecast_days=1';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // SYNC POINT: Always pull current temp from the 'current_weather' object
        final double currentTemp = data['current_weather']['temperature'];

        final hourly = data['hourly'];
        final List<dynamic> times = hourly['time'];
        final String nowIso = DateFormat("yyyy-MM-ddTHH:00").format(DateTime.now());
        int currentIndex = times.indexOf(nowIso);
        if (currentIndex == -1) currentIndex = 0;

        List<Map<String, dynamic>> tempAlerts = [];

        // 1. Current Status (Matches Home Screen logic)
        tempAlerts.add({
          "title": "Current Status",
          "desc": "It's $currentTemp°C in your area. No severe threats detected.",
          "icon": Icons.wb_cloudy_rounded,
          "color": _weather,
          "isWarning": false,
        });

        // 2. Future Forecast Warnings
        for (int i = currentIndex; i < currentIndex + 4 && i < times.length; i++) {
          int code = hourly['weather_code'][i];
          double precip = (hourly['precipitation'][i] as num).toDouble();
          double wind = (hourly['wind_gusts_10m'][i] as num).toDouble();

          if (code >= 95) {
            tempAlerts.insert(0, {
              "title": "Thunderstorm Alert",
              "desc": "Severe storm activity predicted within 3 hours.",
              "icon": Icons.thunderstorm_rounded,
              "color": Colors.deepPurple,
              "isWarning": true,
            });
            break;
          } else if (precip > 0.5) {
            tempAlerts.insert(0, {
              "title": "Rain Warning",
              "desc": "Significant rainfall expected in your area soon.",
              "icon": Icons.umbrella_rounded,
              "color": _weather,
              "isWarning": true,
            });
            break;
          }
        }

        if (mounted) {
          setState(() {
            _weatherAlerts = tempAlerts;
            _isInitialLoad = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isInitialLoad = false);
    }
  }

  // --- Metadata Utilities ---

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return "Recently";
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return "Recently";
    }
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('MMM d').format(date);
  }

  String _getDistanceString(double? lat, double? lng) {
    if (userPosition == null || lat == null || lng == null) return "Location unknown";
    double meters = Geolocator.distanceBetween(userPosition!.latitude, userPosition!.longitude, lat, lng);
    return meters < 1000 ? "${meters.toStringAsFixed(0)}m away" : "${(meters / 1000).toStringAsFixed(1)}km away";
  }

  double? _parseCoord(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Nearby Alerts",
            style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(_showAllGlobal ? Icons.public : Icons.location_on, color: _accent),
            onPressed: () => setState(() => _showAllGlobal = !_showAllGlobal),
          )
        ],
      ),
      body: _isInitialLoad
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _buildUnifiedAlerts(),
    );
  }

  Widget _buildUnifiedAlerts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("crime_reports")
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final nearbyCrimeAlerts = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          double? lat = _parseCoord(data["lat"]);
          double? lng = _parseCoord(data["lng"]);
          if (lat == null || lng == null) return false;
          if (_showAllGlobal) return true;
          return Geolocator.distanceBetween(userPosition!.latitude, userPosition!.longitude, lat, lng) <= 10000;
        }).toList();

        if (nearbyCrimeAlerts.isEmpty && _weatherAlerts.isEmpty) return _buildEmptyState();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_weatherAlerts.isNotEmpty) ...[
              _buildSectionHeader("Local Weather"),
              const SizedBox(height: 12),
              ..._weatherAlerts.map((w) => _buildWeatherCard(w)).toList(),
              const SizedBox(height: 24),
            ],
            if (nearbyCrimeAlerts.isNotEmpty) ...[
              _buildSectionHeader("Security Alerts"),
              const SizedBox(height: 12),
              ...nearbyCrimeAlerts.map((doc) => _buildAlertCard(doc.data() as Map<String, dynamic>)).toList(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(),
        style: TextStyle(color: _textSec.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2));
  }

  Widget _buildWeatherCard(Map<String, dynamic> weather) {
    bool isWarning = weather['isWarning'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? weather['color'].withOpacity(0.08) : _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWarning ? weather['color'].withOpacity(0.2) : _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: weather['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(weather['icon'], color: weather['color'], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(weather['title'], style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(weather['desc'], style: const TextStyle(color: _textSec, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> data) {
    final double? lat = _parseCoord(data["lat"]);
    final double? lng = _parseCoord(data["lng"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _danger.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.gpp_maybe_rounded, color: _danger, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data["type"] ?? "Incident", style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(_getTimeAgo(data["timestamp"]), style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 3),
                Text("Within your area • ${_getDistanceString(lat, lng)}",
                    style: TextStyle(color: _textSec.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(data["description"] ?? "Suspicious activity reported.",
                    style: const TextStyle(color: _textSec, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_moon_outlined, size: 64, color: _textSec.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text("All Clear", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
          const Text("No active alerts within 10 km.", style: TextStyle(color: _textSec, fontSize: 14)),
        ],
      ),
    );
  }
}