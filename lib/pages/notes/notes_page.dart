import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/app_database.dart';
import '../../providers/note_provider.dart';
import '../../providers/database_provider.dart';
import '../../widgets/empty_state.dart';
import '../search/search_page.dart';
import '../../theme/glass_page_route.dart';
import 'note_card.dart';
import 'note_editor.dart';
import '../../widgets/glass_container.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  Map<int, List<Tag>> _tagsByNoteId = {};
  Map<int, Book> _booksById = {};
  bool _extraLoading = true;
  Tag? _selectedTag;
  List<Note>? _loadedExtrasFor;
  List<Note>? _loadingExtrasFor;
  int _extraRequestId = 0;

  Future<void> _loadExtras(List<Note> notes) async {
    if (identical(notes, _loadedExtrasFor) ||
        identical(notes, _loadingExtrasFor)) {
      return;
    }
    _loadingExtrasFor = notes;
    final requestId = ++_extraRequestId;
    final noteIds = notes.map((n) => n.id).toList();
    final bookIds = notes.map((n) => n.bookId).toSet().toList();
    final noteService = ref.read(noteServiceProvider);
    final bookService = ref.read(bookServiceProvider);
    final tagsMap = await noteService.getTagsForNotes(noteIds);
    final booksMap = await bookService.getBooksByIds(bookIds);
    if (!mounted || requestId != _extraRequestId) {
      return;
    }
    final selectedTag = _selectedTag;
    final selectedTagStillExists = selectedTag == null ||
        tagsMap.values
            .expand((tags) => tags)
            .any((tag) => tag.id == selectedTag.id);
    setState(() {
      _tagsByNoteId = tagsMap;
      _booksById = booksMap;
      _loadedExtrasFor = notes;
      _loadingExtrasFor = null;
      _extraLoading = false;
      if (!selectedTagStillExists) {
        _selectedTag = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(allNotesProvider);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: EmptyState(
              icon: Icons.error_outline,
              title: '加载失败',
              subtitle: '$e',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(allNotesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ),
          ),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildHeader(theme, const []),
                const SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: GlassContainer.stable(
                        padding:
                            EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: EmptyState(
                          icon: Icons.note_alt_outlined,
                          title: '还没有笔记',
                          subtitle: '阅读时长按文本可以添加高亮和笔记',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          // Refresh book and tag lookups when the provider emits a new list.
          unawaited(_loadExtras(notes));
          if (_extraLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTags =
              _tagsByNoteId.values.expand((t) => t).toSet().toList();
          allTags.sort((a, b) => a.name.compareTo(b.name));

          final filteredNotes = _selectedTag == null
              ? notes
              : notes.where((n) {
                  final tags = _tagsByNoteId[n.id] ?? [];
                  return tags.any((t) => t.id == _selectedTag!.id);
                }).toList();

          return CustomScrollView(
            slivers: [
              // 导出跟着筛选走：选了标签就只导那一批，与眼前看到的一致。
              _buildHeader(theme, filteredNotes),
              if (allTags.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerLeft,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: allTags.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ChoiceChip(
                            label: const Text('全部'),
                            selected: _selectedTag == null,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedTag = null);
                            },
                          );
                        }
                        final tag = allTags[index - 1];
                        return ChoiceChip(
                          label: Text(tag.name),
                          selected: _selectedTag?.id == tag.id,
                          onSelected: (selected) {
                            setState(() {
                              _selectedTag = selected ? tag : null;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ..._buildGroupedSlivers(filteredNotes),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportNotes(
    List<Note> notes,
    _NoteExportFormat format,
  ) async {
    try {
      final service = ref.read(noteServiceProvider);
      final rows = await service.buildExportRows(notes);
      final content = switch (format) {
        _NoteExportFormat.markdown => service.exportMarkdown(rows),
        _NoteExportFormat.csv => service.exportCsv(rows),
      };
      final extension = format == _NoteExportFormat.markdown ? 'md' : 'csv';
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${directory.path}/笔记_$timestamp.$extension');
      // CSV 带 BOM，否则 Excel 会把中文认成乱码。
      await file.writeAsString(
        format == _NoteExportFormat.csv ? '\ufeff$content' : content,
      );
      await Share.shareXFiles([XFile(file.path)], text: '阅读器笔记');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    }
  }

  Future<void> _confirmDeleteNote(Note note) async {
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

    await ref.read(noteServiceProvider).deleteNote(note.id);
    ref.invalidate(allNotesProvider);
    ref.invalidate(allTagsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('笔记已删除')),
    );
  }

  Widget _buildHeader(ThemeData theme, List<Note> exportable) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: GlassContainer.stable(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: theme.colorScheme.onTertiaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '笔记',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '回顾你的思考与感悟',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  color: theme.colorScheme.onSurface,
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).push(
                    GlassPageRoute(builder: (_) => const SearchPage()),
                  ),
                ),
                PopupMenuButton<_NoteExportFormat>(
                  key: const Key('notes-export-menu'),
                  tooltip: '导出笔记',
                  enabled: exportable.isNotEmpty,
                  icon: Icon(
                    Icons.ios_share_outlined,
                    color: theme.colorScheme.onSurface,
                  ),
                  onSelected: (format) => _exportNotes(exportable, format),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _NoteExportFormat.markdown,
                      child: Text('导出 Markdown'),
                    ),
                    PopupMenuItem(
                      value: _NoteExportFormat.csv,
                      child: Text('导出 CSV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSlivers(List<Note> notes) {
    // Group notes by bookId, preserving order
    final grouped = <int, List<Note>>{};
    for (final note in notes) {
      grouped.putIfAbsent(note.bookId, () => []).add(note);
    }

    final bookIds = grouped.keys.toList();

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final bookId = bookIds[index];
            final bookNotes = grouped[bookId]!;
            final bookTitle = _booksById[bookId]?.title ?? '未知书籍';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GlassContainer.stable(
                borderRadius: 16,
                child: Material(
                  type: MaterialType.transparency,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      title: Text(
                        bookTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      subtitle: Text('${bookNotes.length} 条笔记'),
                      initiallyExpanded: bookIds.length <= 3,
                      children: bookNotes.map((note) {
                        return NoteCard(
                          note: note,
                          tags: _tagsByNoteId[note.id] ?? [],
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              GlassPageRoute(
                                builder: (_) => NoteEditor(noteId: note.id),
                              ),
                            );
                          },
                          onDelete: () => _confirmDeleteNote(note),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: bookIds.length,
        ),
      ),
    ];
  }
}

enum _NoteExportFormat { markdown, csv }
