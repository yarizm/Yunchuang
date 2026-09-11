import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// AI 回复的 Markdown 样式。
///
/// 从 `AiChatPanel` 拆出来：它只吃一个 ThemeData，和面板状态无关，
/// 而且已经有测试单独在用。
MarkdownStyleSheet aiMarkdownStyleSheet(ThemeData theme) {
  final scheme = theme.colorScheme;
  final bodyMedium = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
    fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14,
  );
  final resolvedTheme = theme.copyWith(
    textTheme: theme.textTheme.copyWith(bodyMedium: bodyMedium),
  );
  final body = bodyMedium.copyWith(color: scheme.onSurface);
  final headingColor = scheme.onSurface;
  return MarkdownStyleSheet.fromTheme(resolvedTheme).copyWith(
    a: body.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    ),
    p: body,
    code: bodyMedium.copyWith(
      color: scheme.onSurface,
      backgroundColor: scheme.surfaceContainerHigh,
      fontFamily: 'monospace',
    ),
    h1: theme.textTheme.headlineMedium?.copyWith(color: headingColor),
    h2: theme.textTheme.headlineSmall?.copyWith(color: headingColor),
    h3: theme.textTheme.titleLarge?.copyWith(color: headingColor),
    h4: theme.textTheme.titleMedium?.copyWith(color: headingColor),
    h5: theme.textTheme.titleSmall?.copyWith(color: headingColor),
    h6: theme.textTheme.labelLarge?.copyWith(color: headingColor),
    em: body.copyWith(fontStyle: FontStyle.italic),
    strong: body.copyWith(fontWeight: FontWeight.w700),
    blockquote: body.copyWith(color: scheme.onSurfaceVariant),
    listBullet: body,
    tableHead: body.copyWith(fontWeight: FontWeight.w700),
    tableBody: body,
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
    ),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: scheme.outlineVariant),
    ),
  );
}
