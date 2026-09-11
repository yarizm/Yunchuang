import 'package:flutter/material.dart';

import '../../providers/ai/agent_models.dart';

/// 附件全文查看器，以及它用的分块逻辑。
///
/// 从 `AiChatPanel` 拆出来：弹层只依赖一个附件对象，分块是纯函数。
/// 分块那段值得单独测——切块时要避开代理对，切在中间会把一个字拆成两半
/// 变成乱码，而中文之外的表情、生僻字正是靠代理对表示的。

/// 每块的字符数。太大一次渲染卡顿，太小滚动时块太多。
const attachmentViewerChunkChars = 3000;

List<int> attachmentChunkEnds(
  String content, {
  int chunkChars = attachmentViewerChunkChars,
}) {
  if (content.length <= chunkChars) {
    return [content.length];
  }
  final ends = <int>[];
  var start = 0;
  while (start < content.length) {
    var end = (start + chunkChars)
        .clamp(0, content.length)
        .toInt();
    if (end < content.length) {
      final paragraphEnd = content.lastIndexOf('\n', end - 1);
      if (paragraphEnd > start + chunkChars ~/ 2) {
        end = paragraphEnd + 1;
      } else if (_isLowSurrogate(content.codeUnitAt(end))) {
        end--;
      }
    }
    ends.add(end);
    start = end;
  }
  return ends;
}

bool _isLowSurrogate(int codeUnit) =>
    codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

Future<void> showAiAttachmentViewer(
  BuildContext context,
  AiAttachment attachment,
) {
  final chunkEnds = attachmentChunkEnds(attachment.content);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return FractionallySizedBox(
        key: const ValueKey('ai_attachment_viewer'),
        heightFactor: 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.notes, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '约 ${attachment.length} 字',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭附件',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: chunkEnds.length,
                itemBuilder: (context, index) {
                  final start = index == 0 ? 0 : chunkEnds[index - 1];
                  final end = chunkEnds[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == chunkEnds.length - 1 ? 0 : 12,
                    ),
                    child: SelectableText(
                      attachment.content.substring(start, end),
                      key: ValueKey('ai_attachment_chunk_$index'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
