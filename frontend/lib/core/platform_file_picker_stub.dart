import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class PickedFileBytes {
  const PickedFileBytes({
    required this.bytes,
    required this.name,
  });

  final Uint8List bytes;
  final String name;
}

Future<PickedFileBytes?> pickImageFile() async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  
  if (image != null) {
    final bytes = await image.readAsBytes();
    return PickedFileBytes(bytes: bytes, name: image.name);
  }
  return null;
}
