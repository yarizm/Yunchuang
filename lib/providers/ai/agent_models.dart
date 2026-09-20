import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../models/reader_locator.dart';

const _gzipBase64Encoding = 'gzip+base64';

String _encodePersistedAttachmentMetadata(
  List<Map<String, dynamic>> attachments,
) {
  final storedAttachments = attachments.map((attachment) {
    final content = attachment['content'] as String? ?? '';
    if (content.length < AiPromptDraft.attachmentCompressionThresholdChars) {
      return attachment;
    }

    try {
      final rawBytes = utf8.encode(content);
      final compressed = base64Encode(gzip.encode(rawBytes));
      if (compressed.length + 96 >= rawBytes.length) return attachment;
      return <String, dynamic>{
        'id': attachment['id'],
        'title': attachment['title'],
        'kind': attachment['kind'],
        'contentEncoding': _gzipBase64Encoding,
        'contentLength': content.length,
        'contentData': compressed,
      };
    } catch (_) {
      return attachment;
    }
  }).toList(growable: false);
  return jsonEncode({'attachments': storedAttachments});
}

class AiAttachment {
  final String id;
  final String title;
  final String kind;
  final String? _plainContent;
  final String? _compressedContent;
  final int? _storedContentLength;

  static final Expando<String> _decodedContent = Expando<String>();

  const AiAttachment({
    required this.id,
    required this.title,
    required String content,
    this.kind = 'text',
  })  : _plainContent = content,
        _compressedContent = null,
        _storedContentLength = null;

  const AiAttachment._compressed({
    required this.id,
    required this.title,
    required String compressedContent,
    required int contentLength,
    required this.kind,
  })  : _plainContent = null,
        _compressedContent = compressedContent,
        _storedContentLength = contentLength;

  String get content {
    final plain = _plainContent;
    if (plain != null) return plain;
    final cached = _decodedContent[this];
    if (cached != null) return cached;

    var decoded = '';
    try {
      decoded = utf8.decode(
        gzip.decode(base64Decode(_compressedContent ?? '')),
      );
    } catch (_) {
      // Corrupt metadata should not prevent the conversation from opening.
    }
    _decodedContent[this] = decoded;
    return decoded;
  }

  int get length {
    final plain = _plainContent;
    if (plain != null) return plain.length;
    final decoded = _decodedContent[this];
    if (decoded != null) return decoded.length;
    return _storedContentLength ?? 0;
  }

  String get summary => '$title · 约 $length 字';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'kind': kind,
      };

  factory AiAttachment.fromJson(Map<String, dynamic> json) {
    final plainContent = json['content'];
    final compressedContent = json['contentData'];
    final rawContentLength = json['contentLength'];
    if (plainContent is! String &&
        json['contentEncoding'] == _gzipBase64Encoding &&
        compressedContent is String &&
        rawContentLength is num &&
        rawContentLength.isFinite &&
        rawContentLength >= 0) {
      return AiAttachment._compressed(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '附件',
        compressedContent: compressedContent,
        contentLength: rawContentLength.toInt(),
        kind: json['kind'] as String? ?? 'text',
      );
    }
    return AiAttachment(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '附件',
      content: plainContent as String? ?? '',
      kind: json['kind'] as String? ?? 'text',
    );
  }
}

class AiPromptDraft {
  static const truncationMarker = '[附件内容过长，已保留开头、中段和结尾，其余部分省略]';
  static const attachmentCompressionThresholdChars = 4096;
  static const backgroundMetadataEncodingThresholdChars = 64 * 1024;

  final String instruction;
  final List<AiAttachment> attachments;

  const AiPromptDraft({
    required this.instruction,
    this.attachments = const [],
  });

  int get modelContentLength {
    var length = instruction.trim().length;
    for (final attachment in attachments) {
      length += 6 + attachment.title.length + attachment.length;
    }
    return length;
  }

