import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/dictionary_dao.dart';
import 'package:yunchuang/services/dictionary_service.dart';
import 'package:yunchuang/services/stardict_parser.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late DictionaryDao dao;
  late DictionaryService service;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('dictionary_service_');
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = DictionaryDao(database);
    service = DictionaryService(
      dao,
      appDirectoryProvider: () async => tempDirectory,
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('imports compressed StarDict data and resolves words and synonyms',
      () async {
    final fixture = await _writeFixture(tempDirectory);
    final statuses = <String>[];

    final source = await service.importStarDict(
      fixture,
      onProgress: statuses.add,
    );

    expect(source.name, 'Fixture Dictionary');
    expect(source.entryCount, 2);
    expect(source.enabled, isTrue);
    expect(source.isReady, isTrue);
    expect(await File(source.dataFilePath).exists(), isTrue);
    expect(statuses, contains('正在解压词典正文…'));

    final direct = await service.lookup(' APPLE ');
    expect(direct.installedSourceCount, 1);
    expect(direct.enabledSourceCount, 1);
    expect(direct.definitions.single.headword, 'apple');
    expect(direct.definitions.single.definition, 'A fruit');

    final synonym = await service.lookup('fruit');
    expect(synonym.definitions.single.headword, 'apple');
    expect(synonym.definitions.single.definition, 'A fruit');

    final chinese = await service.lookup('苹果');
    expect(chinese.definitions.single.definition, '一种水果');
  });

  test('can disable and delete an imported dictionary', () async {
    final source = await service.importStarDict(
      await _writeFixture(tempDirectory),
    );
    final dataPath = source.dataFilePath;

    await service.setEnabled(source.id, false);
    final disabled = await service.lookup('apple');
    expect(disabled.installedSourceCount, 1);
    expect(disabled.enabledSourceCount, 0);
    expect(disabled.definitions, isEmpty);

    await service.deleteSource(source.id);
    expect(await dao.getReadySources(), isEmpty);
    expect(await File(dataPath).exists(), isFalse);
  });

  test('rejects incomplete bundles and cleans pending imports', () async {
    expect(
      () => StarDictImportBundle.resolve([
        const StarDictSelectedFile(name: 'only.ifo', path: 'only.ifo'),
      ]),
      throwsA(isA<StarDictFormatException>()),
    );

    final dataFile = File('${tempDirectory.path}/dictionaries/stale.dict');
    await dataFile.parent.create(recursive: true);
    await dataFile.writeAsString('stale');
    await dao.createPendingSource(
      name: 'Stale',
      description: null,
      formatVersion: '2.4.2',
      sameTypeSequence: 'm',
      dataFilePath: dataFile.path,
    );

    await service.cleanupIncompleteImports();
    expect(await dao.getIncompleteSources(), isEmpty);
    expect(await dataFile.exists(), isFalse);
  });

  test('honors cancellation before import starts', () async {
    final cancellation = StarDictImportCancellation()..cancel();
    expect(
      service.importStarDict(
        await _writeFixture(tempDirectory),
        cancellation: cancellation,
      ),
      throwsA(isA<StarDictImportCancelled>()),
    );
  });
}

Future<List<StarDictSelectedFile>> _writeFixture(Directory directory) async {
  final definitionOne = utf8.encode('A fruit');
  final definitionTwo = utf8.encode('一种水果');
  final dictionaryBytes = Uint8List.fromList([
    ...definitionOne,
    ...definitionTwo,
  ]);
  final indexBytes = _indexBytes([
    ('apple', 0, definitionOne.length),
    ('苹果', definitionOne.length, definitionTwo.length),
  ]);
  final info = File('${directory.path}/fixture.ifo');
  final index = File('${directory.path}/picked_index_cache');
  final data = File('${directory.path}/picked_data_cache');
  final synonyms = File('${directory.path}/fixture.syn');
  await info.writeAsString(
    "StarDict's dict ifo file\n"
    'version=2.4.2\n'
    'bookname=Fixture Dictionary\n'
    'wordcount=2\n'
    'synwordcount=1\n'
    'idxfilesize=${indexBytes.length}\n'
    'sametypesequence=m\n',
  );
  await index.writeAsBytes(gzip.encode(indexBytes));
  await data.writeAsBytes(gzip.encode(dictionaryBytes));
  await synonyms.writeAsBytes(_synonymBytes([('fruit', 0)]));
  return [
    StarDictSelectedFile(name: 'fixture.ifo', path: info.path),
    StarDictSelectedFile(name: 'fixture.idx.gz', path: index.path),
    StarDictSelectedFile(name: 'fixture.dict.dz', path: data.path),
    StarDictSelectedFile(name: 'fixture.syn', path: synonyms.path),
  ];
}

Uint8List _indexBytes(List<(String, int, int)> records) {
  final builder = BytesBuilder(copy: false);
  for (final record in records) {
    final data = ByteData(8)
      ..setUint32(0, record.$2, Endian.big)
      ..setUint32(4, record.$3, Endian.big);
    builder
      ..add(utf8.encode(record.$1))
      ..addByte(0)
      ..add(data.buffer.asUint8List());
  }
  return builder.takeBytes();
}

Uint8List _synonymBytes(List<(String, int)> records) {
  final builder = BytesBuilder(copy: false);
  for (final record in records) {
    final data = ByteData(4)..setUint32(0, record.$2, Endian.big);
    builder
      ..add(utf8.encode(record.$1))
      ..addByte(0)
      ..add(data.buffer.asUint8List());
  }
  return builder.takeBytes();
}
