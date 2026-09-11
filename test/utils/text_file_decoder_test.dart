import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/utils/text_file_decoder.dart';

void main() {
  group('TextFileDecoder', () {
    test('decodes utf8 text with bom', () async {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('第一章 开始'),
      ]);

      final decoded = await TextFileDecoder.decodeBytes(bytes);
      expect(decoded.text, '第一章 开始');
      expect(decoded.encoding, 'UTF-8-BOM');
    });

    test('decodes bom file with malformed trailing bytes without throwing',
        () async {
      // BOM + valid '中' + a truncated multi-byte sequence (0xE4 0xB8 with no
      // continuation byte), which is invalid UTF-8.
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('中'),
        0xE4,
        0xB8,
      ]);

      final decoded = await TextFileDecoder.decodeBytes(bytes);
      expect(decoded.encoding, 'UTF-8-BOM');
      expect(decoded.text, startsWith('中'));
      expect(decoded.text, contains('�'));
    });

    test('prefers chinese-capable fallback charset for invalid utf8 bytes', () async {
      final bytes = Uint8List.fromList([0xD2, 0xBB, 0xD5, 0xC2]);

      final decoded = await TextFileDecoder.decodeBytes(
        bytes,
        decoder: (charset, _) async {
          switch (charset) {
            case 'GB18030':
              return '一章';
            case 'GBK':
              return '一章';
            case 'WINDOWS-1252':
              return 'Ò»ÕÂ';
            case 'ISO-8859-1':
              return 'Ò»ÕÂ';
            default:
              throw UnsupportedError(charset);
          }
        },
      );

      expect(decoded.text, '一章');
      expect(decoded.encoding, anyOf('GB18030', 'GBK'));
    });
  });
}
