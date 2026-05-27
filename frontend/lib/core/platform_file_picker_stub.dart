import 'dart:typed_data';

class PickedFileBytes {
  const PickedFileBytes({
    required this.bytes,
    required this.name,
  });

  final Uint8List bytes;
  final String name;
}

Future<PickedFileBytes?> pickImageFile() {
  throw UnsupportedError('Upload file hanya tersedia di versi web.');
}
