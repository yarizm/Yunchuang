import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/note_provider.dart';
import '../../services/note_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';

class NoteEditor extends ConsumerStatefulWidget {
  final int noteId;
  const NoteEditor({super.key, required this.noteId});

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  final _contentController = TextEditingController();
  Note? _note;
  List<Tag> _selectedTags = [];
  List<Tag> _allTags = [];
  bool _loading = true;
  Object? _loadError;

  /// 保存或删除进行中。两个按钮共用一个标志，避免保存到一半又点删除。
  bool _busy = false;

  /// 上次落库时的内容和标签，用来判断返回时有没有东西会丢。
  String _savedContent = '';
  Set<int> _savedTagIds = const {};

  bool get _dirty {
    if (_note == null) return false;
    if (_contentController.text != _savedContent) return true;
    return !setEquals(_selectedTags.map((t) => t.id).toSet(), _savedTagIds);
  }

  @override
  void initState() {
    super.initState();
    // 内容一变就得重算 canPop，否则 PopScope 还拿着上一帧的 dirty 值。
    _contentController.addListener(_onContentChanged);
    _loadNote();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNote() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final service = ref.read(noteServiceProvider);
      final note = await service.getNoteById(widget.noteId);
      final tags = await service.getTagsForNote(widget.noteId);
      final allTags = await service.getAllTags();
      if (!mounted) return;
      setState(() {
        _note = note;
        _selectedTags = tags;
        _allTags = allTags;
        _contentController.text = note?.content ?? '';
        _savedContent = _contentController.text;
        _savedTagIds = tags.map((t) => t.id).toSet();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final note = _note;
    if (note == null || _busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(noteServiceProvider);
      await service.updateNote(
        noteId: note.id,
        content: _contentController.text,
      );
      await service.setTagsForNote(
        note.id,
        _selectedTags.map((t) => t.id).toList(),
      );
      ref.invalidate(allNotesProvider);
      ref.invalidate(allTagsProvider);
      if (!mounted) return;
      // Navigator.pop 不经过 PopScope（只有系统返回 / AppBar 返回走
      // maybePop 才会被 canPop 拦），所以这里不用先把 dirty 清掉。
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  Future<void> _delete() async {
    final note = _note;
    if (note == null || _busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style:
                  TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(noteServiceProvider).deleteNote(note.id);
      ref.invalidate(allNotesProvider);
      ref.invalidate(allTagsProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }

  /// 有未保存的改动时拦住返回，问一句再走。
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('这条笔记有未保存的改动。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '放弃',
              style:
                  TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> _createTag() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _TagNameDialog(),
    );
    if (name == null || !mounted) return;
    try {
      final tag = await ref.read(noteServiceProvider).ensureTag(name);
      if (!mounted) return;
      setState(() {
        if (!_allTags.any((t) => t.id == tag.id)) {
          _allTags = [..._allTags, tag]
            ..sort((a, b) => a.name.compareTo(b.name));
        }
        if (!_selectedTags.any((t) => t.id == tag.id)) {
          _selectedTags = [..._selectedTags, tag];
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新建标签失败：$error')),
      );
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除标签「${tag.name}」'),
        content: const Text('会从所有笔记上移除这个标签，笔记本身不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style:
                  TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(noteServiceProvider).deleteTag(tag.id);
      ref.invalidate(allNotesProvider);
      ref.invalidate(allTagsProvider);
      if (!mounted) return;
      setState(() {
        _allTags = _allTags.where((t) => t.id != tag.id).toList();
        _selectedTags = _selectedTags.where((t) => t.id != tag.id).toList();
        // 这个标签已经不存在了，不该再算作「未保存的改动」。
        _savedTagIds = _savedTagIds.difference({tag.id});
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除标签失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑笔记')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final loadError = _loadError;
    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑笔记')),
        body: EmptyState(
          icon: Icons.error_outline,
          title: '加载失败',
          subtitle: '$loadError',
          action: FilledButton.icon(
            onPressed: _loadNote,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ),
      );
    }

    final note = _note;
    if (note == null) {
      // 列表里点进来之前笔记已经被别处删掉了（比如阅读器里删了高亮）。
      // 给一个空编辑框只会让「保存」按钮变成什么都不做的死按钮。
      return Scaffold(
        appBar: AppBar(title: const Text('编辑笔记')),
        body: EmptyState(
          icon: Icons.note_alt_outlined,
          title: '笔记不存在',
          subtitle: '这条笔记可能已经被删除。',
          action: FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
          ),
        ),
      );
    }

    return PopScope<void>(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑笔记'),
          actions: [
            IconButton(
              tooltip: '删除笔记',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
            TextButton(
              onPressed: _busy ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (note.selectedText != null) ...[
              Text('原文摘录', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              GlassContainer.stable(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Text(
                  note.selectedText!,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text('笔记内容', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            GlassContainer.stable(
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '写下你的想法...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('标签', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              _allTags.isEmpty
                  ? '还没有标签。新建后可以在笔记列表里按标签筛选。'
                  : '点按选择，长按删除标签。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in _allTags)
                  // FilterChip 自己没有 onLongPress，包一层手势来接。点按
                  // 仍由 chip 处理，长按才落到外层。
                  GestureDetector(
                    onLongPress: () => _deleteTag(tag),
                    child: FilterChip(
                      label: Text(tag.name),
                      selected: _selectedTags.any((t) => t.id == tag.id),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.removeWhere((t) => t.id == tag.id);
                          }
                        });
                      },
                    ),
                  ),
                ActionChip(
                  key: const Key('note-editor-new-tag'),
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('新建标签'),
                  onPressed: _createTag,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    super.dispose();
  }
}

class _TagNameDialog extends StatefulWidget {
  const _TagNameDialog();

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建标签'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: NoteService.maxTagNameLength,
        decoration: InputDecoration(
          labelText: '标签名称',
          helperText: '已有同名标签时会直接选中它',
          errorText: _errorText,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = '请输入标签名称');
      return;
    }
    Navigator.pop(context, value);
  }
}
