import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:html/parser.dart' as html_parser;

import '../database/daos/dictionary_dao.dart';

class StarDictFormatException implements Exception {
  final String message;

  const StarDictFormatException(this.message);

  @override
  String toString() => message;
}

class StarDictImportCancelled implements Exception {
  const StarDictImportCancelled();

  @override
  String toString() => '词典导入已取消';
}

class StarDictImportCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const StarDictImportCancelled();
  }
}

class StarDictMetadata {
  final String version;
  final String bookName;
  final int wordCount;
  final int indexFileSize;
  final int offsetBits;
  final int? synonymCount;
  final String? description;
  final String? sameTypeSequence;

  const StarDictMetadata({
    required this.version,
    required this.bookName,
    required this.wordCount,
    required this.indexFileSize,
    required this.offsetBits,
    required this.synonymCount,
    required this.description,
    required this.sameTypeSequence,
  });
}

class StarDictIndexSummary {
  final int entryCount;
  final int requiredDataBytes;

  const StarDictIndexSummary({
    required this.entryCount,
    required this.requiredDataBytes,
  });
}

class StarDictParser {
  static const maxIndexBytes = 128 * 1024 * 1024;
  static const maxWordCount = 1000000;
  static const batchSize = 1000;

  static StarDictMetadata parseIfo(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    if (lines.isEmpty || lines.first.trim() != "StarDict's dict ifo file") {
      throw const StarDictFormatException('不是有效的 StarDict .ifo 文件');
    }
    final values = <String, String>{};
    for (final rawLine in lines.skip(1)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) {
        throw StarDictFormatException('无效的 .ifo 配置行：$rawLine');
      }
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      values[key] = value;
    }

    final version = values['version'];
    if (version != '2.4.2' && version != '3.0.0') {
      throw StarDictFormatException('不支持的 StarDict 版本：${version ?? '缺失'}');
    }
    final bookName = values['bookname']?.trim();
    if (bookName == null || bookName.isEmpty || bookName.length > 500) {
      throw const StarDictFormatException('词典名称缺失或过长');
    }
    final wordCount = int.tryParse(values['wordcount'] ?? '');
    if (wordCount == null || wordCount <= 0 || wordCount > maxWordCount) {
      throw const StarDictFormatException('词条数量无效或超过 100 万条限制');
    }
    final indexFileSize = int.tryParse(values['idxfilesize'] ?? '');
    if (indexFileSize == null ||
        indexFileSize <= 0 ||
        indexFileSize > maxIndexBytes) {
      throw const StarDictFormatException('索引大小无效或超过 128 MB 限制');
    }
    final offsetBits = int.tryParse(values['idxoffsetbits'] ?? '32');
    if (offsetBits != 32 && offsetBits != 64) {
      throw const StarDictFormatException('idxoffsetbits 只能是 32 或 64');
    }
    if (offsetBits == 64 && version != '3.0.0') {
      throw const StarDictFormatException('64 位索引只支持 StarDict 3.0.0');
    }
    final synonymCount = values['synwordcount'] == null
        ? null
        : int.tryParse(values['synwordcount']!);
    if (values['synwordcount'] != null &&
        (synonymCount == null || synonymCount < 0)) {
      throw const StarDictFormatException('同义词数量无效');
    }
    final sameTypeSequence = _normalizeOptional(
      values['sametypesequence'],
    );
    if (sameTypeSequence != null &&
        (!RegExp(r'^[A-Za-z]+$').hasMatch(sameTypeSequence) ||
            sameTypeSequence.length > 64)) {
      throw const StarDictFormatException('sametypesequence 格式无效');
    }

