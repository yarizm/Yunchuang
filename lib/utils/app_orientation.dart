import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 只有手机才有「横屏阅读」这回事：桌面窗口没有方向，
/// `SystemChrome.setPreferredOrientations` 在那里是空操作。
bool get supportsReaderLandscape =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// 按全局偏好（`preferredOrientation`：auto / portrait / landscape）设置方向。
Future<void> applyAppOrientation(String preference) {
  switch (preference) {
    case 'portrait':
      return SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    case 'landscape':
      return applyReaderLandscape();
    default: // 'auto'
      return SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}

/// 阅读器专用：锁横屏。退出阅读器时用 [applyAppOrientation] 交还。
Future<void> applyReaderLandscape() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}
