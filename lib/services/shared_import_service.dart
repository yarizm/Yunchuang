import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// 取走由「打开方式」或「分享」送进来、已由原生侧落盘的书籍路径。
///
/// 用拉取而不是原生推送：intent 在 Activity.onCreate 就到了，那时 Dart 侧
/// 还没起来，推过去会丢。原生侧先攒着，这里在启动与回到前台时来取。
///
/// 只有 Android 实现了对应的 MethodChannel；其他平台直接返回空，调用方
/// 不必自己判断平台。
class SharedImportService {
  static const channel = MethodChannel('yunchuang/shared_files');

  /// 与原生侧 `SharedFileReceiver.CACHE_DIR` 对应，[discard] 靠它确认
  /// 要删的目录确实是原生侧建的槽位，而不是别处的路径。
  static const _cacheDirName = 'shared_imports';

  final MethodChannel _channel;

  /// 覆盖平台判断，仅供测试使用——开发机是 Windows，否则这条路径永远走不到。
  final bool? supportedOverride;

  SharedImportService({MethodChannel? channel, this.supportedOverride})
      : _channel = channel ?? SharedImportService.channel;

  bool get _supported => supportedOverride ?? (!kIsWeb && Platform.isAndroid);

  /// 返回待导入的本地路径并清空原生侧的队列。
  ///
  /// 原生侧已经按扩展名筛过一遍，这里再确认文件确实存在——用户可能在分享
  /// 之后、应用回到前台之前把缓存清了。
  Future<List<String>> consumePending() async {
    if (!_supported) return const [];
    try {
      final result = await _channel.invokeListMethod<String>('consumePending');
      if (result == null || result.isEmpty) return const [];
      return result.where((path) => File(path).existsSync()).toList();
    } on MissingPluginException {
      // 老版本原生代码还没有这个 channel（例如热重载到旧引擎），不该崩。
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// 删掉 [consumePending] 交出去的那几份缓存副本。
  ///
  /// 导入时 `BookService` 已经把书拷进了应用存储（`storedPath`），缓存里
  /// 这份就是纯粹的重复占用，而缓存目录没人会主动清。不删的话每分享一本
  /// 书就永久多占一份体积。
  ///
  /// 无论导入成功与否都删：失败时源文件还在分享方那里，重新分享即可，
  /// 留着一份用不上的副本没有意义。
  ///
  /// 原生侧把每份文件放在各自的子目录里，所以连同父目录一起删。整个过程
  /// 尽力而为，任何一步失败都不该影响已经完成的导入。
  Future<void> discard(Iterable<String> paths) async {
    if (!_supported) return;
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
        final dir = file.parent;
        // 只删原生侧建的那层槽位目录，不碰 shared_imports 本身。
        if (p.basename(dir.path) != _cacheDirName &&
            p.basename(dir.parent.path) == _cacheDirName &&
            dir.existsSync() &&
            dir.listSync().isEmpty) {
          dir.deleteSync();
        }
      } catch (_) {
        // 文件被系统清过、或权限异常，都不影响导入结果。
      }
    }
  }
}
