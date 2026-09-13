import 'dart:convert';

import 'package:dio/dio.dart';
import 'ai_http.dart';
import 'ai_provider.dart';
import 'ai_usage.dart';

class OpenAIProvider
    implements AIProvider, CancellableAIProvider, DisposableAIProvider {
  final String baseUrl;
  final String? apiKey;
  final String model;
  final AIUsageListener? onUsage;
  final Dio _dio;
  final bool _ownsDio;
  var _disposed = false;

  /// 流式请求带 `stream_options.include_usage` 才拿得到准确用量。个别兼容
  /// 服务不认这个字段、直接回 400，那就去掉重试，之后这个实例都不再带。
  bool _streamUsageSupported = true;

  OpenAIProvider({
    required this.baseUrl,
    this.apiKey,
    required this.model,
    this.onUsage,
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

  Options get _requestOptions => Options(
        headers: {
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );

  List<Map<String, String>> _messages(
    String message,
    List<ChatMessage>? history,
  ) {
    return [
      if (history != null) ...history.map((m) => m.toMap()),
      {'role': 'user', 'content': message},
    ];
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
    final messages = _messages(message, history);
    final data = {
      'model': model,
      'messages': messages,
    };
    final options = _requestOptions;
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

    final text = readTextContent(
      readNestedValue(
        response.data,
        ['choices', 0, 'message', 'content'],
        'OpenAI chat response',
      ),
      'OpenAI chat response content',
    );
    final body = response.data;
    _reportUsage(
      exact: AIUsage.fromOpenAi(body is Map ? body['usage'] : null),
      messages: messages,
      completion: text,
    );
    return text;
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
    final messages = _messages(message, history);
    final collected = StringBuffer();
    AIUsage? exact;

    Stream<String> run({required bool includeUsage}) {
      final data = {
        'model': model,
        'messages': messages,
        'stream': true,
        if (includeUsage) 'stream_options': const {'include_usage': true},
      };
      final options = _requestOptions.copyWith(
        responseType: ResponseType.stream,
      );
      return runCancellableDioStreamRequest<String>(
        cancellation,
        (cancelToken) => cancelToken == null
            ? _dio.post('/chat/completions', data: data, options: options)
            : _dio.post(
                '/chat/completions',
                data: data,
                options: options,
                cancelToken: cancelToken,
              ),
        (response) => _decodeResponseStream(
          response,
          onUsage: (usage) => exact = usage,
        ),
      );
    }

    try {
      final withUsage = _streamUsageSupported;
      try {
        await for (final chunk in run(includeUsage: withUsage)) {
          collected.write(chunk);
          yield chunk;
        }
      } on DioException catch (error) {
        // 400 且一个字都还没收到：多半是 stream_options 不被认识，去掉再试。
        // 别的 400 重试也还是 400，代价只是多一次失败的请求。
        if (!withUsage ||
            collected.isNotEmpty ||
            error.response?.statusCode != 400) {
          rethrow;
        }
        _streamUsageSupported = false;
        await for (final chunk in run(includeUsage: false)) {
          collected.write(chunk);
          yield chunk;
        }
      }
    } finally {
      // 中途取消也已经产生了消耗，收到过内容就记；一个字没收到的失败不记。
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
    await for (final payload in decodeSseData(stream)) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final error = providerErrorMessage(data['error']);
        if (error != null) {
          throw AIProviderResponseException('OpenAI 流式响应失败：$error');
        }
        // 开了 include_usage 之后最后一个事件只有 usage、没有 choices。
        final usage = AIUsage.fromOpenAi(data['usage']);
        if (usage != null) onUsage(usage);
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

  /// `GET /models`：OpenAI 兼容服务基本都有，返回 `data[].id`。
  /// 让用户从列表里挑，不用去翻文档抄模型名。
  Future<List<String>> listModels() async {
    final response = await _dio.get('/models', options: _requestOptions);
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('models 响应不是 JSON 对象');
    }
    final error = providerErrorMessage(body['error']);
    if (error != null) {
      throw AIProviderResponseException('AI Provider 返回错误：$error');
    }
    final data = body['data'];
    if (data is! List) throw const FormatException('models 响应缺少 data 列表');
    final ids = data
        .whereType<Map>()
        .map((item) => item['id'])
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ids;
  }
}
