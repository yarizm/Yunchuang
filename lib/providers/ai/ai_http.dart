import 'dart:convert';

import 'package:dio/dio.dart';

import 'ai_provider.dart';

const aiConnectTimeout = Duration(seconds: 10);
const aiSendTimeout = Duration(seconds: 30);
const aiReceiveTimeout = Duration(minutes: 2);

BaseOptions aiProviderBaseOptions(String baseUrl) {
  return BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: aiConnectTimeout,
    sendTimeout: aiSendTimeout,
    receiveTimeout: aiReceiveTimeout,
  );
}

Future<T> runCancellableDioRequest<T>(
  AIRequestCancellation? cancellation,
  Future<T> Function(CancelToken? cancelToken) request,
) async {
  final scope = AIDioCancellationScope(cancellation);
  try {
    return await scope.run(request);
  } finally {
    scope.close();
  }
}

class AIDioCancellationScope {
  AIDioCancellationScope(this.cancellation)
      : cancelToken = cancellation == null ? null : CancelToken() {
    cancellation?.throwIfCancelled();
    _detach = cancellation?.addCancelListener(() {
      final token = cancelToken;
      if (token != null && !token.isCancelled) {
        token.cancel(cancellation!.reason);
      }
    });
  }

  final AIRequestCancellation? cancellation;
  final CancelToken? cancelToken;
  void Function()? _detach;

  AIRequestCancelledException get cancellationException =>
      AIRequestCancelledException(cancellation?.reason ?? '请求已取消。');

  bool isCancellationError(DioException error) {
    return CancelToken.isCancel(error) || cancellation?.isCancelled == true;
  }

  Future<T> run<T>(
    Future<T> Function(CancelToken? cancelToken) request,
  ) async {
    try {
      return await request(cancelToken);
    } on DioException catch (error) {
      if (isCancellationError(error)) throw cancellationException;
      rethrow;
    }
  }

  void close() {
    _detach?.call();
    _detach = null;
  }
}

Stream<T> runCancellableDioStreamRequest<T>(
  AIRequestCancellation? cancellation,
  Future<Response<dynamic>> Function(CancelToken? cancelToken) request,
  Stream<T> Function(Response<dynamic> response) consume,
) async* {
  final scope = AIDioCancellationScope(cancellation);
  try {
    final response = await scope.run(request);
    await for (final value in consume(response)) {
      cancellation?.throwIfCancelled();
      yield value;
    }
    cancellation?.throwIfCancelled();
  } on DioException catch (error) {
    if (scope.isCancellationError(error)) throw scope.cancellationException;
    rethrow;
  } finally {
    scope.close();
  }
}

Stream<String> decodeUtf8Lines(Stream<List<int>> bytes) async* {
  var buffer = '';
  // 用 bind 而不是 bytes.transform(utf8.decoder)：Dio 给的是 Stream<Uint8List>，
  // transform 会在运行时要求一个 StreamTransformer<Uint8List, String>，
  // Utf8Decoder 不是，直接抛 TypeError——真机上流式回复整个失败。
  await for (final chunk in utf8.decoder.bind(bytes)) {
    buffer += chunk;
    while (true) {
      final newline = buffer.indexOf('\n');
      if (newline < 0) break;
      yield _stripCarriageReturn(buffer.substring(0, newline));
      buffer = buffer.substring(newline + 1);
    }
  }
  if (buffer.isNotEmpty) yield _stripCarriageReturn(buffer);
}

Stream<String> decodeSseData(Stream<List<int>> bytes) async* {
  await for (final line in decodeUtf8Lines(bytes)) {
    if (!line.startsWith('data:')) continue;
    final data = line.substring(5).trimLeft();
    if (data.trim() == '[DONE]') return;
    yield data;
  }
}

String _stripCarriageReturn(String line) {
  return line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
}

String describeAIError(Object error) {
  if (error is AIProviderResponseException) {
    return error.message;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return '请求超时，请检查网络、Provider 地址或模型响应速度。';
      case DioExceptionType.connectionError:
        return '无法连接 AI Provider，请检查地址、网络和局域网访问权限。';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          return '认证失败，请检查 API Key 和访问权限。';
        }
        if (status == 404) {
          return '接口或模型不存在，请检查 API 端点和模型名称。';
        }
        if (status == 429) {
          return '请求过于频繁或额度不足，请稍后重试并检查账户额度。';
        }
        if (status != null && status >= 500) {
          return 'AI Provider 服务暂时异常（HTTP $status），请稍后重试。';
        }
        return status == null
            ? 'AI Provider 返回了错误响应。'
            : 'AI Provider 请求失败（HTTP $status）。';
      case DioExceptionType.badCertificate:
        return 'Provider 的 HTTPS 证书无效。';
      case DioExceptionType.cancel:
        return '请求已取消。';
      case DioExceptionType.unknown:
        return 'AI Provider 请求失败：${error.message ?? '未知网络错误'}';
    }
  }
  if (error is FormatException) {
    return 'Provider 返回格式不兼容：${error.message}';
  }
  return error.toString();
}

class AIProviderResponseException implements Exception {
  final String message;

  const AIProviderResponseException(this.message);

  @override
  String toString() => message;
}

String? providerErrorMessage(Object? error) {
  if (error is String && error.trim().isNotEmpty) return error.trim();
  if (error is Map) {
    for (final key in const ['message', 'error', 'code']) {
      final value = error[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
  }
  return null;
}

String readNestedString(
  Object? source,
  List<Object> path,
  String label,
) {
  final current = readNestedValue(source, path, label);
  if (current is String) return current;
  throw FormatException('$label 字段不是字符串');
}

Object? readNestedValue(
  Object? source,
  List<Object> path,
  String label,
) {
  if (source is Map) {
    final error = providerErrorMessage(source['error']);
    if (error != null) {
      throw AIProviderResponseException('AI Provider 返回错误：$error');
    }
  }
  Object? current = source;
  for (final segment in path) {
    if (segment is String) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
        continue;
      }
      throw FormatException('$label 缺少字段: $segment');
    }
    if (segment is int) {
      if (current is List && segment >= 0 && segment < current.length) {
        current = current[segment];
        continue;
      }
      throw FormatException('$label 缺少列表项: $segment');
    }
    throw FormatException('$label 包含不支持的路径片段: $segment');
  }
  return current;
}

String readTextContent(Object? source, String label) {
  final buffer = StringBuffer();
  var foundText = false;

  void collect(Object? value) {
    if (value is String) {
      foundText = true;
      buffer.write(value);
      return;
    }
    if (value is List) {
      for (final part in value) {
        collect(part);
      }
      return;
    }
    if (value is Map) {
      final text = value['text'];
      if (text is String) {
        foundText = true;
        buffer.write(text);
        return;
      }
      if (text is Map && text['value'] is String) {
        foundText = true;
        buffer.write(text['value'] as String);
      }
    }
  }

  collect(source);
  if (!foundText) {
    throw FormatException('$label does not contain text content');
  }
  return buffer.toString();
}
