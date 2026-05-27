import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Shared bottom navigation bar component with smooth animations
/// Based on the modern mahasiswa dashboard navbar design
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavBarItem> items;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.slate900.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = currentIndex == index;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with smooth scale animation and badge support
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: Icon(
                                item.icon,
                                size: 24,
                                color: isSelected ? AppTheme.maroon : AppTheme.slate400,
                              ),
                            ),
                            // Badge for notifications
                            if (item.badgeCount != null && item.badgeCount! > 0)
                              Positioned(
                                right: -8,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    item.badgeCount! > 9 ? '9+' : '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Label with fade animation
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            fontSize: isSelected ? 12 : 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.maroon : AppTheme.slate400,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Navigation bar item model
class NavBarItem {
  final String label;
  final IconData icon;
  final int? badgeCount;

  const NavBarItem({
    required this.label,
    required this.icon,
    this.badgeCount,
  });
}
