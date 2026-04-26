import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../services/user_service.dart';
import '../../services/location_service.dart';
import '../../services/sos_service.dart';
import '../../model/emergency_contact.dart';
import '../../model/user_model.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {

  bool _loading     = false;
  bool _isSOSActive = false;

  final SosService _sosService = SosService();
  StreamSubscription<DatabaseEvent>? _sosSubscription;

  late AnimationController _pulseController;
  late AnimationController _pressController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _pulse2Animation;
  late Animation<double> _pressAnimation;
  late Animation<double> _fadeAnimation;

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
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulse2Animation = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pressAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _listenSOSState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pressController.dispose();
    _fadeController.dispose();
    _sosSubscription?.cancel();
    super.dispose();
  }

  void _listenSOSState() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _sosSubscription = FirebaseDatabase.instance
        .ref("live_tracking/$uid/isSOS")
        .onValue
        .listen((event) {
      final value = event.snapshot.value;
      if (mounted) setState(() => _isSOSActive = value == true);
    });
  }

  Future<void> _handleSos(BuildContext context) async {
    if (_loading) return;

    HapticFeedback.heavyImpact();
    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final AppUser? user = await UserService().getUser(uid);
      if (user == null) throw Exception('User data not found');

      final contacts = await UserService().getEmergencyContacts(uid);
      if (contacts.isEmpty) {
        _showSnack('No emergency contacts added');
        return;
      }

      final verifiedContacts = contacts.where((c) => c.verified).toList();
      if (verifiedContacts.isEmpty) {
        _showSnack('No verified contacts found');
        return;
      }

      final contactNumbers =
      verifiedContacts.map((c) => 'whatsapp:+91${c.phone}').toList();

      final position = await LocationService.getCurrentLocation();

      await _sosService.triggerSos(
        userId: uid,
        userName: user.name,
        latitude: position.latitude,
        longitude: position.longitude,
        contacts: contactNumbers,
      );

      await FirebaseDatabase.instance
          .ref("live_tracking/$uid")
          .update({"isSOS": true});

      _showSnack('SOS triggered — help is on the way', success: true);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stopSos() async {
    HapticFeedback.mediumImpact();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseDatabase.instance
        .ref("live_tracking/$uid")
        .update({"isSOS": false});
    _showSnack("SOS deactivated — you're safe", success: true);
  }

  void _showSnack(String msg, {bool success = false}) {
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
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: success ? _accent : _danger,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [

              // ── Top bar ──────────────────────────────────────────────────
              Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.sos_rounded,
                          color: _danger, size: 17),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Emergency SOS",
                      style: TextStyle(
                        color: _textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    // Live indicator when SOS active
                    if (_isSOSActive) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _danger,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              "ACTIVE",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(height: 1, color: _border),

              // ── Main content ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [

                      const SizedBox(height: 36),

                      // Status banner
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isSOSActive
                            ? _activeBanner()
                            : _safeBanner(),
                      ),

                      const SizedBox(height: 48),

                      // SOS button
                      _loading
                          ? _loadingState()
                          : _buildSosButton(context),

                      const SizedBox(height: 36),

                      // Instruction text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isSOSActive
                            ? _activeHint()
                            : _idleHint(),
                      ),

                      const SizedBox(height: 32),

                      // Stop SOS button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: _isSOSActive
                            ? _stopSosButton()
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 32),

                      // Info card
                      _buildInfoCard(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Banners ───────────────────────────────────────────────────────────────

  Widget _safeBanner() {
    return Container(
      key: const ValueKey('safe'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FBF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: _accent, size: 18),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You're Safe",
                style: TextStyle(
                  color: _accentDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "SOS is not active",
                style: TextStyle(
                  color: _accentDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeBanner() {
    return Container(
      key: const ValueKey('active'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _danger.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _danger.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.warning_rounded, color: _danger, size: 18),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SOS Active",
                style: TextStyle(
                  color: _danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Contacts have been alerted",
                style: TextStyle(
                  color: _danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SOS Button ────────────────────────────────────────────────────────────

  Widget _buildSosButton(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        _handleSos(context);
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation:
        Listenable.merge([_pulseAnimation, _pulse2Animation, _pressAnimation]),
        builder: (_, __) => Transform.scale(
          scale: _pressAnimation.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring 2
              Transform.scale(
                scale: _pulse2Animation.value,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSOSActive
                        ? _danger.withOpacity(0.07)
                        : _danger.withOpacity(0.05),
                  ),
                ),
              ),
              // Inner pulse ring
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSOSActive
                        ? _danger.withOpacity(0.12)
                        : _danger.withOpacity(0.09),
                  ),
                ),
              ),
              // Button
              Container(
                width: 155,
                height: 155,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B81), Color(0xFFFF4D6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _danger.withOpacity(
                          _isSOSActive ? 0.55 : 0.35),
                      blurRadius: _isSOSActive ? 40 : 28,
                      spreadRadius: _isSOSActive ? 4 : 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sos_rounded,
                        color: Colors.white, size: 42),
                    const SizedBox(height: 4),
                    Text(
                      _isSOSActive ? "ACTIVE" : "SOS",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return SizedBox(
      width: 220,
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: _danger,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Alerting contacts...",
              style: TextStyle(
                color: _textSec,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hints ─────────────────────────────────────────────────────────────────

  Widget _idleHint() {
    return Column(
      key: const ValueKey('idle_hint'),
      children: [
        const Text(
          "Tap in an emergency",
          style: TextStyle(
            color: _textPri,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Your location and a distress message\nwill be sent to your verified contacts.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSec.withOpacity(0.8),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _activeHint() {
    return Column(
      key: const ValueKey('active_hint'),
      children: [
        const Text(
          "Help is on the way",
          style: TextStyle(
            color: _danger,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Your contacts have been notified\nwith your live location.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _danger.withOpacity(0.7),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Stop SOS button ───────────────────────────────────────────────────────

  Widget _stopSosButton() {
    return GestureDetector(
      key: const ValueKey('stop_btn'),
      onTap: _stopSos,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _danger.withOpacity(0.35), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.stop_circle_outlined, color: _danger, size: 20),
            SizedBox(width: 9),
            Text(
              "Stop SOS",
              style: TextStyle(
                color: _danger,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    final items = [
      _Info(Icons.location_on_rounded,       _accent, "Live location is shared with contacts"),
      _Info(Icons.message_rounded,           const Color(0xFF5B8DEF), "WhatsApp alert sent instantly"),
      _Info(Icons.people_rounded,            _amber,  "Only verified contacts are notified"),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What happens when you tap SOS",
            style: TextStyle(
              color: _textPri,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(item.icon, color: item.color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────

class _Info {
  final IconData icon;
  final Color    color;
  final String   label;
  const _Info(this.icon, this.color, this.label);
}