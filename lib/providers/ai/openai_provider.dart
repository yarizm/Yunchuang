import 'dart:convert';

import 'package:dio/dio.dart';
import 'ai_http.dart';
import 'ai_provider.dart';

class OpenAIProvider
    implements AIProvider, CancellableAIProvider, DisposableAIProvider {
  final String baseUrl;
  final String? apiKey;
  final String model;
  final Dio _dio;
  final bool _ownsDio;
  var _disposed = false;

  OpenAIProvider({
    required this.baseUrl,
    this.apiKey,
    required this.model,
    Dio? dio,
  })  : _dio = dio ?? Dio(aiProviderBaseOptions(baseUrl)),
        _ownsDio = dio == null;

  @override
  String get name => 'OpenAI';

  @override
  String get type => 'openai';

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
    };
    final options = Options(
      headers: {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );
    final response = await runCancellableDioRequest(
      cancellation,
      (cancelToken) => cancelToken == null
          ? _dio.post('/chat/completions', data: data, options: options)
          : _dio.post(
              '/chat/completions',
              data: data,
              options: options,
              cancelToken: cancelToken,
            ),
    );

    return readTextContent(
      readNestedValue(
        response.data,
        ['choices', 0, 'message', 'content'],
        'OpenAI chat response',
      ),
      'OpenAI chat response content',
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
    final options = Options(
      headers: {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.stream,
    );
    yield* runCancellableDioStreamRequest<String>(
      cancellation,
      (cancelToken) => cancelToken == null
          ? _dio.post('/chat/completions', data: data, options: options)
          : _dio.post(
              '/chat/completions',
              data: data,
              options: options,
              cancelToken: cancelToken,
            ),
      _decodeResponseStream,
    );
  }

  Stream<String> _decodeResponseStream(Response<dynamic> response) async* {
    final stream = response.data.stream as Stream<List<int>>;
    await for (final payload in decodeSseData(stream)) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final error = providerErrorMessage(data['error']);
        if (error != null) {
          throw AIProviderResponseException('OpenAI 流式响应失败：$error');
        }
        final delta =
            (data['choices'] as List?)?.firstOrNull?['delta']?['content'];
        if (delta != null) {
          final text = readTextContent(
            delta,
            'OpenAI streaming response content',
          );
          if (text.isNotEmpty) yield text;
        }
      } on AIProviderResponseException {
        rethrow;
      } catch (_) {
        // Skip malformed events without terminating the remaining response.
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
    await chat('Hello');
    return true;
  }
}
