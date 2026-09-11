import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tts_service.dart';
import 'glass_container.dart';

class TtsMiniPlayer extends ConsumerWidget {
  final String content;
  final VoidCallback onTap;

  const TtsMiniPlayer({
    super.key,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsServiceProvider);

    if (!tts.isPlaying && !tts.isPaused) {
      return const SizedBox.shrink();
    }

    final isPlaying = tts.isPlaying && !tts.isPaused;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer.stable(
        borderRadius: 24,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled),
                tooltip: isPlaying ? '暂停朗读' : '继续朗读',
                iconSize: 32,
                color: Theme.of(context).colorScheme.primary,
                onPressed: () async {
                  if (isPlaying) {
                    await tts.pause();
                  } else if (tts.isPaused) {
                    final resumed = await tts.resume();
                    if (!resumed && context.mounted) {
                      _showError(context, tts);
                    }
                  } else {
                    final started = await tts.play(content, tts.progress);
                    if (!started && context.mounted) {
                      _showError(context, tts);
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '正在朗读',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: tts.progress,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '停止朗读',
                onPressed: () {
                  tts.stop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, TTSService tts) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tts.lastError ?? '系统语音朗读启动失败。'),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
