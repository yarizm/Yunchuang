import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../parsers/csv_importer.dart';
import '../../parsers/weread_importer.dart';
import '../../parsers/kindle_importer.dart';
import '../../parsers/json_importer.dart';
import '../../providers/note_provider.dart';
import '../../utils/text_file_decoder.dart';
import '../../widgets/glass_container.dart';

/// Page for importing notes from external reading apps.
///
/// Supports WeRead (HTML), CSV, Kindle (My Clippings.txt), and JSON formats.
class ImportNotesPage extends ConsumerStatefulWidget {
  const ImportNotesPage({super.key});

  @override
  ConsumerState<ImportNotesPage> createState() => _ImportNotesPageState();
}

class _ImportNotesPageState extends ConsumerState<ImportNotesPage> {
  bool _loading = false;
  String _status = '';

  Future<void> _pickAndImport(String format) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensionsFor(format),
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;

    setState(() {
      _loading = true;
      _status = '正在导入...';
    });

    try {
      final content = await TextFileDecoder.readAsString(filePath);

      final notes = _parse(format, content);

      if (notes.isEmpty) {
        setState(() {
          _status = '未找到可导入的笔记';
          _loading = false;
        });
        return;
      }

      final noteService = ref.read(noteServiceProvider);
      final imported = await noteService.importNotes(notes);
      ref.invalidate(allNotesProvider);
      ref.invalidate(allTagsProvider);

      if (mounted) {
        setState(() {
          _status = '成功导入 $imported 条笔记';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '导入失败: $e';
          _loading = false;
        });
      }
    }
  }

  List<ImportedNote> _parse(String format, String content) {
    switch (format) {
      case 'weread':
        return WeReadImporter.parse(content);
      case 'csv':
        return CsvImporter.parse(content);
      case 'kindle':
        return KindleImporter.parse(content);
      case 'json':
        return JsonImporter.parse(content);
      default:
        return [];
    }
  }

  List<String> _extensionsFor(String format) {
    switch (format) {
      case 'weread':
        return ['html', 'htm'];
      case 'csv':
        return ['csv'];
      case 'kindle':
        return ['txt'];
      case 'json':
        return ['json'];
      default:
        return ['*'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(
        title: const Text('导入笔记'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton.filled(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOption('微信读书', 'weread', '导出的 HTML 表格文件', Icons.phone_android),
          _buildOption('CSV 文件', 'csv', '含 selectedText/content/tags 列',
              Icons.table_chart),
          _buildOption(
              'Kindle 标注', 'kindle', 'My Clippings.txt 文件', Icons.book),
          _buildOption('JSON 文件', 'json', 'JSON 数组格式', Icons.code),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 24),
            GlassContainer.stable(
              color: _status.contains('失败')
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(
      String title, String format, String subtitle, IconData icon) {
    return GlassContainer.stable(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _loading ? null : () => _pickAndImport(format),
        ),
      ),
    );
  }
}
