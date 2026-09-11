import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/daos/dictionary_dao.dart';
import 'package:yunchuang/services/stardict_parser.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('stardict_parser_');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('parses StarDict 2.4.2 and 3.0.0 metadata', () {
    final v2 = StarDictParser.parseIfo(
      "StarDict's dict ifo file\n"
      'version=2.4.2\n'
      'bookname=测试词典\n'
      'wordcount=2\n'
      'idxfilesize=30\n'
      'sametypesequence=tm\n'
      'description=第一行<BR />第二行\n',
    );
    expect(v2.bookName, '测试词典');
    expect(v2.offsetBits, 32);
    expect(v2.sameTypeSequence, 'tm');
    expect(v2.description, '第一行\n第二行');

    final v3 = StarDictParser.parseIfo(
      "StarDict's dict ifo file\n"
      'version=3.0.0\n'
      'bookname=Large\n'
      'wordcount=1\n'
      'idxfilesize=17\n'
      'idxoffsetbits=64\n',
    );
    expect(v3.offsetBits, 64);
  });

  test('rejects unsupported or inconsistent metadata', () {
    expect(
      () => StarDictParser.parseIfo(
        "StarDict's dict ifo file\n"
        'version=1.0\n'
        'bookname=Bad\n'
        'wordcount=1\n'
        'idxfilesize=10\n',
      ),
      throwsA(isA<StarDictFormatException>()),
    );
    expect(
      () => StarDictParser.parseIfo(
        "StarDict's dict ifo file\n"
        'version=2.4.2\n'
        'bookname=Bad\n'
        'wordcount=1\n'
        'idxfilesize=10\n'
        'idxoffsetbits=64\n',
      ),
      throwsA(isA<StarDictFormatException>()),
    );
  });

  test('streams 32-bit gzip index and synonyms in batches', () async {
    final indexBytes = _indexBytes([
      ('apple', 0, 5),
      ('苹果', 5, 6),
    ]);
    final indexFile = File('${tempDirectory.path}/fixture.idx.gz');
    await indexFile.writeAsBytes(gzip.encode(indexBytes));
    final synonymFile = File('${tempDirectory.path}/fixture.syn');
    await synonymFile.writeAsBytes(_synonymBytes([('fruit', 0)]));
    final metadata = StarDictParser.parseIfo(
      "StarDict's dict ifo file\n"
      'version=2.4.2\n'
      'bookname=Fixture\n'
      'wordcount=2\n'
      'synwordcount=1\n'
      'idxfilesize=${indexBytes.length}\n'
      'sametypesequence=m\n',
    );
    final entries = <DictionaryIndexRecord>[];
    final aliases = <DictionaryAliasRecord>[];

    final summary = await StarDictParser.importIndex(
      metadata: metadata,
      indexPath: indexFile.path,
      synonymPath: synonymFile.path,
      onEntryBatch: (batch) async => entries.addAll(batch),
      onAliasBatch: (batch) async => aliases.addAll(batch),
    );

    expect(summary.entryCount, 2);
    expect(summary.requiredDataBytes, 11);
    expect(entries.map((entry) => entry.headword), ['apple', '苹果']);
    expect(entries.last.dataOffset, 5);
    expect(entries.last.dataSize, 6);
    expect(aliases.single.alias, 'fruit');
    expect(aliases.single.targetEntryIndex, 0);
  });

  test('reads 64-bit offsets and rejects a mismatched count', () async {
    final indexBytes = _indexBytes(
      [('large', 0x100000001, 9)],
      offsetBits: 64,
    );
    final indexFile = File('${tempDirectory.path}/large.idx');
    await indexFile.writeAsBytes(indexBytes);
    final metadata = StarDictParser.parseIfo(
      "StarDict's dict ifo file\n"
      'version=3.0.0\n'
      'bookname=Large\n'
      'wordcount=1\n'
      'idxfilesize=${indexBytes.length}\n'
      'idxoffsetbits=64\n',
    );
    final entries = <DictionaryIndexRecord>[];
    final summary = await StarDictParser.importIndex(
      metadata: metadata,
      indexPath: indexFile.path,
      onEntryBatch: (batch) async => entries.addAll(batch),
      onAliasBatch: (_) async {},
    );
    expect(entries.single.dataOffset, 0x100000001);
    expect(summary.requiredDataBytes, 0x10000000a);

    final wrongCount = StarDictParser.parseIfo(
      "StarDict's dict ifo file\n"
      'version=3.0.0\n'
      'bookname=Large\n'
      'wordcount=2\n'
      'idxfilesize=${indexBytes.length}\n'
      'idxoffsetbits=64\n',
    );
    expect(
      StarDictParser.importIndex(
        metadata: wrongCount,
        indexPath: indexFile.path,
        onEntryBatch: (_) async {},
        onAliasBatch: (_) async {},
      ),
      throwsA(isA<StarDictFormatException>()),
    );
  });

  test('decodes optimized and typed textual definition fields', () {
    final optimized = Uint8List.fromList([
      ...utf8.encode('fəŋ'),
      0,
      ...utf8.encode('主角'),
    ]);
    expect(
      StarDictParser.decodeDefinition(
        optimized,
        sameTypeSequence: 'tm',
      ),
      '音标：fəŋ\n主角',
    );

    final typed = Uint8List.fromList([
      'm'.codeUnitAt(0),
      ...utf8.encode('plain'),
      0,
      'h'.codeUnitAt(0),
      ...utf8.encode('<b>bold</b><br>next'),
      0,
    ]);
    expect(
      StarDictParser.decodeDefinition(typed),
      'plain\nbold\nnext',
    );
  });
}

Uint8List _indexBytes(
  List<(String, int, int)> records, {
  int offsetBits = 32,
}) {
  final builder = BytesBuilder(copy: false);
  for (final record in records) {
    builder
      ..add(utf8.encode(record.$1))
      ..addByte(0);
    final data = ByteData(offsetBits == 64 ? 12 : 8);
    if (offsetBits == 64) {
      data
        ..setUint64(0, record.$2, Endian.big)
        ..setUint32(8, record.$3, Endian.big);
    } else {
      data
        ..setUint32(0, record.$2, Endian.big)
        ..setUint32(4, record.$3, Endian.big);
    }
    builder.add(data.buffer.asUint8List());
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
