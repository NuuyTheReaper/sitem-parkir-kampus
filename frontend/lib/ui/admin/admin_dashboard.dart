import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
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
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _connectWS();
  }

  void _connectWS() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConstants.wsUrl));
      _channel!.stream.listen((message) {
        if (mounted) {
          ref.read(refreshTriggerProvider.notifier).state++;
        }
      },
          onError: (_) =>
              Future.delayed(const Duration(seconds: 5), _connectWS));
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  // Consolidated to 4 main navigation items
  final List<Widget> _pages = const [
    DashboardTab(),
    ManagementTab(),
    ActivityTab(),
    ProfileTab(),
  ];

  final List<NavBarItem> _navItems = const [
    NavBarItem(label: 'Overview', icon: IconlyLight.category),
    NavBarItem(label: 'Kelola', icon: IconlyLight.setting),
    NavBarItem(label: 'Aktivitas', icon: Icons.receipt_long_rounded),
    NavBarItem(label: 'Profil', icon: IconlyLight.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Admin Dashboard',
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
