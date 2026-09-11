import 'dart:convert';

import 'csv_importer.dart';

/// Parses a JSON array of note objects.
///
/// Expected format:
/// ```json
/// [
///   {
///     "selectedText": "...",
///     "content": "...",
///     "tags": ["tag1", "tag2"]
///   }
/// ]
/// ```
class JsonImporter {
  static List<ImportedNote> parse(String jsonContent) {
    final dynamic decoded = jsonDecode(jsonContent);
    if (decoded is! List) {
      throw const FormatException('JSON root must be an array');
    }

    return decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Each JSON entry must be an object');
      }
      return ImportedNote(
        selectedText: item['selectedText']?.toString(),
        content: item['content']?.toString(),
        tags: (item['tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            [],
      );
    }).toList();
  }
}
