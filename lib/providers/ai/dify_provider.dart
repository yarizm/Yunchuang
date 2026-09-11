import 'dart:convert';

import 'package:dio/dio.dart';
import 'ai_http.dart';
import 'ai_provider.dart';

class DifyProvider
    implements AIProvider, CancellableAIProvider, DisposableAIProvider {
  final String baseUrl;
  final String apiKey;
  final Dio _dio;
  final bool _ownsDio;
  var _disposed = false;

  DifyProvider({
    required this.baseUrl,
    required this.apiKey,
    Dio? dio,
  })  : _dio = dio ?? Dio(aiProviderBaseOptions(baseUrl)),
        _ownsDio = dio == null;

  @override
  String get name => 'Dify';

  @override
  String get type => 'dify';

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
    final data = {
      'inputs': {},
      'query': _queryWithHistory(message, history),
      'response_mode': 'blocking',
      'user': 'local-user',
    };
    final options = Options(
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );
    final response = await runCancellableDioRequest(
      cancellation,
      (cancelToken) => cancelToken == null
          ? _dio.post('/chat-messages', data: data, options: options)
          : _dio.post(
              '/chat-messages',
              data: data,
              options: options,
              cancelToken: cancelToken,
            ),
    );

    return readNestedString(
      response.data,
      ['answer'],
      'Dify chat response',
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
    final data = {
      'inputs': {},
      'query': _queryWithHistory(message, history),
      'response_mode': 'streaming',
      'user': 'local-user',
    };
    final options = Options(
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.stream,
    );
    yield* runCancellableDioStreamRequest<String>(
      cancellation,
      (cancelToken) => cancelToken == null
          ? _dio.post('/chat-messages', data: data, options: options)
          : _dio.post(
              '/chat-messages',
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
        final data = Map<String, dynamic>.from(
          const JsonDecoder().convert(payload) as Map,
        );
        if (data['event'] == 'error') {
          final error = providerErrorMessage(
                data['message'] ?? data['error'] ?? data['code'],
              ) ??
              '未知错误';
          throw AIProviderResponseException('Dify 流式响应失败：$error');
        }
        final answer = data['answer'] as String?;
        if (answer != null && answer.isNotEmpty) yield answer;
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

  String _queryWithHistory(String message, List<ChatMessage>? history) {
    if (history == null || history.isEmpty) return message;
    final buffer = StringBuffer()
      ..writeln('以下是本轮对话上下文。请遵守 system 指令，参考历史消息，并回答最后的用户问题。')
      ..writeln();
    for (final item in history) {
      buffer
        ..writeln('[${_roleLabel(item.role)}]')
        ..writeln(item.content)
        ..writeln();
    }
    buffer
      ..writeln('[User]')
      ..write(message);
    return buffer.toString();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'system':
        return 'System';
      case 'assistant':
        return 'Assistant';
      case 'user':
        return 'User';
      default:
        return role;
    }
  }
}
