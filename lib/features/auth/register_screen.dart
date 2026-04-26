import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import '../../services/user_service.dart';
import '../auth/home_screen.dart'; // Adjust this path to your Home Screen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {

  final TextEditingController _nameController     = TextEditingController();
  final TextEditingController _phoneController    = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService  _authService  = AuthService();
  final UserService  _userService  = UserService();

  bool _loading     = false;
  bool _obscurePass = true;
  bool _nameFocused  = false;
  bool _phoneFocused = false;
  bool _emailFocused = false;
  bool _passFocused  = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double>   _fadeAnimation;
  late Animation<Offset>   _slideAnimation;

  static const Color _bg         = Color(0xFFF5F7FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _accent     = Color(0xFF00C896);
  static const Color _accentDark = Color(0xFF00A87C);
  static const Color _textPri    = Color(0xFF0D1B2A);
  static const Color _textSec    = Color(0xFF7A8FA6);
  static const Color _border     = Color(0xFFE8EDF3);
  static const Color _danger     = Color(0xFFFF4D6A);

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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- NEW: Google Sign Up Logic ---
  void _registerWithGoogle() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      final user = await _authService.signUpWithGoogle();
      if (user != null && mounted) {
        // 1. Get whatever Google gives us
        String name = user.displayName ?? "New User";
        String email = user.email ?? "";

        // 2. Save to Firestore (phone will be empty for now)
        await _userService.createUser(
          uid: user.uid,
          name: name,
          email: email,
          phone: "", // Google doesn't provide this!
        );

        _showSnackBar("Welcome, $name!", isError: false);

        // 3. Logic: If phone is empty, send to a screen to collect it
        // For now, let's just go home
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false
        );
      }
    } catch (e) {
      print("Log: Google Sign-up error: $e");
      if (mounted) _showSnackBar("Sign-up failed", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _register() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      final user = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (user != null && mounted) {
        await _userService.createUser(
          uid: user.uid,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        _showSnackBar("Account created! Welcome aboard.", isError: false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) _showSnackBar("Registration failed. Try again.", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 17),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: isError ? _danger : _accent,
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
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        const Text("Create account", style: TextStyle(color: _textPri, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1)),
                        const SizedBox(height: 8),
                        const Text("Join LifeGuardian and stay protected", style: TextStyle(color: _textSec, fontSize: 15, fontWeight: FontWeight.w400)),
                        const SizedBox(height: 28),
                        _buildStepIndicator(),
                        const SizedBox(height: 26),
                        _buildFormCard(),
                        const SizedBox(height: 24),

                        // --- NEW: Divider & Google Button ---
                        _buildDivider(),
                        const SizedBox(height: 24),
                        _buildGoogleButton(),

                        const SizedBox(height: 22),
                        _buildTrustBadges(),
                        const SizedBox(height: 22),
                        _buildSignInCTA(),
                        const SizedBox(height: 20),
                        _buildFooterText(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 38, height: 38, decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: const Icon(Icons.arrow_back_rounded, color: _textPri, size: 18)),
        ),
        const SizedBox(width: 14),
        Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16)),
          const SizedBox(width: 8),
          const Text("LifeGuardian", style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        ]),
      ]),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldLabel("Full Name"),
        const SizedBox(height: 8),
        _buildField(controller: _nameController, hint: "Arjun Sharma", icon: Icons.person_outline_rounded, isFocused: _nameFocused, onFocusChange: (v) => setState(() => _nameFocused = v)),
        const SizedBox(height: 18),
        _fieldLabel("Phone Number"),
        const SizedBox(height: 8),
        _buildField(controller: _phoneController, hint: "+91 98765 43210", icon: Icons.phone_outlined, keyboardType: TextInputType.phone, isFocused: _phoneFocused, onFocusChange: (v) => setState(() => _phoneFocused = v)),
        const SizedBox(height: 18),
        _fieldLabel("Email Address"),
        const SizedBox(height: 8),
        _buildField(controller: _emailController, hint: "you@example.com", icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, isFocused: _emailFocused, onFocusChange: (v) => setState(() => _emailFocused = v)),
        const SizedBox(height: 18),
        _fieldLabel("Password"),
        const SizedBox(height: 8),
        _buildField(controller: _passwordController, hint: "Min. 8 characters", icon: Icons.lock_outline_rounded, obscure: _obscurePass, isFocused: _passFocused, onFocusChange: (v) => setState(() => _passFocused = v), suffix: GestureDetector(onTap: () => setState(() => _obscurePass = !_obscurePass), child: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _textSec, size: 18))),
        const SizedBox(height: 10),
        _passwordHint(),
        const SizedBox(height: 26),
        _buildRegisterButton(),
      ]),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _loading ? null : _registerWithGoogle,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border, width: 1.5)),
        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 30),
          SizedBox(width: 8),
          Text("Sign up with Google", style: TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Divider(color: _border, thickness: 1)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text("or", style: TextStyle(color: _textSec.withOpacity(0.7), fontSize: 13))),
      Expanded(child: Divider(color: _border, thickness: 1)),
    ]);
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5))
            : GestureDetector(
          onTap: _register,
          child: Container(
            decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _accent.withOpacity(0.30), blurRadius: 16, offset: const Offset(0, 6))]),
            child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ])),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInCTA() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border, width: 1.5)),
        child: Center(child: RichText(text: const TextSpan(text: "Already have an account? ", style: TextStyle(color: _textSec, fontSize: 14), children: [TextSpan(text: "Sign In", style: TextStyle(color: _accent, fontWeight: FontWeight.w700))]))),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _accent.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: _accent.withOpacity(0.2))),
      child: Row(children: [
        _stepDot(true, "1"), _stepLine(), _stepDot(true, "2"), _stepLine(), _stepDot(false, "3"),
        const SizedBox(width: 12),
        const Text("Almost there — fill in your details", style: TextStyle(color: _accentDark, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _stepDot(bool active, String label) => Container(width: 24, height: 24, decoration: BoxDecoration(color: active ? _accent : _border, shape: BoxShape.circle), child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : _textSec, fontSize: 11, fontWeight: FontWeight.w700))));
  Widget _stepLine() => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Container(width: 20, height: 2, decoration: BoxDecoration(color: _accent.withOpacity(0.3), borderRadius: BorderRadius.circular(2))));

  Widget _buildTrustBadges() {
    return Row(children: [
      _trustBadge(Icons.lock_rounded, "Encrypted"), const SizedBox(width: 10),
      _trustBadge(Icons.verified_user_rounded, "Verified"), const SizedBox(width: 10),
      _trustBadge(Icons.privacy_tip_rounded, "Private"),
    ]);
  }

  Widget _trustBadge(IconData icon, String label) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Column(children: [Icon(icon, color: _accent, size: 17), const SizedBox(height: 4), Text(label, style: const TextStyle(color: _textSec, fontSize: 10.5, fontWeight: FontWeight.w600))])));

  Widget _passwordHint() => Row(children: [Icon(Icons.info_outline_rounded, color: _textSec.withOpacity(0.6), size: 13), const SizedBox(width: 5), Text("Use at least 8 characters with a number", style: TextStyle(color: _textSec.withOpacity(0.7), fontSize: 11.5))]);

  Widget _buildFooterText() => Center(child: Text("By creating an account, you agree to our\nTerms of Service & Privacy Policy", textAlign: TextAlign.center, style: TextStyle(color: _textSec.withOpacity(0.55), fontSize: 11.5, height: 1.6)));

  Widget _fieldLabel(String label) => Text(label, style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, bool isFocused = false, TextInputType keyboardType = TextInputType.text, required ValueChanged<bool> onFocusChange, Widget? suffix}) {
    return Focus(
      onFocusChange: onFocusChange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(color: isFocused ? _accent.withOpacity(0.04) : const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: isFocused ? _accent : _border, width: isFocused ? 1.5 : 1.0)),
        child: TextField(
          controller: controller, obscureText: obscure, keyboardType: keyboardType,
          style: const TextStyle(color: _textPri, fontSize: 14.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: isFocused ? _accent : _textSec, size: 18), suffixIcon: suffix, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15)),
        ),
      ),
    );
  }
}