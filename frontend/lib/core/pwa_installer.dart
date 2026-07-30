import 'package:flutter/foundation.dart';
// Conditional import to prevent errors on non-web platforms
import 'dart:js_interop' as js_interop;
import 'dart:js_util' as js_util;

class PwaInstaller {
  /// Checks if the PWA can be installed (beforeinstallprompt was fired)
  static bool get canInstall {
    if (!kIsWeb) return false;
    try {
      final installable = js_util.getProperty(js_util.globalThis, 'pwaInstallable');
      return installable == true;
    } catch (e) {
      return false;
    }
  }

  /// Triggers the browser install prompt
  static void promptInstall() {
    if (!kIsWeb) return;
    try {
      js_util.callMethod(js_util.globalThis, 'promptInstall', []);
    } catch (e) {
      debugPrint('Failed to prompt install: $e');
    }
  }

  /// Downloads the APK file hosted on the server
  static void downloadApk() {
    if (!kIsWeb) return;
    try {
      final document = js_util.getProperty(js_util.globalThis, 'document');
      final anchor = js_util.callMethod(document, 'createElement', ['a']);
      js_util.setProperty(anchor, 'href', 'app.apk');
      js_util.setProperty(anchor, 'download', 'app.apk');
      js_util.setProperty(anchor, 'target', '_blank');
      
      final body = js_util.getProperty(document, 'body');
      js_util.callMethod(body, 'appendChild', [anchor]);
      js_util.callMethod(anchor, 'click', []);
      js_util.callMethod(body, 'removeChild', [anchor]);
    } catch (e) {
      debugPrint('Failed to download APK: $e');
    }
  }
}
