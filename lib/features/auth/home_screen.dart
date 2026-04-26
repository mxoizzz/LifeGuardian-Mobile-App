import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lifeguardianplus/features/auth/alert_screen.dart';
import 'package:lifeguardianplus/model/activity_model.dart';

import '../../services/user_service.dart';
import '../../services/location_service.dart';
import '../../services/sos_service.dart';
import '../../model/user_model.dart';
import '../map/live_map_screen.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class WeatherData {
  final double temp;
  final bool isDay;

  WeatherData({required this.temp, required this.isDay});

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current_weather'];
    return WeatherData(
      temp: (current['temperature'] as num).toDouble(),
      isDay: current['is_day'] == 1,
    );
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _sosController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _sosScaleAnimation;

  bool _loading = false;
  bool _isSOSActive = false;

  String _currentCity = "Locating...";
  String _safetyStatus = "Scanning Area...";
  String _mostFrequentCrime = "None"; // Added for frequency logic
  Color _statusColor = const Color(0xFF7A8FA6);

  Position? userPosition;

  final SosService _sosService = SosService();
  StreamSubscription<DatabaseEvent>? _sosSubscription;

  static const Color _bg         = Color(0xFFF5F7FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _accent     = Color(0xFF00C896);
  static const Color _danger     = Color(0xFFFF4D6A);
  static const Color _textPri    = Color(0xFF0D1B2A);
  static const Color _textSec    = Color(0xFF7A8FA6);
  static const Color _border     = Color(0xFFE8EDF3);
  static const Color _amber      = Color(0xFFFFB830);

  String tipText = "Avoid isolated roads after dark. Share your route.";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _sosController = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _sosScaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));

    _listenSOSState();
    _startLocationIfAllowed();
    _initGeoLocation();
  }

  Future<WeatherData> fetchWeather() async {
    double lat = userPosition?.latitude ?? 19.27;
    double lon = userPosition?.longitude ?? 76.77;
    final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&timezone=auto';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return WeatherData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load weather');
      }
    } catch (e) {
      return WeatherData(temp: 0.0, isDay: true);
    }
  }

  Future<void> _initGeoLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _currentCity = "Permission Denied");
          return;
        }
      }

      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        setState(() => userPosition = lastPos);
        await _processLocationUpdate(lastPos);
      }

      Position currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() => userPosition = currentPos);
      await _processLocationUpdate(currentPos);
    } catch (e) {
      debugPrint("GeoLocation Error: $e");
    }
  }

  Future<void> _processLocationUpdate(Position pos) async {
    String areaName = "Lat: ${pos.latitude.toStringAsFixed(2)}";
    int foundReports = 0;
    Map<String, int> crimeCounts = {}; // Frequency map

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        areaName = placemarks.first.locality ?? placemarks.first.subAdministrativeArea ?? areaName;
      }
    } catch (_) {}

    try {
      final snapshot = await FirebaseFirestore.instance.collection("crime_reports").get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        double? lat = _parseCoord(data['lat']);
        double? lng = _parseCoord(data['lng']);
        String type = data['type'] ?? data['category'] ?? "General";

        if (lat != null && lng != null) {
          double distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
          if (distance < 5000) {
            foundReports++;
            crimeCounts[type] = (crimeCounts[type] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint("Safety Scan Error: $e");
    }

    String topCrime = "None";
    if (crimeCounts.isNotEmpty) {
      topCrime = crimeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    if (mounted) {
      setState(() {
        _currentCity = areaName;
        _mostFrequentCrime = topCrime;
        _updateSafetyUI(foundReports);
      });
      _logActivity(title: "Area scan completed in $areaName", type: "scan");
    }
  }

  Future<void> _logActivity({required String title, required String type}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final activity = ActivityModel(title: title, type: type, timestamp: DateTime.now());
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('activities').add(activity.toMap());
    } catch (e) { debugPrint("Activity Log Error: $e"); }
  }

  double? _parseCoord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _updateSafetyUI(int reportCount) {
    if (reportCount == 0) {
      _safetyStatus = "All Clear";
      _statusColor = _accent;
    } else if (reportCount <= 4) {
      _safetyStatus = "Caution: $reportCount Reports Nearby";
      _statusColor = _amber;
    } else {
      _safetyStatus = "High Risk: $reportCount Reports";
      _statusColor = _danger;
    }
  }

  void _listenSOSState() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _sosSubscription = FirebaseDatabase.instance.ref("live_tracking/$uid/isSOS").onValue.listen((event) {
      final value = event.snapshot.value;
      if (mounted) setState(() => _isSOSActive = value == true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose(); _fadeController.dispose(); _sosController.dispose();
    _sosSubscription?.cancel(); super.dispose();
  }

  Future<void> _startLocationIfAllowed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await UserService().getUser(uid);
    if (user != null && user.isLocationSharingEnabled == true) {
      LocationService.startLiveTracking(uid: uid);
    }
  }

  void _logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await LocationService.stopLiveTracking(uid);
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _triggerSOS() async {
    if (_loading || _isSOSActive) return;
    setState(() => _loading = true);
    try {
      HapticFeedback.heavyImpact();
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final AppUser? user = await UserService().getUser(uid);
      final verifiedContacts = (await UserService().getEmergencyContacts(uid)).where((c) => c.verified).toList();
      if (verifiedContacts.isEmpty) { _showSnack("No verified emergency contacts found"); return; }
      final position = await LocationService.getCurrentLocation();
      await _sosService.triggerSos(userId: uid, userName: user!.name, latitude: position.latitude, longitude: position.longitude, contacts: verifiedContacts.map((c) => 'whatsapp:+91${c.phone}').toList());
      await FirebaseDatabase.instance.ref("live_tracking/$uid").update({"isSOS": true});
      _logActivity(title: "Emergency SOS triggered", type: "sos");
      _showSnack("SOS Triggered — Help is on the way", success: true);
    } catch (e) { _showSnack("SOS Failed: ${e.toString()}");
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _stopSos() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseDatabase.instance.ref("live_tracking/$uid").update({"isSOS": false});
    _logActivity(title: "SOS emergency deactivated", type: "sos");
    _showSnack("SOS stopped", success: true);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = (timestamp as Timestamp).toDate();
    final duration = DateTime.now().difference(date);
    if (duration.inMinutes < 60) return "${duration.inMinutes} min ago";
    if (duration.inHours < 24) return "${duration.inHours} hours ago";
    return "${duration.inDays} days ago";
  }

  IconData _getIconFromString(String? type) {
    switch (type) {
      case 'share': return Icons.share_location_rounded;
      case 'sos': return Icons.emergency_share_rounded;
      case 'scan': return Icons.radar_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColorFromString(String? type) {
    switch (type) {
      case 'share': return _accent;
      case 'sos': return _danger;
      case 'scan': return const Color(0xFF5B8DEF);
      default: return Colors.grey;
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [Icon(success ? Icons.check_circle_rounded : Icons.warning_rounded, color: Colors.white, size: 18), const SizedBox(width: 10), Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)))]), backgroundColor: success ? (msg.contains("stopped") ? Colors.green : _danger) : Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), margin: const EdgeInsets.fromLTRB(16, 0, 16, 24)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Logged out")));

    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<AppUser?>(
        future: UserService().getUser(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _accent));
          final user = snapshot.data;
          if (user == null) return const Center(child: Text("User profile not found"));

          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(user),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 28),
                      _buildStatusBanner(),
                      const SizedBox(height: 28),
                      _buildSOSCard(),
                      const SizedBox(height: 24),
                      _buildInfoRow(),
                      const SizedBox(height: 24),
                      _buildSafetyTip(),
                      const SizedBox(height: 24),
                      _buildActivityFeed(),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(AppUser user) {
    return SliverAppBar(
      expandedHeight: 0, floating: true, pinned: true, backgroundColor: _bg, elevation: 0, systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("LifeGuardian+", style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w800)),
          Text("Hello, ${user.name.split(' ').first} 👋", style: const TextStyle(color: _textSec, fontSize: 11.5)),
        ]),
      ]),
      actions: [
        _appBarAction(Icons.notifications_outlined, () {
          Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const AlertsScreen(), transitionsBuilder: (_, animation, __, child) => SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child)));
        }),
        _appBarAction(Icons.logout_rounded, _logout),
        const SizedBox(width: 14),
      ],
    );
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(width: 38, height: 38, decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Icon(icon, color: _textPri, size: 18)));
  }

  Widget _buildStatusBanner() {
    final activeColor = _isSOSActive ? _danger : _statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(gradient: LinearGradient(colors: _isSOSActive ? [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)] : [activeColor.withOpacity(0.1), activeColor.withOpacity(0.2)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: activeColor.withOpacity(0.25))),
      child: Row(children: [
        AnimatedBuilder(animation: _pulseAnimation, builder: (_, __) => Transform.scale(scale: _pulseAnimation.value, child: Container(width: 46, height: 46, decoration: BoxDecoration(color: activeColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(_isSOSActive ? Icons.warning_amber_rounded : Icons.verified_user_rounded, color: activeColor, size: 24)))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isSOSActive ? "SOS Active" : _safetyStatus, style: TextStyle(color: _isSOSActive ? _danger : _textPri, fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
          // Frequency Logic Display
          if (!_isSOSActive && _mostFrequentCrime != "None")
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF7A8FA6)),
                  const SizedBox(width: 4),
                  Text("Common: $_mostFrequentCrime", style: const TextStyle(color: Color(0xFF7A8FA6), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Text(_isSOSActive ? "Emergency mode enabled" : "At: $_currentCity", style: const TextStyle(color: _textSec, fontSize: 12), overflow: TextOverflow.ellipsis)
        ])),
        _statusBadge(_isSOSActive ? "SOS" : "LIVE", _isSOSActive ? _danger : _accent),
      ]),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))]));
  }

  Widget _buildSOSCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Emergency SOS", style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(_isSOSActive ? "Contacts Notified" : "Tap to alert contacts", style: const TextStyle(color: _textSec, fontSize: 12.5))]),
          if (_isSOSActive) GestureDetector(onTap: _stopSos, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _textPri, borderRadius: BorderRadius.circular(12)), child: const Text("STOP SOS", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
        ]),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _triggerSOS,
          child: AnimatedBuilder(animation: _sosScaleAnimation, builder: (_, child) => Transform.scale(scale: _sosScaleAnimation.value, child: child), child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(animation: _pulseAnimation, builder: (_, __) => Container(width: 110 * _pulseAnimation.value, height: 110 * _pulseAnimation.value, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: (_isSOSActive ? _danger : _accent).withOpacity(0.2), width: 2)))),
            Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _isSOSActive ? [const Color(0xFF424242), const Color(0xFF212121)] : [const Color(0xFFFF6B81), const Color(0xFFFF4D6A)]), boxShadow: [BoxShadow(color: (_isSOSActive ? Colors.black : _danger).withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 8))]), child: Center(child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.report_problem_rounded, color: Colors.white, size: 28), const SizedBox(height: 4), Text(_isSOSActive ? "ACTIVE" : "SOS", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0))]))),
          ])),
        ),
        const SizedBox(height: 24),
        Text(_isSOSActive ? "SOS mode is active" : (_loading ? "Sending..." : "Tap to send alert"), style: TextStyle(color: _isSOSActive ? _danger : _textSec, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildInfoRow() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return FutureBuilder<WeatherData>(
      future: fetchWeather(),
      builder: (context, snapshot) {
        String tempDisplay = snapshot.hasData ? "${snapshot.data!.temp}°C" : "Loading...";
        IconData weatherIcon = (snapshot.hasData && !snapshot.data!.isDay) ? Icons.nightlight_round : Icons.wb_sunny_rounded;
        return Row(
          children: [
            Expanded(child: _infoCard(icon: weatherIcon, iconColor: _amber, title: tempDisplay, subtitle: _currentCity, bgColor: const Color(0xFFFFF8EC), borderColor: _amber.withOpacity(0.25))),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
                builder: (context, snapshot) {
                  bool isSharing = snapshot.hasData && snapshot.data!.exists ? (snapshot.data!.data() as Map)['isLocationSharingEnabled'] ?? false : false;
                  return _infoCard(icon: isSharing ? Icons.location_on_rounded : Icons.location_off_rounded, iconColor: isSharing ? const Color(0xFF5B8DEF) : Colors.grey, title: isSharing ? "Tracking On" : "Tracking Off", subtitle: isSharing ? "Live Updates" : "Paused", bgColor: isSharing ? const Color(0xFFEEF3FF) : Colors.grey.withOpacity(0.1), borderColor: (isSharing ? const Color(0xFF5B8DEF) : Colors.grey).withOpacity(0.25));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _infoCard({required IconData icon, required Color iconColor, required String title, required String subtitle, required Color bgColor, required Color borderColor}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 18)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _textPri, fontSize: 12.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), Text(subtitle, style: const TextStyle(color: _textSec, fontSize: 10.5), overflow: TextOverflow.ellipsis)]))]));
  }

  Widget _buildSafetyTip() {
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFFFFBF0), borderRadius: BorderRadius.circular(18), border: Border.all(color: _amber.withOpacity(0.3))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: _amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.lightbulb_outline_rounded, color: _amber, size: 18)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Safety Tip", style: TextStyle(color: Color(0xFFB87A00), fontSize: 11.5, fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text(tipText, style: const TextStyle(color: _textPri, fontSize: 13, height: 1.5))]))]));
  }

  Widget _buildActivityFeed() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recent Activity", style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('activities').orderBy('timestamp', descending: true).limit(5).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("No recent activity", style: TextStyle(color: _textSec, fontSize: 13)));
              return ListView.separated(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: snapshot.data!.docs.length, separatorBuilder: (_, __) => Divider(height: 1, color: _border, indent: 60, endIndent: 16),
                itemBuilder: (_, i) {
                  final data = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                  final activity = ActivityModel.fromMap(data);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: _getColorFromString(activity.type).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(_getIconFromString(activity.type), color: _getColorFromString(activity.type), size: 17)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(activity.title, style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600))),
                      Text(_formatTimestamp(Timestamp.fromDate(activity.timestamp)), style: const TextStyle(color: _textSec, fontSize: 11)),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}