    return StarDictMetadata(
      version: version!,
      bookName: bookName,
      wordCount: wordCount,
      indexFileSize: indexFileSize,
      offsetBits: offsetBits!,
      synonymCount: synonymCount,
      description: _normalizeOptional(
        values['description']?.replaceAll(
          RegExp(r'<br\s*/?>', caseSensitive: false),
          '\n',
        ),
      ),
      sameTypeSequence: sameTypeSequence,
    );
  }

  static Future<StarDictIndexSummary> importIndex({
    required StarDictMetadata metadata,
    required String indexPath,
    bool? indexCompressed,
    String? synonymPath,
    required Future<void> Function(List<DictionaryIndexRecord>) onEntryBatch,
    required Future<void> Function(List<DictionaryAliasRecord>) onAliasBatch,
    void Function(int completed, int total)? onProgress,
    StarDictImportCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn<Map<String, Object?>>(
      _runIndexWorker,
      {
        'sendPort': receivePort.sendPort,
        'indexPath': indexPath,
        'indexCompressed':
            indexCompressed ?? indexPath.toLowerCase().endsWith('.gz'),
        'synonymPath': synonymPath,
        'wordCount': metadata.wordCount,
        'indexFileSize': metadata.indexFileSize,
        'offsetBits': metadata.offsetBits,
        'synonymCount': metadata.synonymCount,
      },
      debugName: 'stardict-index-import',
    );

    try {
      await for (final rawMessage in receivePort) {
        final message = rawMessage as List<Object?>;
        final type = message[0] as String;
        if (type == 'entries') {
          cancellation?.throwIfCancelled();
          final rawRecords = message[1] as List<Object?>;
          final records = rawRecords.map((raw) {
            final values = raw as List<Object?>;
            return DictionaryIndexRecord(
              entryIndex: values[0] as int,
              headword: values[1] as String,
              normalizedHeadword: values[2] as String,
              dataOffset: values[3] as int,
              dataSize: values[4] as int,
            );
          }).toList(growable: false);
          await onEntryBatch(records);
          onProgress?.call(message[2] as int, metadata.wordCount);
          (message[3] as SendPort).send(true);
          continue;
        }
        if (type == 'aliases') {
          cancellation?.throwIfCancelled();
          final rawRecords = message[1] as List<Object?>;
          final records = rawRecords.map((raw) {
            final values = raw as List<Object?>;
            return DictionaryAliasRecord(
              alias: values[0] as String,
              normalizedAlias: values[1] as String,
              targetEntryIndex: values[2] as int,
            );
          }).toList(growable: false);
          await onAliasBatch(records);
          (message[2] as SendPort).send(true);
          continue;
        }
        if (type == 'done') {
          return StarDictIndexSummary(
            entryCount: message[1] as int,
            requiredDataBytes: message[2] as int,
          );
        }
        if (type == 'error') {
          throw StarDictFormatException(message[1] as String);
        }
      }
      throw const StarDictFormatException('词典索引解析进程意外结束');
    } finally {
      isolate.kill(priority: Isolate.immediate);
      receivePort.close();
    }
  }

  static String decodeDefinition(
    Uint8List bytes, {
    String? sameTypeSequence,
  }) {
    if (bytes.isEmpty) return '';
    final parts = <String>[];
    if (sameTypeSequence?.isNotEmpty == true) {
      var cursor = 0;
      final sequence = sameTypeSequence!;
      for (var index = 0;
          index < sequence.length && cursor <= bytes.length;
          index++) {
        final type = sequence[index];
        final isLast = index == sequence.length - 1;
        late Uint8List field;
        if (isLast) {
          field = Uint8List.sublistView(bytes, cursor);
          cursor = bytes.length;
        } else if (_isLowerType(type)) {
          final end = bytes.indexOf(0, cursor);
          if (end < 0) {
            throw const StarDictFormatException('词典释义字段缺少结束标记');
          }
          field = Uint8List.sublistView(bytes, cursor, end);
          cursor = end + 1;
        } else {
          final length = _readUint32(bytes, cursor);
          cursor += 4;
          if (length < 0 || cursor + length > bytes.length) {
            throw const StarDictFormatException('词典释义字段长度越界');
          }
          field = Uint8List.sublistView(bytes, cursor, cursor + length);
          cursor += length;
        }
        _appendTextPart(parts, type, field);
      }
    } else {
      var cursor = 0;
      while (cursor < bytes.length) {
        final typeCode = bytes[cursor++];
        final type = String.fromCharCode(typeCode);
        if (!RegExp(r'^[A-Za-z]$').hasMatch(type)) {
          throw const StarDictFormatException('词典释义包含无效的数据类型');
        }
        late Uint8List field;
        if (_isLowerType(type)) {
          final end = bytes.indexOf(0, cursor);
          if (end < 0) {
            throw const StarDictFormatException('词典释义字段缺少结束标记');
          }
          field = Uint8List.sublistView(bytes, cursor, end);
          cursor = end + 1;
        } else {
          final length = _readUint32(bytes, cursor);
          cursor += 4;
          if (length < 0 || cursor + length > bytes.length) {
            throw const StarDictFormatException('词典释义字段长度越界');
          }
          field = Uint8List.sublistView(bytes, cursor, cursor + length);
          cursor += length;
        }
        _appendTextPart(parts, type, field);
      }
    }
    return parts.where((part) => part.trim().isNotEmpty).join('\n').trim();
  }
}

