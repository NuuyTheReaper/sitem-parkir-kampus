// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebMjpegViewer extends StatefulWidget {
  final String streamUrl;
  const WebMjpegViewer({Key? key, required this.streamUrl}) : super(key: key);

  @override
  State<WebMjpegViewer> createState() => _WebMjpegViewerState();
}

class _WebMjpegViewerState extends State<WebMjpegViewer> {
  late String viewId;

  @override
  void initState() {
    super.initState();
    viewId = 'mjpeg-view-${DateTime.now().millisecondsSinceEpoch}';

    final htmlContent = '''
      <html>
        <body style="margin: 0; padding: 0; overflow: hidden; background-color: #000;">
          <img src="${widget.streamUrl}" style="width: 100vw; height: 100vh; object-fit: cover; pointer-events: none;" />
        </body>
      </html>
    ''';
    final dataUri =
        'data:text/html;charset=utf-8,${Uri.encodeComponent(htmlContent)}';

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => html.IFrameElement()
        ..src = dataUri
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..allow = 'camera; microphone; fullscreen; display-capture'
        ..style.overflow = 'hidden',
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: viewId);
  }
}
