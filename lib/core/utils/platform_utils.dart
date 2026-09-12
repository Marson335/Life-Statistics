import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppPlatform {
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isDesktop => isWindows;
  static bool get isMobile => isAndroid;
}
