import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reading_background.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/ui_provider.dart';
import '../../services/background_image_service.dart';
import '../../widgets/glass_container.dart';

/// 外观设置：全局背景样式、浓度、自定义背景图。
///
/// 正文纸张不在这里，在「阅读偏好」里——它和字号行距一样是读书时的设置，
/// 而且那一页已经有实时预览。
class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final customPath = ref.watch(customBackgroundPathProvider);
    final theme = Theme.of(context);
    // 存的值可能是「custom 但图片已经不在了」。界面按实际生效的样式渲染，
    // 见 effectiveBackgroundStyleProvider。
    final style = ref.watch(effectiveBackgroundStyleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('外观'),
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
                Text('背景', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '底色始终跟随主题，这里选的是叠在上面的装饰层',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                RadioGroup<AppBackgroundStyle>(
                  groupValue: style,
                  onChanged: (value) {
                    if (value == null) return;
                    // 还没有图就先去选图，选完自动落到 custom；否则用户选中
                    // 一个什么都不显示的选项，会以为坏了。
                    if (value == AppBackgroundStyle.custom &&
                        customPath == null) {
                      _pickImage();
                      return;
                    }
                    ref
                        .read(preferencesProvider.notifier)
                        .updateAppBackgroundStyle(value);
                  },
                  child: Column(
                    children: [
                      for (final option in AppBackgroundStyle.values)
                        RadioListTile<AppBackgroundStyle>(
                          value: option,
                          contentPadding: EdgeInsets.zero,
                          title: Text(option.label),
                          subtitle: Text(
                            _describe(option),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (style != AppBackgroundStyle.solid)
            GlassContainer.stable(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('浓度', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('背景越淡，书封和正文越突出', style: theme.textTheme.bodySmall),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: prefs.backgroundIntensity,
                          divisions: 20,
                          label: '${(prefs.backgroundIntensity * 100).round()}%',
                          onChanged: (value) => ref
                              .read(preferencesProvider.notifier)
                              .updateBackgroundIntensity(value),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${(prefs.backgroundIntensity * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          GlassContainer.stable(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('自定义背景图', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                if (customPath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(customPath),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _importing ? null : _pickImage,
                      icon: _importing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                      label: Text(customPath == null ? '选择图片' : '换一张'),
                    ),
                    if (customPath != null) ...[
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _importing ? null : _clearImage,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('移除'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '图片会缩到长边 ${BackgroundImageService.maxEdge}px 存进应用目录，'
                  '随备份一起导出。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _describe(AppBackgroundStyle style) {
    switch (style) {
      case AppBackgroundStyle.solid:
        return '只有主题底色，最省电';
      case AppBackgroundStyle.gradient:
        return '由主题色推出的缓慢流动渐变';
      case AppBackgroundStyle.illustration:
        return '内置水彩书斋插画';
      case AppBackgroundStyle.custom:
        return '用自己的图片';
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
    );
    final files = result?.files ?? const [];
    final path = files.isEmpty ? null : files.first.path;
    // 选图期间用户可能已经退出这一页了。
    if (path == null || !mounted) return;

    setState(() => _importing = true);
    final service = ref.read(backgroundImageServiceProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    try {
      // 先落盘再改偏好，中途失败不会留下指向空文件的设置。
      final fileName = await service.import(File(path));
      notifier.updateCustomBackgroundPath(fileName);
      notifier.updateAppBackgroundStyle(AppBackgroundStyle.custom);
      // 清理孤儿文件是收尾，背景这时已经换好了。pruneExcept 自己吞掉所有
      // 异常，不会把成功的导入报成失败。
      await service.pruneExcept(fileName);
    } on BackgroundImageException catch (error) {
      if (mounted) _toast(error.message);
    } catch (error) {
      if (mounted) _toast('导入失败：$error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _clearImage() async {
    final notifier = ref.read(preferencesProvider.notifier);
    final service = ref.read(backgroundImageServiceProvider);
    final fileName = ref.read(preferencesProvider).customBackgroundPath;
    // 先改偏好再删文件：反过来的话删完、改偏好前崩溃，界面会引用一个
    // 已经不存在的路径。
    notifier.updateCustomBackgroundPath(null);
    await service.remove(fileName);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
