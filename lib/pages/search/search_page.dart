import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reader_locator.dart';
import '../../providers/search_provider.dart';
import '../../services/search_service.dart';
import '../../theme/glass_page_route.dart';
import '../../widgets/glass_container.dart';
import '../reader/reader_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;
  int _searchRequestId = 0;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final requestId = ++_searchRequestId;
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(searchServiceProvider);
      final results = await service.search(query);
      if (mounted && requestId == _searchRequestId) {
        setState(() => _results = results);
      }
    } on SearchException catch (error) {
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _results = [];
          _error = error.message;
        });
      }
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(
        title: GlassContainer.stable(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: 24,
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '搜索书名、笔记、正文...',
              border: InputBorder.none,
            ),
            onChanged: _onQueryChanged,
            onSubmitted: (query) {
              _debounce?.cancel();
              _search(query);
            },
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.isEmpty ? '输入关键词搜索' : '没有找到结果',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    )
                  : _buildGroupedBody(),
    );
  }

  Widget _buildGroupedBody() {
    final books = _results.where((r) => r.type == 'book').toList();
    final notes = _results.where((r) => r.type == 'note').toList();
    final chapters = _results.where((r) => r.type == 'chapter').toList();

    final sections = <Widget>[];
    if (books.isNotEmpty) {
      sections.add(_sectionHeader('书籍', books.length));
      sections.addAll(books.map((r) => _bookTile(r)));
    }
    if (notes.isNotEmpty) {
      sections.add(_sectionHeader('笔记', notes.length));
      sections.addAll(notes.map((r) => _noteTile(r)));
    }
    if (chapters.isNotEmpty) {
      sections.add(_sectionHeader('正文', chapters.length));
      sections.addAll(chapters.map((r) => _chapterTile(r)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections,
    );
  }

  Widget _sectionHeader(String label, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text('$label ($count)',
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }

  Widget _bookTile(SearchResult r) {
    return GlassContainer.stable(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(Icons.book),
          title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: r.subtitle != null ? Text(r.subtitle!) : null,
          onTap: () => Navigator.push(
            context,
            GlassPageRoute(
              isOpaque: true,
              builder: (_) => ReaderPage(bookId: r.id),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noteTile(SearchResult r) {
    return GlassContainer.stable(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(Icons.note),
          title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: r.highlight != null
              ? Text(r.highlight!, maxLines: 2, overflow: TextOverflow.ellipsis)
              : null,
          onTap: r.locator == null ? null : () => _openLocator(r.locator!),
        ),
      ),
    );
  }

  Widget _chapterTile(SearchResult r) {
    return GlassContainer.stable(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(Icons.menu_book),
          title: Text('${r.bookTitle} › ${r.chapterTitle}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: r.highlight != null
              ? Text(_stripSnippetMarkers(r.highlight!),
                  maxLines: 2, overflow: TextOverflow.ellipsis)
              : null,
          onTap: r.locator == null ? null : () => _openLocator(r.locator!),
        ),
      ),
    );
  }

  void _openLocator(ReaderLocator locator) {
    Navigator.push(
      context,
      GlassPageRoute(
        isOpaque: true,
        builder: (_) => ReaderPage(
          bookId: locator.bookId,
          initialLocator: locator,
        ),
      ),
    );
  }

  String _stripSnippetMarkers(String s) =>
      s.replaceAll('»', '').replaceAll('«', '');

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
