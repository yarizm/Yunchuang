import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../database/daos/dictionary_dao.dart';
import 'stardict_parser.dart';
import '../utils/app_data_directory.dart';

typedef DictionaryDirectoryProvider = Future<Directory> Function();

class StarDictSelectedFile {
  final String name;
  final String path;

  const StarDictSelectedFile({
    required this.name,
    required this.path,
  });
}

class StarDictImportBundle {
  final StarDictSelectedFile info;
  final StarDictSelectedFile index;
  final StarDictSelectedFile data;
  final StarDictSelectedFile? synonyms;

  const StarDictImportBundle({
    required this.info,
    required this.index,
    required this.data,
    required this.synonyms,
  });

  factory StarDictImportBundle.resolve(List<StarDictSelectedFile> files) {
    final available = <String, StarDictSelectedFile>{};
    for (final file in files) {
      final name = p.basename(file.name).toLowerCase();
      if (available.containsKey(name)) {
        throw StarDictFormatException('重复选择了文件：${file.name}');
      }
      available[name] = file;
    }
    final infoFiles =
        available.entries.where((entry) => entry.key.endsWith('.ifo')).toList();
    if (infoFiles.length != 1) {
      throw const StarDictFormatException('每次请选择一套词典，且必须包含一个 .ifo 文件');
    }
    final infoEntry = infoFiles.single;
    final baseName = infoEntry.key.substring(0, infoEntry.key.length - 4);
    StarDictSelectedFile? find(List<String> suffixes) {
      for (final suffix in suffixes) {
        final file = available['$baseName$suffix'];
        if (file != null) return file;
      }
      return null;
    }

    final index = find(const ['.idx', '.idx.gz']);
    if (index == null) {
      throw const StarDictFormatException('缺少同名的 .idx 或 .idx.gz 文件');
    }
    final data = find(const ['.dict', '.dict.dz']);
    if (data == null) {
      throw const StarDictFormatException('缺少同名的 .dict 或 .dict.dz 文件');
    }
    return StarDictImportBundle(
      info: infoEntry.value,
      index: index,
      data: data,
      synonyms: find(const ['.syn']),
    );
  }
}

class DictionaryDefinition {
  final int sourceId;
  final String sourceName;
  final String headword;
  final String definition;

  const DictionaryDefinition({
    required this.sourceId,
    required this.sourceName,
    required this.headword,
    required this.definition,
  });
}

class DictionaryLookupResult {
  final int installedSourceCount;
  final int enabledSourceCount;
  final List<DictionaryDefinition> definitions;

  const DictionaryLookupResult({
    required this.installedSourceCount,
    required this.enabledSourceCount,
    required this.definitions,
  });
}

class DictionaryService {
  static const maxDataFileBytes = 2 * 1024 * 1024 * 1024;
  static const maxDefinitionBytes = 2 * 1024 * 1024;

  final DictionaryDao _dao;
  final DictionaryDirectoryProvider _appDirectoryProvider;

  DictionaryService(
    this._dao, {
    DictionaryDirectoryProvider? appDirectoryProvider,
  }) : _appDirectoryProvider =
            appDirectoryProvider ?? appDataDirectory;

  Stream<List<DictionarySource>> watchSources() => _dao.watchReadySources();

