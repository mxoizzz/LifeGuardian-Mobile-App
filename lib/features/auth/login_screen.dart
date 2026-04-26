import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifeguardianplus/features/auth/home_screen.dart';
import 'package:lifeguardianplus/services/user_service.dart';
import 'auth_service.dart';
import 'register_screen.dart';
import '../auth/home_screen.dart'; // Make sure this path is correct

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService                  = AuthService();
  final UserService _userService                  = UserService();

  bool _loading        = false;
  bool _obscurePass    = true;
  bool _emailFocused   = false;
  bool _passFocused    = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double>   _fadeAnimation;
  late Animation<Offset>   _slideAnimation;

  // ── Design tokens ────────────────────────────────────────────────────────
  static const Color _bg        = Color(0xFFF5F7FA);
  static const Color _surface   = Color(0xFFFFFFFF);
  static const Color _accent    = Color(0xFF00C896);
  static const Color _textPri   = Color(0xFF0D1B2A);
  static const Color _textSec   = Color(0xFF7A8FA6);
  static const Color _border    = Color(0xFFE8EDF3);
  static const Color _danger    = Color(0xFFFF4D6A);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // NEW: Google Sign-In Logic
  void _loginWithGoogle() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);

    try {
      final user = await _authService.signUpWithGoogle();
      if (user != null && mounted) {
        // 1. Fetch available details from the Google account
        String displayName = user.displayName ?? "User";
        String email = user.email ?? "";
        String photoUrl = user.photoURL ?? ""; // You can store this too!

        // 2. We don't have the phone yet, so we pass an empty string or 'Not Provided'
        await _userService.createUser(
          uid: user.uid,
          name: displayName,
          email: email,
          phone: "", // Phone is empty for now
        );

        _showSnack("Welcome, $displayName!", success: true);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      // ... handle error
    }
  }

  void _login() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);

    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      _showSnack("Welcome back!", success: true);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _showSnack("Invalid email or password");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white, size: 17),
            const SizedBox(width: 10),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
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
      resizeToAvoidBottomInset: true,
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
                  const SizedBox(height: 52),
                  _buildBrand(),
                  const SizedBox(height: 44),
                  _buildHeaders(),
                  const SizedBox(height: 40),
                  _buildFormCard(),
                  const SizedBox(height: 28),
                  _buildDivider(),
                  const SizedBox(height: 28),
                  _buildGoogleButton(), // NEW: Google Button
                  const SizedBox(height: 20),
                  _buildRegisterCTA(),
                  const SizedBox(height: 36),
                  _buildFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Text("LifeGuardian", style: TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildHeaders() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Welcome back", style: TextStyle(color: _textPri, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1)),
        SizedBox(height: 8),
        Text("Sign in to continue staying safe", style: TextStyle(color: _textSec, fontSize: 15, fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel("Email address"),
          const SizedBox(height: 8),
          _buildField(controller: _emailController, hint: "you@example.com", icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, isFocused: _emailFocused, onFocusChange: (v) => setState(() => _emailFocused = v)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _fieldLabel("Password"),
              GestureDetector(onTap: () {}, child: const Text("Forgot password?", style: TextStyle(color: _accent, fontSize: 12.5, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 8),
          _buildField(controller: _passwordController, hint: "••••••••", icon: Icons.lock_outline_rounded, obscure: _obscurePass, isFocused: _passFocused, onFocusChange: (v) => setState(() => _passFocused = v), suffix: GestureDetector(onTap: () => setState(() => _obscurePass = !_obscurePass), child: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _textSec, size: 18))),
          const SizedBox(height: 26),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5))
            : GestureDetector(
          onTap: _login,
          child: Container(
            decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _accent.withOpacity(0.30), blurRadius: 16, offset: const Offset(0, 6))]),
            child: const Center(child: Text("Sign In", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2))),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: _border, thickness: 1)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text("or", style: TextStyle(color: _textSec.withOpacity(0.7), fontSize: 13))),
        Expanded(child: Divider(color: _border, thickness: 1)),
      ],
    );
  }

  // NEW: Google Sign-In Button Widget
  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _loading ? null : _loginWithGoogle,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Note: Use a Google icon image here if you have one in assets
            const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 32),
            const SizedBox(width: 8),
            Text("Continue with Google", style: TextStyle(color: _textPri.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCTA() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border, width: 1.5)),
        child: Center(child: RichText(text: const TextSpan(text: "Don't have an account? ", style: TextStyle(color: _textSec, fontSize: 14, fontWeight: FontWeight.w400), children: [TextSpan(text: "Create one", style: TextStyle(color: _accent, fontWeight: FontWeight.w700))]))),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(child: Text("Your safety is our priority. Always.", style: TextStyle(color: _textSec.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w400)));
  }

  Widget _fieldLabel(String label) {
    return Text(label, style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1));
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, bool isFocused = false, TextInputType keyboardType = TextInputType.text, required ValueChanged<bool> onFocusChange, Widget? suffix}) {
    return Focus(
      onFocusChange: onFocusChange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(color: isFocused ? _accent.withOpacity(0.04) : const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: isFocused ? _accent : _border, width: isFocused ? 1.5 : 1.0)),
        child: TextField(
          controller: controller, obscureText: obscure, keyboardType: keyboardType,
          style: const TextStyle(color: _textPri, fontSize: 14.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: _textSec.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w400), prefixIcon: Icon(icon, color: isFocused ? _accent : _textSec, size: 18), suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 14), child: suffix) : null, suffixIconConstraints: const BoxConstraints(), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15)),
        ),
      ),
    );
  }
}