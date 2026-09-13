import 'dart:convert';

import 'package:dio/dio.dart';
import 'ai_http.dart';
import 'ai_provider.dart';
import 'ai_usage.dart';

class OllamaProvider
    implements AIProvider, CancellableAIProvider, DisposableAIProvider {
  final String baseUrl;
  final String model;
  final AIUsageListener? onUsage;
  final Dio _dio;
  final bool _ownsDio;
  var _disposed = false;

  OllamaProvider({
    this.baseUrl = 'http://localhost:11434',
    required this.model,
    this.onUsage,
    Dio? dio,
  })  : _dio = dio ?? Dio(aiProviderBaseOptions(baseUrl)),
        _ownsDio = dio == null;

  @override
  String get name => 'Ollama';

  @override
  String get type => 'ollama';

  @override
  void dispose() {
    if (_disposed || !_ownsDio) return;
    _disposed = true;
    _dio.close();
  }

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) {
    return _chat(message, history: history);
  }

  @override
  Future<String> chatCancellable(
    String message, {
    List<ChatMessage>? history,
    required AIRequestCancellation cancellation,
  }) {
    return _chat(
      message,
      history: history,
      cancellation: cancellation,
    );
  }

  Future<String> _chat(
    String message, {
    List<ChatMessage>? history,
    AIRequestCancellation? cancellation,
  }) async {
    final messages = [
      if (history != null) ...history.map((m) => m.toMap()),
      {'role': 'user', 'content': message},
    ];

    final data = {
      'model': model,
      'messages': messages,
      'stream': false,
    };
    final response = await runCancellableDioRequest(
      cancellation,
      (cancelToken) => cancelToken == null
          ? _dio.post('/api/chat', data: data)
          : _dio.post('/api/chat', data: data, cancelToken: cancelToken),
    );

    final text = readNestedString(
      response.data,
      ['message', 'content'],
      'Ollama chat response',
    );
    _reportUsage(
      exact: _usageFromChunk(response.data),
      messages: messages,
      completion: text,
    );
    return text;
  }

  /// Ollama 在最后一个块里给 `prompt_eval_count` / `eval_count`。
  static AIUsage? _usageFromChunk(Object? data) {
    if (data is! Map) return null;
    final prompt = data['prompt_eval_count'];
    final completion = data['eval_count'];
    if (prompt is! num && completion is! num) return null;
    return AIUsage(
      promptTokens: prompt is num ? prompt.toInt() : 0,
      completionTokens: completion is num ? completion.toInt() : 0,
    );
  }

  void _reportUsage({
    required AIUsage? exact,
    required List<Map<String, String>> messages,
    required String completion,
  }) {
    final listener = onUsage;
    if (listener == null) return;
    listener(
      exact ??
          AIUsage.estimate(
            promptTexts: messages.map((m) => m['content'] ?? ''),
            completion: completion,
          ),
    );
  }

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) {
    return _chatStream(message, history: history);
  }

  @override
  Stream<String> chatStreamCancellable(
    String message, {
    List<ChatMessage>? history,
    required AIRequestCancellation cancellation,
  }) {
    return _chatStream(
      message,
      history: history,
      cancellation: cancellation,
    );
  }

  Stream<String> _chatStream(
    String message, {
    List<ChatMessage>? history,
    AIRequestCancellation? cancellation,
  }) async* {
    final messages = [
      if (history != null) ...history.map((m) => m.toMap()),
      {'role': 'user', 'content': message},
    ];

    final data = {
      'model': model,
      'messages': messages,
      'stream': true,
    };
    final options = Options(responseType: ResponseType.stream);
    final collected = StringBuffer();
    AIUsage? exact;
    try {
      await for (final chunk in runCancellableDioStreamRequest<String>(
        cancellation,
        (cancelToken) => cancelToken == null
            ? _dio.post('/api/chat', data: data, options: options)
            : _dio.post(
                '/api/chat',
                data: data,
                options: options,
                cancelToken: cancelToken,
              ),
        (response) => _decodeResponseStream(
          response,
          onUsage: (usage) => exact = usage,
        ),
      )) {
        collected.write(chunk);
        yield chunk;
      }
    } finally {
      if (exact != null || collected.isNotEmpty) {
        _reportUsage(
          exact: exact,
          messages: messages,
          completion: collected.toString(),
        );
      }
    }
  }

  Stream<String> _decodeResponseStream(
    Response<dynamic> response, {
    required AIUsageListener onUsage,
  }) async* {
    final stream = response.data.stream as Stream<List<int>>;
    await for (final line in decodeUtf8Lines(stream)) {
      if (line.trim().isEmpty) continue;
      try {
        final data = Map<String, dynamic>.from(
          const JsonDecoder().convert(line) as Map,
        );
        final error = providerErrorMessage(data['error']);
        if (error != null) {
          throw AIProviderResponseException('Ollama 流式响应失败：$error');
        }
        final usage = _usageFromChunk(data);
        if (usage != null) onUsage(usage);
        final content = data['message']?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      } on AIProviderResponseException {
        rethrow;
      } catch (_) {
        // Skip malformed lines without terminating the remaining response.
      }
    }
  }

  /// `GET /api/tags`：本机已经拉取的模型。
  Future<List<String>> listModels() async {
    final response = await _dio.get('/api/tags');
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Ollama tags response 不是 JSON 对象');
    }
    final error = providerErrorMessage(data['error']);
    if (error != null) {
      throw AIProviderResponseException('Ollama 返回错误：$error');
    }
    final models = data['models'];
    if (models is! List) {
      throw const FormatException('Ollama tags response 缺少 models 列表');
    }
    return models
        .whereType<Map>()
        .map((item) => item['name'] ?? item['model'])
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<String> complete(String prompt) => chat(prompt);

  @override
  Future<String> completeCancellable(
    String prompt, {
    required AIRequestCancellation cancellation,
  }) {
    return chatCancellable(prompt, cancellation: cancellation);
  }

  @override
  Future<bool> testConnection() async {
    final response = await _dio.get('/api/tags');
    final data = response.data;
    if (data is Map) {
      final error = providerErrorMessage(data['error']);
      if (error != null) {
        throw AIProviderResponseException('Ollama 返回错误：$error');
      }
      final models = data['models'];
      if (models is! List) {
        throw const FormatException('Ollama tags response 缺少 models 列表');
      }
      final configuredModel = model.trim();
      final installedModels = models
          .whereType<Map>()
          .expand((item) => [item['name'], item['model']])
          .whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty);
      if (installedModels.any(
        (installed) => _matchesOllamaModel(configuredModel, installed),
      )) {
        return true;
      }
      throw AIProviderResponseException(
        'Ollama 服务已连接，但未找到模型“$configuredModel”。'
        '请先在运行 Ollama 的设备上拉取该模型。',
      );
    }
    throw const FormatException('Ollama tags response 不是 JSON 对象');
  }
}

bool _matchesOllamaModel(String configured, String installed) {
  final expected = configured.toLowerCase();
  final candidate = installed.toLowerCase();
  if (expected == candidate) return true;
  final nameStart = expected.lastIndexOf('/') + 1;
  final hasExplicitTag = expected.substring(nameStart).contains(':');
  return !hasExplicitTag && candidate == '$expected:latest';
}
