import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/settings/ai_provider_list.dart';
import 'package:yunchuang/pages/settings/ai_usage_page.dart';
import 'package:yunchuang/providers/ai/ai_usage.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';

void main() {
  Future<({AppDatabase database, ProviderContainer container, int id})> setUp(
    WidgetTester tester, {
    required Widget home,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final id = await database.into(database.aiProviders).insert(
          AiProvidersCompanion.insert(
            name: '我的 DeepSeek',
            type: 'openai',
            baseUrl: 'https://api.deepseek.com',
            modelName: 'deepseek-flash',
            isDefault: const Value(true),
          ),
        );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
    return (database: database, container: container, id: id);
  }

  testWidgets('shows today and total tokens per provider and can reset',
      (tester) async {
    final env = await setUp(tester, home: const AiUsagePage());
    final tracker = env.container.read(aiUsageTrackerProvider);

    expect(find.text('还没有用过'), findsOneWidget);

    tracker.record(
      env.id,
      const AIUsage(promptTokens: 1200, completionTokens: 300),
    );
    tracker.record(
      env.id,
      const AIUsage(promptTokens: 100, completionTokens: 34, estimated: true),
    );
    await tester.pumpAndSettle();

    // 顶部汇总 + 卡片里的今日 / 累计
    expect(find.text('≈ 1.63k'), findsNWidgets(2));
    expect(find.textContaining('输入 1.30k / 输出 334'), findsNWidgets(2));
    expect(find.textContaining('1 次按字数估算'), findsOneWidget);
    expect(find.text('2 次'), findsNWidgets(2));

    await tester.tap(find.byKey(Key('ai-usage-reset-${env.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清零'));
    await tester.pumpAndSettle();

    expect(find.text('还没有用过'), findsOneWidget);
    expect(tracker.usageFor(env.id).isEmpty, isTrue);
  });

  testWidgets('provider list summarises usage and links to the usage page',
      (tester) async {
    final env = await setUp(tester, home: const AiProviderListPage());
    env.container.read(aiUsageTrackerProvider).record(
          env.id,
          const AIUsage(promptTokens: 2000, completionTokens: 500),
        );
    await tester.pumpAndSettle();

    expect(find.textContaining('今日 ≈ 2.50k'), findsOneWidget);
    expect(find.textContaining('累计 ≈ 2.50k'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-provider-usage')));
    await tester.pumpAndSettle();

    expect(find.text('AI 用量'), findsOneWidget);
    expect(find.text('我的 DeepSeek'), findsOneWidget);
  });

  // Provider 删掉，它的用量也跟着清，不然列表里永远留着一个对不上的数。
  testWidgets('deleting a provider forgets its usage', (tester) async {
    final env = await setUp(tester, home: const AiProviderListPage());
    final tracker = env.container.read(aiUsageTrackerProvider);
    tracker.record(
      env.id,
      const AIUsage(promptTokens: 10, completionTokens: 1),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除 我的 DeepSeek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(tracker.all, isEmpty);
  });
}
