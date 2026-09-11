import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class ReaderBrightnessController {
  Future<double> getCurrentBrightness();

  Future<void> setBrightness(double value);

  Future<void> resetBrightness();
}

class ScreenBrightnessService implements ReaderBrightnessController {
  static const _channel = MethodChannel('yunchuang/screen_brightness');

  const ScreenBrightnessService();

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<double> getCurrentBrightness() async {
    if (!_isSupported) return 0.5;
    try {
      final value = await _channel.invokeMethod<double>('getBrightness');
      return (value ?? 0.5).clamp(0.05, 1.0);
    } on PlatformException {
      return 0.5;
    } on MissingPluginException {
      return 0.5;
    }
  }

  @override
  Future<void> setBrightness(double value) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>(
        'setBrightness',
        {'value': value.clamp(0.05, 1.0)},
      );
    } on PlatformException {
      // Reading remains usable if a device rejects a window brightness change.
    } on MissingPluginException {
      // Widget tests and unsupported embedding versions have no native channel.
    }
  }

  @override
  Future<void> resetBrightness() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('resetBrightness');
    } on PlatformException {
      // The platform default remains in effect when reset is unavailable.
    } on MissingPluginException {
      // Widget tests and unsupported embedding versions have no native channel.
    }
  }
}
