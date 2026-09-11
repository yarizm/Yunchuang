import 'package:flutter/material.dart';

import '../../providers/ai/agent_models.dart';

/// AI 回复下方的「来源」卡片。
///
/// 从 `AiChatPanel` 拆出来：它只需要一组引用和一个点击回调，不碰面板状态。
class AiSourceReferenceList extends StatelessWidget {
  final List<AiSourceReference> references;
  final ValueChanged<AiSourceReference>? onOpen;

  const AiSourceReferenceList({
    super.key,
    required this.references,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
      final theme = Theme.of(context);
    final visibleReferences = references.take(6).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '引用来源',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var index = 0;
                  index < visibleReferences.length;
                  index++) ...[
                Builder(builder: (context) {
                  final reference = visibleReferences[index];
                  final canOpenReference = (reference.type == 'chapter' ||
                          reference.type == 'note') &&
                      (reference.chapterId != null ||
                          reference.locator?.pageNumber != null) &&
                      onOpen != null;
                  return Semantics(
                    button: canOpenReference,
                    child: InkWell(
                      onTap: canOpenReference
                          ? () => onOpen!(reference)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reference.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                  if (reference.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      reference.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    reference.snippet,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (canOpenReference) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (index != visibleReferences.length - 1)
                  Divider(
                    height: 14,
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.45),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
