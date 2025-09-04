import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

bool get isMobile {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

bool get isWeb => kIsWeb;
