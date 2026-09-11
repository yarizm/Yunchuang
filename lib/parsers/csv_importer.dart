import 'package:csv/csv.dart';

/// A lightweight note model used by all importers.
/// Separate from the Drift [Note] — importers produce these,
/// then the UI persists them via [NoteService].
class ImportedNote {
  final String? selectedText;
  final String? content;
  final List<String> tags;

  ImportedNote({this.selectedText, this.content, this.tags = const []});
}

/// Parses CSV files exported by various reading apps.
///
/// Expected columns (case-insensitive header row required):
///   - `selectedText` — the highlighted passage
///   - `content`      — user annotation / note
///   - `tags`         — comma-separated tag list inside one cell
///
/// Uses RFC 4180 compliant parsing via the `csv` package.
class CsvImporter {
  static List<ImportedNote> parse(String csvContent) {
    if (csvContent.trim().isEmpty) return [];

    final rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
        .convert(csvContent);
    if (rows.isEmpty) return [];

    // First row is headers — locate columns case-insensitively.
    final headers =
        rows[0].map((h) => h.toString().trim().toLowerCase()).toList();
    final textIdx = headers.indexOf('selectedtext');
    final contentIdx = headers.indexOf('content');
    final tagsIdx = headers.indexOf('tags');

    final notes = <ImportedNote>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];

      final text = textIdx >= 0 && textIdx < row.length
          ? row[textIdx]?.toString()
          : null;
      final content = contentIdx >= 0 && contentIdx < row.length
          ? row[contentIdx]?.toString()
          : null;
      final tagsStr = tagsIdx >= 0 && tagsIdx < row.length
          ? row[tagsIdx]?.toString() ?? ''
          : '';
      final tags = tagsStr
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Skip completely empty rows.
      if (text != null || content != null) {
        notes.add(ImportedNote(
          selectedText: text,
          content: content,
          tags: tags,
        ));
      }
    }

    return notes;
  }
}
