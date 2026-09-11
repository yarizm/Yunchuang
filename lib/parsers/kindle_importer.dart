import 'csv_importer.dart';

/// Parses Kindle "My Clippings.txt" format.
///
/// Each entry is separated by `==========`.
/// Within an entry:
///   - Line 1: Book title (author)
///   - Line 2: Metadata — contains "Highlight", "Note", or "Bookmark"
///   - Line 3+: The clipped text / note content
class KindleImporter {
  static List<ImportedNote> parse(String content) {
    final notes = <ImportedNote>[];
    final entries = content.split('==========');

    for (final entry in entries) {
      final lines = entry
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.length < 3) continue;

      // Line 0: book title + author
      // Line 1: metadata (highlight/note type + location)
      // Lines 2+: actual content
      final metadata = lines[1];
      final isNote =
          RegExp(r'\bNote\b', caseSensitive: false).hasMatch(metadata);
      final text = lines.sublist(2).join('\n').trim();

      if (text.isEmpty) continue;

      notes.add(ImportedNote(
        selectedText: isNote ? null : text,
        content: isNote ? text : null,
      ));
    }

    return notes;
  }
}
