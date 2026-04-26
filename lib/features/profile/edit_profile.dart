import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🔥 ADD THESE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {

  // 🔥 Controllers
  final _nameController  = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // 🔥 Firebase
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _loading = false;
  bool _nameFocused = false;
  bool _emailFocused = false;
  bool _phoneFocused = false;

  // ── Animations ─────────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double>   _fadeAnimation;
  late Animation<Offset>   _slideAnimation;

  // ── Design tokens ──────────────────────────────────────────
  static const Color _bg      = Color(0xFFF5F7FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent  = Color(0xFF00C896);
  static const Color _textPri = Color(0xFF0D1B2A);
  static const Color _textSec = Color(0xFF7A8FA6);
  static const Color _border  = Color(0xFFE8EDF3);

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 17,
            ),
            const SizedBox(width: 10),

            // 🔥 FIX HERE
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor:
        isError ? const Color(0xFFFF4D6A) : const Color(0xFF00C896),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchUserData(); // 🔥 Fetch data when screen opens
  }

  // 🔥 Animation setup
  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
  }

  // 🔥 FETCH USER DATA FROM FIRESTORE
  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc =
      await _firestore.collection("users").doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;

        setState(() {
          _nameController.text  = data["name"] ?? "";
          _emailController.text = data["email"] ?? user.email ?? "";
          _phoneController.text = data["phone"] ?? "";
        });
      }
    } catch (e) {
      print("Fetch Error: $e");
    }
  }

  // 🔥 SAVE UPDATED DATA
  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();

    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      _showSnackBar("Update failed: Name and Phone Number Required.", isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection("users").doc(user.uid).set({
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "phone": _phoneController.text.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showSnackBar("Profile updated successfully", isError: false);
        Navigator.pop(context, true); // 🔥 send success signal
      }
    } catch (e) {
      print("Update Error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update Failed")),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
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

                  // Header
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
                      const Text(
                        "Edit Profile",
                        style: TextStyle(
                            color: _textPri,
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                            Border.all(color: _surface, width: 4),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: CircleAvatar(
                            backgroundColor: _accent,
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0]
                                  .toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        _buildField(
                          label: "Full Name",
                          controller: _nameController,
                          hint: "John Doe",
                          icon: Icons.person_outline_rounded,
                          isFocused: _nameFocused,
                          onFocusChange: (v) =>
                              setState(() => _nameFocused = v),
                        ),
                        const SizedBox(height: 20),
                        _buildField(
                          label: "Email Address",
                          controller: _emailController,
                          hint: "john@example.com",
                          icon: Icons.email_outlined,
                          isFocused: _emailFocused,
                          onFocusChange: (v) =>
                              setState(() => _emailFocused = v),
                        ),
                        const SizedBox(height: 20),
                        _buildField(
                          label: "Phone Number",
                          controller: _phoneController,
                          hint: "+91 XXXXX XXXXX",
                          icon: Icons.phone_outlined,
                          isFocused: _phoneFocused,
                          onFocusChange: (v) =>
                              setState(() => _phoneFocused = v),
                        ),
                        const SizedBox(height: 32),

                        // Save Button
                        GestureDetector(
                          onTap: _loading ? null : _handleSave,
                          child: Container(
                            height: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius:
                              BorderRadius.circular(18),
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : const Text(
                              "Save Changes",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight:
                                  FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isFocused,
    required ValueChanged<bool> onFocusChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _textPri,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: onFocusChange,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isFocused
                  ? _accent.withOpacity(0.04)
                  : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isFocused ? _accent : _border),
            ),
            child: TextField(
              controller: controller,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon,
                    color: isFocused ? _accent : _textSec),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}