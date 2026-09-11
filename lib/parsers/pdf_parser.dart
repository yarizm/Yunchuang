import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'txt_parser.dart';

/// Parses PDF files into metadata and page-based chapters.
///
/// Uses `syncfusion_flutter_pdf` to extract actual text from each page.
class PdfParser {
  /// Parse PDF file and return metadata + page-based chapters.
  static Future<({ParsedMetadata metadata, List<ParsedChapter> chapters})>
      parseFile(String filePath, {bool extractText = true}) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final title = _filenameWithoutExt(filePath);
    const author = '';

    final chapters = <ParsedChapter>[];

    // syncfusion page counts from 1, but index is 0-based for loops
    final count = document.pages.count;

    try {
      final extractor = PdfTextExtractor(document);
      for (var i = 0; i < count; i++) {
        String content = '';
        try {
          if (extractText) {
            content = extractor.extractText(startPageIndex: i, endPageIndex: i);
          }
        } catch (e) {
          content = '提取文本失败: $e';
        }

        chapters.add(ParsedChapter(
          title: '第 ${i + 1} 页',
          content: content,
          sortOrder: i,
        ));
      }
    } finally {
      document.dispose();
    }

    return (
      metadata: ParsedMetadata(
        title: title,
        author: author,
      ),
      chapters: chapters,
    );
  }

  static Future<String> extractPageText(String filePath, int pageIndex) async {
    final pages = await extractPageTexts(filePath, [pageIndex]);
    return pages[pageIndex] ?? '';
  }

  /// Extract text for multiple pages while opening the PDF only once.
  static Future<Map<int, String>> extractPageTexts(
    String filePath,
    Iterable<int> pageIndices,
  ) async {
    final requested = pageIndices.toSet();
    if (requested.isEmpty) return const {};

    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final result = <int, String>{};
      for (final pageIndex in requested) {
        if (pageIndex < 0 || pageIndex >= document.pages.count) {
          result[pageIndex] = '';
          continue;
        }
        result[pageIndex] = extractor.extractText(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
      }
      return result;
    } finally {
      document.dispose();
    }
  }

  static String _filenameWithoutExt(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }
}
