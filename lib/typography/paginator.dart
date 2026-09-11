import 'line_box.dart';

/// 把行盒序列聚合成页盒序列。
///
/// 纯函数：不测量、不碰 Flutter。行高来自度量器，与渲染端精确一致，
/// 分页本身不需要为「渲染比测量多占一行」预留余量。
///
/// 渲染端对「页文本切片」独立断行时与整章断行存在宽度边界处的微差
/// （中文长页多一行、西文按词断行可差两行，见
/// test/typography/selectable_text_parity_test.dart），该余量由调用方
/// （paged_reader）在页容量中扣除，待接管渲染后移除。
///
/// [firstPageHeight] 通常小于 [pageHeight]，因为首页要让出章节标题块。
/// [paragraphSpacing] 在段落边界处计入——即上一行以硬换行结束时。
/// 换页后不在页首补段间距。
///
/// 单行高度超过页容量时，该行独占一页，不会被丢弃。
List<PageBox> paginate({
  required List<LineBox> lines,
  required double firstPageHeight,
  required double pageHeight,
  double paragraphSpacing = 0,
}) {
  if (lines.isEmpty) return const [];

  final pages = <PageBox>[];
  var current = <LineBox>[];
  var capacity = firstPageHeight;
  var used = 0.0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final followsParagraphBreak = i > 0 && lines[i - 1].hardBreak;
    final spacing =
        (followsParagraphBreak && current.isNotEmpty) ? paragraphSpacing : 0.0;

    final overflows =
        current.isNotEmpty && used + spacing + line.height > capacity;

    if (overflows) {
      pages.add(PageBox(current));
      current = [line];
      capacity = pageHeight;
      used = line.height;
    } else {
      current.add(line);
      used += spacing + line.height;
    }
  }

  if (current.isNotEmpty) pages.add(PageBox(current));
  return pages;
}

/// 在页盒序列中定位某个原文偏移所在的页序号。
///
/// 偏移落在行间间隙（换行符处）时归入其后的页；超出末页则返回末页。
int pageIndexForOffset(List<PageBox> pages, int offset) {
  if (pages.isEmpty) return 0;
  for (var i = 0; i < pages.length; i++) {
    if (offset < pages[i].endOffset) return i;
  }
  return pages.length - 1;
}
