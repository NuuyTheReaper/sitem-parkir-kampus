import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Shared bottom navigation bar component with a dome bulge and premium active-rise animation
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

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: currentIndex.toDouble()),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack, // Playful bounce for the sliding dome bulge
              builder: (context, animValue, child) {
                return SizedBox(
                  height: 96,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Custom Painted Dome Bulge Background Card
                      Positioned.fill(
                        child: CustomPaint(
                          painter: NotchedNavbarPainter(
                            activeIndex: animValue,
                            itemCount: items.length,
                            color: Colors.white,
                            shadowColor: AppTheme.slate900.withOpacity(0.06),
                          ),
                        ),
                      ),

                      // 2. Row of Interactive Navigation Tabs
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 96,
                        child: Row(
                          children: items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isSelected = currentIndex == index;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => onTap(index),
                                behavior: HitTestBehavior.opaque,
                                child: SizedBox(
                                  height: 96,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Transforming and Rising Icon Container
                                      AnimatedPositioned(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutBack, // Rises up with a satisfying bounce
                                        top: isSelected ? 8 : 30, // Rises to y = 8 when active, nests inside the dome
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          width: isSelected ? 48 : 36,
                                          height: isSelected ? 48 : 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: isSelected
                                                ? const LinearGradient(
                                                    colors: [
                                                      AppTheme.maroon,
                                                      Color(0xFFA63333),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: AppTheme.maroon.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            clipBehavior: Clip.none,
                                            children: [
                                              Icon(
                                                item.icon,
                                                size: isSelected ? 22 : 24,
                                                color: isSelected ? Colors.white : AppTheme.slate400,
                                              ),
                                              if (item.badgeCount != null && item.badgeCount! > 0)
                                                Positioned(
                                                  right: isSelected ? -2 : -4,
                                                  top: isSelected ? -2 : -4,
                                                  child: _buildBadge(item.badgeCount!),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Label Text: Placed at a fixed baseline at the bottom of the bar
                                      Positioned(
                                        bottom: 12,
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 200),
                                          style: TextStyle(
                                            color: isSelected ? AppTheme.maroon : AppTheme.slate500,
                                            fontSize: 10,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            letterSpacing: -0.1,
                                          ),
                                          child: Text(item.label),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Custom Painter to draw a modern card shape with a smooth bulging dome shape
class NotchedNavbarPainter extends CustomPainter {
  final double activeIndex;
  final int itemCount;
  final Color color;
  final Color shadowColor;

  NotchedNavbarPainter({
    required this.activeIndex,
    required this.itemCount,
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final double width = size.width;
    final double height = size.height;

    const double topY = 20.0;
    const double cornerRadius = 24.0;

    final double itemWidth = width / itemCount;
    final double activeX = (activeIndex + 0.5) * itemWidth;

    final path = Path();

    // Start at bottom-left corner
    path.moveTo(0, height);

    // Line to top-left rounded corner
    path.lineTo(0, topY + cornerRadius);
    path.arcToPoint(
      const Offset(cornerRadius, topY),
      radius: const Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Draw the dome bulge path centered at activeX
    const double domeWidth = 90.0;
    final double startX = (activeX - domeWidth / 2).clamp(cornerRadius, width - cornerRadius);
    final double endX = (activeX + domeWidth / 2).clamp(cornerRadius, width - cornerRadius);

    path.lineTo(startX, topY);

    // Smooth curve rising up to dome peak (y = 0)
    path.cubicTo(
      activeX - 25, topY,
      activeX - 20, 0,
      activeX, 0,
    );

    // Smooth curve falling back down to top baseline (y = topY)
    path.cubicTo(
      activeX + 20, 0,
      activeX + 25, topY,
      endX, topY,
    );

    path.lineTo(width - cornerRadius, topY);

    // Top-right rounded corner
    path.arcToPoint(
      Offset(width, topY + cornerRadius),
      radius: const Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Bottom-right corner
    path.lineTo(width, height - cornerRadius);
    path.arcToPoint(
      Offset(width - cornerRadius, height),
      radius: const Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Bottom-left corner
    path.lineTo(cornerRadius, height);
    path.arcToPoint(
      Offset(0, height - cornerRadius),
      radius: const Radius.circular(cornerRadius),
      clockwise: true,
    );

    path.close();

    // Draw card shadows (dual layer for floating depth)
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw main card body
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NotchedNavbarPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.color != color ||
        oldDelegate.shadowColor != shadowColor;
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
