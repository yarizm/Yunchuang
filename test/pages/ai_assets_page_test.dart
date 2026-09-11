import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/ai_dao.dart';
import 'package:yunchuang/pages/settings/ai_assets_page.dart';
import 'package:yunchuang/providers/ai/ai_service.dart';
import 'package:yunchuang/providers/database_provider.dart';

void main() {
  testWidgets('skill tab shows action menu and toggles enabled',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final skillId = await database.into(database.aiSkills).insert(
          AiSkillsCompanion.insert(
            name: '搜索助手',
            description: const Value('回答前搜索当前书'),
            contentMarkdown: 'Use search_current_book.',
            allowedToolsJson: const Value('["search_current_book"]'),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AiAssetsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索助手'), findsOneWidget);
    expect(find.byTooltip('更多 Skill 操作'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final skill = await (database.select(database.aiSkills)
          ..where((table) => table.id.equals(skillId)))
        .getSingle();
    expect(skill.enabled, isFalse);

    await tester.tap(find.byTooltip('更多 Skill 操作'));
    await tester.pumpAndSettle();
    expect(find.text('导出 Skill'), findsOneWidget);
    await tester.tap(find.text('删除 Skill'));
    await tester.pumpAndSettle();
    expect(find.text('删除 Skill'), findsOneWidget);
    expect(find.textContaining('不可撤销'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await database.select(database.aiSkills).get(), hasLength(1));

    await tester.tap(find.byTooltip('更多 Skill 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除 Skill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(await database.select(database.aiSkills).get(), isEmpty);
  });

  testWidgets(
      'persona actions have tooltips and deletion requires confirmation',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    await database.into(database.aiPersonas).insert(
          AiPersonasCompanion.insert(
            name: '方源人格',
            type: 'character',
            characterName: const Value('方源'),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AiAssetsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('人格'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('更多人格操作'), findsOneWidget);
    await tester.tap(find.byTooltip('更多人格操作'));
    await tester.pumpAndSettle();
    expect(find.text('导出人格'), findsOneWidget);
    await tester.tap(find.text('删除人格'));
    await tester.pumpAndSettle();
    expect(find.text('删除人格'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(await database.select(database.aiPersonas).get(), isEmpty);
  });

  testWidgets('locks only the skill row whose mutation is still running',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final firstId = await database.into(database.aiSkills).insert(
          AiSkillsCompanion.insert(
            name: '受控 Skill',
            contentMarkdown: '等待更新完成',
          ),
        );
    await database.into(database.aiSkills).insert(
          AiSkillsCompanion.insert(
            name: '仍可操作 Skill',
            contentMarkdown: '保持可用',
          ),
        );
    final service = _BlockingMutationAIService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiAssetsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('仍可操作 Skill'), findsOneWidget);
    expect(find.byType(Switch, skipOffstage: false), findsNWidgets(2));

    final firstCard = find.ancestor(
      of: find.text('受控 Skill'),
      matching: find.byType(Card),
    );
    await tester.tap(find.descendant(
      of: firstCard,
      matching: find.byType(Switch),
    ));
    await tester.pump();

    expect(service.skillUpdateCalls, 1);
    expect(service.skillLoadAttempts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Switch, skipOffstage: false), findsOneWidget);

    service.updateGate.complete();
    await tester.pumpAndSettle();

    expect(service.skillLoadAttempts, 2);
    expect(find.byType(Switch, skipOffstage: false), findsNWidgets(2));
    final first = await (database.select(database.aiSkills)
          ..where((skill) => skill.id.equals(firstId)))
        .getSingle();
    expect(first.enabled, isFalse);
  });

  testWidgets('validates a custom persona before closing the dialog',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AiAssetsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建人格'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pump();

    expect(find.text('请输入人格名称'), findsOneWidget);
    expect(find.text('请输入系统提示词'), findsOneWidget);
    expect(find.text('新建人格'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), '简洁助手');
    await tester.enterText(find.byType(TextFormField).at(1), '回答不超过三句话。');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final personas = await database.select(database.aiPersonas).get();
    expect(personas, hasLength(1));
    expect(personas.single.name, '简洁助手');
    expect(personas.single.systemPrompt, '回答不超过三句话。');
  });

  testWidgets('keeps asset actions visible without overflow on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    await database.into(database.aiSkills).insert(
          AiSkillsCompanion.insert(
            name: '这是一个名称很长但操作区仍然需要完整显示的 Skill',
            description: const Value('用于验证窄屏布局不会挤出边界。'),
            contentMarkdown: '保持移动端操作可用。',
          ),
        );
    await database.into(database.aiPersonas).insert(
          AiPersonasCompanion.insert(
            name: '这是一个名称很长的自定义人格',
            type: 'custom',
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AiAssetsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byTooltip('更多 Skill 操作'), findsOneWidget);

    await tester.tap(find.text('人格'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('更多人格操作'), findsOneWidget);
  });

  testWidgets('shows retryable errors instead of empty AI asset lists',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FailingAIService(database, failLoads: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiAssetsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Skill 加载失败'), findsOneWidget);
    expect(find.text('暂无 Skill'), findsNothing);
    expect(find.byTooltip('重试加载'), findsOneWidget);

    await tester.tap(find.byTooltip('重试加载'));
    await tester.pumpAndSettle();
    expect(service.skillLoadAttempts, greaterThanOrEqualTo(2));
    expect(find.text('Skill 加载失败'), findsOneWidget);

    await tester.tap(find.text('人格'));
    await tester.pumpAndSettle();

    expect(find.text('人格加载失败'), findsOneWidget);
    expect(find.text('暂无人格'), findsNothing);
    expect(find.byTooltip('重试加载'), findsOneWidget);
  });

  testWidgets('reports AI asset mutation failures without changing records',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    await database.into(database.aiSkills).insert(
          AiSkillsCompanion.insert(
            name: '不可修改 Skill',
            contentMarkdown: '保持不变',
          ),
        );
    await database.into(database.aiPersonas).insert(
          AiPersonasCompanion.insert(
            name: '不可删除人格',
            type: 'custom',
          ),
        );
    final service = _FailingAIService(database, failMutations: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: AiAssetsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('更新 Skill 状态失败'), findsOneWidget);
    expect((await database.select(database.aiSkills).get()).single.enabled,
        isTrue);

    ScaffoldMessenger.of(tester.element(find.byType(AiAssetsPage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多 Skill 操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除 Skill'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('删除 Skill 失败'), findsOneWidget);
    expect(await database.select(database.aiSkills).get(), hasLength(1));

    ScaffoldMessenger.of(tester.element(find.byType(AiAssetsPage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多人格操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('删除人格失败'), findsOneWidget);
    expect(await database.select(database.aiPersonas).get(), hasLength(1));
  });
}

class _FailingAIService extends AIService {
  final bool failLoads;
  final bool failMutations;
  int skillLoadAttempts = 0;

  _FailingAIService(
    AppDatabase database, {
    this.failLoads = false,
    this.failMutations = false,
  }) : super(AiDao(database));

  @override
  Future<List<AiSkill>> getSkills() async {
    skillLoadAttempts++;
    if (failLoads) throw StateError('skill storage unavailable');
    return super.getSkills();
  }

  @override
  Future<List<AiPersona>> getPersonas({int? bookId}) async {
    if (failLoads) throw StateError('persona storage unavailable');
    return super.getPersonas(bookId: bookId);
  }

  @override
  Future<void> setSkillEnabled(int id, bool enabled) async {
    if (failMutations) throw StateError('skill update unavailable');
    return super.setSkillEnabled(id, enabled);
  }

  @override
  Future<void> deleteSkill(int id) async {
    if (failMutations) throw StateError('skill deletion unavailable');
    return super.deleteSkill(id);
  }

  @override
  Future<void> deletePersona(int id) async {
    if (failMutations) throw StateError('persona deletion unavailable');
    return super.deletePersona(id);
  }
}

class _BlockingMutationAIService extends AIService {
  final updateGate = Completer<void>();
  int skillLoadAttempts = 0;
  int skillUpdateCalls = 0;

  _BlockingMutationAIService(AppDatabase database) : super(AiDao(database));

  @override
  Future<List<AiSkill>> getSkills() {
    skillLoadAttempts++;
    return super.getSkills();
  }

  @override
  Future<void> setSkillEnabled(int id, bool enabled) async {
    skillUpdateCalls++;
    await updateGate.future;
    await super.setSkillEnabled(id, enabled);
  }
}
