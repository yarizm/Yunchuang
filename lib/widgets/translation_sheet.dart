import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/settings/ai_provider_list.dart';
import '../providers/ai/ai_provider.dart';
import '../services/translation_service.dart';
import '../theme/glass_page_route.dart';

class TranslationSheet extends StatefulWidget {
  final TranslationService service;
  final String text;
  final String targetLanguage;

  const TranslationSheet({
    super.key,
    required this.service,
    required this.text,
    required this.targetLanguage,
  });

  static Future<void> show(
    BuildContext context, {
    required TranslationService service,
    required String text,
    required String targetLanguage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.78,
        child: TranslationSheet(
          service: service,
          text: text,
          targetLanguage: targetLanguage,
        ),
      ),
    );
  }

  @override
  State<TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<TranslationSheet> {
  AIRequestCancellation? _cancellation;
  TranslationResult? _result;
  String? _error;
  bool _errorNeedsProvider = false;
  bool _loading = true;
  bool _sourceExpanded = false;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  Future<void> _translate() async {
    _cancellation?.cancel();
    final cancellation = AIRequestCancellation();
    setState(() {
      _cancellation = cancellation;
      _result = null;
      _error = null;
      _errorNeedsProvider = false;
      _loading = true;
    });
    try {
      final result = await widget.service.translate(
        text: widget.text,
        targetLanguage: widget.targetLanguage,
        cancellation: cancellation,
      );
      if (!mounted || cancellation.isCancelled) return;
      setState(() {
        _result = result;
        _loading = false;
        _cancellation = null;
      });
    } on AIRequestCancelledException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cancellation = null;
        _error = '翻译已取消。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cancellation = null;
        _error = '$error';
        _errorNeedsProvider =
            error is TranslationException && error.missingProvider;
      });
    }
  }

  Future<void> _openProviderSettings() async {
    await Navigator.of(context, rootNavigator: true).push(
      GlassPageRoute<void>(builder: (_) => const AiProviderListPage()),
    );
    // 配好回来直接再试一次，不用再点重试。
    if (mounted) unawaited(_translate());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.translate),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '翻译为${widget.targetLanguage}',
                  style: theme.textTheme.titleLarge,
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
              InkWell(
                onTap: () => setState(() => _sourceExpanded = !_sourceExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '原文 · ${widget.text.trim().length} 字符',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Icon(
                        _sourceExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.text.trim(),
                maxLines: _sourceExpanded ? null : 4,
                overflow:
                    _sourceExpanded ? TextOverflow.visible : TextOverflow.fade,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text('译文', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              if (_loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
                const Text('正在请求默认 AI Provider…'),
              ] else if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_errorNeedsProvider) ...[
                      FilledButton.tonalIcon(
                        key: const Key('translation-configure-provider'),
                        onPressed: _openProviderSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('去配置'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton.icon(
                      key: const Key('retry-translation'),
                      onPressed: _translate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ] else if (_result != null) ...[
                SelectableText(
                  _result!.translatedText,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '由 ${_result!.providerName} 生成',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                if (_loading)
                  OutlinedButton.icon(
                    onPressed: () => _cancellation?.cancel('用户取消了翻译。'),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('取消'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('copy-translation'),
                  onPressed: _result == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: _result!.translatedText),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('译文已复制。')),
                          );
                        },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('复制译文'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }
}
