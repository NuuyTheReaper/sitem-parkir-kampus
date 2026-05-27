import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double height;
  const ShimmerList({super.key, this.itemCount = 3, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: AppTheme.slate100,
          highlightColor: AppTheme.slate50,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ModernEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icon, size: 56, color: AppTheme.slate400),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate900,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.slate500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(actionLabel!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    )),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showStnkPhotoDialog(BuildContext context, String path) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Foto STNK',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.2)),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.slate600),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.slate100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20)),
            child: Image.network(
              '${AppConstants.uploadBaseUrl}$path',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(48),
                color: AppTheme.slate50,
                child: Column(
                  children: [
                    Icon(Icons.broken_image_rounded,
                        size: 48, color: AppTheme.slate400),
                    const SizedBox(height: 16),
                    Text('Gagal memuat gambar',
                        style: TextStyle(color: AppTheme.slate500, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
