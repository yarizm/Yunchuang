import 'package:flutter/material.dart';

import '../../database/app_database.dart';

/// 角色人格生成完成后，用户选的下一步。
enum PersonaGeneratedAction { view, use }

/// 生成完成的提示框。[persona] 为空（刷新后的列表里没找到它）时只留
/// 「稍后再说」，不给指向一个拿不到的人格的按钮。
Future<PersonaGeneratedAction?> showPersonaGeneratedDialog(
  BuildContext context, {
  required AiPersona? persona,
  required String fallbackName,
}) {
  return showDialog<PersonaGeneratedAction>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          size: 52,
          color: theme.colorScheme.primary,
        ),
        title: const Text('角色人格已生成'),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.theater_comedy_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona?.name ?? fallbackName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text('已保存，可立即查看、编辑或启用'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后再说'),
          ),
          if (persona != null) ...[
            OutlinedButton.icon(
              key: const Key('persona-generation-view'),
              onPressed: () =>
                  Navigator.pop(dialogContext, PersonaGeneratedAction.view),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('查看并编辑'),
            ),
            FilledButton.icon(
              key: const Key('persona-generation-use'),
              onPressed: () =>
                  Navigator.pop(dialogContext, PersonaGeneratedAction.use),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('立即启用'),
            ),
          ],
        ],
      );
    },
  );
}
