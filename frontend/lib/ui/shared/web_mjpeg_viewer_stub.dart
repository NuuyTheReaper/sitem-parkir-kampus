import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class WebMjpegViewer extends StatefulWidget {
  final String streamUrl;
  const WebMjpegViewer({super.key, required this.streamUrl});

  @override
  State<WebMjpegViewer> createState() => _WebMjpegViewerState();
}

class _WebMjpegViewerState extends State<WebMjpegViewer> {
  Uint8List? _frameBytes;
  StreamSubscription<List<int>>? _streamSubscription;
  HttpClient? _client;
  bool _hasError = false;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(covariant WebMjpegViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _streamSubscription?.cancel();
    _client?.close(force: true);
  }

  void _startStream() async {
    if (!mounted) return;
    setState(() {
      _frameBytes = null;
      _hasError = false;
      _isConnecting = true;
    });

    try {
      _client = HttpClient();
      _client!.connectionTimeout = const Duration(seconds: 10);
      
      final uri = Uri.parse(widget.streamUrl);
      final request = await _client!.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isConnecting = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }

      List<int> buffer = [];
      _streamSubscription = response.listen(
        (List<int> chunk) {
          buffer.addAll(chunk);

          // Safety check: prevent buffer from growing indefinitely if stream is invalid
          if (buffer.length > 5 * 1024 * 1024) {
            buffer.clear();
          }

          while (true) {
            // Find SOI (0xFF, 0xD8)
            int soiIndex = -1;
            for (int i = 0; i < buffer.length - 1; i++) {
              if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
                soiIndex = i;
                break;
              }
            }

            if (soiIndex == -1) {
              // No SOI found. Clear buffer, keeping only last byte if it might be start of 0xFF
              if (buffer.isNotEmpty) {
                int lastByte = buffer.last;
                buffer.clear();
                if (lastByte == 0xFF) {
                  buffer.add(0xFF);
                }
              }
              break;
            }

            // Find EOI (0xFF, 0xD9)
            int eoiIndex = -1;
            for (int i = soiIndex; i < buffer.length - 1; i++) {
              if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
                eoiIndex = i + 1; // Include 0xD9
                break;
              }
            }

            if (eoiIndex == -1) {
              // EOI not found yet. Keep buffer from soiIndex onwards and wait for more data.
              if (soiIndex > 0) {
                buffer = buffer.sublist(soiIndex);
              }
              break;
            }

            // Frame extracted!
            final frame = buffer.sublist(soiIndex, eoiIndex + 1);
            if (mounted) {
              setState(() {
                _frameBytes = Uint8List.fromList(frame);
              });
            }

            // Remove processed frame from buffer
            buffer = buffer.sublist(eoiIndex + 1);
          }
        },
        onError: (err) {
          debugPrint('MJPEG Stream error: $err');
          if (mounted) {
            setState(() {
              _hasError = true;
              _isConnecting = false;
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Error starting MJPEG stream: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }
    
    if (_isConnecting) {
      return const ColoredBox(
        color: Color(0xFF020617),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.greenAccent),
              SizedBox(height: 12),
              Text(
                'Menghubungkan ke kamera...',
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
    }

    if (_frameBytes == null) {
      return const ColoredBox(
        color: Color(0xFF020617),
        child: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Image.memory(
      _frameBytes!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }

  Widget _buildErrorWidget() {
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
  }
}
