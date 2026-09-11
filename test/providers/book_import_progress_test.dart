import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/book_import_progress.dart';

// 导入流程本身（BookImportFlow.importPaths）没有在这里做端到端测试：它要
// BuildContext，只能在 testWidgets 里跑，而导入内部的哈希和分章都在
// `Isolate.run` 上——那是真异步，fake async 时间轴推不动，包进 runAsync 又会
// 挂住不返回。用户能看见的那一层（进度条出现、导入期间 FAB 禁用）在
// test/pages/home_page_test.dart 里覆盖，这里覆盖进度本身的算法。
void main() {
  test('label 从 1 开始数，符合人的直觉', () {
    expect(
      const BookImportProgress(completed: 0, total: 3, currentName: 'a')
          .label,
      '正在导入 1/3',
    );
    expect(
      const BookImportProgress(completed: 2, total: 3, currentName: 'c')
          .label,
      '正在导入 3/3',
    );
  });

  test('fraction 是已完成的比例', () {
    expect(
      const BookImportProgress(completed: 1, total: 4, currentName: '')
          .fraction,
      0.25,
    );
    expect(
      const BookImportProgress(completed: 4, total: 4, currentName: '')
          .fraction,
      1.0,
    );
  });

  // total 是从 paths.length 来的，理论上不会是 0，但进度条直接拿它做除数，
  // 除爆的话整棵树都渲染不出来。
  test('total 为 0 时不会除爆', () {
    expect(
      const BookImportProgress(completed: 0, total: 0, currentName: '')
          .fraction,
      0,
    );
    expect(
      const BookImportProgress(completed: 0, total: -1, currentName: '')
          .fraction,
      0,
    );
  });
}
