import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_service.dart';
import '../../model/emergency_contact.dart';

class AddEmergencyContactScreen extends StatefulWidget {
  const AddEmergencyContactScreen({super.key});

  @override
  State<AddEmergencyContactScreen> createState() =>
      _AddEmergencyContactScreenState();
}

class _AddEmergencyContactScreenState
    extends State<AddEmergencyContactScreen> with TickerProviderStateMixin {

  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading     = false;
  bool _nameFocused = false;
  bool _phoneFocused = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double>   _fadeAnimation;
  late Animation<Offset>   _slideAnimation;

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
  static const Color _blue       = Color(0xFF5B8DEF);
  // ───────────────────────────────────────────────────────────────────────────

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Save Logic with Duplicate Check ────────────────────────────────────────

  Future<void> _saveContact() async {
    final name  = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      HapticFeedback.mediumImpact();
      _showSnackbar("Please fill in all fields", color: _amber);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // 1. Check if the number already exists in DB
      final contacts = await UserService().getEmergencyContacts(uid);
      final alreadyExists = contacts.any((c) => c.phone.replaceAll(' ', '') == phone.replaceAll(' ', ''));

      if (alreadyExists) {
        HapticFeedback.heavyImpact();
        _showSnackbar("This number is already in your list", color: _danger);
        setState(() => _loading = false);
        return;
      }

      // 2. Proceed with adding if not a duplicate
      final contact = EmergencyContact(
        id: '',
        name: name,
        phone: phone,
        verified: false,
        createdAt: DateTime.now(),
      );

      await UserService().addEmergencyContact(uid: uid, contact: contact);

      if (!mounted) return;

      _showSnackbar(
        "Contact added — verification pending",
        color: _accent,
        icon: Icons.check_circle_rounded,
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar("An error occurred. Please try again.", color: _danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackbar(String message,
      {required Color color, IconData icon = Icons.error_outline_rounded}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: color,
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
                  const SizedBox(height: 20),
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
                          color: _danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: _danger, size: 19),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Add Contact",
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
                  const Text(
                    "Emergency Contact",
                    style: TextStyle(
                      color: _textPri,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This person will be alerted when you trigger SOS",
                    style: TextStyle(
                      color: _textSec,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _amber.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.info_outline_rounded,
                              color: _amber, size: 16),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "A verification SMS will be sent to this number. The contact must verify to receive SOS alerts.",
                            style: TextStyle(
                              color: Color(0xFFB87A00),
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel("Contact Name"),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _nameController,
                          hint: "e.g. Mom, Priya, Rahul",
                          icon: Icons.person_outline_rounded,
                          isFocused: _nameFocused,
                          onFocusChange: (v) =>
                              setState(() => _nameFocused = v),
                        ),
                        const SizedBox(height: 20),
                        _fieldLabel("Phone Number"),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _phoneController,
                          hint: "+91XXXXXXXXXX",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          isFocused: _phoneFocused,
                          onFocusChange: (v) =>
                              setState(() => _phoneFocused = v),
                        ),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints.expand(height: 62),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _loading
                                ? Container(
                              key: const ValueKey('loading'),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    color: _accent,
                                    strokeWidth: 3.0,
                                  ),
                                ),
                              ),
                            )
                                : GestureDetector(
                              key: const ValueKey('button'),
                              onTap: _saveContact,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accent.withOpacity(0.35),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.person_add_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Save Contact",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStepsCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepsCard() {
    final steps = [
      _Step(Icons.send_rounded,           _accent, "Contact is saved to your profile"),
      _Step(Icons.sms_rounded,            _blue,   "Verification SMS is sent to their number"),
      _Step(Icons.verified_user_rounded,  _danger, "Once verified, they receive SOS alerts"),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What happens next",
            style: TextStyle(
              color: _textPri,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            final i    = e.key;
            final step = e.value;
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: step.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(step.icon,
                              color: step.color, size: 16),
                        ),
                        if (i < steps.length - 1)
                          Container(
                            width: 1.5,
                            height: 24,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: _border,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        step.label,
                        style: const TextStyle(
                          color: _textPri,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _textPri,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isFocused = false,
    TextInputType keyboardType = TextInputType.text,
    required ValueChanged<bool> onFocusChange,
  }) {
    return Focus(
      onFocusChange: onFocusChange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isFocused
              ? _accent.withOpacity(0.04)
              : const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFocused ? _accent : _border,
            width: isFocused ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: _textPri,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: _textSec.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon,
                color: isFocused ? _accent : _textSec, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final Color    color;
  final String   label;
  const _Step(this.icon, this.color, this.label);
}