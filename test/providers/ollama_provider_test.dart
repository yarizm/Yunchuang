import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/providers/ai/ai_http.dart';
import 'package:yunchuang/providers/ai/ollama_provider.dart';

class MockDio extends Mock implements Dio {}

class FakeStreamBody {
  const FakeStreamBody(this.stream);

  final Stream<List<int>> stream;
}

void main() {
  test('testConnection verifies the configured Ollama model', () async {
    final dio = MockDio();
    final provider = OllamaProvider(model: 'qwen2.5', dio: dio);
    when(() => dio.get(any())).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {
            'models': [
              {'name': 'qwen2.5:latest'},
            ],
          },
        ));

    expect(await provider.testConnection(), isTrue);
    verify(() => dio.get('/api/tags')).called(1);
  });

  test('testConnection rejects a missing Ollama model with guidance', () async {
    final dio = MockDio();
    final provider = OllamaProvider(model: 'qwen2.5:14b', dio: dio);
    when(() => dio.get(any())).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {
            'models': [
              {'name': 'qwen2.5:7b'},
            ],
          },
        ));

    await expectLater(
      provider.testConnection(),
      throwsA(
        isA<AIProviderResponseException>()
            .having(
                (error) => error.message, 'message', contains('qwen2.5:14b'))
            .having((error) => error.message, 'message', contains('拉取')),
      ),
    );
  });

  test('testConnection surfaces Ollama errors from tags response', () async {
    final dio = MockDio();
    final provider = OllamaProvider(model: 'qwen2.5', dio: dio);
    when(() => dio.get(any())).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {'error': 'service unavailable'},
        ));

    await expectLater(
      provider.testConnection(),
      throwsA(
        isA<AIProviderResponseException>().having(
          (error) => error.message,
          'message',
          contains('service unavailable'),
        ),
      ),
    );
  });

  test('testConnection rejects malformed Ollama tags responses', () async {
    final dio = MockDio();
    final provider = OllamaProvider(model: 'qwen2.5', dio: dio);
    when(() => dio.get(any())).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {'models': 'qwen2.5:latest'},
        ));

    await expectLater(
      provider.testConnection(),
      throwsA(isA<FormatException>()),
    );
  });

  test('chatStream parses split NDJSON including the final unclosed line',
      () async {
    final dio = MockDio();
    final provider = OllamaProvider(model: 'qwen2.5', dio: dio);
    when(() => dio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: FakeStreamBody(Stream.fromIterable([
            utf8.encode('{"message":{"content":"A"}}\n{"message":'),
            utf8.encode('{"content":"B"}}'),
          ])),
        ));

    final chunks = await provider.chatStream('Hi').toList();

    expect(chunks, ['A', 'B']);
  });

  test('chatStream surfaces Ollama errors carried inside NDJSON', () async {
    final dio = MockDio();
    final provider = OllamaProvider(model: 'qwen2.5', dio: dio);
    when(() => dio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: FakeStreamBody(Stream.value(
            utf8.encode('{"error":"model not found"}\n'),
          )),
        ));

    await expectLater(
      provider.chatStream('Hi').toList(),
      throwsA(
        isA<AIProviderResponseException>().having(
          (error) => error.message,
          'message',
          contains('model not found'),
        ),
      ),
    );
  });
}
