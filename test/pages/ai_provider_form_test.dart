import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/ai_dao.dart';
import 'package:yunchuang/pages/settings/ai_provider_form.dart';
import 'package:yunchuang/providers/ai/ai_service.dart';
import 'package:yunchuang/providers/database_provider.dart';

void main() {
  testWidgets('opens provider configuration manual', (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          home: AiProviderFormPage(),
        ),
      ),
    );

    await tester.tap(find.byTooltip('配置手册'));
    await tester.pumpAndSettle();

    expect(find.text('AI Provider 配置手册'), findsOneWidget);
    expect(find.textContaining('API 端点'), findsWidgets);
    expect(find.textContaining('Ollama'), findsWidgets);
    expect(find.textContaining('ollama pull'), findsOneWidget);
    expect(find.textContaining('Dify'), findsWidgets);
  });

  testWidgets('shows provider-specific troubleshooting when test fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(_FailingAIService(database)),
        ],
        child: const MaterialApp(
          home: AiProviderFormPage(),
        ),
      ),
    );

    await tester.tap(find.text('Ollama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '本地 Ollama');
    await tester.enterText(find.byType(TextFormField).at(2), 'qwen2.5');

    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.textContaining('手机不能使用 localhost'), findsOneWidget);
    expect(find.textContaining('局域网 IP'), findsOneWidget);
  });

  testWidgets('dify configuration does not require a model name',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FailingAIService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: AiProviderFormPage(),
        ),
      ),
    );

    await tester.tap(find.text('Dify'));
    await tester.pumpAndSettle();
    expect(find.text('模型名称'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Dify 助手');
    await tester.enterText(find.byType(TextFormField).at(2), 'app-key');
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(service.testedConfigs, hasLength(1));
    expect(service.testedConfigs.single.type, 'dify');
    expect(service.testedConfigs.single.modelName, '');
    expect(find.textContaining('Dify 应用类型'), findsOneWidget);
  });

  testWidgets('dify configuration requires an App API Key', (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FailingAIService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiProviderFormPage()),
      ),
    );

    await tester.tap(find.text('Dify'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Dify 助手');
    await tester.tap(find.text('测试连接'));
    await tester.pump();

    expect(find.text('请输入 Dify App API Key'), findsOneWidget);
    expect(service.testedConfigs, isEmpty);
  });

  testWidgets('preserves separate drafts while switching provider templates',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AiProviderFormPage()),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://openai-compatible.test/v1',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'openai-key');
    await tester.enterText(find.byType(TextFormField).at(3), 'openai-model');

    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(2)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('显示 API 密钥'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(2)).obscureText,
      isFalse,
    );

    await tester.tap(find.text('Dify'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('显示 API 密钥'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(2)).obscureText,
      isTrue,
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://dify.test/v1',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'dify-key');

    await tester.tap(find.text('Ollama'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'http://192.168.1.8:11434',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'qwen2.5');

    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    final openAiFields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(openAiFields.at(1)).controller!.text,
      'https://openai-compatible.test/v1',
    );
    expect(
      tester.widget<TextFormField>(openAiFields.at(2)).controller!.text,
      'openai-key',
    );
    expect(
      tester.widget<TextFormField>(openAiFields.at(3)).controller!.text,
      'openai-model',
    );

    await tester.tap(find.text('Dify'));
    await tester.pumpAndSettle();
    final difyFields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(difyFields.at(1)).controller!.text,
      'https://dify.test/v1',
    );
    expect(
      tester.widget<TextFormField>(difyFields.at(2)).controller!.text,
      'dify-key',
    );

    await tester.tap(find.text('Ollama'));
    await tester.pumpAndSettle();
    final ollamaFields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(ollamaFields.at(1)).controller!.text,
      'http://192.168.1.8:11434',
    );
    expect(
      tester.widget<TextFormField>(ollamaFields.at(2)).controller!.text,
      'qwen2.5',
    );
  });

  testWidgets('shows an actionable authentication error from the provider',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(_AuthFailingAIService(database)),
        ],
        child: const MaterialApp(home: AiProviderFormPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'OpenAI 测试');
    await tester.enterText(find.byType(TextFormField).at(3), 'gpt-4o-mini');
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.textContaining('认证失败'), findsOneWidget);
    expect(find.textContaining('API Key'), findsOneWidget);
  });

  testWidgets('trims saved fields and makes the first provider default',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AiProviderFormPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '  Main AI  ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  https://example.test/v1  ',
    );
    await tester.enterText(find.byType(TextFormField).at(3), '  model-id  ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final saved = await AiDao(database).getAllProviders();
    expect(saved.single.name, 'Main AI');
    expect(saved.single.baseUrl, 'https://example.test/v1');
    expect(saved.single.modelName, 'model-id');
    expect(saved.single.isDefault, isTrue);
  });

  testWidgets('rejects an endpoint without an HTTP scheme', (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FailingAIService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiProviderFormPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Invalid URL');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'api.example.test');
    await tester.enterText(find.byType(TextFormField).at(3), 'model-id');
    await tester.tap(find.text('测试连接'));
    await tester.pump();

    expect(find.text('请输入有效的 HTTP(S) 端点'), findsOneWidget);
    expect(service.testedConfigs, isEmpty);
  });

  testWidgets('keeps the form open and reports provider save failures',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(_SaveFailingAIService(database)),
        ],
        child: const MaterialApp(home: AiProviderFormPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '保存失败测试');
    await tester.enterText(find.byType(TextFormField).at(3), 'model-id');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(AiProviderFormPage), findsOneWidget);
    expect(
      find.text('保存失败：Bad state: database unavailable'),
      findsOneWidget,
    );
  });
}

class _FailingAIService extends AIService {
  final testedConfigs = <AiProvider>[];

  _FailingAIService(AppDatabase database) : super(AiDao(database));

  @override
  Future<bool> testProvider(AiProvider config) async {
    testedConfigs.add(config);
    return false;
  }
}

class _AuthFailingAIService extends AIService {
  _AuthFailingAIService(AppDatabase database) : super(AiDao(database));

  @override
  Future<bool> testProvider(AiProvider config) {
    final request = RequestOptions(path: '/chat/completions');
    throw DioException(
      requestOptions: request,
      response: Response<void>(requestOptions: request, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
  }
}

class _SaveFailingAIService extends AIService {
  _SaveFailingAIService(AppDatabase database) : super(AiDao(database));

  @override
  Future<int> saveProvider(
    AiProvidersCompanion provider, {
    int? providerId,
    bool makeDefault = false,
  }) {
    throw StateError('database unavailable');
  }
}
