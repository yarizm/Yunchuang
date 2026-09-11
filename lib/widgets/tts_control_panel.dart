import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tts_service.dart';

class TtsControlPanel extends ConsumerWidget {
  final String content;
  final Listenable? chapterListenable;
  final int Function()? currentChapterIndex;
  final int chapterCount;
  final Future<void> Function()? onPreviousChapter;
  final Future<void> Function()? onNextChapter;
  final Future<void> Function()? onBeforePlay;
  final Future<void> Function(double rate)? onSpeechRateChanged;
  final Future<void> Function(String language)? onLanguageChanged;
  final Future<void> Function(TTSVoice? voice)? onVoiceChanged;
  final Future<void> Function(TTSSleepTimerOption option)? onSleepTimerChanged;
  final Future<void> Function()? onResetBookSettings;

  const TtsControlPanel({
    super.key,
    required this.content,
    this.chapterListenable,
    this.currentChapterIndex,
    this.chapterCount = 0,
    this.onPreviousChapter,
    this.onNextChapter,
    this.onBeforePlay,
    this.onSpeechRateChanged,
    this.onLanguageChanged,
    this.onVoiceChanged,
    this.onSleepTimerChanged,
    this.onResetBookSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsServiceProvider);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    '语音朗读控制',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: '停止朗读',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () async {
                    await tts.stop();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            if (tts.status == TTSStatus.initializing) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在连接系统语音引擎…'),
                ],
              ),
            ],
            if (tts.lastError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tts.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final ready = await tts.ensureInitialized(retry: true);
                        if (!ready && context.mounted) {
                          _showError(context, tts);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildProgressBar(context, tts),
            const SizedBox(height: 24),
            _buildControls(context, tts),
            const SizedBox(height: 16),
            _buildSpeedSlider(context, tts),
            const SizedBox(height: 8),
            if (onLanguageChanged != null) ...[
              _buildSettingRow(
                context,
                icon: Icons.language_rounded,
                label: '语言',
                value: tts.language,
                controlKey: const Key('tts-language-setting'),
                onTap: () => _showLanguageOptions(context, tts),
              ),
              const SizedBox(height: 4),
            ],
            if (onVoiceChanged != null) ...[
              _buildSettingRow(
                context,
                icon: Icons.record_voice_over_outlined,
                label: '声音',
                value: tts.voice?.name ?? '系统默认',
                controlKey: const Key('tts-voice-setting'),
                onTap: () => _showVoiceOptions(context, tts),
              ),
              const SizedBox(height: 4),
            ],
            _buildSleepTimer(context, tts),
            if (onResetBookSettings != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onResetBookSettings,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('恢复全局默认'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, TTSService tts) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
          ),
          child: Slider(
            value: tts.progress,
            min: 0.0,
            max: 1.0,
            onChanged: (value) {
              tts.updateProgressUI(value);
            },
            onChangeEnd: (value) {
              _play(context, tts, value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(tts.progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('100%', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, TTSService tts) {
    Widget buildControls() {
      final isPlaying = tts.isPlaying && !tts.isPaused;
      final chapterIndex = currentChapterIndex?.call() ?? 0;
      final canGoPrevious =
          onPreviousChapter != null && chapterIndex > 0 && chapterCount > 0;
      final canGoNext = onNextChapter != null &&
          chapterCount > 0 &&
          chapterIndex < chapterCount - 1;

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                tooltip: '朗读上一章',
                iconSize: 32,
                onPressed: canGoPrevious ? onPreviousChapter : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay_10),
                tooltip: '后退百分之十',
                iconSize: 32,
                onPressed: () => _seekRelative(context, tts, -0.1),
              ),
              IconButton(
                icon: Icon(isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled),
                tooltip: isPlaying ? '暂停朗读' : '继续朗读',
                iconSize: 64,
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
                    await _play(context, tts, tts.progress);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                tooltip: '前进百分之十',
                iconSize: 32,
                onPressed: () => _seekRelative(context, tts, 0.1),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                tooltip: '朗读下一章',
                iconSize: 32,
                onPressed: canGoNext ? onNextChapter : null,
              ),
            ],
          ),
          if (chapterCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '第 ${chapterIndex + 1} / $chapterCount 章',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      );
    }

    final listenable = chapterListenable;
    if (listenable == null) return buildControls();
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, child) => buildControls(),
    );
  }

  Future<void> _seekRelative(
    BuildContext context,
    TTSService tts,
    double delta,
  ) async {
    final newProgress = (tts.progress + delta).clamp(0.0, 1.0);
    final chapterIndex = currentChapterIndex?.call() ?? 0;
    final canGoNext = onNextChapter != null &&
        chapterCount > 0 &&
        chapterIndex < chapterCount - 1;
    if (newProgress >= 1 && canGoNext) {
      await onNextChapter!();
      return;
    }
    await _play(context, tts, newProgress.clamp(0.0, 0.999));
  }

  Widget _buildSpeedSlider(BuildContext context, TTSService tts) {
    return Row(
      children: [
        const Icon(Icons.speed, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            value: tts.speechRate,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: '${(tts.speechRate * 2).toStringAsFixed(1)}x',
            onChanged: (val) {
              tts.setSpeechRate(
                val,
                persist: onSpeechRateChanged == null,
              );
            },
            onChangeEnd: (val) async {
              await onSpeechRateChanged?.call(val);
              await tts.applySpeechRate();
            },
          ),
        ),
        Text('${(tts.speechRate * 2).toStringAsFixed(1)}x',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Key controlKey,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '设置$label',
      child: InkWell(
        key: controlKey,
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageOptions(
    BuildContext context,
    TTSService tts,
  ) async {
    await tts.refreshCapabilities();
    if (!context.mounted) return;
    final languages = tts.availableLanguages;
    if (languages.isEmpty) {
      _showMessage(context, '系统语音引擎没有返回可用语言。');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '朗读语言',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    Text('${languages.length} 项'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final language = languages[index];
                    return ListTile(
                      leading: const Icon(Icons.language_rounded),
                      title: Text(language),
                      trailing: language == tts.language
                          ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(language),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await onLanguageChanged?.call(selected);
    }
  }

  Future<void> _showVoiceOptions(
    BuildContext context,
    TTSService tts,
  ) async {
    await tts.refreshCapabilities();
    if (!context.mounted) return;
    final matchingVoices = tts.availableVoices
        .where((voice) => voice.supportsLanguage(tts.language))
        .toList(growable: false);
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '朗读声音',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    Text('${matchingVoices.length} 项'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: matchingVoices.length + 1,
                  itemBuilder: (context, index) {
                    final voice = index == 0 ? null : matchingVoices[index - 1];
                    final selectedVoice = tts.voice;
                    final isSelected = voice == selectedVoice;
                    return ListTile(
                      leading: Icon(
                        voice == null
                            ? Icons.settings_voice_outlined
                            : Icons.record_voice_over_outlined,
                      ),
                      title: Text(voice?.name ?? '系统默认'),
                      subtitle: voice == null ? null : Text(voice.locale),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(
                        voice ?? _VoiceSelection.systemDefault,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await onVoiceChanged?.call(
        selected is TTSVoice ? selected : null,
      );
    }
  }

  Widget _buildSleepTimer(BuildContext context, TTSService tts) {
    return Row(
      children: [
        const Icon(Icons.bedtime_outlined, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            '睡眠定时',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Semantics(
          button: true,
          label: '设置睡眠定时',
          child: InkWell(
            key: const Key('tts-sleep-timer-setting'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showSleepTimerOptions(context, tts),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_sleepTimerLabel(tts.preferredSleepTimerOption)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSleepTimerOptions(
    BuildContext context,
    TTSService tts,
  ) async {
    final selected = await showModalBottomSheet<TTSSleepTimerOption>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '睡眠定时',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ),
                for (final option in TTSSleepTimerOption.values)
                  ListTile(
                    leading: Icon(_sleepTimerIcon(option)),
                    title: Text(_sleepTimerLabel(option)),
                    trailing: option == tts.preferredSleepTimerOption
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(sheetContext).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      if (onSleepTimerChanged != null) {
        await onSleepTimerChanged!(selected);
      } else {
        tts.setSleepTimer(selected);
      }
    }
  }

  IconData _sleepTimerIcon(TTSSleepTimerOption option) {
    return switch (option) {
      TTSSleepTimerOption.off => Icons.timer_off_outlined,
      TTSSleepTimerOption.minutes15 ||
      TTSSleepTimerOption.minutes30 ||
      TTSSleepTimerOption.minutes60 =>
        Icons.timer_outlined,
      TTSSleepTimerOption.endOfChapter => Icons.menu_book_outlined,
    };
  }

  String _sleepTimerLabel(TTSSleepTimerOption option) {
    return switch (option) {
      TTSSleepTimerOption.off => '关闭',
      TTSSleepTimerOption.minutes15 => '15 分钟',
      TTSSleepTimerOption.minutes30 => '30 分钟',
      TTSSleepTimerOption.minutes60 => '60 分钟',
      TTSSleepTimerOption.endOfChapter => '本章结束',
    };
  }

  Future<void> _play(
    BuildContext context,
    TTSService tts,
    double progress,
  ) async {
    await onBeforePlay?.call();
    final activeContent =
        tts.currentText.trim().isNotEmpty ? tts.currentText : content;
    final started = await tts.play(activeContent, progress);
    if (!started && context.mounted) {
      _showError(context, tts);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

enum _VoiceSelection { systemDefault }
