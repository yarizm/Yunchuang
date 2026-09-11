import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class BackgroundImageException implements Exception {
  final String message;
  const BackgroundImageException(this.message);

  @override
  String toString() => message;
}

/// 管理用户自选的背景图：导入、缩放、落盘、清理。
///
/// 偏好里只存**文件名**，不存绝对路径。应用文档目录的绝对路径不是稳定的
/// （Android 换包名、重装、恢复备份都会变），存全路径的话恢复之后指向一个
/// 不存在的位置，背景就默默消失了。
class BackgroundImageService {
  static const directoryName = 'backgrounds';

  /// 超过这个大小直接拒绝。不是怕存不下，是怕在解码时把内存吃爆——
  /// 一张 8000×6000 的原图解出来是 190MB 的位图。
  static const maxSourceBytes = 30 * 1024 * 1024;

  /// 落盘时长边缩到这个尺寸。背景铺满屏幕但永远是虚化的陪衬，
  /// 留着 4800px 的原图只会让每次备份都胖几 MB。
  static const maxEdge = 2160;

  static const _allowedExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'};

  final Directory _documentsDirectory;
  final Uuid _uuid;

  BackgroundImageService(this._documentsDirectory, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  Directory get directory =>
      Directory(p.join(_documentsDirectory.path, directoryName));

  /// 由偏好里的文件名还原出绝对路径。文件名为空或文件不在都返回 null，
  /// 调用方据此退回纯色背景。
  String? resolvePath(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    // 存进来的应该只是个文件名。真混进了路径分隔符就当它无效，不去拼接——
    // 否则 `../../` 这种值会让后面的删除操作跑到目录外面去。
    if (fileName != p.basename(fileName)) return null;
    final path = p.join(directory.path, fileName);
    return File(path).existsSync() ? path : null;
  }

  /// 把 [source] 收进应用目录，返回落盘后的文件名。
  Future<String> import(File source) async {
    final extension = p.extension(source.path).toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw BackgroundImageException('不支持的图片格式：$extension');
    }
    if (!await source.exists()) {
      throw const BackgroundImageException('图片文件不存在');
    }
    final length = await source.length();
    if (length > maxSourceBytes) {
      final mb = (maxSourceBytes / 1024 / 1024).round();
      throw BackgroundImageException('图片超过 $mb MB，请先压缩');
    }

    final bytes = await source.readAsBytes();
    // ImmutableBuffer 和 ImageDescriptor 都持有 native 内存，都必须显式释放。
    // 一律在这一层的 finally 里收——之前是「小图分支自己 dispose，大图分支
    // 交给 _encodeScaled dispose」，所有权劈成两半，中间任何一步抛异常都会
    // 漏掉（directory.create、instantiateCodec、getNextFrame 都在保护范围外）。
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      try {
        buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        descriptor = await ui.ImageDescriptor.encoded(buffer);
      } catch (error) {
        throw BackgroundImageException('图片无法解码：$error');
      }

      await directory.create(recursive: true);
      // 每次导入换一个新文件名。`FileImage` 是按路径缓存的，沿用同一个名字会
      // 让换过的背景在下次重启前一直显示旧图。
      final longEdge = math.max(descriptor.width, descriptor.height);

      if (longEdge <= maxEdge) {
        // 已经够小就原样拷贝。重新编码成 PNG 反而会让一张 JPEG 胖好几倍。
        final fileName = '${_uuid.v4()}$extension';
        await File(p.join(directory.path, fileName))
            .writeAsBytes(bytes, flush: true);
        return fileName;
      }

      final scale = maxEdge / longEdge;
      final resized = await _encodeScaled(
        descriptor,
        (descriptor.width * scale).round(),
        (descriptor.height * scale).round(),
      );
      final fileName = '${_uuid.v4()}.png';
      await File(p.join(directory.path, fileName))
          .writeAsBytes(resized, flush: true);
      return fileName;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// 把 [descriptor] 按目标尺寸解码后重新编码成 PNG。
  ///
  /// 不负责释放 [descriptor]——调用方在自己的 finally 里收。
  Future<Uint8List> _encodeScaled(
    ui.ImageDescriptor descriptor,
    int width,
    int height,
  ) async {
    final codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: height,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw const BackgroundImageException('图片重编码失败');
        }
        return data.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// 删掉一张不再引用的背景图。文件已经不在就当成功。
  Future<void> remove(String? fileName) async {
    final path = resolvePath(fileName);
    if (path == null) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // 删不掉不该拦着用户换背景，下次导入会覆盖引用。
    }
  }

  /// 清掉目录里除 [keep] 之外的所有图。
  ///
  /// 换背景走的是「先写新图、再改偏好」，中间崩了就会留下一张没人引用的
  /// 孤儿文件。每次换背景顺手扫一遍，比起额外记一张引用表更省事。
  ///
  /// **绝不抛异常。** 这是收尾清理，跑在背景已经换好之后；让它把失败冒到
  /// 调用方，用户就会在看着新背景的同时收到一句「导入失败」。
  Future<void> pruneExcept(String? keep) async {
    try {
      if (!await directory.exists()) return;
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        if (p.basename(entity.path) == keep) continue;
        try {
          await entity.delete();
        } on FileSystemException {
          // 单个文件删不掉，跳过它继续清剩下的。
        }
      }
    } on FileSystemException {
      // 连目录都列不出来（权限、目录被移走），孤儿文件留着就是了。
    }
  }
}
