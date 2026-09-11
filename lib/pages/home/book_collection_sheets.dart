import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/book_provider.dart';
import '../../providers/database_provider.dart';

Future<void> showBookCollectionManager(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _BookCollectionManager(),
  );
}

Future<void> showBookCollectionAssignment(
  BuildContext context,
  Book book,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BookCollectionAssignment(book: book),
  );
}

Future<bool?> showBatchBookCollectionAction(
  BuildContext context,
  Set<int> bookIds,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BatchBookCollectionAction(bookIds: {...bookIds}),
  );
}

class _BookCollectionManager extends ConsumerWidget {
  const _BookCollectionManager();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(bookCollectionsProvider);
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Column(
        children: [
          _SheetHeader(
            title: '管理书架',
            onClose: () => Navigator.pop(context),
          ),
          const Divider(height: 1),
          Expanded(
            child: collections.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _SheetError(
                message: '加载书架失败：$error',
                onRetry: () => ref.invalidate(bookCollectionsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _SheetEmpty(
                    icon: Icons.shelves,
                    title: '还没有自定义书架',
                  );
                }
                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = [...items];
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    unawaited(
                      _reorderCollections(
                        context,
                        ref,
                        reordered.map((item) => item.id).toList(),
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final collection = items[index];
                    return ListTile(
                      key: ValueKey(collection.id),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Tooltip(
                          message: '拖动排序',
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                      title: Text(
                        collection.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '重命名书架',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _renameCollection(
                              context,
                              ref,
                              collection,
                            ),
                          ),
                          IconButton(
                            tooltip: '删除书架',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteCollection(
                              context,
                              ref,
                              collection,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('新建书架'),
                  onPressed: () => _createCollection(context, ref),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCollection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await _promptCollectionName(context, title: '新建书架');
    if (name == null || !context.mounted) return;
    try {
      await ref.read(collectionDaoProvider).createCollection(name);
    } catch (error) {
      if (context.mounted) _showCollectionError(context, error);
    }
  }

  Future<void> _renameCollection(
    BuildContext context,
    WidgetRef ref,
    BookCollection collection,
  ) async {
    final name = await _promptCollectionName(
      context,
      title: '重命名书架',
      initialValue: collection.name,
    );
    if (name == null || !context.mounted) return;
    try {
      await ref
          .read(collectionDaoProvider)
          .renameCollection(collection.id, name);
    } catch (error) {
      if (context.mounted) _showCollectionError(context, error);
    }
  }

  Future<void> _deleteCollection(
    BuildContext context,
    WidgetRef ref,
    BookCollection collection,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除书架'),
            content: Text('删除“${collection.name}”不会删除其中的书籍。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(collectionDaoProvider).deleteCollection(collection.id);
      if (ref.read(selectedBookCollectionProvider) == collection.id) {
        ref.read(selectedBookCollectionProvider.notifier).state = null;
      }
    } catch (error) {
      if (context.mounted) _showCollectionError(context, error);
    }
  }

  Future<void> _reorderCollections(
    BuildContext context,
    WidgetRef ref,
    List<int> orderedIds,
  ) async {
    try {
      await ref.read(collectionDaoProvider).reorderCollections(orderedIds);
    } catch (error) {
      if (context.mounted) _showCollectionError(context, error);
    }
  }
}

class _BookCollectionAssignment extends ConsumerStatefulWidget {
  final Book book;

  const _BookCollectionAssignment({required this.book});

  @override
  ConsumerState<_BookCollectionAssignment> createState() =>
      _BookCollectionAssignmentState();
}

class _BookCollectionAssignmentState
    extends ConsumerState<_BookCollectionAssignment> {
  Set<int>? _selectedIds;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(bookCollectionsProvider);
    final membership = ref.watch(bookCollectionIdsProvider(widget.book.id));

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Column(
        children: [
          _SheetHeader(
            title: '加入书架',
            onClose: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: collections.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _SheetError(
                message: '加载书架失败：$error',
                onRetry: () => ref.invalidate(bookCollectionsProvider),
              ),
              data: (items) => membership.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _SheetError(
                  message: '加载书籍归属失败：$error',
                  onRetry: () => ref.invalidate(
                    bookCollectionIdsProvider(widget.book.id),
                  ),
                ),
                data: (storedIds) {
                  final selected = _selectedIds ??= {...storedIds};
                  if (items.isEmpty) {
                    return const _SheetEmpty(
                      icon: Icons.shelves,
                      title: '还没有自定义书架',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final collection = items[index];
                      return CheckboxListTile(
                        value: selected.contains(collection.id),
                        title: Text(
                          collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: _saving
                            ? null
                            : (checked) {
                                setState(() {
                                  if (checked ?? false) {
                                    selected.add(collection.id);
                                  } else {
                                    selected.remove(collection.id);
                                  }
                                });
                              },
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('新建'),
                    onPressed: _saving ? null : _createAndSelectCollection,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                      onPressed: _saving || _selectedIds == null ? null : _save,
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

  Future<void> _createAndSelectCollection() async {
    final name = await _promptCollectionName(context, title: '新建书架');
    if (name == null || !mounted) return;
    try {
      final id = await ref.read(collectionDaoProvider).createCollection(name);
      if (mounted) setState(() => (_selectedIds ??= {}).add(id));
    } catch (error) {
      if (mounted) _showCollectionError(context, error);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(collectionDaoProvider).setBookCollections(
        widget.book.id,
        {..._selectedIds!},
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showCollectionError(context, error);
      }
    }
  }
}

enum _BatchCollectionMode { include, remove }

class _BatchBookCollectionAction extends ConsumerStatefulWidget {
  final Set<int> bookIds;

  const _BatchBookCollectionAction({required this.bookIds});

  @override
  ConsumerState<_BatchBookCollectionAction> createState() =>
      _BatchBookCollectionActionState();
}

class _BatchBookCollectionActionState
    extends ConsumerState<_BatchBookCollectionAction> {
  final Set<int> _collectionIds = {};
  _BatchCollectionMode _mode = _BatchCollectionMode.include;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(bookCollectionsProvider);
    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Column(
        children: [
          _SheetHeader(
            title: '批量管理书架',
            onClose: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '已选择 ${widget.bookIds.length} 本书',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                SegmentedButton<_BatchCollectionMode>(
                  segments: const [
                    ButtonSegment(
                      value: _BatchCollectionMode.include,
                      label: Text('加入'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: _BatchCollectionMode.remove,
                      label: Text('移出'),
                      icon: Icon(Icons.remove),
                    ),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: _saving
                      ? null
                      : (selection) {
                          setState(() => _mode = selection.single);
                        },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: collections.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _SheetError(
                message: '加载书架失败：$error',
                onRetry: () => ref.invalidate(bookCollectionsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _SheetEmpty(
                    icon: Icons.shelves,
                    title: '还没有自定义书架',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final collection = items[index];
                    return CheckboxListTile(
                      value: _collectionIds.contains(collection.id),
                      title: Text(
                        collection.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: _saving
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  _collectionIds.add(collection.id);
                                } else {
                                  _collectionIds.remove(collection.id);
                                }
                              });
                            },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('新建'),
                    onPressed: _saving ? null : _createAndSelectCollection,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done),
                      label: Text(_mode == _BatchCollectionMode.include
                          ? '加入所选书架'
                          : '移出所选书架'),
                      onPressed:
                          _saving || _collectionIds.isEmpty ? null : _save,
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

  Future<void> _createAndSelectCollection() async {
    final name = await _promptCollectionName(context, title: '新建书架');
    if (name == null || !mounted) return;
    try {
      final id = await ref.read(collectionDaoProvider).createCollection(name);
      if (mounted) setState(() => _collectionIds.add(id));
    } catch (error) {
      if (mounted) _showCollectionError(context, error);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(collectionDaoProvider).updateBooksInCollections(
            bookIds: widget.bookIds,
            collectionIds: _collectionIds,
            include: _mode == _BatchCollectionMode.include,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showCollectionError(context, error);
      }
    }
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _SheetHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SheetError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetEmpty extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SheetEmpty({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(title),
        ],
      ),
    );
  }
}

Future<String?> _promptCollectionName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CollectionNameDialog(
      title: title,
      initialValue: initialValue,
    ),
  );
}

class _CollectionNameDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const _CollectionNameDialog({
    required this.title,
    required this.initialValue,
  });

  @override
  State<_CollectionNameDialog> createState() => _CollectionNameDialogState();
}

class _CollectionNameDialogState extends State<_CollectionNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: '书架名称',
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
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = '请输入书架名称');
      return;
    }
    Navigator.pop(context, value);
  }
}

void _showCollectionError(BuildContext context, Object error) {
  final message =
      error.toString().contains('UNIQUE') ? '已存在同名书架' : '操作失败：$error';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
