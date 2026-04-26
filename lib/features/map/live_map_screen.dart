import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with SingleTickerProviderStateMixin {
  mb.MapboxMap? mapboxMap;
  mb.CircleAnnotationManager? circleManager;

  bool isReady = false;
  bool isFirstLoad = true;
  bool isHeatmapMode = false;
  bool useRadiusFilter = true;

  double myLat = 0;
  double myLng = 0;

  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFF00C896);
  static const Color _accentDark = Color(0xFF00A87C);
  static const Color _textPri = Color(0xFF0D1B2A);
  static const Color _textSec = Color(0xFF7A8FA6);
  static const Color _border = Color(0xFFE8EDF3);
  static const Color _amber = Color(0xFFFFB830);
  static const Color _blue = Color(0xFF5B8DEF);
  static const Color _bg = Color(0xFFF5F7FA);

  String get myUid => FirebaseAuth.instance.currentUser!.uid;

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void recenterMap() {
    if (myLat == 0 || myLng == 0) return;
    HapticFeedback.lightImpact();
    mapboxMap?.easeTo(
      mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position(myLng, myLat)), zoom: 16),
      mb.MapAnimationOptions(duration: 800),
    );
  }

  Future<void> loadCrimeHeatmap() async {
    if (mapboxMap == null) return;

    final snapshot =
    await FirebaseFirestore.instance.collection("crime_reports").get();

    List features = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [data["lng"], data["lat"]]
        }
      };
    }).toList();

    final geoJson = {"type": "FeatureCollection", "features": features};

    try {
      bool sourceExists =
      await mapboxMap!.style.styleSourceExists("crime-source");
      if (!sourceExists) {
        await mapboxMap!.style.addSource(
          mb.GeoJsonSource(id: "crime-source", data: jsonEncode(geoJson)),
        );
      }

      bool layerExists = await mapboxMap!.style.styleLayerExists("crime-heat");
      if (!layerExists) {
        await mapboxMap!.style.addLayer(
          mb.HeatmapLayer(
            id: "crime-heat",
            sourceId: "crime-source",
            heatmapRadius: 30.0,
            heatmapIntensity: 1.5,
          ),
        );
        await mapboxMap!.style.setStyleLayerProperty(
          "crime-heat",
          "heatmap-color",
          jsonEncode([
            "interpolate",
            ["linear"],
            ["heatmap-density"],
            0, "rgba(0, 255, 0, 0)",
            0.3, "lime",
            0.6, "yellow",
            1, "red"
          ]),
        );
      } else {
        await mapboxMap!.style
            .setStyleLayerProperty("crime-heat", "visibility", "visible");
      }
    } catch (e) {
      debugPrint("Heatmap Error: $e");
    }
  }

  Future<void> toggleMode() async {
    HapticFeedback.lightImpact();
    setState(() => isHeatmapMode = !isHeatmapMode);

    if (isHeatmapMode) {
      await circleManager?.deleteAll();
      await loadCrimeHeatmap();
    } else {
      try {
        await mapboxMap?.style
            .setStyleLayerProperty("crime-heat", "visibility", "none");
      } catch (e) {
        debugPrint("Layer visibility error: $e");
      }
      _listen();
    }
  }

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    mapboxMap = map;
    await map.location
        .updateSettings(mb.LocationComponentSettings(enabled: false));

    circleManager = await map.annotations.createCircleAnnotationManager();

    setState(() => isReady = true);
    _listen();
  }

  void _onStyleLoaded(mb.StyleLoadedEventData data) async {
    await loadCrimeHeatmap();
    await mapboxMap?.style
        .setStyleLayerProperty("crime-heat", "visibility", "none");
  }

  void _listen() {
    FirebaseDatabase.instance.ref("live_tracking").onValue.listen(
          (event) async {
        if (!isReady || circleManager == null || isHeatmapMode) return;
        final raw = event.snapshot.value;
        if (raw == null) return;

        final data = Map<String, dynamic>.from(raw as Map);
        List<mb.CircleAnnotationOptions> options = [];

        for (final entry in data.entries) {
          final value = Map<String, dynamic>.from(entry.value);

          // Null-Safety: Skip if coords are missing
          if (value["lat"] == null || value["lng"] == null) continue;
          if (value["isSharing"] != true) continue;

          final lat = (value["lat"] as num).toDouble();
          final lng = (value["lng"] as num).toDouble();
          final isMe = entry.key == myUid;
          final isSOS = value["isSOS"] == true;

          if (isMe) {
            myLat = lat;
            myLng = lng;
            if (isFirstLoad) {
              recenterMap();
              isFirstLoad = false;
            }
          }

          // Filter Logic
          if (!isMe && !isSOS && useRadiusFilter) {
            if (myLat != 0 && myLng != 0) {
              if (calculateDistance(myLat, myLng, lat, lng) > 5) continue;
            } else {
              continue;
            }
          }

          options.add(mb.CircleAnnotationOptions(
            geometry: mb.Point(coordinates: mb.Position(lng, lat)),
            circleRadius: isSOS ? 14.0 : (isMe ? 10.0 : 7.0),
            circleColor: isSOS
                ? Colors.red.value
                : (isMe ? Colors.green.value : Colors.blue.value),
            circleStrokeWidth: 2.0,
            circleStrokeColor: Colors.white.value,
            circleOpacity: 1.0,
          ));
        }

        await circleManager!.deleteAll();
        if (options.isNotEmpty) {
          await circleManager!.createMulti(options);
        }
      },
    );
  }

  @override
  void dispose() {
    circleManager?.deleteAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleSpacing: 20,
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.map_rounded, color: _blue, size: 17),
            ),
            const SizedBox(width: 10),
            const Text(
              "Live Map",
              style: TextStyle(
                color: _textPri,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => useRadiusFilter = !useRadiusFilter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: useRadiusFilter ? _accent.withOpacity(0.1) : _bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: useRadiusFilter ? _accent.withOpacity(0.35) : _border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    size: 14,
                    color: useRadiusFilter ? _accentDark : _textSec,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "5 km",
                    style: TextStyle(
                      color: useRadiusFilter ? _accentDark : _textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const ui.Size.fromHeight(1.0),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Stack(
        children: [
          mb.MapWidget(
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            cameraOptions: mb.CameraOptions(
              center: mb.Point(coordinates: mb.Position(73.8567, 18.5204)),
              zoom: 12,
            ),
          ),
          if (isHeatmapMode)
            Positioned(top: 16, right: 16, child: _buildHeatmapLegend()),
          if (!isHeatmapMode)
            Positioned(top: 16, left: 16, child: _buildDotLegend()),
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _mapButton(
                  icon: Icons.my_location_rounded,
                  label: "Recenter",
                  color: _blue,
                  onTap: recenterMap,
                ),
                const SizedBox(height: 10),
                _mapButton(
                  icon: isHeatmapMode
                      ? Icons.people_rounded
                      : Icons.local_fire_department_rounded,
                  label: isHeatmapMode ? "Live View" : "Crime Heatmap",
                  color: isHeatmapMode ? _accent : _amber,
                  onTap: toggleMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dotRow(Colors.green, "You"),
          const SizedBox(height: 7),
          _dotRow(Colors.blue, "Others"),
          const SizedBox(height: 7),
          _dotRow(Colors.red, "SOS"),
        ],
      ),
    );
  }

  Widget _dotRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: _textPri,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapLegend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: _amber, size: 13),
              ),
              const SizedBox(width: 7),
              const Text(
                "Crime Density",
                style: TextStyle(
                  color: _textPri,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              width: 110,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00FF00),
                    Color(0xFFFFFF00),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          const SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Low",
                    style: TextStyle(
                        fontSize: 10,
                        color: _textSec,
                        fontWeight: FontWeight.w500)),
                Text("High",
                    style: TextStyle(
                        fontSize: 10,
                        color: _textSec,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}