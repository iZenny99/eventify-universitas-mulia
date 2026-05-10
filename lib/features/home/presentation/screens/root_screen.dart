import 'package:flutter/material.dart';

import '../../../../core/utils/spacing.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../attendance/presentation/screens/qr_screen.dart';
import '../../../certificates/presentation/screens/certificates_screen.dart';
import '../../../events/presentation/screens/my_events_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'home_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  // Helper agar halaman anak (tab) bisa mengakses fungsi pindah tab
  static RootScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<RootScreenState>();

  @override
  RootScreenState createState() => RootScreenState();
}

class RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _pages = const [
    HomeScreen(),
    MyEventsScreen(),
    QrScreen(),
    CertificatesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 520 ? 520.0 : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: maxWidth,
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: IndexedStack(index: _currentIndex, children: _pages),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, // Hapus const
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)), // Hapus const
        ),
        child: NavigationBar(
          elevation: 0,
          backgroundColor: AppColors.surface,
          selectedIndex: _currentIndex,
          indicatorColor: AppColors.primary.withOpacity(0.1),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: changeTab,
          destinations: [
            _buildNavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
            _buildNavItem(Icons.event_note_outlined, Icons.event_note_rounded, 'Events'),
            _buildNavItem(Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, 'Check-in'),
            _buildNavItem(Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, 'Certif'),
            _buildNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  NavigationDestination _buildNavItem(IconData icon, IconData activeIcon, String label) {
    return NavigationDestination(
      icon: Icon(icon, color: AppColors.textSecondary, size: 24),
      selectedIcon: Icon(activeIcon, color: AppColors.primary, size: 24),
      label: label,
    );
  }
}
