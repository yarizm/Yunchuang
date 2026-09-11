import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

typedef CharsetDecodeCallback = Future<String> Function(
  String charset,
  Uint8List bytes,
);

class DecodedTextFile {
  final String text;
  final String encoding;
  final bool normalizedToUtf8;

  const DecodedTextFile({
    required this.text,
    required this.encoding,
    this.normalizedToUtf8 = false,
  });

  DecodedTextFile copyWith({
    String? text,
    String? encoding,
    bool? normalizedToUtf8,
  }) {
    return DecodedTextFile(
      text: text ?? this.text,
      encoding: encoding ?? this.encoding,
      normalizedToUtf8: normalizedToUtf8 ?? this.normalizedToUtf8,
    );
  }
}

class TextFileDecoder {
  static const List<String> _candidateCharsets = [
    'GB18030',
    'GBK',
    'GB2312',
    'BIG5',
    'SHIFT_JIS',
    'WINDOWS-1252',
    'ISO-8859-1',
  ];

  static Future<String> readAsString(
    String filePath, {
    bool normalizeToUtf8 = false,
  }) async {
    final decoded = await decodeFile(
      filePath,
      normalizeToUtf8: normalizeToUtf8,
    );
    return decoded.text;
  }

  static Future<DecodedTextFile> decodeFile(
    String filePath, {
    bool normalizeToUtf8 = false,
    CharsetDecodeCallback? decoder,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final decoded = await decodeBytes(bytes, decoder: decoder);
    if (!normalizeToUtf8 || !_shouldRewriteAsUtf8(decoded.encoding)) {
      return decoded;
    }

    final rewritten = await _rewriteAsUtf8(file, decoded.text);
    return decoded.copyWith(normalizedToUtf8: rewritten);
  }

  /// Rewrites [file] as UTF-8 through a sibling temp file, so a crash or a
  /// full disk mid-write cannot leave the user's book truncated. Returns false
  /// when the rewrite could not be completed — the original is left untouched
  /// and the decoded text is still usable in memory.
  static Future<bool> _rewriteAsUtf8(File file, String text) async {
    final temp = File('${file.path}.utf8.tmp');
    try {
      await temp.writeAsString(text, encoding: utf8, flush: true);
      await temp.rename(file.path);
      return true;
    } catch (_) {
      // Best effort: drop the partial temp file and keep the original.
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {
        // Nothing further to do; the original file is still intact.
      }
      return false;
    }
  }

  static Future<DecodedTextFile> decodeBytes(
    Uint8List bytes, {
    CharsetDecodeCallback? decoder,
  }) async {
    if (bytes.isEmpty) {
      return const DecodedTextFile(text: '', encoding: 'UTF-8');
    }

    final charsetDecoder = decoder ?? CharsetConverter.decode;

    if (_hasUtf8Bom(bytes)) {
      // Decode with allowMalformed so a corrupt BOM file degrades gracefully
      // instead of throwing FormatException (matches the non-BOM paths below).
      return DecodedTextFile(
        text: const Utf8Decoder(allowMalformed: true).convert(bytes.sublist(3)),
        encoding: 'UTF-8-BOM',
      );
    }

    final utf16Bom = await _tryDecodeUtf16Bom(bytes, charsetDecoder);
    if (utf16Bom != null) {
      return utf16Bom;
    }

    if (_isAscii(bytes)) {
      return DecodedTextFile(text: ascii.decode(bytes), encoding: 'UTF-8');
    }

    final candidates = <_DecodedCandidate>[];

    final utf8Text = _tryDecodeUtf8(bytes);
    if (utf8Text != null) {
      candidates.add(
        _DecodedCandidate('UTF-8', utf8Text, _scoreText(utf8Text)),
      );
    }

    for (final charset in _candidateCharsets) {
      final text = await _tryDecodeWithCharset(charsetDecoder, charset, bytes);
      if (text == null) {
        continue;
      }
      candidates.add(
        _DecodedCandidate(charset, text, _scoreText(text)),
      );
    }

    if (candidates.isEmpty) {
      return DecodedTextFile(
        text: utf8.decode(bytes, allowMalformed: true),
        encoding: 'UTF-8-MALFORMED',
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    return DecodedTextFile(text: best.text, encoding: best.charset);
  }

  static bool _shouldRewriteAsUtf8(String encoding) {
    return encoding != 'UTF-8' && encoding != 'UTF-8-MALFORMED';
  }

  static bool _hasUtf8Bom(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
  }

  static Future<DecodedTextFile?> _tryDecodeUtf16Bom(
    Uint8List bytes,
    CharsetDecodeCallback decoder,
  ) async {
    if (bytes.length < 2) {
      return null;
    }

    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final text = await _tryDecodeWithCharset(
        decoder,
        'UTF-16LE',
        Uint8List.sublistView(bytes, 2),
      );
      if (text != null) {
        return DecodedTextFile(text: text, encoding: 'UTF-16LE-BOM');
      }
    }

    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final text = await _tryDecodeWithCharset(
        decoder,
        'UTF-16BE',
        Uint8List.sublistView(bytes, 2),
      );
      if (text != null) {
        return DecodedTextFile(text: text, encoding: 'UTF-16BE-BOM');
      }
    }

    return null;
  }

  static bool _isAscii(Uint8List bytes) => bytes.every((byte) => byte < 0x80);

  static String? _tryDecodeUtf8(Uint8List bytes) {
    try {
      return const Utf8Decoder(allowMalformed: false).convert(bytes);
    } on FormatException {
      return null;
    }
  }

  static Future<String?> _tryDecodeWithCharset(
    CharsetDecodeCallback decoder,
    String charset,
    Uint8List bytes,
  ) async {
    try {
      return await decoder(charset, bytes);
    } catch (_) {
      return null;
    }
  }

  static double _scoreText(String text) {
    if (text.isEmpty) {
      return -1000000;
    }

    var printable = 0;
    var cjk = 0;
    var chinesePunctuation = 0;
    var replacements = 0;
    var control = 0;
    var nulls = 0;
    var suspiciousMojibake = 0;

    for (final rune in text.runes) {
      if (rune == 0xFFFD) {
        replacements++;
        continue;
      }
      if (rune == 0x0000) {
        nulls++;
        continue;
      }
      if (rune == 0x0A || rune == 0x0D || rune == 0x09) {
        printable++;
        continue;
      }
      if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
        control++;
        continue;
      }

      printable++;
      if (_isCjk(rune)) {
        cjk++;
      }
      if (_isChinesePunctuation(rune)) {
        chinesePunctuation++;
      }
      if (_looksLikeMojibakeRune(rune)) {
        suspiciousMojibake++;
      }
    }

    final length = text.runes.length;
    final printableRatio = printable / length;
    final cjkRatio = cjk / length;
    final punctuationRatio = chinesePunctuation / length;

    var score = printableRatio * 120;
    score += cjkRatio * 160;
    score += punctuationRatio * 80;
    score -= replacements * 60;
    score -= nulls * 100;
    score -= control * 25;
    score -= suspiciousMojibake * 2;

    if (_chapterSignal.hasMatch(text)) {
      score += 10;
    }

    return score;
  }

  static bool _isCjk(int rune) {
    return (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF);
  }

  static bool _isChinesePunctuation(int rune) {
    switch (rune) {
      case 0x3001:
      case 0x3002:
      case 0x3008:
      case 0x3009:
      case 0x300A:
      case 0x300B:
      case 0x300C:
      case 0x300D:
      case 0x300E:
      case 0x300F:
      case 0x3010:
      case 0x3011:
      case 0xFF01:
      case 0xFF08:
      case 0xFF09:
      case 0xFF0C:
      case 0xFF1A:
      case 0xFF1B:
      case 0xFF1F:
        return true;
      default:
        return false;
    }
  }

  static bool _looksLikeMojibakeRune(int rune) {
    return (rune >= 0x00C0 && rune <= 0x00FF) ||
        rune == 0x0152 ||
        rune == 0x0153;
  }

  static final RegExp _chapterSignal = RegExp(
    r'(第[0-9零〇一二两三四五六七八九十百千万甲乙丙丁]+[章节回卷篇部集册]|Chapter\s+\d+)',
    caseSensitive: false,
  );
}

class _DecodedCandidate {
  final String charset;
  final String text;
  final double score;

  const _DecodedCandidate(this.charset, this.text, this.score);
}
