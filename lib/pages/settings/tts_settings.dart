import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/tts_service.dart';
import '../../widgets/glass_container.dart';

class TtsSettingsPage extends ConsumerWidget {
  const TtsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TTS 设置'),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filled(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '系统语音引擎',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _statusIcon(tts.status),
                      color: _statusColor(context, tts.status),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_statusText(tts))),
                  ],
                ),
                if (tts.lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    tts.lastError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: tts.status == TTSStatus.initializing
                      ? null
                      : () async {
                          final ready =
                              await tts.ensureInitialized(retry: true);
                          if (!ready && context.mounted) {
                            _showError(context, tts);
                          }
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新检测'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '语速',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: tts.speechRate,
                  min: 0.1,
                  max: 1,
                  divisions: 9,
                  label: '${(tts.speechRate * 2).toStringAsFixed(1)}x',
                  onChanged: (value) {
                    tts.setSpeechRate(value);
                  },
                ),
                Center(
                  child: Text(
                    '当前语速：${(tts.speechRate * 2).toStringAsFixed(1)}x',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: tts.status == TTSStatus.initializing
                        ? null
                        : () async {
                            final started = await tts.play(
                              '这是一段测试语音，当前语速为'
                              '${(tts.speechRate * 2).toStringAsFixed(1)}倍。',
                            );
                            if (!started && context.mounted) {
                              _showError(context, tts);
                            }
                          },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('试听'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _statusText(TTSService tts) {
    return switch (tts.status) {
      TTSStatus.initializing => '正在检测系统语音引擎…',
      TTSStatus.ready => '已就绪（${tts.language}）',
      TTSStatus.playing => '正在朗读（${tts.language}）',
      TTSStatus.paused => '朗读已暂停',
      TTSStatus.error => '系统语音引擎不可用',
    };
  }

  static IconData _statusIcon(TTSStatus status) {
    return switch (status) {
      TTSStatus.initializing => Icons.sync,
      TTSStatus.ready => Icons.check_circle_outline,
      TTSStatus.playing => Icons.volume_up,
      TTSStatus.paused => Icons.pause_circle_outline,
      TTSStatus.error => Icons.error_outline,
    };
  }

  static Color _statusColor(BuildContext context, TTSStatus status) {
    if (status == TTSStatus.error) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.primary;
  }

  static void _showError(BuildContext context, TTSService tts) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tts.lastError ?? '系统语音朗读启动失败。'),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
