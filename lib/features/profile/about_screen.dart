import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this to pubspec.yaml

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── Design tokens (Consistent with your Settings) ────────────────────────
  static const Color _bg      = Color(0xFFF5F7FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent  = Color(0xFF00C896);
  static const Color _textPri = Color(0xFF0D1B2A);
  static const Color _textSec = Color(0xFF7A8FA6);
  static const Color _border  = Color(0xFFE8EDF3);
  static const Color _blue    = Color(0xFF5B8DEF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildAppLogo(),
            const SizedBox(height: 48),
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildLinksSection(),
            const SizedBox(height: 40),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 15),
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 50),
        ),
        const SizedBox(height: 20),
        const Text(
          "LifeGuardian+",
          style: TextStyle(color: _textPri, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const Text(
          "v1.0.0 (Stable Build)",
          style: TextStyle(color: _textSec, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Our Mission", style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          Text(
            "LifeGuardian+ was built with a single goal: to ensure that no one ever has to face an emergency alone. By combining real-time location tracking with instant SOS alerts, we provide a safety net for you and your loved ones.",
            style: TextStyle(color: _textSec, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _linkTile(Icons.language_rounded, "Official Website", "lifeguardianplus.com"),
          const SizedBox(height: 12),
          _linkTile(Icons.mail_outline_rounded, "Support Email", "support@lifeguardian.plus"),
          const SizedBox(height: 12),
          _linkTile(Icons.star_outline_rounded, "Rate Us", "Open Play Store"),
        ],
      ),
    );
  }

  Widget _linkTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Icon(Icons.open_in_new_rounded, color: Color(0xFFCDD5E0), size: 18),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          "Made with ❤️ by the LifeGuardian Team",
          style: TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          "© 2026 LifeGuardian+ Inc.",
          style: TextStyle(color: _textSec.withOpacity(0.5), fontSize: 11),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}