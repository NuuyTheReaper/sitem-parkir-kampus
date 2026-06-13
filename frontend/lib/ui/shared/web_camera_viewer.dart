import 'package:flutter/material.dart';
import 'web_camera_viewer_stub.dart'
    if (dart.library.html) 'web_camera_viewer_web.dart' as impl;

class WebCameraController {
  Future<List<int>?> Function()? captureFn;

  Future<List<int>?> capture() async {
    if (captureFn != null) {
      return await captureFn!();
    }
    return null;
  }
}

class WebCameraViewer extends StatefulWidget {
  final WebCameraController controller;
  const WebCameraViewer({super.key, required this.controller});

  @override
  State<WebCameraViewer> createState() => _WebCameraViewerState();
}

class _WebCameraViewerState extends State<WebCameraViewer> {
  @override
  Widget build(BuildContext context) {
    return impl.WebCameraViewerImpl(controller: widget.controller);
  }
}
