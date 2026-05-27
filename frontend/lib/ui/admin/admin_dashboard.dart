import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../shared/app_header.dart';
import '../shared/app_navbar.dart';
import '../shared/profile_tab.dart';
import 'dashboard_tab.dart';
import 'management_tab.dart';
import 'activity_tab.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _currentIndex = 0;

  // Consolidated to 4 main navigation items
  final List<Widget> _pages = const [
    DashboardTab(),
    ManagementTab(),
    ActivityTab(),
    ProfileTab(),
  ];

  final List<NavBarItem> _navItems = const [
    NavBarItem(label: 'Overview', icon: Icons.dashboard_rounded),
    NavBarItem(label: 'Kelola', icon: Icons.settings_rounded),
    NavBarItem(label: 'Aktivitas', icon: Icons.receipt_long_rounded),
    NavBarItem(label: 'Profil', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Admin Dashboard',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: _navItems,
      ),
    );
  }
}
