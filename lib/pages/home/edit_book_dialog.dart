import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../database/app_database.dart';
import '../../providers/book_provider.dart';
import '../../widgets/glass_container.dart';

class EditBookDialog extends ConsumerStatefulWidget {
  final Book book;

  const EditBookDialog({super.key, required this.book});

  @override
  ConsumerState<EditBookDialog> createState() => _EditBookDialogState();
}

class _EditBookDialogState extends ConsumerState<EditBookDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _seriesCtrl;
  late final TextEditingController _seriesIndexCtrl;
  String? _coverPath;
  String? _seriesIndexError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.book.title);
    _authorCtrl = TextEditingController(text: widget.book.author);
    _seriesCtrl = TextEditingController(text: widget.book.seriesName ?? '');
    _seriesIndexCtrl = TextEditingController(
      text: _formatSeriesIndex(widget.book.seriesIndex),
    );
    _coverPath = widget.book.coverPath;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _seriesCtrl.dispose();
    _seriesIndexCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _coverPath = result.files.first.path;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final author = _authorCtrl.text.trim();
    if (title.isEmpty) return;
    final seriesName = _seriesCtrl.text.trim();
    final seriesIndexText = _seriesIndexCtrl.text.trim();
    final seriesIndex =
        seriesIndexText.isEmpty ? null : double.tryParse(seriesIndexText);
    if (seriesIndexText.isNotEmpty && seriesIndex == null) {
      setState(() => _seriesIndexError = '请输入有效数字');
      return;
    }

    await ref.read(booksProvider.notifier).updateBookMetadata(
          widget.book.id,
          title: title,
          author: author,
          coverPath: _coverPath,
          seriesName: seriesName.isEmpty ? null : seriesName,
          seriesIndex: seriesName.isEmpty ? null : seriesIndex,
        );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatSeriesIndex(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GlassContainer.stable(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('编辑书籍信息', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _pickCover,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      image:
                          _coverPath != null && File(_coverPath!).existsSync()
                              ? DecorationImage(
                                  image: FileImage(File(_coverPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _coverPath == null || !File(_coverPath!).existsSync()
                        ? const Icon(Icons.add_photo_alternate, size: 40)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickCover,
                  child: const Text('更换封面'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '书名 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _authorCtrl,
                decoration: const InputDecoration(
                  labelText: '作者',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _seriesCtrl,
                decoration: const InputDecoration(
                  labelText: '系列名',
                  hintText: '例如：三体',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _seriesIndexCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '系列卷序',
                  hintText: '例如：1、2、2.5',
                  errorText: _seriesIndexError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_seriesIndexError != null) {
                    setState(() => _seriesIndexError = null);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
