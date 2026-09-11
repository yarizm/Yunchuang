import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/providers/ai/ai_http.dart';
import 'package:yunchuang/providers/ai/ai_provider.dart';
import 'package:yunchuang/providers/ai/dify_provider.dart';

class MockDio extends Mock implements Dio {}

class FakeStreamBody {
  const FakeStreamBody(this.stream);

  final Stream<List<int>> stream;
}

void main() {
  group('DifyProvider', () {
    late MockDio mockDio;
    late DifyProvider provider;

    setUp(() {
      mockDio = MockDio();
      provider = DifyProvider(
        baseUrl: 'https://dify.example/v1',
        apiKey: 'app-key',
        dio: mockDio,
      );
    });

    test('chat includes history in query so agent context reaches Dify',
        () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {'answer': 'ok'},
          ));

      final result = await provider.chat(
        '请继续回答',
        history: const [
          ChatMessage(role: 'system', content: '你必须只输出 JSON。'),
          ChatMessage(role: 'assistant', content: '{"action":"tool"}'),
          ChatMessage(role: 'user', content: '工具返回：片段内容'),
        ],
      );

      expect(result, 'ok');
      final captured = verify(() => mockDio.post(
            '/chat-messages',
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          )).captured.single as Map<String, dynamic>;
      final query = captured['query'] as String;
      expect(query, contains('[System]'));
      expect(query, contains('你必须只输出 JSON。'));
      expect(query, contains('[Assistant]'));
      expect(query, contains('工具返回：片段内容'));
      expect(query, endsWith('请继续回答'));
      expect(captured['response_mode'], 'blocking');
    });

    test('chatStream parses Dify SSE answers without a trailing newline',
        () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: FakeStreamBody(Stream.fromIterable([
              utf8.encode('event: message\ndata: {"answer":"first"}\n'),
              utf8.encode('data:{"answer":"second"}'),
            ])),
          ));

      final chunks = await provider.chatStream('Hi').toList();

      expect(chunks, ['first', 'second']);
    });

    test('chatStream surfaces Dify error events', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: FakeStreamBody(Stream.value(utf8.encode(
              'event: error\ndata: {"event":"error","message":"app unavailable"}\n',
            ))),
          ));

      await expectLater(
        provider.chatStream('Hi').toList(),
        throwsA(
          isA<AIProviderResponseException>().having(
            (error) => error.message,
            'message',
            contains('app unavailable'),
          ),
        ),
      );
    });
  });
}
