import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/providers/ai/ai_provider.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/services/translation_service.dart';
import 'package:yunchuang/widgets/translation_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows a generated translation and provider attribution',
      (tester) async {
    final provider = _TranslationProvider();
    final service = TranslationService.withProviderLoader(
      () async => provider,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TranslationSheet.show(
                context,
                service: service,
                text: '你好，世界。',
                targetLanguage: '英语',
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('翻译为英语'), findsOneWidget);
    expect(find.text('原文 · 6 字符'), findsOneWidget);
    expect(find.text('Hello, world.'), findsOneWidget);
    expect(find.text('由 Test Provider 生成'), findsOneWidget);
    expect(find.byKey(const Key('copy-translation')), findsOneWidget);
  });

  testWidgets('没配 Provider 时给出「去配置」入口，而不只是重试', (tester) async {
    var loads = 0;
    final provider = _TranslationProvider();
    // 第一次没有 Provider；从设置页回来之后就有了。
    final service = TranslationService.withProviderLoader(
      () async => ++loads == 1 ? null : provider,
    );

    // 「去配置」推的是 Provider 列表页，它要读库；GlassPageRoute 给它铺的
    // 背景要读偏好。
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TranslationSheet.show(
                  context,
                  service: service,
                  text: '你好，世界。',
                  targetLanguage: '英语',
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('请先在设置中配置并启用默认 AI Provider。'), findsOneWidget);
    expect(find.byKey(const Key('translation-configure-provider')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('translation-configure-provider')));
    await tester.pumpAndSettle();
    expect(find.text('AI Provider'), findsOneWidget);

    // 配完回来自动重试，不用再点一次。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Hello, world.'), findsOneWidget);
    expect(find.byKey(const Key('translation-configure-provider')),
        findsNothing);
  });
}

class _TranslationProvider implements AIProvider {
  @override
  String get name => 'Test Provider';

  @override
  String get type => 'test';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async {
    return 'Hello, world.';
  }

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) {
    return const Stream.empty();
  }

  @override
  Future<String> complete(String prompt) async => 'Hello, world.';

  @override
  Future<bool> testConnection() async => true;
}
