import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次导入的进度。
///
/// 导入一本书要算整个文件的 SHA-256、拷贝文件、解析分章、写库，几十兆的
/// PDF 或者一次选一整个文件夹时会跑好几秒甚至更久。在这之前界面没有任何
/// 反应——用户点完「导入」看不出发生了什么，很容易再点一次，于是同一批书
/// 被并发导两遍。
class BookImportProgress {
  /// 已经处理完的文件数（不含正在处理的这个）。
  final int completed;

  final int total;

  /// 正在处理的文件名，用来让用户看出卡在哪一本上。
  final String currentName;

  const BookImportProgress({
    required this.completed,
    required this.total,
    required this.currentName,
  });

  /// 0..1，只有一个文件时也给得出合理的值。
  double get fraction => total <= 0 ? 0 : completed / total;

  /// 人看的进度，从 1 开始数。
  String get label => '正在导入 ${completed + 1}/$total';
}

/// 当前是否有导入在跑，跑到哪了。null 表示空闲。
final bookImportProgressProvider =
    StateProvider<BookImportProgress?>((ref) => null);
