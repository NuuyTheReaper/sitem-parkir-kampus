// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool openExternalUrl(String url) {
  html.window.open(url, '_blank');
  return true;
}
