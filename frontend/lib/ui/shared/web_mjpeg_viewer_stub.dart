import 'package:flutter/material.dart';

class WebMjpegViewer extends StatelessWidget {
  final String streamUrl;
  const WebMjpegViewer({Key? key, required this.streamUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      streamUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: Color(0xFF020617),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_outlined,
                    color: Color(0xFF94A3B8), size: 36),
                SizedBox(height: 8),
                Text(
                  'Preview kamera tidak tersedia',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
