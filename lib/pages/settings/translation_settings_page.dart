import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/translation_provider.dart';
import '../../widgets/glass_container.dart';

class TranslationSettingsPage extends ConsumerWidget {
  static const targetLanguages = [
    '简体中文',
    '繁體中文',
    '英语',
    '日语',
    '韩语',
    '法语',
    '德语',
    '西班牙语',
  ];

  const TranslationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(translationSettingsProvider);
    final notifier = ref.read(translationSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('在线翻译')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer.stable(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('online-translation-switch'),
                    secondary: const Icon(Icons.translate),
                    title: const Text('启用在线翻译'),
                    subtitle: const Text('使用默认 AI Provider 翻译选中文本'),
                    value: settings.enabled,
                    onChanged: (enabled) async {
                      if (!enabled) {
                        await notifier.setEnabled(false);
                        return;
                      }
                      final accepted = await _confirmEnable(context);
                      if (accepted == true) {
                        await notifier.setEnabled(true);
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('目标语言'),
                    trailing: DropdownButton<String>(
                      key: const Key('translation-target-language'),
                      value: settings.targetLanguage,
                      underline: const SizedBox.shrink(),
                      onChanged: settings.enabled
                          ? (value) {
                              if (value != null) {
                                notifier.setTargetLanguage(value);
                              }
                            }
                          : null,
                      items: [
                        for (final language in targetLanguages)
                          DropdownMenuItem(
                            value: language,
                            child: Text(language),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const GlassContainer.stable(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.privacy_tip_outlined, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '仅在你主动点击“翻译”时发送当前选中文本。'
                    '翻译结果不写入聊天记录；请求可能产生 Provider 费用。',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmEnable(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('启用在线翻译？'),
        content: const Text(
          '启用后，只有在你主动点击“翻译”时，选中的书籍文本才会发送到当前默认 AI Provider。'
          '这可能消耗 token 并受 Provider 的隐私政策约束。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-enable-translation'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认启用'),
          ),
        ],
      ),
    );
  }
}
