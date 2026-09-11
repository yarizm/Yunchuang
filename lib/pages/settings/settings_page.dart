import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/glass_container.dart';
import 'ai_reading_safety_page.dart';
import 'ai_assets_page.dart';
import 'ai_provider_list.dart';
import 'tts_settings.dart';
import 'data_management.dart';
import 'dictionary_page.dart';
import 'import_notes.dart';
import 'appearance_page.dart';
import 'reading_preferences.dart';
import 'translation_settings_page.dart';
import 'vocabulary_page.dart';
import '../../theme/glass_page_route.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer.stable(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.smart_toy),
                    title: const Text('AI Provider'),
                    subtitle: const Text('配置 OpenAI / Ollama / Dify'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(
                          builder: (_) => const AiProviderListPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.extension),
                    title: const Text('AI 扩展'),
                    subtitle: const Text('管理 Skill、人格与导入导出'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(builder: (_) => const AiAssetsPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('AI 阅读安全'),
                    subtitle: const Text('防剧透范围与未读内容授权'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(
                        builder: (_) => const AiReadingSafetyPage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.record_voice_over),
                    title: const Text('TTS 设置'),
                    subtitle: const Text('系统语音引擎与语速'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(builder: (_) => const TtsSettingsPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('生词本'),
                    subtitle: const Text('管理查词记录与导出'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(builder: (_) => const VocabularyPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text('离线词典'),
                    subtitle: const Text('导入与管理 StarDict'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(builder: (_) => const DictionaryPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: const Text('在线翻译'),
                    subtitle: const Text('默认关闭，使用 AI Provider'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(
                        builder: (_) => const TranslationSettingsPage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.wallpaper),
                    title: const Text('外观'),
                    subtitle: const Text('背景样式与自定义图片'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(builder: (_) => const AppearancePage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.text_fields),
                    title: const Text('阅读偏好'),
                    subtitle: const Text('字号、行距、主题、纸张'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(
                          builder: (_) => const ReadingPreferencesPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: const Text('数据管理'),
                    subtitle: const Text('备份与恢复'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(
                          builder: (_) => const DataManagementPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('导入笔记'),
                    subtitle: const Text('WeRead / CSV / Kindle / JSON'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      GlassPageRoute(builder: (_) => const ImportNotesPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
