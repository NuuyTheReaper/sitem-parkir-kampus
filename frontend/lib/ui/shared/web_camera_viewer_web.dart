// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'web_camera_viewer.dart';

class WebCameraViewerImpl extends StatefulWidget {
  final WebCameraController controller;
  const WebCameraViewerImpl({super.key, required this.controller});

  @override
  State<WebCameraViewerImpl> createState() => _WebCameraViewerImplState();
}

class _WebCameraViewerImplState extends State<WebCameraViewerImpl> {
  late String viewId;
  html.VideoElement? _videoElement;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    viewId = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';

    _videoElement = html.VideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..autoplay = true
      ..muted = true;

    widget.controller.captureFn = _captureFrame;

    html.window.navigator.mediaDevices?.getUserMedia({'video': true}).then((initialStream) {
      initialStream.getTracks().forEach((track) => track.stop());
      
      html.window.navigator.mediaDevices?.enumerateDevices().then((devices) {
        final videoDevices = devices.where((d) => d.kind == 'videoinput').toList();
        if (videoDevices.isEmpty) return;
        
        var selectedDevice = videoDevices.first;
        for (var device in videoDevices) {
          final label = (device.label ?? '').toLowerCase();
          if (label.contains('usb') || label.contains('external') || label.contains('webcam')) {
            selectedDevice = device;
            break;
          }
        }
        if (selectedDevice == videoDevices.first && videoDevices.length > 1) {
          selectedDevice = videoDevices.last;
        }
        
        final constraints = {
          'video': {
            'deviceId': {'exact': selectedDevice.deviceId}
          }
        };
        
        html.window.navigator.mediaDevices?.getUserMedia(constraints).then((stream) {
          if (mounted) {
            setState(() {
              _videoElement?.srcObject = stream;
            });
          }
        });
      });
    }).catchError((err) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = err.toString();
        });
      }
    });

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _videoElement!,
    );
  }

  @override
  void didUpdateWidget(covariant WebCameraViewerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.captureFn = null;
      widget.controller.captureFn = _captureFrame;
    }
  }

  Future<List<int>?> _captureFrame() async {
    if (_videoElement == null || _videoElement!.videoWidth == 0) return null;

    final canvas = html.CanvasElement(
      width: _videoElement!.videoWidth,
      height: _videoElement!.videoHeight,
    );

    final ctx = canvas.context2D;
    ctx.drawImage(_videoElement!, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
    final base64Str = dataUrl.split(',')[1];
    return base64.decode(base64Str);
  }

  @override
  void dispose() {
    widget.controller.captureFn = null;
    if (_videoElement?.srcObject != null) {
      final stream = _videoElement!.srcObject as html.MediaStream;
      stream.getTracks().forEach((track) => track.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return ColoredBox(
        color: const Color(0xFF020617),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, color: Color(0xFFEF4444), size: 36),
              const SizedBox(height: 8),
              const Text(
                'Akses kamera ditolak / error',
                style: TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return HtmlElementView(viewType: viewId);
  }
}
