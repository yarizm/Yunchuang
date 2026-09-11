import 'package:flutter/material.dart';

class ReaderSelectedRange {
  final String text;
  final int start;
  final int end;

  const ReaderSelectedRange({
    required this.text,
    required this.start,
    required this.end,
  });
}

ReaderSelectedRange readerSelectedRange({
  required String renderedText,
  required TextSelection selection,
  int leadingTextLength = 0,
}) {
  final normalizedLeadingLength =
      leadingTextLength.clamp(0, renderedText.length);
  final selectionStart = selection.start.clamp(0, renderedText.length);
  final selectionEnd = selection.end.clamp(selectionStart, renderedText.length);
  final sourceLength = renderedText.length - normalizedLeadingLength;
  final sourceStart =
      (selectionStart - normalizedLeadingLength).clamp(0, sourceLength);
  final sourceEnd =
      (selectionEnd - normalizedLeadingLength).clamp(sourceStart, sourceLength);
  final renderedSelection =
      renderedText.substring(selectionStart, selectionEnd);
  final selectedPrefixLength = (normalizedLeadingLength - selectionStart).clamp(
    0,
    renderedSelection.length,
  );

  return ReaderSelectedRange(
    text: renderedSelection.substring(selectedPrefixLength),
    start: sourceStart,
    end: sourceEnd,
  );
}

List<ContextMenuButtonItem> buildReaderContextMenuItems({
  required EditableTextState editableTextState,
  int leadingTextLength = 0,
  void Function(String text, int start, int end)? onHighlight,
  void Function(String text, int start, int end)? onNote,
  void Function(String text, int start, int end)? onReadAloud,
  void Function(String text, int start, int end)? onVocabulary,
  ValueChanged<String>? onTranslate,
  void Function(String text)? onAi,
}) {
  final buttonItems = editableTextState.contextMenuButtonItems;

  ReaderSelectedRange selectedRange() => readerSelectedRange(
        renderedText: editableTextState.textEditingValue.text,
        selection: editableTextState.textEditingValue.selection,
        leadingTextLength: leadingTextLength,
      );

  if (onTranslate != null) {
    buttonItems.insert(
      0,
      ContextMenuButtonItem(
        label: '翻译',
        onPressed: () {
          final selected = selectedRange();
          if (selected.text.isNotEmpty) onTranslate(selected.text);
          ContextMenuController.removeAny();
        },
      ),
    );
  }

  if (onAi != null) {
    buttonItems.insert(
        0,
        ContextMenuButtonItem(
          label: '✨ AI 解释',
          onPressed: () {
            final selected = selectedRange();
            if (selected.text.isNotEmpty) onAi(selected.text);
            ContextMenuController.removeAny();
          },
        ));
  }

  if (onNote != null) {
    buttonItems.insert(
        0,
        ContextMenuButtonItem(
          label: '📝 写笔记',
          onPressed: () {
            final selected = selectedRange();
            if (selected.text.isNotEmpty) {
              onNote(selected.text, selected.start, selected.end);
            }
            ContextMenuController.removeAny();
          },
        ));
  }

  if (onHighlight != null) {
    buttonItems.insert(
        0,
        ContextMenuButtonItem(
          label: '🖍️ 高亮',
          onPressed: () {
            final selected = selectedRange();
            if (selected.text.isNotEmpty) {
              onHighlight(selected.text, selected.start, selected.end);
            }
            ContextMenuController.removeAny();
          },
        ));
  }

  if (onReadAloud != null) {
    buttonItems.insert(
      0,
      ContextMenuButtonItem(
        label: '朗读',
        onPressed: () {
          final selected = selectedRange();
          if (selected.text.isNotEmpty) {
            onReadAloud(selected.text, selected.start, selected.end);
          }
          ContextMenuController.removeAny();
        },
      ),
    );
  }

  if (onVocabulary != null) {
    buttonItems.insert(
      0,
      ContextMenuButtonItem(
        label: '查词',
        onPressed: () {
          final selected = selectedRange();
          if (selected.text.isNotEmpty) {
            onVocabulary(selected.text, selected.start, selected.end);
          }
          ContextMenuController.removeAny();
        },
      ),
    );
  }

  return buttonItems;
}
