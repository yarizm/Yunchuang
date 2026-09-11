import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/ai/ai_http.dart';
import 'package:yunchuang/providers/ai/ai_provider.dart';

void main() {
  test('cancellation interrupts pending futures and notifies listeners',
      () async {
    final cancellation = AIRequestCancellation();
    final source = Completer<String>();
    var listenerCalled = false;
    cancellation.addCancelListener(() => listenerCalled = true);
    final expectation = expectLater(
      cancellation.bindFuture(source.future),
      throwsA(isA<AIRequestCancelledException>()),
    );

    cancellation.cancel('测试取消');
    await expectation;

    expect(listenerCalled, isTrue);
    expect(cancellation.isCancelled, isTrue);
    expect(cancellation.reason, '测试取消');
    source.complete('迟到结果');
  });

  test('cancellation closes a bound stream without waiting for another chunk',
      () async {
    final cancellation = AIRequestCancellation();
    final source = StreamController<String>();
    addTearDown(source.close);
    final values = <String>[];
    final error = Completer<Object>();
    final subscription = cancellation.bindStream(source.stream).listen(
          values.add,
          onError: (Object value) => error.complete(value),
        );
    addTearDown(subscription.cancel);

    source.add('部分回答');
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();

    expect(await error.future, isA<AIRequestCancelledException>());
    expect(values, ['部分回答']);
  });

  test('Dio bridge cancels the underlying request token', () async {
    final cancellation = AIRequestCancellation();
    CancelToken? captured;
    final future = runCancellableDioRequest<String>(
      cancellation,
      (cancelToken) {
        captured = cancelToken;
        return cancelToken!.whenCancel.then<String>((error) => throw error);
      },
    );
    final expectation = expectLater(
      future,
      throwsA(isA<AIRequestCancelledException>()),
    );

    cancellation.cancel('停止网络请求');
    await expectation;

    expect(captured, isNotNull);
    expect(captured!.isCancelled, isTrue);
  });

  test('Dio cancellation scope remains active after response headers',
      () async {
    final cancellation = AIRequestCancellation();
    final scope = AIDioCancellationScope(cancellation);
    addTearDown(scope.close);

    final response = await scope.run((_) async => 'headers received');
    expect(response, 'headers received');
    expect(scope.cancelToken!.isCancelled, isFalse);

    cancellation.cancel('cancel response body');

    expect(scope.cancelToken!.isCancelled, isTrue);
  });

  test('SSE decoder handles split chunks, CRLF and final data without newline',
      () async {
    final chunks = [
      utf8.encode('event: message\r\ndata:{"value":"'),
      utf8.encode('first"}\r\ndata: {"value":"second"}'),
    ];

    final values = await decodeSseData(Stream.fromIterable(chunks)).toList();

    expect(values, ['{"value":"first"}', '{"value":"second"}']);
  });

  test('SSE decoder stops at done marker', () async {
    final bytes = utf8.encode('data: one\ndata: [DONE]\ndata: ignored\n');

    final values = await decodeSseData(Stream.value(bytes)).toList();

    expect(values, ['one']);
  });

  test('UTF-8 line decoder preserves a final NDJSON line without newline',
      () async {
    final chunks = [
      utf8.encode('{"message":{"content":"A"}}\n{"message":'),
      utf8.encode('{"content":"B"}}'),
    ];

    final lines = await decodeUtf8Lines(Stream.fromIterable(chunks)).toList();

    expect(lines, [
      '{"message":{"content":"A"}}',
      '{"message":{"content":"B"}}',
    ]);
  });

  test('friendly errors distinguish auth, timeout, rate and format failures',
      () {
    DioException responseError(int status) => DioException.badResponse(
          statusCode: status,
          requestOptions: RequestOptions(),
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: status,
          ),
        );

    expect(describeAIError(responseError(401)), contains('API Key'));
    expect(describeAIError(responseError(429)), contains('额度'));
    expect(
      describeAIError(DioException.connectionTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: RequestOptions(),
      )),
      contains('请求超时'),
    );
    expect(
      describeAIError(const FormatException('missing answer')),
      contains('格式不兼容'),
    );
  });
}
