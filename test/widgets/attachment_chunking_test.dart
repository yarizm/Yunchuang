import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/widgets/ai_chat/attachment_viewer.dart';

/// 按 [attachmentChunkEnds] 给出的边界切块。
List<String> chunk(String content, {int chunkChars = 100}) {
  final ends = attachmentChunkEnds(content, chunkChars: chunkChars);
  final parts = <String>[];
  var start = 0;
  for (final end in ends) {
    parts.add(content.substring(start, end));
    start = end;
  }
  return parts;
}

void main() {
  test('短内容只有一块', () {
    expect(attachmentChunkEnds('短短一句', chunkChars: 100), [4]);
  });

  test('切出来的块拼回去和原文一模一样', () {
    final content = List.generate(50, (i) => '第 $i 段正文内容。').join('\n');
    expect(chunk(content).join(), content);
  });

  test('边界单调递增，且最后一块正好到结尾', () {
    final content = '字' * 1000;
    final ends = attachmentChunkEnds(content, chunkChars: 100);

    expect(ends.first, greaterThan(0));
    expect(ends.last, content.length);
    for (var i = 1; i < ends.length; i++) {
      expect(ends[i], greaterThan(ends[i - 1]));
    }
  });

  test('优先切在段落边界上', () {
    // 换行落在后半段，应该被选作切点，块以换行结尾。
    final content = '${'甲' * 80}\n${'乙' * 200}';
    expect(chunk(content, chunkChars: 100).first, '${'甲' * 80}\n');
  });

  test('段落边界太靠前就不迁就它', () {
    // 换行只在第 5 个字符，切到那里会切出一堆碎块。
    final content = '甲甲甲甲\n${'乙' * 300}';
    expect(chunk(content, chunkChars: 100).first.length, 100);
  });

  // 这是把这段逻辑单独拆出来测的理由：emoji、生僻字在 Dart 里是一对
  // 代理项（两个 code unit）。正好切在中间会把一个字拆成两半，
  // substring 出来就是两个乱码，而且拼回去也修不回来。
  test('不会把代理对从中间切开', () {
    // 每个 emoji 占两个 code unit，40 个正好 80。再加内容把它推到边界上。
    final content = '${'字' * 99}😀${'尾' * 200}';
    final parts = chunk(content, chunkChars: 100);

    for (final part in parts) {
      if (part.isEmpty) continue;
      expect(_isHighSurrogate(part.codeUnitAt(part.length - 1)), isFalse,
          reason: '块尾停在了高代理项上：$part');
      expect(_isLowSurrogate(part.codeUnitAt(0)), isFalse,
          reason: '块首从低代理项开始：$part');
    }
    expect(parts.join(), content);
  });

  test('整段都是代理对时也切得干净', () {
    final content = '😀' * 300;
    final parts = chunk(content, chunkChars: 101);

    expect(parts.join(), content);
    for (final part in parts) {
      // 长度必须是偶数，否则说明切开了某个代理对。
      expect(part.length.isEven, isTrue, reason: '块长 ${part.length} 是奇数');
    }
  });

  test('空内容给出一个空块，不是空表', () {
    expect(attachmentChunkEnds('', chunkChars: 100), [0]);
  });
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
