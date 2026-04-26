import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens assumed to be in separate files
import 'package:lifeguardianplus/features/profile/about_screen.dart';
import 'package:lifeguardianplus/features/profile/change_password_screen.dart';
import 'package:lifeguardianplus/features/profile/privacy_policy_screen.dart';

import '../../services/user_service.dart';
import '../../services/location_service.dart';
import '../../model/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {

  bool _locationSharingEnabled = true;
  bool _loading = true;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _bg         = Color(0xFFF5F7FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _accent     = Color(0xFF00C896);
  static const Color _textPri    = Color(0xFF0D1B2A);
  static const Color _textSec    = Color(0xFF7A8FA6);
  static const Color _border     = Color(0xFFE8EDF3);
  static const Color _danger     = Color(0xFFFF4D6A);
  static const Color _amber      = Color(0xFFFFB830);
  static const Color _blue       = Color(0xFF5B8DEF);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadSetting();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Logic for fetching settings
  Future<void> _loadSetting() async {
    final uid  = FirebaseAuth.instance.currentUser!.uid;
    final user = await UserService().getUser(uid);
    if (user != null && mounted) {
      setState(() {
        _locationSharingEnabled = user.isLocationSharingEnabled;
        _loading = false;
      });
      _fadeController.forward();
    }
  }

  // Logic for toggling location
  Future<void> _toggleLocationSharing(bool value) async {
    HapticFeedback.lightImpact();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _locationSharingEnabled = value);
    await UserService().updateLocationSharing(uid: uid, enabled: value);
    if (value) {
      LocationService.startLiveTracking(uid: uid);
    } else {
      await LocationService.stopLiveTracking(uid);
    }
  }

  // Logout Logic
  void _logout() async {
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      Navigator.pop(context);
    }
  }

  // DELETE ACCOUNT LOGIC
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This action is permanent. All your emergency contacts and activity history will be wiped."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: _danger))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: _danger)));

    try {
      final uid = user.uid;
      await LocationService.stopLiveTracking(uid);
      await FirebaseDatabase.instance.ref("live_tracking/$uid").remove();
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await user.delete();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      Navigator.pop(context);
      // Handle "requires-recent-login" error here if necessary
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Container(height: 1, color: _border),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _accent))
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  children: [
                    _sectionLabel("Privacy & Location"),
                    const SizedBox(height: 10),
                    _settingsCard(children: [
                      _toggleTile(
                        icon: Icons.location_on_rounded,
                        iconColor: _accent,
                        title: "Live Location Sharing",
                        subtitle: "Share your real-time location during app usage",
                        value: _locationSharingEnabled,
                        onChanged: _toggleLocationSharing,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _sectionLabel("Account"),
                    const SizedBox(height: 10),
                    _settingsCard(children: [
                      _arrowTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFFBB6BD9),
                        title: "Change Password",
                        subtitle: "Update your account password",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen())),
                      ),
                      Divider(height: 1, color: _border, indent: 56, endIndent: 16),
                      _arrowTile(
                        icon: Icons.shield_outlined,
                        iconColor: _accent,
                        title: "Privacy Policy",
                        subtitle: "How we handle your data",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen())),
                      ),
                      Divider(height: 1, color: _border, indent: 56, endIndent: 16),
                      _arrowTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: _blue,
                        title: "About LifeGuardian+",
                        subtitle: "Version 1.0.0",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen())),
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _sectionLabel("Danger Zone"),
                    const SizedBox(height: 10),
                    _settingsCard(children: [
                      _dangerTile(icon: Icons.logout_rounded, label: "Sign Out", onTap: _logout),
                      Divider(height: 1, color: _danger.withOpacity(0.15), indent: 56, endIndent: 16),
                      _dangerTile(icon: Icons.delete_outline_rounded, label: "Delete Account", onTap: _deleteAccount),
                    ]),

                    const SizedBox(height: 32),
                    _buildBrandingFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 15),
            ),
          ),
          const SizedBox(width: 14),
          const Text("Settings", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildBrandingFooter() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          const Text("LifeGuardian+", style: TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text("Your safety is our priority. Always.", style: TextStyle(color: _textSec.withOpacity(0.6), fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(padding: const EdgeInsets.only(left: 4), child: Text(label.toUpperCase(), style: TextStyle(color: _textSec.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0)));

  Widget _settingsCard({required List<Widget> children}) => Container(decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)), child: Column(children: children));

  Widget _toggleTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(color: _textSec, fontSize: 11.5))])),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: _accent),
    ]));
  }

  Widget _arrowTile({required IconData icon, required Color iconColor, required String title, required String subtitle, VoidCallback? onTap}) {
    return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(color: _textSec, fontSize: 11.5))])),
      const Icon(Icons.chevron_right_rounded, color: Color(0xFFCDD5E0), size: 20),
    ])));
  }

  Widget _dangerTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: _danger.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _danger, size: 18)),
      const SizedBox(width: 14),
      Text(label, style: const TextStyle(color: _danger, fontSize: 14, fontWeight: FontWeight.w600)),
      const Spacer(),
      const Icon(Icons.chevron_right_rounded, color: Color(0xFFCDD5E0), size: 20),
    ])));
  }
}