  String toModelContent({int? maxChars}) {
    if (attachments.isEmpty) {
      return _boundedModelText(instruction.trim(), maxChars);
    }
    final buffer = StringBuffer(instruction.trim());
    for (final attachment in attachments) {
      buffer
        ..writeln('\n\n[${attachment.title}]')
        ..writeln(attachment.content);
    }
    return _boundedModelText(buffer.toString(), maxChars);
  }

  String _boundedModelText(String value, int? maxChars) {
    if (maxChars == null || value.length <= maxChars) return value;
    if (maxChars <= 0) return '';

    const firstMarker = '\n\n$truncationMarker\n\n';
    const secondMarker = '\n\n[继续省略至附件结尾]\n\n';
    const markerChars = firstMarker.length + secondMarker.length;
    if (maxChars <= markerChars + 3) {
      return value.substring(0, maxChars);
    }

    final available = maxChars - markerChars;
    final headChars = available * 2 ~/ 5;
    final middleChars = available ~/ 5;
    final tailChars = available - headChars - middleChars;
    final middleStart = (value.length ~/ 2 - middleChars ~/ 2)
        .clamp(headChars, value.length - tailChars)
        .toInt();
    return '${value.substring(0, headChars)}$firstMarker'
        '${value.substring(middleStart, middleStart + middleChars)}'
        '$secondMarker${value.substring(value.length - tailChars)}';
  }

  Map<String, dynamic> toMetadataJson() => {
        'attachments': attachments.map((item) => item.toJson()).toList(),
      };

  Future<String> toPersistedMetadataJson() {
    final serialized = attachments.map((item) => item.toJson()).toList();
    final totalChars = attachments.fold<int>(
      0,
      (total, attachment) => total + attachment.length,
    );
    if (totalChars >= backgroundMetadataEncodingThresholdChars) {
      return Isolate.run(
        () => _encodePersistedAttachmentMetadata(serialized),
      );
    }
    return Future.value(_encodePersistedAttachmentMetadata(serialized));
  }