  Future<DictionarySource> importStarDict(
    List<StarDictSelectedFile> selectedFiles, {
    void Function(String status)? onProgress,
    StarDictImportCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await cleanupIncompleteImports();
    final bundle = StarDictImportBundle.resolve(selectedFiles);
    final metadata = StarDictParser.parseIfo(
      await File(bundle.info.path).readAsString(),
    );
    if ((metadata.synonymCount ?? 0) > 0 && bundle.synonyms == null) {
      throw const StarDictFormatException(
        '.ifo 声明了同义词，但所选文件中缺少同名 .syn 文件',
      );
    }

    final root = await _dictionaryRoot();
    await root.create(recursive: true);
    final safeName = metadata.bookName
        .replaceAll(RegExp(r'[^A-Za-z0-9._\-\u4e00-\u9fff]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final destination = File(
      p.join(
        root.path,
        '${DateTime.now().microsecondsSinceEpoch}_'
        '${safeName.isEmpty ? 'dictionary' : safeName}.dict',
      ),
    );

    int? sourceId;
    try {
      sourceId = await _dao.createPendingSource(
        name: metadata.bookName,
        description: metadata.description,
        formatVersion: metadata.version,
        sameTypeSequence: metadata.sameTypeSequence,
        dataFilePath: destination.path,
      );
      onProgress?.call('正在导入词典索引…');
      final summary = await StarDictParser.importIndex(
        metadata: metadata,
        indexPath: bundle.index.path,
        indexCompressed: bundle.index.name.toLowerCase().endsWith('.gz'),
        synonymPath: bundle.synonyms?.path,
        cancellation: cancellation,
        onEntryBatch: (records) => _dao.insertEntryBatch(sourceId!, records),
        onAliasBatch: (records) => _dao.insertAliasBatch(sourceId!, records),
        onProgress: (completed, total) {
          onProgress?.call('正在导入词典索引（$completed/$total）…');
        },
      );
      cancellation?.throwIfCancelled();

      onProgress?.call(
        bundle.data.name.toLowerCase().endsWith('.dz')
            ? '正在解压词典正文…'
            : '正在复制词典正文…',
      );
      final dataBytes = await _prepareDataFile(
        bundle.data.path,
        destination.path,
        compressed: bundle.data.name.toLowerCase().endsWith('.dz'),
      );
      cancellation?.throwIfCancelled();
      if (dataBytes < summary.requiredDataBytes) {
        throw const StarDictFormatException('词典正文小于索引声明的数据范围');
      }
      await _dao.finalizeSource(sourceId, summary.entryCount);
      final source = await _dao.getSource(sourceId);
      if (source == null) {
        throw const StarDictFormatException('词典导入完成后无法读取记录');
      }
      onProgress?.call('词典导入完成');
      return source;
    } catch (_) {
      if (sourceId != null) {
        await _dao.deleteSource(sourceId);
      }
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Future<DictionaryLookupResult> lookup(
    String term, {
    int limit = 8,
  }) async {
    final normalized = DictionaryDao.normalizeHeadword(term);
    final sources = await _dao.getReadySources();
    final enabledCount = sources.where((source) => source.enabled).length;
    if (normalized.isEmpty || enabledCount == 0) {
      return DictionaryLookupResult(
        installedSourceCount: sources.length,
        enabledSourceCount: enabledCount,
        definitions: const [],
      );
    }
    final matches = await _dao.lookup(normalized, limit: limit);
    final definitions = <DictionaryDefinition>[];
    for (final match in matches) {
      if (match.dataOffset < 0 ||
          match.dataSize <= 0 ||
          match.dataSize > maxDefinitionBytes) {
        continue;
      }
      final file = File(match.dataFilePath);
      if (!await file.exists()) continue;
      RandomAccessFile? reader;
      try {
        reader = await file.open();
        final fileLength = await reader.length();
        if (match.dataOffset + match.dataSize > fileLength) continue;
        await reader.setPosition(match.dataOffset);
        final bytes = await reader.read(match.dataSize);
        if (bytes.length != match.dataSize) continue;
        final definition = StarDictParser.decodeDefinition(
          Uint8List.fromList(bytes),
          sameTypeSequence: match.sameTypeSequence,
        );
        if (definition.isEmpty) continue;
        definitions.add(
          DictionaryDefinition(
            sourceId: match.sourceId,
            sourceName: match.sourceName,
            headword: match.headword,
            definition: definition,
          ),
        );
      } on FileSystemException {
        continue;
      } on StarDictFormatException {
        continue;
      } finally {
        await reader?.close();
      }
    }
    return DictionaryLookupResult(
      installedSourceCount: sources.length,
      enabledSourceCount: enabledCount,
      definitions: List.unmodifiable(definitions),
    );
  }

  Future<void> setEnabled(int sourceId, bool enabled) async {
    final updated = await _dao.setEnabled(sourceId, enabled);
    if (updated != 1) {
      throw StateError('词典不存在或尚未完成导入');
    }
  }

  Future<void> deleteSource(int sourceId) async {
    final source = await _dao.getSource(sourceId);
    if (source == null) return;
    await _dao.deleteSource(sourceId);
    await _deleteManagedDataFile(source.dataFilePath);
  }

  Future<void> cleanupIncompleteImports() async {
    final incomplete = await _dao.getIncompleteSources();
    for (final source in incomplete) {
      await _dao.deleteSource(source.id);
      await _deleteManagedDataFile(source.dataFilePath);
    }
  }

  Future<Directory> _dictionaryRoot() async {
    final appDirectory = await _appDirectoryProvider();
    return Directory(p.join(appDirectory.path, 'dictionaries'));
  }

  Future<void> _deleteManagedDataFile(String path) async {
    final root = await _dictionaryRoot();
    final normalizedRoot = p.normalize(p.absolute(root.path));
    final normalizedFile = p.normalize(p.absolute(path));
    if (!p.isWithin(normalizedRoot, normalizedFile)) return;
    final file = File(normalizedFile);
    if (await file.exists()) await file.delete();
  }

  Future<int> _prepareDataFile(
    String sourcePath,
    String destinationPath, {
    required bool compressed,
  }) {
    return Isolate.run(
      () => _copyOrDecompressStarDictData(
        sourcePath,
        destinationPath,
        maxDataFileBytes,
        compressed,
      ),
      debugName: 'stardict-data-prepare',
    );
  }
}

Future<int> _copyOrDecompressStarDictData(
  String sourcePath,
  String destinationPath,
  int maxBytes,
  bool compressed,
) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    throw const StarDictFormatException('找不到词典正文文件');
  }
  final destination = File(destinationPath);
  await destination.parent.create(recursive: true);
  var written = 0;
  IOSink? sink;
  try {
    sink = destination.openWrite();
    final sourceStream =
        compressed ? gzip.decoder.bind(source.openRead()) : source.openRead();
    await for (final chunk in sourceStream) {
      written += chunk.length;
      if (written > maxBytes) {
        throw const StarDictFormatException('词典正文解压后超过 2 GB 限制');
      }
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    return written;
  } catch (_) {
    await sink?.close();
    if (await destination.exists()) await destination.delete();
    rethrow;
  }
}