Future<void> _runIndexWorker(Map<String, Object?> request) async {
  final sendPort = request['sendPort']! as SendPort;
  try {
    final indexPath = request['indexPath']! as String;
    final indexCompressed = request['indexCompressed']! as bool;
    final expectedSize = request['indexFileSize']! as int;
    final expectedCount = request['wordCount']! as int;
    final offsetBits = request['offsetBits']! as int;
    final indexBytes = await _readIndexBytes(
      indexPath,
      expectedSize,
      compressed: indexCompressed,
    );
    var cursor = 0;
    var entryIndex = 0;
    var requiredDataBytes = 0;
    var batch = <List<Object?>>[];
    final offsetBytes = offsetBits == 64 ? 8 : 4;

    while (cursor < indexBytes.length) {
      final wordEnd = indexBytes.indexOf(0, cursor);
      if (wordEnd <= cursor || wordEnd - cursor >= 256) {
        throw const StarDictFormatException('索引包含无效词条名称');
      }
      if (wordEnd + 1 + offsetBytes + 4 > indexBytes.length) {
        throw const StarDictFormatException('词典索引记录不完整');
      }
      final headword = utf8.decode(
        Uint8List.sublistView(indexBytes, cursor, wordEnd),
      );
      cursor = wordEnd + 1;
      final dataOffset = offsetBits == 64
          ? ByteData.sublistView(indexBytes, cursor, cursor + 8)
              .getUint64(0, Endian.big)
          : ByteData.sublistView(indexBytes, cursor, cursor + 4)
              .getUint32(0, Endian.big);
      cursor += offsetBytes;
      final dataSize = ByteData.sublistView(indexBytes, cursor, cursor + 4)
          .getUint32(0, Endian.big);
      cursor += 4;
      if (dataSize <= 0 || dataOffset > 0x7fffffffffffffff) {
        throw const StarDictFormatException('词典索引偏移或长度无效');
      }
      final dataEnd = dataOffset + dataSize;
      if (dataEnd > 0x7fffffffffffffff) {
        throw const StarDictFormatException('词典索引数据范围过大');
      }
      if (dataEnd > requiredDataBytes) requiredDataBytes = dataEnd;
      final normalized = _normalizeHeadword(headword);
      if (normalized.isEmpty || headword.length > 500) {
        throw const StarDictFormatException('词典索引包含空词条或超长词条');
      }
      batch.add([
        entryIndex,
        headword,
        normalized,
        dataOffset,
        dataSize,
      ]);
      entryIndex++;
      if (batch.length >= StarDictParser.batchSize) {
        final shouldContinue = await _sendWorkerBatch(
          sendPort,
          'entries',
          batch,
          progress: entryIndex,
        );
        if (!shouldContinue) return;
        batch = <List<Object?>>[];
      }
    }
    if (batch.isNotEmpty) {
      final shouldContinue = await _sendWorkerBatch(
        sendPort,
        'entries',
        batch,
        progress: entryIndex,
      );
      if (!shouldContinue) return;
    }
    if (entryIndex != expectedCount) {
      throw StarDictFormatException(
        '词典索引记录数为 $entryIndex，与 .ifo 声明的 $expectedCount 不一致',
      );
    }

    final synonymPath = request['synonymPath'] as String?;
    if (synonymPath != null) {
      final bytes = await File(synonymPath).readAsBytes();
      var synonymCursor = 0;
      var synonymCount = 0;
      var aliasBatch = <List<Object?>>[];
      while (synonymCursor < bytes.length) {
        final wordEnd = bytes.indexOf(0, synonymCursor);
        if (wordEnd <= synonymCursor || wordEnd - synonymCursor >= 256) {
          throw const StarDictFormatException('同义词索引包含无效名称');
        }
        if (wordEnd + 5 > bytes.length) {
          throw const StarDictFormatException('同义词索引记录不完整');
        }
        final alias = utf8.decode(
          Uint8List.sublistView(bytes, synonymCursor, wordEnd),
        );
        synonymCursor = wordEnd + 1;
        final targetIndex =
            ByteData.sublistView(bytes, synonymCursor, synonymCursor + 4)
                .getUint32(0, Endian.big);
        synonymCursor += 4;
        if (targetIndex >= entryIndex) {
          throw const StarDictFormatException('同义词指向不存在的词条');
        }
        final normalizedAlias = _normalizeHeadword(alias);
        if (normalizedAlias.isEmpty || alias.length > 500) {
          throw const StarDictFormatException('同义词索引包含空名称或超长名称');
        }
        aliasBatch.add([alias, normalizedAlias, targetIndex]);
        synonymCount++;
        if (aliasBatch.length >= StarDictParser.batchSize) {
          final shouldContinue = await _sendWorkerBatch(
            sendPort,
            'aliases',
            aliasBatch,
          );
          if (!shouldContinue) return;
          aliasBatch = <List<Object?>>[];
        }
      }
      if (aliasBatch.isNotEmpty) {
        final shouldContinue = await _sendWorkerBatch(
          sendPort,
          'aliases',
          aliasBatch,
        );
        if (!shouldContinue) return;
      }
      final expectedSynonymCount = request['synonymCount'] as int?;
      if (expectedSynonymCount != null &&
          synonymCount != expectedSynonymCount) {
        throw StarDictFormatException(
          '同义词记录数为 $synonymCount，与 .ifo 声明的 '
          '$expectedSynonymCount 不一致',
        );
      }
    }
    sendPort.send(['done', entryIndex, requiredDataBytes]);
  } catch (error, stackTrace) {
    sendPort.send(['error', '$error', '$stackTrace']);
  }
}

