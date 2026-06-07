// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool openExternalUrl(String url) {
  html.window.open(url, '_blank');
  return true;
}

void downloadBytes(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = filename;
  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}

