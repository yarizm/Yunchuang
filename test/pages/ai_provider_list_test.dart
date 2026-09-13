import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/ai_dao.dart';
import 'package:yunchuang/pages/settings/ai_provider_list.dart';
import 'package:yunchuang/providers/ai/ai_service.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('retries provider loading after an error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _RetryingProviderService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiProviderListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(
        find.textContaining('provider database unavailable'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(service.loadCount, 2);
    expect(find.text('还没有配置 AI Provider'), findsOneWidget);
  });

  testWidgets('reports a delete failure and keeps the provider actionable',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _DeletingProviderService(database, shouldFail: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiProviderListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除 Test Provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(service.deletedIds, [1]);
    expect(find.textContaining('删除失败'), findsOneWidget);
    expect(find.byTooltip('删除 Test Provider'), findsOneWidget);
  });

  testWidgets('disables repeated deletion while the request is pending',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _PendingDeleteProviderService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiProviderListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除 Test Provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pump();

    expect(service.deletedIds, [1]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final deleteButton = find.ancestor(
      of: find.byTooltip('删除 Test Provider'),
      matching: find.byType(IconButton),
    );
    expect(
      tester.widget<IconButton>(deleteButton).onPressed,
      isNull,
    );

    service.completeDelete();
    await tester.pumpAndSettle();
    expect(service.deletedIds, [1]);
  });
}

AiProvider _provider() => const AiProvider(
      id: 1,
      name: 'Test Provider',
      type: 'openai',
      baseUrl: 'https://example.test/v1',
      apiKey: null,
      modelName: 'test-model',
      isDefault: true,
      extraConfig: null,
    );

class _RetryingProviderService extends AIService {
  int loadCount = 0;

  _RetryingProviderService(AppDatabase database) : super(AiDao(database));

  @override
  Future<List<AiProvider>> getProviders() async {
    loadCount += 1;
    if (loadCount == 1) {
      throw StateError('provider database unavailable');
    }
    return const [];
  }
}

class _DeletingProviderService extends AIService {
  final bool shouldFail;
  final List<int> deletedIds = [];

  _DeletingProviderService(
    AppDatabase database, {
    required this.shouldFail,
  }) : super(AiDao(database));

  @override
  Future<List<AiProvider>> getProviders() async => [_provider()];

  @override
  Future<void> deleteProvider(int providerId) async {
    deletedIds.add(providerId);
    if (shouldFail) throw StateError('delete unavailable');
  }
}

class _PendingDeleteProviderService extends _DeletingProviderService {
  final Completer<void> _deleteCompleter = Completer<void>();

  _PendingDeleteProviderService(super.database) : super(shouldFail: false);

  @override
  Future<void> deleteProvider(int providerId) {
    deletedIds.add(providerId);
    return _deleteCompleter.future;
  }

  void completeDelete() => _deleteCompleter.complete();
}
