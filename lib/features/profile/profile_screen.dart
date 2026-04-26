import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lifeguardianplus/features/profile/edit_profile.dart';
import 'package:lifeguardianplus/features/profile/settings_screen.dart';

import '../../services/user_service.dart';
import '../../services/storage_service.dart';
import '../../model/user_model.dart';
import '../../model/emergency_contact.dart';
import 'add_emergency_contact_screen.dart';
import 'verify_contact_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late Future<AppUser?> _userFuture;
  late Future<List<EmergencyContact>> _contactsFuture;

  late AnimationController _fadeController;
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

  @override
  void initState() {
    super.initState();
    _refreshData();

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
    super.dispose();
  }

  void _refreshData() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _userFuture = UserService().getUser(uid);
    _contactsFuture = UserService().getEmergencyContacts(uid);
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final imageFile = File(pickedFile.path);

    try {
      final imageUrl = await StorageService().uploadProfileImage(
        uid: uid,
        image: imageFile,
      );
      await UserService().updateProfileImage(uid: uid, imageUrl: imageUrl);
      setState(_refreshData);

      if (!mounted) return;
      _showSnackbar("Profile picture updated", success: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackbar("Failed to upload image", success: false);
    }
  }

  Future<void> _removeContact(String contactId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await UserService().deleteEmergencyContact(uid, contactId);
      setState(_refreshData);
      _showSnackbar("Contact removed", success: true);
    } catch (_) {
      _showSnackbar("Failed to remove contact", success: false);
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
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
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
      body: FutureBuilder<AppUser?>(
        future: _userFuture,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          if (!userSnap.hasData) {
            return const Center(child: Text("Profile data not found"));
          }

          final user = userSnap.data!;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: _buildProfileIdentity(user),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      _buildInfoCard(user),
                      const SizedBox(height: 20),
                      _buildActionButtons(context),
                      const SizedBox(height: 28),
                      _buildContactsSection(),
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: false,
      title: const Text(
        "Profile",
        style: TextStyle(
          color: _textPri,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.settings_outlined, color: _textPri, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileIdentity(AppUser user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 2.5),
                    color: const Color(0xFFE8FBF4),
                  ),
                  child: ClipOval(
                    child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                        ? Image.network(user.profileImageUrl!, fit: BoxFit.cover)
                        : Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
                        style: const TextStyle(
                          color: _accentDark,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textPri,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSec,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppUser user) {
    return Container(
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
        children: [
          _infoRow(
            icon: Icons.person_outline_rounded,
            iconColor: _accent,
            label: "Full Name",
            value: user.name,
          ),
          Divider(height: 1, color: _border, indent: 56, endIndent: 20),
          _infoRow(
            icon: Icons.mail_outline_rounded,
            iconColor: const Color(0xFF5B8DEF),
            label: "Email",
            value: user.email,
          ),
          Divider(height: 1, color: _border, indent: 56, endIndent: 20),
          _infoRow(
            icon: Icons.phone_outlined,
            iconColor: _amber,
            label: "Phone",
            value: user.phone,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _textSec, fontSize: 11.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: _textPri, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _border, size: 20),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: Icons.edit_outlined,
            label: "Edit Profile",
            color: const Color(0xFF5B8DEF),
            onTap: () async {
              final result = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const EditProfileScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInQuart;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    return SlideTransition(position: animation.drive(tween), child: child);
                  },
                ),
              );
              if (result == true) setState(_refreshData);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: Icons.person_add_outlined,
            label: "Add Contact",
            color: _accent,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEmergencyContactScreen()),
              );
              setState(_refreshData);
            },
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Emergency Contacts",
              style: TextStyle(
                color: _textPri,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEmergencyContactScreen()),
                );
                setState(_refreshData);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_rounded, color: _accentDark, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Add",
                      style: TextStyle(
                        color: _accentDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<EmergencyContact>>(
          future: _contactsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _accent),
                ),
              );
            }
            if (!snap.hasData || snap.data!.isEmpty) {
              return _emptyContactsState();
            }
            final contacts = snap.data!;
            return Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contacts.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: _border, indent: 68, endIndent: 20),
                itemBuilder: (context, i) => _contactTile(contacts[i], context),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _contactTile(EmergencyContact contact, BuildContext context) {
    final isVerified = contact.verified;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isVerified ? _accent.withOpacity(0.12) : _amber.withOpacity(0.12),
            ),
            child: Center(
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : "?",
                style: TextStyle(
                  color: isVerified ? _accentDark : const Color(0xFFB87A00),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(contact.phone, style: const TextStyle(color: _textSec, fontSize: 12)),
              ],
            ),
          ),
          if (!isVerified)
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VerifyContactScreen(contact: contact)),
                );
                if (result == true) setState(_refreshData);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _amber.withOpacity(0.3), width: 1),
                ),
                child: const Text(
                  "Verify",
                  style: TextStyle(
                      color: Color(0xFFB87A00), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified_rounded, color: _accentDark, size: 12),
                  SizedBox(width: 4),
                  Text("Verified",
                      style: TextStyle(
                          color: _accentDark, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: _textSec.withOpacity(0.5), size: 20),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'remove') {
                _showDeleteConfirmation(contact);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline_rounded, color: _danger, size: 18),
                    SizedBox(width: 10),
                    Text("Remove", style: TextStyle(color: _danger, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Contact", style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text("Are you sure you want to remove ${contact.name} from your emergency contacts?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: _textSec)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeContact(contact.id);
            },
            child: const Text("Remove", style: TextStyle(color: _danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _emptyContactsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _danger.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded, color: _danger, size: 26),
          ),
          const SizedBox(height: 14),
          const Text(
            "No emergency contacts",
            style: TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            "Add someone who can be alerted\nif you trigger an SOS",
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSec, fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}