import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Shared app header component for consistent header design across the app
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final List<Widget>? actions;
  final VoidCallback? onLogout;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle = 'Smart Campus Parking',
    this.actions,
    this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.headerGradient,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Logo
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.local_parking,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              
              // Title & Subtitle
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Actions (notifications, logout, etc.)
              if (actions != null) ...actions!,
              
              // Default logout button if no actions provided
              if (actions == null && onLogout != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.white, size: 20),
                    tooltip: 'Keluar',
                    onPressed: onLogout,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
