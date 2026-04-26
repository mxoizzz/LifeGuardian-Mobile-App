import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../model/emergency_contact.dart';
import '../../services/user_service.dart';

class VerifyContactScreen extends StatefulWidget {
  final EmergencyContact contact;

  const VerifyContactScreen({super.key, required this.contact});

  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen>
    with TickerProviderStateMixin {

  bool _loading = false;
  bool _codeCopied = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double>   _fadeAnimation;
  late Animation<Offset>   _slideAnimation;
  late Animation<double>   _pulseAnimation;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _bg         = Color(0xFFF5F7FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _accent     = Color(0xFF00C896);
  static const Color _accentDark = Color(0xFF00A87C);
  static const Color _textPri    = Color(0xFF0D1B2A);
  static const Color _textSec    = Color(0xFF7A8FA6);
  static const Color _border     = Color(0xFFE8EDF3);
  static const Color _danger     = Color(0xFFFF4D6A);
  static const Color _blue       = Color(0xFF5B8DEF);
  static const Color _whatsapp   = Color(0xFF25D366);
  // ───────────────────────────────────────────────────────────────────────────

  static const String _twilioSandboxNumber = '14155238886';
  static const String _joinCode            = 'join poor-rough';

  String get _waJoinLink =>
      'https://wa.me/$_twilioSandboxNumber?text=${Uri.encodeComponent(_joinCode)}';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _markVerified() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    await UserService().markContactVerified(widget.contact.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _copyCode() {
    Clipboard.setData(const ClipboardData(text: _joinCode));
    HapticFeedback.lightImpact();
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2),
            () { if (mounted) setState(() => _codeCopied = false); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const SizedBox(height: 20),

                  // ── Back + title ─────────────────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: _textPri,
                            size: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _whatsapp.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.verified_user_rounded,
                            color: _whatsapp, size: 19),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Verify Contact",
                        style: TextStyle(
                          color: _textPri,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // ── Heading ──────────────────────────────────────────
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        height: 1.15,
                      ),
                      children: [
                        const TextSpan(text: "Verify\n"),
                        TextSpan(
                          text: widget.contact.name,
                          style: const TextStyle(color: _accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Ask ${widget.contact.name} to scan this QR code using WhatsApp from their phone.",
                    style: const TextStyle(
                      color: _textSec,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── QR card ──────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [

                        // WhatsApp badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _whatsapp.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _whatsapp.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              const Icon(Icons.chat_rounded, color: _whatsapp, size: 14),
                              SizedBox(width: 6),
                              Text(
                                "Scan with WhatsApp",
                                style: TextStyle(
                                  color: _whatsapp,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // QR code with pulse ring
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, child) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _whatsapp.withOpacity(0.25),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _whatsapp.withOpacity(0.12),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _waJoinLink,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          widget.contact.phone,
                          style: const TextStyle(
                            color: _textSec,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Join code card ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded,
                                  color: _blue, size: 15),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Join Message",
                              style: TextStyle(
                                color: _textPri,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          "If they can't scan, ask them to send this message on WhatsApp:",
                          style: TextStyle(
                            color: _textSec,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Code box
                        GestureDetector(
                          onTap: _copyCode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: _codeCopied
                                  ? _accent.withOpacity(0.07)
                                  : const Color(0xFFF8FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _codeCopied
                                    ? _accent.withOpacity(0.35)
                                    : _border,
                                width: _codeCopied ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _joinCode,
                                    style: TextStyle(
                                      color: _codeCopied ? _accentDark : _textPri,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _codeCopied
                                      ? const Icon(Icons.check_circle_rounded,
                                      color: _accent, size: 18,
                                      key: ValueKey('check'))
                                      : const Icon(Icons.copy_rounded,
                                      color: _textSec, size: 18,
                                      key: ValueKey('copy')),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_codeCopied) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: _accent, size: 13),
                              SizedBox(width: 5),
                              Text(
                                "Copied to clipboard",
                                style: TextStyle(
                                  color: _accentDark,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Confirm verified button ───────────────────────────
                  // ── Confirm verified button (Forced Height) ───────────────────────────
                  ConstrainedBox(
                    constraints: const BoxConstraints.expand(height: 62), // Forced expansion to 62
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _loading
                          ? Container(
                        key: const ValueKey('loading'),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                color: _accent, strokeWidth: 3),
                          ),
                        ),
                      )
                          : GestureDetector(
                        key: const ValueKey('button'),
                        onTap: _markVerified,
                        child: Container(
                          alignment: Alignment.center, // Ensures content stays centered in the taller box
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.verified_rounded,
                                  color: Colors.white, size: 24),
                              SizedBox(width: 14),
                              Text(
                                "I've verified this contact",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17, // Scaled font for the 62 height
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Footer note ──────────────────────────────────────
                  Center(
                    child: Text(
                      "Only mark verified after they've completed the WhatsApp step",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSec.withOpacity(0.65),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}