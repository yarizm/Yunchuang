import 'dart:convert';

import 'package:dio/dio.dart';
import 'ai_http.dart';
import 'ai_provider.dart';

class OllamaProvider
    implements AIProvider, CancellableAIProvider, DisposableAIProvider {
  final String baseUrl;
  final String model;
  final Dio _dio;
  final bool _ownsDio;
  var _disposed = false;

  OllamaProvider({
    this.baseUrl = 'http://localhost:11434',
    required this.model,
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

    return readNestedString(
      response.data,
      ['message', 'content'],
      'Ollama chat response',
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
    yield* runCancellableDioStreamRequest<String>(
      cancellation,
      (cancelToken) => cancelToken == null
          ? _dio.post('/api/chat', data: data, options: options)
          : _dio.post(
              '/api/chat',
              data: data,
              options: options,
              cancelToken: cancelToken,
            ),
      _decodeResponseStream,
    );
  }

  Stream<String> _decodeResponseStream(Response<dynamic> response) async* {
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
        final content = data['message']?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      } on AIProviderResponseException {
        rethrow;
      } catch (_) {
        // Skip malformed lines without terminating the remaining response.
      }
    }
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
