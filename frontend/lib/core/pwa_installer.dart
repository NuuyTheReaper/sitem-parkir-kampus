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
}
