import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

bool openExternalUrl(String url) => false;

void downloadBytes(List<int> bytes, String filename) {
  _saveAndShare(bytes, filename);
}

Future<void> _saveAndShare(List<int> bytes, String filename) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan Parkir');
  } catch (e) {
    print('Failed to save or share CSV file: $e');
  }
}