  static List<AiAttachment> attachmentsFromMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(metadataJson) as Map<String, dynamic>;
      final attachments = decoded['attachments'];
      if (attachments is! List) return const [];
      return attachments
          .whereType<Map>()
          .map((item) => AiAttachment.fromJson(
                item.cast<String, dynamic>(),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class AiSourceReference {
  final String type;
  final String title;
  final String snippet;
  final String? subtitle;
  final String? query;
  final int? bookId;
  final int? chapterId;
  final int? noteId;
  final double? chapterPosition;
  final ReaderLocator? locator;

  const AiSourceReference({
    required this.type,
    required this.title,
    required this.snippet,
    this.subtitle,
    this.query,
    this.bookId,
    this.chapterId,
    this.noteId,
    this.chapterPosition,
    this.locator,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'snippet': snippet,
        if (subtitle != null) 'subtitle': subtitle,
        if (query != null) 'query': query,
        if (bookId != null) 'bookId': bookId,
        if (chapterId != null) 'chapterId': chapterId,
        if (noteId != null) 'noteId': noteId,
        if (chapterPosition != null && chapterPosition!.isFinite)
          'chapterPosition': chapterPosition,
        if (locator != null) 'locator': locator!.toJson(),
      };

  factory AiSourceReference.fromJson(Map<String, dynamic> json) {
    final rawLocator = json['locator'];
    final locator = rawLocator is Map
        ? ReaderLocator.fromJson(rawLocator.cast<String, dynamic>())
        : null;
    final rawPosition = json['chapterPosition'];
    final parsedPosition = rawPosition is num ? rawPosition.toDouble() : null;
    return AiSourceReference(
      type: json['type'] as String? ?? 'source',
      title: json['title'] as String? ?? '引用来源',
      snippet: json['snippet'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      query: json['query'] as String? ?? locator?.query,
      bookId: json['bookId'] as int? ??
          (locator != null && locator.bookId > 0 ? locator.bookId : null),
      chapterId: json['chapterId'] as int? ?? locator?.chapterId,
      noteId: json['noteId'] as int?,
      chapterPosition: parsedPosition != null && parsedPosition.isFinite
          ? parsedPosition.clamp(0.0, 1.0).toDouble()
          : locator?.chapterPosition,
      locator: locator,
    );
  }

  static List<AiSourceReference> fromMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(metadataJson) as Map<String, dynamic>;
      final references = decoded['references'];
      if (references is! List) return const [];
      return references
          .whereType<Map>()
          .map((item) => AiSourceReference.fromJson(
                item.cast<String, dynamic>(),
              ))
          .where((item) => item.snippet.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

enum SpoilerProtectionLevel {
  strict('strict'),
  ask('ask'),
  fullBook('fullBook');

  final String wireName;

  const SpoilerProtectionLevel(this.wireName);

  static SpoilerProtectionLevel fromWireName(String? value) {
    return SpoilerProtectionLevel.values.firstWhere(
      (level) => level.wireName == value,
      orElse: () => SpoilerProtectionLevel.strict,
    );
  }
}

class AgentContext {
  final int? bookId;
  final String? bookTitle;
  final int? currentChapterId;
  final String? currentChapterTitle;
  final int? currentChapterOrder;
  final double? currentPosition;
  final String? selectedText;
  final String? surroundingText;
  final SpoilerProtectionLevel spoilerProtectionLevel;
  final bool unreadContentAuthorized;

  const AgentContext({
    this.bookId,
    this.bookTitle,
    this.currentChapterId,
    this.currentChapterTitle,
    this.currentChapterOrder,
    this.currentPosition,
    this.selectedText,
    this.surroundingText,
    this.spoilerProtectionLevel = SpoilerProtectionLevel.strict,
    this.unreadContentAuthorized = false,
  });

  AgentContext copyWith({
    int? bookId,
    String? bookTitle,
    int? currentChapterId,
    String? currentChapterTitle,
    int? currentChapterOrder,
    double? currentPosition,
    String? selectedText,
    String? surroundingText,
    SpoilerProtectionLevel? spoilerProtectionLevel,
    bool? unreadContentAuthorized,
  }) {
    return AgentContext(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      currentChapterOrder: currentChapterOrder ?? this.currentChapterOrder,
      currentPosition: currentPosition ?? this.currentPosition,
      selectedText: selectedText ?? this.selectedText,
      surroundingText: surroundingText ?? this.surroundingText,
      spoilerProtectionLevel:
          spoilerProtectionLevel ?? this.spoilerProtectionLevel,
      unreadContentAuthorized:
          unreadContentAuthorized ?? this.unreadContentAuthorized,
    );
  }

  Map<String, dynamic> toJson() => {
        if (bookId != null) 'bookId': bookId,
        if (bookTitle != null) 'bookTitle': bookTitle,
        if (currentChapterId != null) 'currentChapterId': currentChapterId,
        if (currentChapterTitle != null)
          'currentChapterTitle': currentChapterTitle,
        if (currentChapterOrder != null)
          'currentChapterOrder': currentChapterOrder,
        if (currentPosition != null) 'currentPosition': currentPosition,
        if (selectedText != null) 'selectedText': selectedText,
        if (surroundingText != null) 'surroundingText': surroundingText,
        'spoilerProtection': spoilerProtectionLevel.wireName,
        if (unreadContentAuthorized) 'unreadContentAuthorized': true,
      };
}

enum AgentEventType { status, keepAlive, delta, done }

class AgentEvent {
  final AgentEventType type;
  final String content;
  final Map<String, dynamic>? metadata;

  const AgentEvent._(this.type, this.content, [this.metadata]);

  const AgentEvent.status(String content, [Map<String, dynamic>? metadata])
      : this._(AgentEventType.status, content, metadata);

  const AgentEvent.keepAlive() : this._(AgentEventType.keepAlive, '');

  const AgentEvent.delta(String content)
      : this._(AgentEventType.delta, content);

  const AgentEvent.done(String content, [Map<String, dynamic>? metadata])
      : this._(AgentEventType.done, content, metadata);
}
