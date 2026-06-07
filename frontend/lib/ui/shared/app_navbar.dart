import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Shared bottom navigation bar component with curved notch and premium slide animations
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
            final double width = constraints.maxWidth;

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: currentIndex.toDouble(), end: currentIndex.toDouble()),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack, // Playful bounce for the sliding notch
              builder: (context, animValue, child) {
                final double itemWidth = width / items.length;
                final double activeX = (animValue + 0.5) * itemWidth;

                return SizedBox(
                  height: 88,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Custom Painted Curved Background
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

                      // 2. Floating White Bubble in the notch
                      Positioned(
                        left: activeX - 7,
                        top: 9,
                        width: 14,
                        height: 14,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                      // 3. Row of Interactive Navigation Tabs
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 16,
                        height: 72,
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
                                  height: 72,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Inactive State: Gray Icon only (no label, matching reference image)
                                      AnimatedOpacity(
                                        opacity: isSelected ? 0.0 : 1.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: isSelected
                                            ? const SizedBox.shrink()
                                            : Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Icon(
                                                    item.icon,
                                                    size: 24,
                                                    color: AppTheme.slate400,
                                                  ),
                                                  if (item.badgeCount != null && item.badgeCount! > 0)
                                                    Positioned(
                                                      right: -6,
                                                      top: -6,
                                                      child: _buildBadge(item.badgeCount!),
                                                    ),
                                                ],
                                              ),
                                      ),

                                      // Active State: Floating Color Badge + Bold Label
                                      AnimatedOpacity(
                                        opacity: isSelected ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: isSelected
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  AnimatedScale(
                                                    scale: isSelected ? 1.0 : 0.6,
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeOutBack,
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        Container(
                                                          width: 42,
                                                          height: 42,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            gradient: const LinearGradient(
                                                              colors: [
                                                                AppTheme.primary,
                                                                Color(0xFFA63333), // Softer maroon gradient
                                                              ],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: AppTheme.primary.withOpacity(0.3),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, 3),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Icon(
                                                            item.icon,
                                                            size: 20,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        if (item.badgeCount != null && item.badgeCount! > 0)
                                                          Positioned(
                                                            right: -2,
                                                            top: -2,
                                                            child: _buildBadge(item.badgeCount!),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.label.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: AppTheme.primary,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const SizedBox.shrink(),
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

/// Custom Painter to draw a modern card shape with a smooth Bezier notch
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

    const double topY = 16.0;
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

    // Draw the notch path at activeX
    const double notchWidth = 90.0;
    final double startX = activeX - notchWidth / 2;
    final double endX = activeX + notchWidth / 2;

    if (startX > cornerRadius) {
      path.lineTo(startX, topY);
    } else {
      path.lineTo(cornerRadius, topY);
    }

    // Left shoulder and slope down
    path.cubicTo(
      activeX - 32, topY,
      activeX - 28, topY - 8,
      activeX - 22, topY - 8,
    );

    path.cubicTo(
      activeX - 16, topY - 8,
      activeX - 12, topY + 20,
      activeX, topY + 20,
    );

    // Slope up and right shoulder
    path.cubicTo(
      activeX + 12, topY + 20,
      activeX + 16, topY - 8,
      activeX + 22, topY - 8,
    );

    path.cubicTo(
      activeX + 28, topY - 8,
      activeX + 32, topY,
      endX, topY,
    );

    // Line to top-right corner
    if (endX < width - cornerRadius) {
      path.lineTo(width - cornerRadius, topY);
    } else {
      path.lineTo(width - cornerRadius, topY);
    }

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

    // Draw card shadows (dual layer for floating effect)
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
