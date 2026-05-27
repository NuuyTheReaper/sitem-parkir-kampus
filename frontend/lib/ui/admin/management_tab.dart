import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import 'users_tab.dart';
import 'prodi_tab.dart';

/// Management Tab - Simplified management interface
/// Includes: Users (Mahasiswa + Petugas) and Prodi
class ManagementTab extends ConsumerStatefulWidget {
  const ManagementTab({super.key});

  @override
  ConsumerState<ManagementTab> createState() => _ManagementTabState();
}

class _ManagementTabState extends ConsumerState<ManagementTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar Header - Mobile First Design
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.slate200)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.maroon,
            unselectedLabelColor: AppTheme.slate500,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            indicatorColor: AppTheme.maroon,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(
                icon: Icon(Icons.people_rounded, size: 20),
                text: 'Users',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                icon: Icon(Icons.account_balance_rounded, size: 20),
                text: 'Prodi',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              UsersTab(),
              ProdiTab(),
            ],
          ),
        ),
      ],
    );
  }
}
