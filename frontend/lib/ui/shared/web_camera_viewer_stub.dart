import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'web_camera_viewer.dart';

class WebCameraViewerImpl extends StatefulWidget {
  final WebCameraController controller;
  const WebCameraViewerImpl({super.key, required this.controller});

  @override
  State<WebCameraViewerImpl> createState() => _WebCameraViewerImplState();
}

class _WebCameraViewerImplState extends State<WebCameraViewerImpl> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    widget.controller.captureFn = _captureFrame;
  }

  @override
  void didUpdateWidget(covariant WebCameraViewerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.captureFn = null;
      widget.controller.captureFn = _captureFrame;
    }
  }

  @override
  void dispose() {
    widget.controller.captureFn = null;
    super.dispose();
  }

  Future<List<int>?> _captureFrame() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 80,
      );
      if (photo != null) {
        return await photo.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error capturing frame via ImagePicker: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.greenAccent,
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kamera Device Siap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Ketuk "Scan Plat" di atas untuk memotret kendaraan menggunakan kamera perangkat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
