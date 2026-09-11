import 'dart:io';
import 'dart:isolate';

import 'package:epubx/epubx.dart';
import 'package:path/path.dart' as path;

import '../models/html_text_document.dart';
import 'txt_parser.dart';

class EpubLinkTarget {
  final int chapterIndex;
  final String? anchor;

  const EpubLinkTarget({
    required this.chapterIndex,
    this.anchor,
  });
}

/// Parses EPUB files into chapters and metadata using the `epubx` package.
class EpubParser {
  static const backgroundStripThresholdChars = 64 * 1024;

  /// 从 EPUB 里找封面图的字节。
  ///
  /// 之前依赖 epubx 的 `CoverImage`，它只认 EPUB2 的 `<meta name="cover">`
  /// 且要把图解码一遍，解不开就当没有封面；更糟的是拿到之后取的却是
  /// `Images` 里的**第一张**图——插图本的封面就成了随便哪张插图。这里直接
  /// 按规范找：EPUB3 的 `properties="cover-image"`、EPUB2 的 meta 指向的
  /// manifest 项，都没有再退到文件名带 cover 的图。字节原样返回，不解码。
  static List<int>? findCoverBytes(EpubBook epub) {
    final images = epub.Content?.Images;
    if (images == null || images.isEmpty) return null;
    final manifest = epub.Schema?.Package?.Manifest?.Items ?? const [];
    final metaItems = epub.Schema?.Package?.Metadata?.MetaItems ?? const [];

    String? href;
    for (final item in manifest) {
      final properties =
          item.Properties?.toLowerCase().split(RegExp(r'\s+')) ?? const [];
      if (properties.contains('cover-image')) {
        href = item.Href;
        break;
      }
    }
    if (href == null) {
      for (final meta in metaItems) {
        if (meta.Name?.toLowerCase() != 'cover') continue;
        final id = meta.Content;
        if (id == null || id.isEmpty) continue;
        for (final item in manifest) {
          if (item.Id == id) {
            href = item.Href;
            break;
          }
        }
        if (href != null) break;
      }
    }
    href ??= images.keys.cast<String?>().firstWhere(
          (key) => key!.toLowerCase().contains('cover'),
          orElse: () => null,
        );
    if (href == null) return null;

    // Images 的键是 manifest 里的 href；个别生成器会在 manifest 里写成
    // 相对路径而键里带目录，按文件名结尾再兜一次。
    final direct = images[href]?.Content;
    if (direct != null && direct.isNotEmpty) return direct;
    final fileName = href.split('/').last.toLowerCase();
    for (final entry in images.entries) {
      if (entry.key.toLowerCase().endsWith(fileName)) {
        final bytes = entry.value.Content;
        if (bytes != null && bytes.isNotEmpty) return bytes;
      }
    }
    return null;
  }

  static Future<
      ({
        ParsedMetadata metadata,
        List<ParsedChapter> chapters,
        List<int>? coverBytes
      })> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);

    final title = epub.Title ?? '未知书名';
    final author = epub.Author ?? '';

    final coverBytes = findCoverBytes(epub);

    final chapters = <ParsedChapter>[];
    var sortOrder = 0;
    for (final chapter in epub.Chapters ?? <EpubChapter>[]) {
      final chapterTitle = chapter.Title ?? '第${sortOrder + 1}章';
      final content = chapter.HtmlContent ?? '';
      if (content.trim().isNotEmpty) {
        chapters.add(
          ParsedChapter(
            title: chapterTitle,
            content: content,
            sortOrder: sortOrder,
          ),
        );
        sortOrder++;
      }
    }

    return (
      metadata: ParsedMetadata(title: title, author: author),
      chapters: chapters,
      coverBytes: coverBytes,
    );
  }

  /// Converts chapter HTML to the exact text used by rendering and locators.
  static String stripHtml(String html) {
    return parseHtmlTextDocument(html).plainText;
  }

  static Future<List<String>> stripHtmlBatch(
    Iterable<String> htmlDocuments, {
    int isolateThresholdChars = backgroundStripThresholdChars,
  }) async {
    final documents = htmlDocuments.toList(growable: false);
    if (documents.isEmpty) return const [];
    var totalChars = 0;
    for (final document in documents) {
      totalChars += document.length;
    }
    if (isolateThresholdChars > 0 && totalChars < isolateThresholdChars) {
      return documents.map(stripHtml).toList(growable: false);
    }
    return Isolate.run(
      () => documents.map(stripHtml).toList(growable: false),
    );
  }

  static Future<List<String?>> readChapterFileNames(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    return [
      for (final chapter in epub.Chapters ?? <EpubChapter>[])
        if ((chapter.HtmlContent ?? '').trim().isNotEmpty)
          chapter.ContentFileName,
    ];
  }

  static EpubLinkTarget? resolveChapterHref(
    List<String?> chapterFileNames,
    int sourceChapterIndex,
    String href,
  ) {
    if (sourceChapterIndex < 0 ||
        sourceChapterIndex >= chapterFileNames.length) {
      return null;
    }
    final normalizedHref = href.trim();
    if (normalizedHref.isEmpty || normalizedHref.startsWith('//')) return null;

    Uri uri;
    try {
      uri = Uri.parse(normalizedHref);
    } on FormatException {
      return null;
    }
    if (uri.hasScheme) return null;

    final anchor =
        uri.fragment.isEmpty ? null : _decodeUriComponent(uri.fragment);
    if (uri.path.isEmpty) {
      return EpubLinkTarget(
        chapterIndex: sourceChapterIndex,
        anchor: anchor,
      );
    }

    final sourceFile = chapterFileNames[sourceChapterIndex];
    if (sourceFile == null || sourceFile.trim().isEmpty) return null;
    final sourcePath = _normalizeEpubPath(sourceFile);
    final hrefPath = _decodeUriComponent(uri.path);
    final targetPath = hrefPath.startsWith('/')
        ? _normalizeEpubPath(hrefPath.substring(1))
        : _normalizeEpubPath(
            path.posix.join(path.posix.dirname(sourcePath), hrefPath),
          );

    var targetIndex = chapterFileNames.indexWhere(
      (fileName) =>
          fileName != null && _normalizeEpubPath(fileName) == targetPath,
    );
    if (targetIndex < 0) {
      final basename = path.posix.basename(targetPath);
      final basenameMatches = <int>[];
      for (var index = 0; index < chapterFileNames.length; index++) {
        final fileName = chapterFileNames[index];
        if (fileName != null &&
            path.posix.basename(_normalizeEpubPath(fileName)) == basename) {
          basenameMatches.add(index);
        }
      }
      if (basenameMatches.length == 1) targetIndex = basenameMatches.single;
    }
    if (targetIndex < 0) return null;
    return EpubLinkTarget(chapterIndex: targetIndex, anchor: anchor);
  }

  static String _normalizeEpubPath(String value) {
    return path.posix
        .normalize(_decodeUriComponent(value).replaceAll('\\', '/'))
        .replaceFirst(RegExp(r'^/+'), '');
  }

  static String _decodeUriComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
  }
}
