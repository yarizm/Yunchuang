import 'dart:convert';

import '../../models/reader_locator.dart';
import '../../providers/ai/agent_models.dart';

/// 把 Agent 工具回传的原始 JSON 解析成「来源引用」。
///
/// 从 `AiChatPanel` 拆出来：这一层没有任何状态，也不碰 BuildContext，输入是
/// 模型那边来的自由格式 Map，输出是 [AiSourceReference]。留在 2600 行的
/// 面板里既看不见也没法单独测——而它恰恰是最需要单独测的那部分，因为输入
/// 完全由模型决定，缺字段、类型不对、数字变成字符串都得兜住。

/// 从消息 metadata 里取出工具调用记录。解析不了就当没有。
List<String> toolEventsFromMetadata(String? metadataJson) {
  if (metadataJson == null || metadataJson.isEmpty) return const [];
  try {
    final decoded = jsonDecode(metadataJson) as Map<String, dynamic>;
    final events = decoded['toolEvents'];
    if (events is! List) return const [];
    return events.map((item) => item.toString()).toList();
  } catch (_) {
    return const [];
  }
}

/// 从一条 status 事件里解析出这次工具调用带回的来源。
///
/// [fallbackBookId] 用在工具没回 bookId 的时候——读章节片段是在当前书里读的，
/// 面板知道是哪本书，工具结果里却不一定带。
List<AiSourceReference> sourceReferencesFromStatus(
  AgentEvent event, {
  int? fallbackBookId,
}) {
  final metadata = event.metadata;
  if (metadata == null) return const [];
  final tool = metadata['tool'] as String?;
  final result = metadata['result'];
  if (result is! Map) return const [];
  final data = result.cast<String, dynamic>();

  switch (tool) {
    case 'search_current_book':
      return _chapterSearchReferences(data);
    case 'read_chapter_excerpt':
      return _chapterExcerptReferences(data, fallbackBookId);
    case 'search_notes':
      return _noteSearchReferences(data);
    default:
      return const [];
  }
}

/// 去重用的键。同一段正文可能被搜索和读片段各带回一次。
String sourceReferenceKey(AiSourceReference reference) {
  return [
    reference.type,
    reference.chapterId,
    reference.noteId,
    reference.snippet,
  ].join('|');
}

List<AiSourceReference> _chapterSearchReferences(Map<String, dynamic> data) {
  final refs = <AiSourceReference>[];
  for (final match in _mapList(data['matches'])) {
    final snippets = _stringList(match['snippets']);
    final snippet = snippets.join('\n');
    if (snippet.trim().isEmpty) continue;
    final bookId = _intOrNull(data['bookId']);
    final chapterId = _intOrNull(match['chapterId']);
    final chapterPosition = _doubleOrNull(match['chapterPosition']);
    final query = data['query']?.toString();
    refs.add(AiSourceReference(
      type: 'chapter',
      title: match['chapterTitle']?.toString() ?? '章节引用',
      subtitle: match['isUnread'] == true
          ? '未读正文 · 命中 ${match['hitCount'] ?? 1} 次'
          : '正文 · 命中 ${match['hitCount'] ?? 1} 次',
      query: query,
      bookId: bookId,
      chapterId: chapterId,
      chapterPosition: chapterPosition,
      locator: bookId == null
          ? null
          : ReaderLocator(
              bookId: bookId,
              chapterId: chapterId,
              textOffsetStart: _intOrNull(match['textOffsetStart']),
              textOffsetEnd: _intOrNull(match['textOffsetEnd']),
              chapterPosition: chapterPosition,
              query: query,
              selectedText: match['selectedText']?.toString(),
              contextBefore: match['contextBefore']?.toString(),
              contextAfter: match['contextAfter']?.toString(),
              contextHash: match['contextHash']?.toString(),
            ),
      snippet: compactSnippet(snippet),
    ));
  }
  return refs;
}

List<AiSourceReference> _chapterExcerptReferences(
  Map<String, dynamic> data,
  int? fallbackBookId,
) {
  final excerpt = data['excerpt']?.toString() ?? '';
  if (excerpt.trim().isEmpty) return const [];
  final queryMatched = data['queryMatched'];
  final bookId = _intOrNull(data['bookId']) ?? fallbackBookId;
  final chapterId = _intOrNull(data['chapterId']);
  final chapterPosition = _doubleOrNull(data['chapterPosition']);
  final query = data['query']?.toString();
  return [
    AiSourceReference(
      type: 'chapter',
      title: data['chapterTitle']?.toString() ?? '章节片段',
      subtitle: data['isUnread'] == true
          ? '未读章节片段'
          : queryMatched == false
              ? '章节片段 · 关键词未命中'
              : '章节片段',
      query: query,
      bookId: bookId,
      chapterId: chapterId,
      chapterPosition: chapterPosition,
      locator: bookId == null
          ? null
          : ReaderLocator(
              bookId: bookId,
              chapterId: chapterId,
              textOffsetStart: _intOrNull(data['textOffsetStart']),
              textOffsetEnd: _intOrNull(data['textOffsetEnd']),
              chapterPosition: chapterPosition,
              query: query,
              selectedText: data['selectedText']?.toString(),
              contextBefore: data['contextBefore']?.toString(),
              contextAfter: data['contextAfter']?.toString(),
              contextHash: data['contextHash']?.toString(),
            ),
      snippet: compactSnippet(excerpt),
    ),
  ];
}

List<AiSourceReference> _noteSearchReferences(Map<String, dynamic> data) {
  final refs = <AiSourceReference>[];
  for (final match in _mapList(data['matches'])) {
    final snippets = _stringList(match['snippets']);
    final fallback = match['selectedText'] ?? match['content'];
    final snippet =
        snippets.isEmpty ? fallback?.toString() ?? '' : snippets.join('\n');
    if (snippet.trim().isEmpty) continue;
    final chapterTitle = match['chapterTitle']?.toString();
    final typeLabel = _noteTypeLabel(match['type']?.toString());
    final scopeLabel = match['isUnread'] == true ? '未读$typeLabel' : typeLabel;
    final bookId = _intOrNull(data['bookId']);
    final chapterId = _intOrNull(match['chapterId']);
    refs.add(AiSourceReference(
      type: 'note',
      title: '笔记 #${match['noteId'] ?? ''}',
      subtitle: chapterTitle == null || chapterTitle.isEmpty
          ? scopeLabel
          : '$scopeLabel · $chapterTitle',
      bookId: bookId,
      chapterId: chapterId,
      noteId: _intOrNull(match['noteId']),
      locator: bookId == null
          ? null
          : ReaderLocator(
              bookId: bookId,
              chapterId: chapterId,
              pageNumber: _intOrNull(match['pageNumber']),
              textOffsetStart: _intOrNull(match['textOffsetStart']),
              textOffsetEnd: _intOrNull(match['textOffsetEnd']),
              query: match['query']?.toString() ?? data['query']?.toString(),
              selectedText: match['selectedText']?.toString(),
            ),
      snippet: compactSnippet(snippet),
    ));
  }
  return refs;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleOrNull(Object? value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null || !parsed.isFinite) return null;
  return parsed.clamp(0.0, 1.0).toDouble();
}

/// 压成单行并截断，给引用卡片当摘要用。
String compactSnippet(String text, {int maxChars = 320}) {
  final compacted = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compacted.length <= maxChars) return compacted;
  return '${compacted.substring(0, maxChars)}...';
}

String _noteTypeLabel(String? type) {
  switch (type) {
    case 'highlight':
      return '划线';
    case 'bookmark':
      return '书签';
    default:
      return '笔记';
  }
}
