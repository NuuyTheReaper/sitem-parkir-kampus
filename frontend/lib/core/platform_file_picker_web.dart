// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
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
  final completer = Completer<PickedFileBytes?>();
  final uploadInput = html.FileUploadInputElement()..accept = 'image/*';

  uploadInput.onChange.first.then((_) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();

    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      final bytes = switch (result) {
        Uint8List data => data,
        ByteBuffer buffer => Uint8List.view(buffer),
        _ => Uint8List(0),
      };

      if (!completer.isCompleted) {
        completer.complete(PickedFileBytes(bytes: bytes, name: file.name));
      }
    }, onError: completer.completeError);

    reader.readAsArrayBuffer(file);
  }, onError: completer.completeError);

  uploadInput.click();
  return completer.future;
}
