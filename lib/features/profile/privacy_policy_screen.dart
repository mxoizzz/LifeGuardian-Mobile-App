import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // ── Design tokens (Matching your Settings Screen) ────────────────────────
  static const Color _bg      = Color(0xFFF5F7FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent  = Color(0xFF00C896);
  static const Color _textPri = Color(0xFF0D1B2A);
  static const Color _textSec = Color(0xFF7A8FA6);
  static const Color _border  = Color(0xFFE8EDF3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── Modern Floating App Bar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: _surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: const Text(
                "Privacy Policy",
                style: TextStyle(
                  color: _textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // ── Policy Content ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoCard(
                    "Last Updated: April 2026",
                    "Please read our privacy policy carefully to understand how we collect, use, and protect your personal data.",
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader("1. Data Collection"),
                  _policyText(
                      "LifeGuardian+ collects location data to enable emergency tracking features even when the app is closed or not in use. This data is only shared with your designated emergency contacts."
                  ),

                  _sectionHeader("2. Real-time Tracking"),
                  _policyText(
                      "When Live Location Sharing is enabled, your coordinates are transmitted to our secure servers and shared with chosen peers. You can disable this at any time in the Settings."
                  ),

                  _sectionHeader("3. Data Security"),
                  _policyText(
                      "We use industry-standard encryption (AES-256) to protect your data. Your account information is stored securely via Firebase Authentication and Firestore."
                  ),

                  _sectionHeader("4. Your Rights"),
                  _policyText(
                      "You have the right to access, correct, or delete your data at any time. Deleting your account will permanently wipe all associated data from our servers."
                  ),

                  const SizedBox(height: 32),
                  _footerContact(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: _textPri,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _policyText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _textSec,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }

  Widget _infoCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: _textPri.withOpacity(0.7), fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _footerContact() {
    return Center(
      child: Column(
        children: [
          Text(
            "Questions about our policy?",
            style: TextStyle(color: _textSec, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            "support@lifeguardian.plus",
            style: TextStyle(
              color: _accent,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}