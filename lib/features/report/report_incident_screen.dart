import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../model/crime_report.dart';
import 'pick_location_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen>
    with TickerProviderStateMixin {

  final TextEditingController _descriptionController = TextEditingController();

  String _selectedType  = "Theft";
  String _locationMode  = "current"; // current | manual
  bool   _isLoading     = false;
  bool   _descFocused   = false;
  double? _selectedLat;
  double? _selectedLng;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _bg         = Color(0xFFF5F7FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _accent     = Color(0xFF00C896);
  static const Color _accentDark = Color(0xFF00A87C);
  static const Color _textPri    = Color(0xFF0D1B2A);
  static const Color _textSec    = Color(0xFF7A8FA6);
  static const Color _border     = Color(0xFFE8EDF3);
  static const Color _danger     = Color(0xFFFF4D6A);
  static const Color _amber      = Color(0xFFFFB830);
  static const Color _blue       = Color(0xFF5B8DEF);
  // ───────────────────────────────────────────────────────────────────────────

  // Incident types with icons and colors
  final List<_IncidentType> _incidentTypes = const [
    _IncidentType("Theft",               Icons.inventory_2_outlined,     Color(0xFFFF4D6A)),
    _IncidentType("Harassment",          Icons.report_gmailerrorred_outlined,     Color(0xFFFF8C42)),
    _IncidentType("Accident",            Icons.car_crash_outlined,       Color(0xFFFFB830)),
    _IncidentType("Suspicious Activity", Icons.visibility_outlined,      Color(0xFF5B8DEF)),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_isLoading) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      double lat, lng;

      if (_locationMode == "current") {
        LocationPermission permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception("Location permission denied");
        }
        Position position = await Geolocator.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;
      } else {
        if (_selectedLat == null || _selectedLng == null) {
          throw Exception("Please select a location on the map");
        }
        lat = _selectedLat!;
        lng = _selectedLng!;
      }

      final report = CrimeReport(
        lat: lat,
        lng: lng,
        type: _selectedType,
        description: _descriptionController.text.trim(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await FirebaseFirestore.instance
          .collection("crime_reports")
          .add(report.toMap());

      _descriptionController.clear();
      setState(() {
        _selectedLat = null;
        _selectedLng = null;
      });

      if (!mounted) return;
      _showSnackbar("Report submitted. Thank you for keeping the community safe.", success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(e.toString(), success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 17,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: success ? _accent : _danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  _buildAlertBanner(),
                  const SizedBox(height: 24),
                  _buildLocationSection(),
                  const SizedBox(height: 20),
                  _buildIncidentTypeSection(),
                  const SizedBox(height: 20),
                  _buildDescriptionSection(),
                  const SizedBox(height: 28),
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                  _buildFooterNote(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
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
      title: const Text(
        "Report Incident",
        style: TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  // ── Alert banner ───────────────────────────────────────────────────────────

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _danger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: _danger, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Report Responsibly",
                  style: TextStyle(
                    color: _danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "False reports may affect community safety. Only report genuine incidents.",
                  style: TextStyle(
                    color: Color(0xFFCC2244),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Location section ───────────────────────────────────────────────────────

  Widget _buildLocationSection() {
    return _sectionCard(
      icon: Icons.location_on_rounded,
      iconColor: _blue,
      title: "Location",
      child: Column(
        children: [
          _locationOption(
            value: "current",
            icon: Icons.my_location_rounded,
            title: "Use Current Location",
            subtitle: "Automatically detect where you are",
            color: _accent,
          ),
          const SizedBox(height: 10),
          _locationOption(
            value: "manual",
            icon: Icons.map_rounded,
            title: "Pick on Map",
            subtitle: "Manually pin the incident location",
            color: _blue,
          ),

          // Map picker button
          if (_locationMode == "manual") ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PickLocationScreen()),
                );
                if (result != null) {
                  setState(() {
                    _selectedLat = result["lat"];
                    _selectedLng = result["lng"];
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedLat != null
                        ? _blue.withOpacity(0.4)
                        : _blue.withOpacity(0.2),
                    width: _selectedLat != null ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedLat != null
                          ? Icons.check_circle_rounded
                          : Icons.add_location_alt_rounded,
                      color: _blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedLat != null
                          ? "Location selected (${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)})"
                          : "Tap to select location on map",
                      style: TextStyle(
                        color: _blue,
                        fontSize: 13,
                        fontWeight: _selectedLat != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _locationOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _locationMode == value;

    return GestureDetector(
      onTap: () => setState(() => _locationMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.07) : const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : _border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isSelected ? color : _textSec, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? _textPri : _textSec,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textSec,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : _border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 11)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Incident type section ──────────────────────────────────────────────────

  Widget _buildIncidentTypeSection() {
    return _sectionCard(
      icon: Icons.category_outlined,
      iconColor: _amber,
      title: "Incident Type",
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _incidentTypes.map((type) {
          final isSelected = _selectedType == type.label;
          return GestureDetector(
            onTap: () => setState(() => _selectedType = type.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? type.color.withOpacity(0.1)
                    : const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? type.color.withOpacity(0.45)
                      : _border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type.icon,
                    color: isSelected ? type.color : _textSec,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    type.label,
                    style: TextStyle(
                      color: isSelected ? type.color : _textSec,
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Description section ────────────────────────────────────────────────────

  Widget _buildDescriptionSection() {
    return _sectionCard(
      icon: Icons.edit_note_rounded,
      iconColor: const Color(0xFFBB6BD9),
      title: "Description",
      child: Focus(
        onFocusChange: (v) => setState(() => _descFocused = v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _descFocused
                ? _accent.withOpacity(0.04)
                : const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _descFocused ? _accent : _border,
              width: _descFocused ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 5,
            style: const TextStyle(
              color: _textPri,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText:
              "Describe what happened — time, people involved, any details that may help...",
              hintStyle: TextStyle(
                color: _textSec.withOpacity(0.5),
                fontSize: 13,
                height: 1.6,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ),
    );
  }

  // ── Submit button ──────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isLoading
            ? Container(
          key: const ValueKey('loading'),
          decoration: BoxDecoration(
            color: _danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: _danger, strokeWidth: 2.5),
            ),
          ),
        )
            : GestureDetector(
          key: const ValueKey('button'),
          onTap: _submitReport,
          child: Container(
            decoration: BoxDecoration(
              color: _danger,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _danger.withOpacity(0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Padding(
              // Adding horizontal padding keeps the button from touching the screen edges
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity, // Forces the button to fill the width
                height: 56,            // Standard height for a primary action button
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350), // Matches the reddish theme in your image
                    borderRadius: BorderRadius.circular(12), // Rounded corners for a modern feel
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Centers the content horizontally
                    children: const [
                      Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Submit Report",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Center(
      child: Text(
        "Reports are anonymous and reviewed by our safety team",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textSec.withOpacity(0.6),
          fontSize: 11.5,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Section card wrapper ───────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────

class _IncidentType {
  final String label;
  final IconData icon;
  final Color color;
  const _IncidentType(this.label, this.icon, this.color);
}