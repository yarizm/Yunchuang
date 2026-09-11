import 'csv_importer.dart';

/// Parses WeRead (微信读书) exported notes.
///
/// WeRead exports notes as an HTML table where each `<tr>` contains
/// `<td>` cells — typically the first cell is the highlighted text
/// and the second is the user's note/annotation.
class WeReadImporter {
  static List<ImportedNote> parse(String htmlContent) {
    final notes = <ImportedNote>[];

    final rowPattern = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);

    for (final rowMatch in rowPattern.allMatches(htmlContent)) {
      final cells = cellPattern.allMatches(rowMatch.group(1)!).toList();

      if (cells.isEmpty) continue;

      final text = _stripHtml(cells[0].group(1)!).trim();
      final note =
          cells.length > 1 ? _stripHtml(cells[1].group(1)!).trim() : '';

      if (text.isNotEmpty) {
        notes.add(ImportedNote(
          selectedText: text,
          content: note.isNotEmpty ? note : null,
        ));
      }
    }

    return notes;
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
