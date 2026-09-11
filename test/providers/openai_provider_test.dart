import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:yunchuang/providers/ai/ai_http.dart';
import 'package:yunchuang/providers/ai/openai_provider.dart';

class MockDio extends Mock implements Dio {}

class FakeStreamBody {
  const FakeStreamBody(this.stream);

  final Stream<List<int>> stream;
}

void main() {
  group('OpenAIProvider', () {
    late MockDio mockDio;
    late OpenAIProvider provider;

    setUp(() {
      mockDio = MockDio();
      provider = OpenAIProvider(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        model: 'gpt-4o-mini',
        dio: mockDio,
      );
    });

    test('chat sends correct request format', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {
              'choices': [
                {
                  'message': {'content': 'Hello!'}
                }
              ]
            },
          ));

      final result = await provider.chat('Hi');
      expect(result, 'Hello!');
      verify(() => mockDio.post(
            '/chat/completions',
            data: {
              'model': 'gpt-4o-mini',
              'messages': [
                {'role': 'user', 'content': 'Hi'}
              ],
            },
            options: any(named: 'options'),
          )).called(1);
    });

    test('chat joins text parts returned by compatible providers', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {
              'choices': [
                {
                  'message': {
                    'content': [
                      {'type': 'text', 'text': 'Hello'},
                      {
                        'type': 'text',
                        'text': {'value': ' world'},
                      },
                    ],
                  }
                }
              ]
            },
          ));

      expect(await provider.chat('Hi'), 'Hello world');
    });

    test('chat throws a format error for malformed responses', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {'choices': []},
          ));

      expect(
        () => provider.chat('Hi'),
        throwsA(isA<FormatException>()),
      );
    });

    test('chat surfaces provider error payloads returned with HTTP 200',
        () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {
              'error': {'message': 'model unavailable'}
            },
          ));

      await expectLater(
        provider.chat('Hi'),
        throwsA(
          isA<AIProviderResponseException>().having(
            (error) => error.message,
            'message',
            contains('model unavailable'),
          ),
        ),
      );
    });

    test('chatStream parses split SSE events and a final unclosed line',
        () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: FakeStreamBody(Stream.fromIterable([
              utf8.encode('data:{"choices":[{"delta":{"content":"A"}}]}\r'),
              utf8.encode(
                '\ndata: {"choices":[{"delta":{"content":"B"}}]}',
              ),
            ])),
          ));

      final chunks = await provider.chatStream('Hi').toList();

      expect(chunks, ['A', 'B']);
    });

    test('chatStream joins array content deltas', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: FakeStreamBody(Stream.value(utf8.encode(
              'data: {"choices":[{"delta":{"content":['
              '{"type":"text","text":"A"},'
              '{"type":"text","text":{"value":"B"}}]}}]}\n',
            ))),
          ));

      expect(await provider.chatStream('Hi').toList(), ['AB']);
    });

    test('chatStream surfaces provider errors carried inside SSE', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: FakeStreamBody(Stream.value(utf8.encode(
              'data: {"error":{"message":"quota exhausted"}}\n',
            ))),
          ));

      await expectLater(
        provider.chatStream('Hi').toList(),
        throwsA(
          isA<AIProviderResponseException>().having(
            (error) => error.message,
            'message',
            contains('quota exhausted'),
          ),
        ),
      );
    });
  });

  group('aiProviderBaseOptions', () {
    test('sets bounded HTTP timeouts', () {
      final options = aiProviderBaseOptions('https://example.test');

      expect(options.baseUrl, 'https://example.test');
      expect(options.connectTimeout, aiConnectTimeout);
      expect(options.sendTimeout, aiSendTimeout);
      expect(options.receiveTimeout, aiReceiveTimeout);
    });
  });
}
