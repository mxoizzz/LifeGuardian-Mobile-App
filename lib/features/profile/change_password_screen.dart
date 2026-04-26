import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  // ── Design tokens ────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF5F7FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent  = Color(0xFF00C896);
  static const Color _textPri = Color(0xFF0D1B2A);
  static const Color _textSec = Color(0xFF7A8FA6);
  static const Color _border  = Color(0xFFE8EDF3);
  static const Color _danger  = Color(0xFFFF4D6A);

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── UPDATED: Core Logic with Re-authentication ──────────────────────────
  void _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != null) {
        // 1. Create a credential using the email and the entered CURRENT password
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentController.text.trim(),
        );

        // 2. Re-authenticate the user.
        // This is the step that checks if the "Current Password" is correct.
        await user.reauthenticateWithCredential(credential);

        // 3. If the above didn't throw an error, update to the NEW password
        await user.updatePassword(_newController.text.trim());

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context);
          _showSnackBar("Password updated successfully", _accent);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        String errorMsg = "An error occurred";
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          errorMsg = "The current password you entered is incorrect.";
        } else if (e.code == 'weak-password') {
          errorMsg = "The new password is too weak.";
        } else {
          errorMsg = e.message ?? "Update failed";
        }

        _showSnackBar(errorMsg, _danger);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Something went wrong. Please try again.", _danger);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),

              _buildLabel("Current Password"),
              _buildTextField(
                controller: _currentController,
                hint: "Enter current password",
                isPassword: true,
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),

              const SizedBox(height: 24),
              _buildLabel("New Password"),
              _buildTextField(
                controller: _newController,
                hint: "Minimum 8 characters",
                isPassword: true,
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),

              const SizedBox(height: 24),
              _buildLabel("Confirm New Password"),
              _buildTextField(
                controller: _confirmController,
                hint: "Repeat new password",
                isPassword: true,
                obscure: _obscureNew,
                validator: (val) {
                  if (val == null || val.isEmpty) return "Please confirm your password";
                  if (val != _newController.text) return "Passwords do not match";
                  return null;
                },
              ),

              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Change Password",
          style: TextStyle(color: _textPri, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        SizedBox(height: 8),
        Text(
          "Set a strong password to protect your account security and emergency data.",
          style: TextStyle(color: _textSec, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w500),
      validator: validator ?? (val) {
        if (val == null || val.isEmpty) return "Field required";
        if (val.length < 8) return "Minimum 8 characters";
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0BCCB), fontSize: 14),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _textSec, size: 20),
          onPressed: onToggle,
        ) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _danger, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleUpdate,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accent.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("Update Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}