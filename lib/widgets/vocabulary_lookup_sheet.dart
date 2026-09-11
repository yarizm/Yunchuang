import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/reader_locator.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';

class VocabularyLookupSheet extends StatefulWidget {
  final VocabularyService service;
  final DictionaryService? dictionaryService;
  final int bookId;
  final int? chapterId;
  final String term;
  final String? contextText;
  final int? positionStart;
  final int? positionEnd;
  final ValueChanged<ReaderLocator>? onOccurrenceTap;

  const VocabularyLookupSheet({
    super.key,
    required this.service,
    this.dictionaryService,
    required this.bookId,
    required this.chapterId,
    required this.term,
    this.contextText,
    this.positionStart,
    this.positionEnd,
    this.onOccurrenceTap,
  });

  static Future<bool?> show(
    BuildContext context, {
    required VocabularyService service,
    DictionaryService? dictionaryService,
    required int bookId,
    required int? chapterId,
    required String term,
    String? contextText,
    int? positionStart,
    int? positionEnd,
    ValueChanged<ReaderLocator>? onOccurrenceTap,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.88,
        child: VocabularyLookupSheet(
          service: service,
          dictionaryService: dictionaryService,
          bookId: bookId,
          chapterId: chapterId,
          term: term,
          contextText: contextText,
          positionStart: positionStart,
          positionEnd: positionEnd,
          onOccurrenceTap: onOccurrenceTap,
        ),
      ),
    );
  }

  @override
  State<VocabularyLookupSheet> createState() => _VocabularyLookupSheetState();
}

class _VocabularyLookupSheetState extends State<VocabularyLookupSheet> {
  final _definitionController = TextEditingController();
  VocabularyEntry? _existing;
  VocabularyLookupResult? _lookup;
  DictionaryLookupResult? _dictionaryLookup;
  String? _progressMessage;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final existingFuture =
          widget.service.findForBook(widget.bookId, widget.term);
      final dictionaryFuture = widget.dictionaryService?.lookup(widget.term) ??
          Future.value(
            const DictionaryLookupResult(
              installedSourceCount: 0,
              enabledSourceCount: 0,
              definitions: [],
            ),
          );
      final occurrenceFuture = widget.service.findOccurrences(
          bookId: widget.bookId,
          term: widget.term,
          onProgress: (message) {
            if (mounted) setState(() => _progressMessage = message);
          });
      final results = await Future.wait<Object?>([
        existingFuture,
        dictionaryFuture,
        occurrenceFuture,
      ]);
      if (!mounted) return;
      setState(() {
        _existing = results[0] as VocabularyEntry?;
        _definitionController.text = _existing?.definition ?? '';
        _dictionaryLookup = results[1] as DictionaryLookupResult;
        _lookup = results[2] as VocabularyLookupResult;
        _progressMessage = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _progressMessage = null;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.service.save(
        bookId: widget.bookId,
        chapterId: widget.chapterId,
        term: widget.term,
        definition: _definitionController.text,
        contextText: widget.contextText,
        positionStart: widget.positionStart,
        positionEnd: widget.positionEnd,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookup = _lookup;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.term,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _existing == null ? '本地查词与生词记录' : '已在生词本中',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (widget.dictionaryService != null) ...[
                  Text('离线词典', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_loading)
                    const LinearProgressIndicator()
                  else
                    _buildDictionaryDefinitions(theme),
                  const SizedBox(height: 24),
                ],
                TextField(
                  key: const Key('vocabulary-definition-field'),
                  controller: _definitionController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '我的释义',
                    hintText: '可手动填写，或使用上方的离线词典释义',
                    alignLabelWithHint: true,
                  ),
                ),
                if (widget.contextText?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 20),
                  Text('来源原句', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    widget.contextText!.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('本书出现位置', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (lookup != null)
                      Text(
                        '${lookup.totalCount} 处',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_progressMessage ?? '正在搜索当前书…'),
                ] else if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ),
                ] else if (lookup == null || lookup.occurrences.isEmpty) ...[
                  Text(
                    '当前书中没有找到其他位置。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  for (final occurrence in lookup.occurrences)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(
                        occurrence.chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        occurrence.snippet,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: widget.onOccurrenceTap == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onOccurrenceTap!(occurrence.locator);
                            },
                    ),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('save-vocabulary-entry'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bookmark_add_outlined),
                  label: Text(_existing == null ? '加入生词本' : '更新生词'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDictionaryDefinitions(ThemeData theme) {
    final lookup = _dictionaryLookup;
    if (lookup == null || lookup.installedSourceCount == 0) {
      return Text(
        '尚未导入离线词典，可在“设置 → 离线词典”中导入 StarDict。',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (lookup.enabledSourceCount == 0) {
      return Text(
        '已导入的离线词典均处于停用状态。',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (lookup.definitions.isEmpty) {
      return Text(
        '已启用的离线词典中没有找到该词条。',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lookup.definitions.length; index++) ...[
          if (index > 0) const Divider(height: 24),
          Text(
            '${lookup.definitions[index].sourceName} · '
            '${lookup.definitions[index].headword}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(lookup.definitions[index].definition),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _definitionController.text =
                    lookup.definitions[index].definition;
              },
              icon: const Icon(Icons.south, size: 18),
              label: const Text('填入我的释义'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _definitionController.dispose();
    super.dispose();
  }
}
