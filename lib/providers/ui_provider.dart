import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reading_background.dart';
import '../services/background_image_service.dart';
import 'preferences_provider.dart';

/// Expensive decorative animation should be disabled while reading.
final backgroundAnimationEnabledProvider = StateProvider<bool>((ref) => true);

/// 应用文档目录。在 `main()` 里覆盖——`getApplicationDocumentsDirectory()` 是
/// 异步的，而背景图路径要在同步的 build 里解析。
final appDocumentsDirectoryProvider = Provider<Directory>((ref) {
  throw UnimplementedError();
});

final backgroundImageServiceProvider = Provider<BackgroundImageService>((ref) {
  return BackgroundImageService(ref.watch(appDocumentsDirectoryProvider));
});

/// 自定义背景图的绝对路径。偏好里只存文件名，这里补上目录并确认文件还在。
///
/// 没设过背景图就直接返回，不去碰 [appDocumentsDirectoryProvider]——那个
/// 是要在 `main()` 里注入的，让「没用这个功能」也依赖它，等于每个挂载
/// 整个 App 的测试都得先准备一个文档目录。
final customBackgroundPathProvider = Provider<String?>((ref) {
  final fileName = ref.watch(
    preferencesProvider.select((p) => p.customBackgroundPath),
  );
  if (fileName == null || fileName.isEmpty) return null;
  return ref.watch(backgroundImageServiceProvider).resolvePath(fileName);
});

/// 实际生效的背景样式。
///
/// 偏好里存着 `custom`、图片却不在了，是个真实会出现的状态：恢复了一份不含
/// `backgrounds/` 的老备份（v3 及以前），或者用户在系统文件管理器里把图删了。
/// 这时候 [AppBackground] 会安静退回纯色，但设置页如果照着存的值渲染，就会
/// 显示「自定义图片」选中、却既没有缩略图也没有背景，还多出一条对不上任何
/// 东西的浓度滑块。
///
/// 所以显示和渲染都走这里。存的值不动——不在 build 里写偏好；用户点一下
/// 「自定义图片」就会去选图，状态自然就修好了。
final effectiveBackgroundStyleProvider = Provider<AppBackgroundStyle>((ref) {
  final style = ref.watch(
    preferencesProvider.select((p) => p.backgroundStyle),
  );
  if (style != AppBackgroundStyle.custom) return style;
  return ref.watch(customBackgroundPathProvider) == null
      ? AppBackgroundStyle.solid
      : style;
});