Future<Uint8List> _readIndexBytes(
  String indexPath,
  int expectedSize, {
  required bool compressed,
}) async {
  final file = File(indexPath);
  if (!await file.exists()) {
    throw const StarDictFormatException('找不到词典索引文件');
  }
  final raw = await file.readAsBytes();
  final bytes = compressed
      ? Uint8List.fromList(gzip.decode(raw))
      : Uint8List.fromList(raw);
  if (bytes.length != expectedSize) {
    throw StarDictFormatException(
      '词典索引大小为 ${bytes.length}，与 .ifo 声明的 $expectedSize 不一致',
    );
  }
  return bytes;
}

Future<bool> _sendWorkerBatch(
  SendPort sendPort,
  String type,
  List<List<Object?>> records, {
  int? progress,
}) async {
  final acknowledgement = ReceivePort();
  sendPort.send([
    type,
    records,
    if (progress != null) progress,
    acknowledgement.sendPort,
  ]);
  final result = await acknowledgement.first;
  acknowledgement.close();
  return result == true;
}

int _readUint32(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    throw const StarDictFormatException('词典释义字段长度不完整');
  }
  return ByteData.sublistView(bytes, offset, offset + 4)
      .getUint32(0, Endian.big);
}

bool _isLowerType(String type) {
  final code = type.codeUnitAt(0);
  return code >= 0x61 && code <= 0x7a;
}

void _appendTextPart(
  List<String> parts,
  String type,
  Uint8List bytes,
) {
  if (!_isLowerType(type) || type == 'r' || bytes.isEmpty) return;
  var text = utf8.decode(bytes, allowMalformed: true).replaceAll('\u0000', '');
  if ({'g', 'h', 'k', 'x'}.contains(type)) {
    text = _markupToText(text);
  } else if (type == 'w') {
    text = _wikiToText(text);
  }
  text = text.trim();
  if (text.isEmpty) return;
  if (type == 't' || type == 'y') {
    parts.add('音标：$text');
  } else {
    parts.add(text);
  }
}

String _markupToText(String value) {
  final withBreaks = value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(?:p|div|li|tr|ar)>', caseSensitive: false),
        '\n',
      );
  final text = html_parser.parseFragment(withBreaks).text ?? '';
  return text
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

String _wikiToText(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'\[\[(?:[^\]|]+\|)?([^\]]+)\]\]'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r"'{2,}"), '')
      .replaceAllMapped(
        RegExp(r'={2,}\s*(.*?)\s*={2,}'),
        (match) => match.group(1) ?? '',
      )
      .trim();
}

String _normalizeHeadword(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
