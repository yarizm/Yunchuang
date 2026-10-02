import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/pages/settings/tts_settings.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/external_tts.dart';
import 'package:yunchuang/services/tts_service.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

class _SilentSynthesizer implements SpeechSynthesizer {
  @override
  Future<Uint8List> synthesize(String text, {required double speed}) async =>
      Uint8List(0);
}

void main() {
  testWidgets('external speech service can be configured and turned off',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final flutterTts = _MockFlutterTts();
    when(() => flutterTts.getLanguages).thenAnswer((_) async => ['zh-CN']);
    when(() => flutterTts.getVoices).thenAnswer((_) async => const []);
    when(() => flutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => flutterTts.stop()).thenAnswer((_) async => 1);
    // ProviderScope 拆掉时会 dispose 它，这里不用再管。
    final service = TTSService(
      flutterTts: flutterTts,
      createSynthesizer: (_) => _SilentSynthesizer(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ttsServiceProvider.overrideWith((ref) => service),
        ],
        child: const MaterialApp(home: TtsSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('external-tts-base-url')), findsNothing);
    await tester.tap(find.text('外部语音服务'));
    await tester.pumpAndSettle();

    // 开了但没填全：还用系统语音。
    expect(find.text('还没填全，朗读暂时仍用系统语音。'), findsOneWidget);
    expect(service.engine, TTSEngine.system);

    await tester.enterText(
      find.byKey(const Key('external-tts-base-url')),
      'http://192.168.1.5:5050/v1',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('都要填'), findsOneWidget);
    expect(service.engine, TTSEngine.system);

    await tester.enterText(
        find.byKey(const Key('external-tts-model')), 'tts-1');
    await tester.enterText(
      find.byKey(const Key('external-tts-voice')),
      ' zh-CN-XiaoxiaoNeural ',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.engine, TTSEngine.external);
    expect(service.externalSettings.voice, 'zh-CN-XiaoxiaoNeural');
    expect(preferences.getBool(ExternalTtsSettings.enabledKey), isTrue);
    expect(
      preferences.getString(ExternalTtsSettings.baseUrlKey),
      'http://192.168.1.5:5050/v1',
    );
    expect(preferences.getString(ExternalTtsSettings.apiKeyKey), '');
    expect(find.text('还没填全，朗读暂时仍用系统语音。'), findsNothing);
    expect(find.text('已就绪（zh-CN-XiaoxiaoNeural）'), findsOneWidget);

    await tester.tap(find.text('系统语音'));
    await tester.pumpAndSettle();

    expect(service.engine, TTSEngine.system);
    expect(preferences.getBool(ExternalTtsSettings.enabledKey), isFalse);
    // 关掉只是不用，填过的地址留着，下次打开不用重填。
    expect(service.externalSettings.voice, 'zh-CN-XiaoxiaoNeural');
    expect(find.byKey(const Key('external-tts-base-url')), findsNothing);
  });
}
