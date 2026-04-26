import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 1. Mapbox must be prefixed to avoid 'Size' naming conflicts
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:http/http.dart' as http;

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen>
    with SingleTickerProviderStateMixin {

  mapbox.MapboxMap? mapboxMap;

  double? lat;
  double? lng;
  String  locationName  = "Move the map to select a location";
  bool    _isSearching  = false;
  bool    _pinFocused   = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode             _searchFocus      = FocusNode();

  late AnimationController _pinController;
  late Animation<double>   _pinBounce;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _bg         = Color(0xFFF5F7FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _accent     = Color(0xFF00C896);
  static const Color _textPri    = Color(0xFF0D1B2A);
  static const Color _textSec    = Color(0xFF7A8FA6);
  static const Color _border     = Color(0xFFE8EDF3);
  static const Color _danger     = Color(0xFFFF4D6A);
  static const Color _blue       = Color(0xFF5B8DEF);

  static const String _accessToken =
      "YOUR_MAPBOX_TOKEN";

  @override
  void initState() {
    super.initState();
    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pinBounce = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _pinController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _getAddress(double lat, double lng) async {
    final url =
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$_accessToken";
    try {
      final response = await http.get(Uri.parse(url));
      final data     = jsonDecode(response.body);
      if (data["features"].isNotEmpty && mounted) {
        setState(() {
          locationName = data["features"][0]["place_name"];
        });
      }
    } catch (_) {}
  }

  void _onCameraChanged(mapbox.CameraChangedEventData data) async {
    if (!_pinFocused) {
      setState(() => _pinFocused = true);
      _pinController.forward();
    }
    final center = await mapboxMap?.getCameraState();
    if (center != null) {
      lat = center.center.coordinates.lat.toDouble();
      lng = center.center.coordinates.lng.toDouble();
      _getAddress(lat!, lng!);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    _searchFocus.unfocus();
    setState(() => _isSearching = true);
    final url =
        "https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$_accessToken";
    try {
      final response = await http.get(Uri.parse(url));
      final data     = jsonDecode(response.body);
      if (data["features"].isNotEmpty) {
        final coords = data["features"][0]["geometry"]["coordinates"];
        mapboxMap?.easeTo(
          mapbox.CameraOptions(
            center: mapbox.Point(coordinates: mapbox.Position(coords[0], coords[1])),
            zoom: 15,
          ),
          mapbox.MapAnimationOptions(duration: 800),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _confirm() {
    if (lat == null || lng == null) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, {
      "lat": lat,
      "lng": lng,
      "address": locationName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm = lat != null && lng != null;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textPri, size: 15),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_location_alt_rounded,
                  color: _blue, size: 16),
            ),
            const SizedBox(width: 9),
            const Text(
              "Pick Location",
              style: TextStyle(
                color: _textPri,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: Stack(
        children: [
          mapbox.MapWidget(
            onMapCreated: (map) => mapboxMap = map,
            onCameraChangeListener: _onCameraChanged,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: mapbox.Position(73.8567, 18.5204)),
              zoom: 12,
            ),
          ),
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded,
                      color: _textSec, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search for a place...",
                        hintStyle: TextStyle(
                          color: _textSec.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: _searchLocation,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _searchLocation(_searchController.text),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: _isSearching
                          ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 17),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pinBounce,
            builder: (_, child) => Center(
              child: Transform.translate(
                offset: Offset(0, _pinBounce.value - 28),
                child: child,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _danger.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 18),
                ),
                // 2. FIXED: Positional arguments used for Flutter's Size
                CustomPaint(
                  size: const Size(12, 10),
                  painter: _PinTailPainter(color: _danger),
                ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Container(
                width: 18,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.09),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: _danger, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selected Location",
                          style: TextStyle(
                            color: _textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          locationName,
                          style: const TextStyle(
                            color: _textPri,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: canConfirm ? _confirm : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  color: canConfirm ? _accent : _textSec.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canConfirm
                      ? [
                    BoxShadow(
                      color: _accent.withOpacity(0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: canConfirm
                          ? Colors.white
                          : _textSec.withOpacity(0.5),
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      "Confirm Location",
                      style: TextStyle(
                        color: canConfirm
                            ? Colors.white
                            : _textSec.withOpacity(0.5),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}