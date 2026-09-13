import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:yunchuang/providers/ai/ai_http.dart';
import 'package:yunchuang/providers/ai/ai_usage.dart';
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

    // Dio 的响应体是 Stream<Uint8List>。bytes.transform(utf8.decoder) 在运行时
    // 要求 StreamTransformer<Uint8List, String>，Utf8Decoder 不是，会抛
    // TypeError——测试里用 Stream<List<int>> 看不出来，真机上流式全挂。
    test('chatStream accepts a Stream<Uint8List> body like Dio gives',
        () async {
      final body = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(
          utf8.encode('data: {"choices":[{"delta":{"content":"真"}}]}\n'),
        ),
        Uint8List.fromList(
          utf8.encode('data: {"choices":[{"delta":{"content":"机"}}]}\n'),
        ),
      ]);
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: FakeStreamBody(body),
          ));

      expect(await provider.chatStream('Hi').toList(), ['真', '机']);
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

  group('OpenAIProvider usage', () {
    late MockDio mockDio;
    late List<AIUsage> reported;
    late OpenAIProvider provider;

    setUp(() {
      mockDio = MockDio();
      reported = [];
      provider = OpenAIProvider(
        baseUrl: 'https://api.example.test/v1',
        apiKey: 'k',
        model: 'm',
        dio: mockDio,
        onUsage: reported.add,
      );
    });

    test('chat reports the usage block from the response', () async {
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
              ],
              'usage': {'prompt_tokens': 11, 'completion_tokens': 2},
            },
          ));

      await provider.chat('Hi');

      expect(reported, [
        const AIUsage(promptTokens: 11, completionTokens: 2),
      ]);
    });

    test('chat estimates when the response carries no usage', () async {
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
                  'message': {'content': 'Hello world!'}
                }
              ],
            },
          ));

      await provider.chat('Hi there');

      expect(reported, hasLength(1));
      expect(reported.single.estimated, isTrue);
      expect(reported.single.promptTokens, estimatePromptTokens(['Hi there']));
      expect(
        reported.single.completionTokens,
        estimateTokenCount('Hello world!'),
      );
    });

    test('chatStream asks for usage and reads it from the final event',
        () async {
      Map<String, dynamic>? sent;
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        sent = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        return Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: FakeStreamBody(Stream.fromIterable([
            utf8.encode('data: {"choices":[{"delta":{"content":"A"}}]}\n'),
            utf8.encode('data: {"choices":[{"delta":{"content":"B"}}]}\n'),
            utf8.encode(
              'data: {"choices":[],"usage":{"prompt_tokens":9,'
              '"completion_tokens":2}}\n',
            ),
            utf8.encode('data: [DONE]\n'),
          ])),
        );
      });

      expect(await provider.chatStream('Hi').toList(), ['A', 'B']);
      expect(sent?['stream_options'], {'include_usage': true});
      expect(reported, [
        const AIUsage(promptTokens: 9, completionTokens: 2),
      ]);
    });

    test('chatStream estimates from the collected text without usage',
        () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: FakeStreamBody(Stream.value(utf8.encode(
              'data: {"choices":[{"delta":{"content":"Hello world"}}]}\n',
            ))),
          ));

      await provider.chatStream('Hi').toList();

      expect(reported, hasLength(1));
      expect(reported.single.estimated, isTrue);
      expect(
        reported.single.completionTokens,
        estimateTokenCount('Hello world'),
      );
    });

    // 个别兼容服务不认 stream_options，直接 400。去掉重试一次，之后不再带。
    test('chatStream retries without stream_options after a 400', () async {
      final sentBodies = <Map<String, dynamic>>[];
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        final body = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        sentBodies.add(body);
        if (body.containsKey('stream_options')) {
          throw DioException.badResponse(
            statusCode: 400,
            requestOptions: RequestOptions(),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 400,
            ),
          );
        }
        return Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: FakeStreamBody(Stream.value(utf8.encode(
            'data: {"choices":[{"delta":{"content":"ok"}}]}\n',
          ))),
        );
      });

      expect(await provider.chatStream('Hi').toList(), ['ok']);
      expect(sentBodies, hasLength(2));
      expect(sentBodies.last.containsKey('stream_options'), isFalse);

      // 第二次直接不带。
      expect(await provider.chatStream('Again').toList(), ['ok']);
      expect(sentBodies, hasLength(3));
      expect(sentBodies.last.containsKey('stream_options'), isFalse);
    });

    test('a failure before any output is not counted', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException.badResponse(
        statusCode: 401,
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      ));

      await expectLater(
        provider.chatStream('Hi').toList(),
        throwsA(isA<DioException>()),
      );
      expect(reported, isEmpty);
    });

    test('listModels reads ids from GET /models', () async {
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(),
                statusCode: 200,
                data: {
                  'data': [
                    {'id': 'gpt-5.6-terra'},
                    {'id': 'gpt-5.6-luna'},
                    {'id': 'gpt-5.6-luna'},
                    {'object': 'model'},
                  ],
                },
              ));

      expect(await provider.listModels(), ['gpt-5.6-luna', 'gpt-5.6-terra']);
      verify(() => mockDio.get('/models', options: any(named: 'options')))
          .called(1);
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
