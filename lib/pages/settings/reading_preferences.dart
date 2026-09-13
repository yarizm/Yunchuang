import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/preferences_provider.dart';
import '../../utils/app_orientation.dart';
import '../../theme/reader_theme.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/reader_paper_picker.dart';
import '../../utils/font_utils.dart';

/// 阅读偏好设置：字号、行距、主题
class ReadingPreferencesPage extends ConsumerWidget {
  const ReadingPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final theme = Theme.of(context);
    // 一次算好给下面的预览用。这一页有滑块，每帧都会重建。
    final preview = readerPreviewColors(
      themeName: prefs.theme,
      paper: prefs.readerPaper,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读偏好'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
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
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('字号', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Slider(
                        value: prefs.fontSize,
                        min: 12,
                        max: 28,
                        divisions: 16,
                        label: prefs.fontSize.round().toString(),
                        onChanged: (v) => notifier.updateFontSize(v),
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 24)),
                  ],
                ),
                Center(
                  child: Text(
                    '${prefs.fontSize.round()}px',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('顶部留白', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Slider(
                  value: prefs.topContentPadding,
                  min: 0,
                  max: 96,
                  divisions: 24,
                  label: prefs.topContentPadding.round().toString(),
                  onChanged: (v) => notifier.updateTopContentPadding(v),
                ),
                Center(
                  child: Text(
                    '${prefs.topContentPadding.round()}px',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('行距', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Slider(
                  value: prefs.lineHeight,
                  min: 1.2,
                  max: 2.5,
                  divisions: 13,
                  label: prefs.lineHeight.toStringAsFixed(1),
                  onChanged: (v) => notifier.updateLineHeight(v),
                ),
                Center(
                  child: Text(
                    prefs.lineHeight.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('主题', style: theme.textTheme.titleSmall),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    return SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        key: ValueKey(prefs.theme),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ),
                        segments: [
                          ButtonSegment(
                            value: 'light',
                            label: compact ? null : const Text('日间'),
                            icon: const Icon(Icons.light_mode),
                            tooltip: '日间主题',
                          ),
                          ButtonSegment(
                            value: 'sepia',
                            label: compact ? null : const Text('护眼'),
                            icon: const Icon(Icons.brightness_5),
                            tooltip: '护眼主题',
                          ),
                          ButtonSegment(
                            value: 'dark',
                            label: compact ? null : const Text('夜间'),
                            icon: const Icon(Icons.dark_mode),
                            tooltip: '夜间主题',
                          ),
                          ButtonSegment(
                            value: 'system',
                            label: compact ? null : const Text('跟随系统'),
                            icon: const Icon(Icons.brightness_auto),
                            tooltip: '跟随系统',
                          ),
                        ],
                        selected: {prefs.theme},
                        onSelectionChanged: (s) =>
                            notifier.updateTheme(s.first),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正文纸张', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '只改阅读页的底色，书架和设置页不受影响',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ReaderPaperPicker(
                  selected: prefs.readerPaper,
                  lastCustomColor: prefs.readerPaperColor == null
                      ? null
                      : Color(prefs.readerPaperColor!),
                  onChanged: notifier.updateReaderPaper,
                ),
              ],
            ),
          ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('预览', style: theme.textTheme.titleSmall),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: preview.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text(
                    '这是一段预览文字。通过调整上方的滑块，可以改变阅读时的字号和行距。选择不同的主题可以切换日间、护眼或夜间模式。',
                    style: TextStyle(
                      fontSize: prefs.fontSize,
                      height: prefs.lineHeight,
                      fontFamily: FontUtils.resolveFontFamily(prefs.fontFamily),
                      fontFamilyFallback:
                          FontUtils.resolveFontFamilyFallback(prefs.fontFamily),
                      color: preview.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('保持亮屏', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('阅读时屏幕不自动熄灭', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                  value: prefs.keepScreenOn,
                  onChanged: (v) => notifier.updateKeepScreenOn(v),
                ),
              ],
            ),
          ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('方向锁定', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'auto', label: Text('自动')),
                      ButtonSegment(value: 'portrait', label: Text('竖屏')),
                      ButtonSegment(value: 'landscape', label: Text('横屏')),
                    ],
                    selected: {prefs.preferredOrientation},
                    onSelectionChanged: (s) =>
                        notifier.updatePreferredOrientation(s.first),
                  ),
                ),
                if (supportsReaderLandscape) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('阅读时横屏', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              '进入阅读器自动转成横屏，退出后恢复上面的设置',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: prefs.readerLandscape,
                        onChanged: notifier.updateReaderLandscape,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
