import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/dictionary_aliases.dart';
import '../tables/dictionary_entries.dart';
import '../tables/dictionary_sources.dart';

part 'dictionary_dao.g.dart';

class DictionaryIndexRecord {
  final int entryIndex;
  final String headword;
  final String normalizedHeadword;
  final int dataOffset;
  final int dataSize;

  const DictionaryIndexRecord({
    required this.entryIndex,
    required this.headword,
    required this.normalizedHeadword,
    required this.dataOffset,
    required this.dataSize,
  });
}

class DictionaryAliasRecord {
  final String alias;
  final String normalizedAlias;
  final int targetEntryIndex;

  const DictionaryAliasRecord({
    required this.alias,
    required this.normalizedAlias,
    required this.targetEntryIndex,
  });
}

class DictionaryIndexMatch {
  final int sourceId;
  final String sourceName;
  final String dataFilePath;
  final String? sameTypeSequence;
  final int entryIndex;
  final String headword;
  final int dataOffset;
  final int dataSize;

  const DictionaryIndexMatch({
    required this.sourceId,
    required this.sourceName,
    required this.dataFilePath,
    required this.sameTypeSequence,
    required this.entryIndex,
    required this.headword,
    required this.dataOffset,
    required this.dataSize,
  });
}

@DriftAccessor(
  tables: [DictionarySources, DictionaryEntries, DictionaryAliases],
)
class DictionaryDao extends DatabaseAccessor<AppDatabase>
    with _$DictionaryDaoMixin {
  DictionaryDao(super.db);

  Stream<List<DictionarySource>> watchReadySources() {
    return (select(dictionarySources)
          ..where((source) => source.isReady.equals(true))
          ..orderBy([
            (source) => OrderingTerm.desc(source.enabled),
            (source) => OrderingTerm.asc(source.name),
            (source) => OrderingTerm.asc(source.id),
          ]))
        .watch();
  }

  Future<List<DictionarySource>> getReadySources() {
    return (select(dictionarySources)
          ..where((source) => source.isReady.equals(true))
          ..orderBy([
            (source) => OrderingTerm.desc(source.enabled),
            (source) => OrderingTerm.asc(source.name),
          ]))
        .get();
  }

  Future<DictionarySource?> getSource(int id) {
    return (select(dictionarySources)..where((source) => source.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> createPendingSource({
    required String name,
    required String? description,
    required String formatVersion,
    required String? sameTypeSequence,
    required String dataFilePath,
  }) {
    return into(dictionarySources).insert(
      DictionarySourcesCompanion.insert(
        name: name,
        description: Value(_normalizeOptional(description)),
        formatVersion: formatVersion,
        sameTypeSequence: Value(_normalizeOptional(sameTypeSequence)),
        dataFilePath: dataFilePath,
      ),
    );
  }

  Future<void> insertEntryBatch(
    int sourceId,
    List<DictionaryIndexRecord> records,
  ) async {
    if (records.isEmpty) return;
    await batch((batch) {
      batch.insertAll(
        dictionaryEntries,
        [
          for (final record in records)
            DictionaryEntriesCompanion.insert(
              sourceId: sourceId,
              entryIndex: record.entryIndex,
              headword: record.headword,
              normalizedHeadword: record.normalizedHeadword,
              dataOffset: record.dataOffset,
              dataSize: record.dataSize,
            ),
        ],
      );
    });
  }

  Future<void> insertAliasBatch(
    int sourceId,
    List<DictionaryAliasRecord> records,
  ) async {
    if (records.isEmpty) return;
    await batch((batch) {
      batch.insertAll(
        dictionaryAliases,
        [
          for (final record in records)
            DictionaryAliasesCompanion.insert(
              sourceId: sourceId,
              alias: record.alias,
              normalizedAlias: record.normalizedAlias,
              targetEntryIndex: record.targetEntryIndex,
            ),
        ],
      );
    });
  }

  Future<void> finalizeSource(int id, int entryCount) async {
    await (update(dictionarySources)..where((source) => source.id.equals(id)))
        .write(
      DictionarySourcesCompanion(
        entryCount: Value(entryCount),
        enabled: const Value(true),
        isReady: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> setEnabled(int id, bool enabled) {
    return (update(dictionarySources)
          ..where(
            (source) => source.id.equals(id) & source.isReady.equals(true),
          ))
        .write(
      DictionarySourcesCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteSource(int id) {
    return (delete(dictionarySources)..where((source) => source.id.equals(id)))
        .go();
  }

  Future<List<DictionarySource>> getIncompleteSources() {
    return (select(dictionarySources)
          ..where((source) => source.isReady.equals(false)))
        .get();
  }

  Future<List<DictionaryIndexMatch>> lookup(
    String normalizedTerm, {
    int limit = 8,
  }) async {
    final normalized = normalizeHeadword(normalizedTerm);
    if (normalized.isEmpty) return const [];
    final safeLimit = limit.clamp(1, 30).toInt();
    final rows = await customSelect(
      '''
      SELECT e.source_id, s.name AS source_name, s.data_file_path,
             s.same_type_sequence, e.entry_index, e.headword,
             e.data_offset, e.data_size, 0 AS match_kind
      FROM dictionary_entries e
      INNER JOIN dictionary_sources s ON s.id = e.source_id
      WHERE s.is_ready = 1 AND s.enabled = 1
        AND e.normalized_headword = ?
      UNION ALL
      SELECT e.source_id, s.name AS source_name, s.data_file_path,
             s.same_type_sequence, e.entry_index, e.headword,
             e.data_offset, e.data_size, 1 AS match_kind
      FROM dictionary_aliases a
      INNER JOIN dictionary_entries e
        ON e.source_id = a.source_id
       AND e.entry_index = a.target_entry_index
      INNER JOIN dictionary_sources s ON s.id = a.source_id
      WHERE s.is_ready = 1 AND s.enabled = 1
        AND a.normalized_alias = ?
      ORDER BY match_kind, source_id, entry_index
      LIMIT ?
      ''',
      variables: [
        Variable.withString(normalized),
        Variable.withString(normalized),
        Variable.withInt(safeLimit * 2),
      ],
      readsFrom: {
        dictionarySources,
        dictionaryEntries,
        dictionaryAliases,
      },
    ).get();

    final seen = <(int, int)>{};
    final matches = <DictionaryIndexMatch>[];
    for (final row in rows) {
      final key = (
        row.read<int>('source_id'),
        row.read<int>('entry_index'),
      );
      if (!seen.add(key)) continue;
      matches.add(
        DictionaryIndexMatch(
          sourceId: key.$1,
          sourceName: row.read<String>('source_name'),
          dataFilePath: row.read<String>('data_file_path'),
          sameTypeSequence: row.read<String?>('same_type_sequence'),
          entryIndex: key.$2,
          headword: row.read<String>('headword'),
          dataOffset: row.read<int>('data_offset'),
          dataSize: row.read<int>('data_size'),
        ),
      );
      if (matches.length >= safeLimit) break;
    }
    return matches;
  }

  static String normalizeHeadword(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
