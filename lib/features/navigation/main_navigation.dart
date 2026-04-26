import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/home_screen.dart';
import '../map/live_map_screen.dart';
import '../sos/sos_screen.dart';
import '../profile/profile_screen.dart';
import '../report/report_incident_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {

  int _selectedIndex = 0;

  late AnimationController _sosController;
  late AnimationController _pulseController;
  late Animation<double>   _sosScaleAnimation;
  late Animation<double>   _pulseAnimation;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent  = Color(0xFF00C896);
  static const Color _danger  = Color(0xFFFF4D6A);
  static const Color _textPri = Color(0xFF0D1B2A);
  static const Color _textSec = Color(0xFF7A8FA6);
  static const Color _border  = Color(0xFFE8EDF3);
  static const Color _bg      = Color(0xFFF5F7FA);
  // ───────────────────────────────────────────────────────────────────────────

  final List<Widget> _screens = const [
    HomeScreen(),
    LiveMapScreen(),
    SosScreen(),
    ReportIncidentScreen(),
    ProfileScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.home_rounded,          Icons.home_outlined,          "Home",    0),
    _NavItem(Icons.map_rounded,           Icons.map_outlined,           "Map",     1),
    _NavItem(Icons.report_rounded,        Icons.report_outlined,        "Report",  3),
    _NavItem(Icons.person_rounded,        Icons.person_outline_rounded, "Profile", 4),
  ];

  @override
  void initState() {
    super.initState();

    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _sosScaleAnimation = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(parent: _sosController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sosController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  void _openSos() {
    HapticFeedback.heavyImpact();
    setState(() => _selectedIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,

      // ✅ extendBody: false (default) — body never goes under the nav bar.
      // This is the correct fix for the LiveMapScreen overlap issue.
      // extendBody: false,  ← this is the default, no need to set it explicitly

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),

      // ── SOS FAB (Sized 68px & Positioned Lower) ──────────────────
      floatingActionButton: _selectedIndex == 2
          ? null
          : Transform.translate(
        offset: const Offset(0, 12), // Pushes the button 12 pixels down
        child: GestureDetector(
          onTapDown: (_) => _sosController.forward(),
          onTapUp: (_) {
            _sosController.reverse();
            _openSos();
          },
          onTapCancel: () => _sosController.reverse(),
          child: AnimatedBuilder(
            animation: Listenable.merge([_sosScaleAnimation, _pulseAnimation]),
            builder: (_, __) => Transform.scale(
              scale: _sosScaleAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Pulse ring
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _danger.withOpacity(0.12),
                      ),
                    ),
                  ),
                  // 2. Main button
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B81), Color(0xFFFF4D6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _danger.withOpacity(0.40),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.priority_high_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        Text(
                          "SOS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
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

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom nav bar ─────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        // ✅ SafeArea handles the system bottom inset (home indicator on
        // iOS / gesture bar on Android) so the nav items sit above it.
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                Expanded(child: _buildNavItem(_navItems[0])),
                Expanded(child: _buildNavItem(_navItems[1])),
                const SizedBox(width: 72), // gap for centred FAB
                Expanded(child: _buildNavItem(_navItems[2])),
                Expanded(child: _buildNavItem(_navItems[3])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item) {
    final isSelected = _selectedIndex == item.index;

    return GestureDetector(
      onTap: () => _onTabSelected(item.index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected ? _accent.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? _accent : _textSec,
              size: 21,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? _accent : _textSec,
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: isSelected ? 0.1 : 0,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String  label;
  final int     index;
  const _NavItem(this.activeIcon, this.icon, this.label, this.index);
}