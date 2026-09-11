import 'dart:developer' as developer;
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/ai/ai_persona_selection_store.dart';
import 'providers/database_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/ui_provider.dart';
import 'services/backup_service.dart';
import 'services/tts_media_session.dart';
import 'utils/app_data_directory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await BackupService.applyPendingRestore();
  } catch (error) {
    runApp(_StartupFailureApp(message: '$error'));
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  // 恢复出来的全局偏好要等 prefs 就绪才能写回，见 applyPendingPreferences。
  await BackupService.applyPendingPreferences(prefs);
  // 背景图存在这个目录下。路径要在同步的 build 里用到，所以先取出来注入。
  //
  // 拿不到就不注入，绝不让它拦住启动：背景是装饰，而
  // customBackgroundPathProvider 只在真的设过背景图时才会去读这个 provider，
  // 没设过的人根本走不到这里。设过的人最多是背景退回纯色。
  Directory? documentsDirectory;
  try {
    documentsDirectory = await appDataDirectory();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to resolve documents directory; custom background disabled',
      name: 'startup.documents_dir',
      error: error,
      stackTrace: stackTrace,
    );
  }
  TtsMediaSession? ttsMediaSession;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      ttsMediaSession = await AudioService.init(
        builder: TtsMediaSession.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.yarizm.yunchuang.channel.tts',
          androidNotificationChannelName: '朗读播放',
          androidNotificationChannelDescription: '显示当前书籍朗读状态和播放控制',
          androidNotificationIcon: 'drawable/audio_service_play_arrow',
          androidShowNotificationBadge: false,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to initialize Android TTS media session',
        name: 'tts.media_session',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (documentsDirectory != null)
        appDocumentsDirectoryProvider.overrideWithValue(documentsDirectory),
      ttsMediaSessionProvider.overrideWithValue(ttsMediaSession),
      aiPersonaSelectionStoreProvider.overrideWithValue(
        SharedPreferencesAiPersonaSelectionStore(prefs),
      ),
    ],
    child: const ReadingOfflineApp(),
  ));
}

class _StartupFailureApp extends StatelessWidget {
  final String message;

  const _StartupFailureApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_outlined, size: 48),
                const SizedBox(height: 16),
                const Text('数据恢复失败'),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
