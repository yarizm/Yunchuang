import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/ai_dao.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/providers/ai/agent_models.dart';
import 'package:yunchuang/providers/ai/ai_asset_service.dart';
import 'package:yunchuang/providers/ai/ai_persona_selection_store.dart';
import 'package:yunchuang/providers/ai/ai_provider.dart';
import 'package:yunchuang/providers/ai/ai_service.dart';
import 'package:yunchuang/providers/ai/character_persona_checkpoint_store.dart';
import 'package:yunchuang/providers/ai/spoiler_protection_provider.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/widgets/ai_chat/ai_markdown_style.dart';
import 'package:yunchuang/widgets/ai_chat_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('AI Markdown uses explicit high-contrast theme colors', () {
    for (final theme in [
      AppTheme.lightTheme,
      AppTheme.sepiaTheme,
      AppTheme.darkTheme,
    ]) {
      final scheme = theme.colorScheme;
      final styles = aiMarkdownStyleSheet(theme);

      expect(styles.p?.color, scheme.onSurface);
      expect(styles.a?.color, scheme.primary);
      expect(styles.code?.color, scheme.onSurface);
      expect(styles.code?.backgroundColor, scheme.surfaceContainerHigh);
      expect(styles.blockquote?.color, scheme.onSurfaceVariant);
      expect(
        (styles.blockquoteDecoration as BoxDecoration).color,
        scheme.surfaceContainerHigh,
      );
      expect(
        (styles.codeblockDecoration as BoxDecoration).color,
        scheme.surfaceContainerHigh,
      );
    }
  });

  testWidgets('without a provider the empty state leads to settings',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    var conversationsCreated = 0;
    final service = _FakeAIService(
      database,
      // 这条用例里不该有任何请求发出去；用不带流的 provider，省得 teardown
      // 等一个永远没人监听的 StreamController.close()。
      _ImmediateProvider(),
      hasProvider: false,
      conversationCreator: (_, __) async => ++conversationsCreated,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有配置 AI 服务'), findsOneWidget);
    expect(find.text('开始对话'), findsNothing);

    // 硬发也发不出去：不建会话、不落任何消息，只提示并给出入口。
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('还没有配置 AI 服务，无法发送。'), findsOneWidget);
    expect(conversationsCreated, 0);
    expect(service.appendedRoles, isEmpty);
    expect(find.text('hello'), findsOneWidget); // 输入框里的内容没被清掉

    await tester.tap(find.byKey(const Key('ai-chat-configure-provider')));
    await tester.pumpAndSettle();
    expect(find.text('AI Provider'), findsOneWidget);

    // 在设置页配好了再回来，空状态要切回正常的「开始对话」。
    service.hasProvider = true;
    // 设置页的返回键是自定义的 IconButton，pageBack 认不出来。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('还没有配置 AI 服务'), findsNothing);
    expect(find.text('开始对话'), findsOneWidget);
  });

  testWidgets('ignores streaming chunks after panel disposal', (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ControlledProvider();
    addTearDown(provider.close);
    final service = _FakeAIService(database, provider);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: 'hello'),
          ),
        ),
      ),
    );
    await tester.pump();
    await provider.listened.future.timeout(const Duration(seconds: 1));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    provider.emit('late chunk');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(service.appendedRoles, ['user']);
  });

  testWidgets('blocks sending until the initial conversation is loaded',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final conversations = Completer<List<AiConversation>>();
    final now = DateTime(2026, 1, 1);
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      messages: [
        AiMessage(
          id: 1,
          conversationId: 7,
          role: 'assistant',
          content: '已经载入的历史消息',
          createdAt: now,
        ),
      ],
      conversationsLoader: (_) => conversations.future,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.send),
          )
          .onPressed,
      isNull,
    );
    expect(service.appendedRoles, isEmpty);

    conversations.complete([
      AiConversation(
        id: 7,
        bookId: null,
        title: '已有会话',
        createdAt: now,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('已经载入的历史消息'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

    await tester.enterText(find.byType(TextField), '载入后发送');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(service.appendedRoles, ['user', 'assistant']);
  });

  testWidgets('shows a retry state when conversation initialization fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    var loadAttempts = 0;
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversationsLoader: (_) async {
        loadAttempts++;
        if (loadAttempts == 1) {
          throw StateError('conversation storage unavailable');
        }
        return const [];
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('无法加载 AI 会话'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重试'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(loadAttempts, 2);
    expect(find.text('开始对话'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('reports refresh errors when opening AI management sheets',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    var conversationLoads = 0;
    var personaLoads = 0;
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversationsLoader: (_) async {
        conversationLoads++;
        if (conversationLoads > 1) {
          throw StateError('conversation refresh unavailable');
        }
        return const [];
      },
      personasLoader: (_) async {
        personaLoads++;
        if (personaLoads > 1) {
          throw StateError('persona refresh unavailable');
        }
        return const [];
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('加载会话列表失败'), findsOneWidget);
    expect(find.text('开始对话'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(AiChatPanel)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('加载人格列表失败'), findsOneWidget);
    expect(find.text('开始对话'), findsOneWidget);
  });

  testWidgets('keeps a newly created conversation active after refresh fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    var conversationLoads = 0;
    var conversationCreates = 0;
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversationsLoader: (_) async {
        conversationLoads++;
        if (conversationLoads > 2) {
          throw StateError('conversation refresh unavailable');
        }
        return const [];
      },
      conversationCreator: (title, bookId) async {
        conversationCreates++;
        return 9;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新会话'));
    await tester.pumpAndSettle();

    expect(conversationCreates, 1);
    expect(find.textContaining('新会话已创建，但刷新列表失败'), findsOneWidget);
    expect(find.text('开始对话'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(AiChatPanel)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '写入新会话');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(conversationCreates, 1);
    expect(service.appendedConversationIds, [9, 9]);
    expect(service.appendedRoles, ['user', 'assistant']);
  });

  testWidgets('stop button cancels streaming and keeps the partial answer',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ControlledProvider();
    addTearDown(provider.close);
    final service = _FakeAIService(database, provider);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: 'hello'),
          ),
        ),
      ),
    );
    await tester.pump();
    await provider.listened.future.timeout(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byTooltip('停止生成'), findsOneWidget);

    provider.emit('部分');
    await tester.pump(const Duration(milliseconds: 10));
    provider.emit('回答');
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.textContaining('部分回答'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('部分回答'), findsOneWidget);

    await tester.tap(find.byTooltip('停止生成'));
    await provider.cancelled.future.timeout(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('已停止生成', findRichText: true),
      findsOneWidget,
    );
    expect(find.byTooltip('发送'), findsOneWidget);
    expect(service.appendedRoles, ['user']);
  });

  testWidgets('keeps a typed draft when send is pressed during generation',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ControlledProvider();
    addTearDown(provider.close);
    final service = _FakeAIService(database, provider);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: '第一条问题'),
          ),
        ),
      ),
    );
    await tester.pump();
    await provider.listened.future.timeout(const Duration(seconds: 1));
    await tester.pump();

    final input = find.byType(TextField);
    await tester.enterText(input, '生成结束后要发送的问题');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(tester.widget<TextField>(input).controller!.text, '生成结束后要发送的问题');
    expect(find.text('生成结束后要发送的问题'), findsOneWidget);
    expect(service.appendedRoles, ['user']);

    await tester.tap(find.byTooltip('停止生成'));
    await provider.cancelled.future.timeout(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(input).controller!.text, '生成结束后要发送的问题');
  });

  testWidgets('failed requests can retry without duplicating the user message',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _RetryProvider();
    final service = _FakeAIService(database, provider);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: '重试这个问题'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('请求失败'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);
    expect(service.appendedRoles, ['user']);

    await tester.tap(find.widgetWithText(TextButton, '重试'));
    await tester.pumpAndSettle();

    expect(find.text('重试成功'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重试'), findsNothing);
    expect(provider.calls, 2);
    expect(service.appendedRoles, ['user', 'assistant']);
  });

  testWidgets('keeps a generated answer when assistant persistence fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      assistantSaveFailures: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: '保留这个回答'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已收到。'), findsOneWidget);
    expect(find.textContaining('请求失败'), findsNothing);
    expect(find.text('回答未保存'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重新保存'), findsOneWidget);
    expect(service.appendedRoles, ['user']);

    await tester.tap(find.widgetWithText(TextButton, '重新保存'));
    await tester.pumpAndSettle();

    expect(find.text('已收到。'), findsOneWidget);
    expect(find.text('回答未保存'), findsNothing);
    expect(find.widgetWithText(TextButton, '重新保存'), findsNothing);
    expect(find.text('回答已保存'), findsOneWidget);
    expect(service.appendedRoles, ['user', 'assistant']);
  });

  testWidgets('auto-saves an older answer before sending a follow-up',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ImmediateProvider();
    final service = _FakeAIService(
      database,
      provider,
      assistantSaveFailures: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: '第一轮问题'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('回答未保存'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '继续追问');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(provider.calls, 2);
    expect(service.appendedRoles, ['user', 'assistant', 'user', 'assistant']);
    expect(find.text('回答未保存'), findsNothing);
    expect(find.text('未保存的回答已自动补存'), findsOneWidget);
  });

  testWidgets('keeps follow-up text when automatic answer saving still fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ImmediateProvider();
    final service = _FakeAIService(
      database,
      provider,
      assistantSaveFailures: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: '第一轮问题'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '不能丢失的追问');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(provider.calls, 1);
    expect(service.appendedRoles, ['user']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '不能丢失的追问',
    );
    expect(find.text('回答未保存'), findsOneWidget);
    expect(find.textContaining('保存仍然失败'), findsOneWidget);
  });

  testWidgets('auto-saves an unsaved answer before switching conversations',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversations: [
        AiConversation(id: 1, bookId: null, title: '当前会话', createdAt: now),
        AiConversation(id: 2, bookId: null, title: '目标会话', createdAt: now),
      ],
      messageLoader: (conversationId) async => conversationId == 2
          ? [
              AiMessage(
                id: 2,
                conversationId: 2,
                role: 'assistant',
                content: '目标会话内容',
                metadataJson: null,
                createdAt: now,
              ),
            ]
          : const [],
      assistantSaveFailures: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: '切换前保存'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('回答未保存'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(AiChatPanel)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('目标会话'));
    await tester.pumpAndSettle();

    expect(service.appendedRoles, ['user', 'assistant']);
    expect(service.appendedConversationIds, [1, 1]);
    expect(find.text('目标会话内容'), findsOneWidget);
    expect(find.text('回答未保存'), findsNothing);
  });

  testWidgets('keeps the current conversation when answer saving still fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    var conversationCreates = 0;
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversations: [
        AiConversation(id: 1, bookId: null, title: '当前会话', createdAt: now),
      ],
      conversationCreator: (title, bookId) async {
        conversationCreates++;
        return 2;
      },
      assistantSaveFailures: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(initialPrompt: '不能丢失的回答'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('回答未保存'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(AiChatPanel)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新会话'));
    await tester.pumpAndSettle();

    expect(conversationCreates, 0);
    expect(service.appendedRoles, ['user']);
    expect(find.text('已收到。'), findsOneWidget);
    expect(find.text('回答未保存'), findsOneWidget);
    expect(find.textContaining('保存仍然失败'), findsOneWidget);
  });

  testWidgets('shows long AI attachments collapsed until tapped',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FakeAIService(database, _ImmediateProvider());
    const longText = '很长正文内容，默认不应该直接铺满聊天框。'
        '很长正文内容，默认不应该直接铺满聊天框。'
        '很长正文内容，默认不应该直接铺满聊天框。';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              initialDraft: AiPromptDraft(
                instruction: '分析本章内容',
                attachments: [
                  AiAttachment(
                    id: 'chapter',
                    title: '本章内容',
                    content: longText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分析本章内容'), findsOneWidget);
    expect(find.textContaining('本章内容 · 约'), findsOneWidget);
    expect(find.textContaining('默认不应该直接铺满'), findsNothing);

    await tester.tap(find.textContaining('本章内容 · 约'));
    await tester.pumpAndSettle();

    final expandedText = tester.widget<Text>(find.text(longText));
    expect(expandedText.maxLines, isNull);
    expect(expandedText.overflow, isNull);
  });

  testWidgets('opens very large attachments in a lazily chunked viewer',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FakeAIService(database, _ImmediateProvider());
    final veryLongText = List.generate(
      1800,
      (index) => '第 $index 段正文用于验证移动端附件查看不会一次布局整章。',
    ).join('\n');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              initialDraft: AiPromptDraft(
                instruction: '分析超长章节',
                attachments: [
                  AiAttachment(
                    id: 'very-long-chapter',
                    title: '超长章节',
                    content: veryLongText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(veryLongText), findsNothing);
    final userMessageIndex = service.appendedRoles.indexOf('user');
    final metadataJson = service.appendedMetadataJson[userMessageIndex]!;
    final storedAttachment = ((jsonDecode(metadataJson)
            as Map<String, dynamic>)['attachments'] as List)
        .single as Map<String, dynamic>;
    expect(storedAttachment['content'], isNull);
    expect(storedAttachment['contentEncoding'], 'gzip+base64');
    expect(storedAttachment['contentLength'], veryLongText.length);
    expect(
      AiPromptDraft.attachmentsFromMetadata(metadataJson).single.content,
      veryLongText,
    );
    await tester.tap(find.textContaining('超长章节 · 约'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_attachment_viewer')), findsOneWidget);
    expect(find.byTooltip('关闭附件'), findsOneWidget);
    final firstChunk = tester.widget<SelectableText>(
      find.byKey(const ValueKey('ai_attachment_chunk_0')),
    );
    expect(firstChunk.data, isNotEmpty);
    expect(firstChunk.data!.length, lessThanOrEqualTo(3000));
    expect(firstChunk.data!.length, lessThan(veryLongText.length));
    expect(find.text(veryLongText), findsNothing);

    await tester.tap(find.byTooltip('关闭附件'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai_attachment_viewer')), findsNothing);
  });

  testWidgets('renders tool source references from agent results',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'test.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final chapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源第一次出现。方源正在观察局势。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final service = _FakeAIService(
      database,
      _ScriptedProvider([
        '{"action":"tool","tool":"search_current_book","args":{"query":"方源"}}',
        '{"action":"final","answer":"方源是片段中的关键人物。"}',
      ]),
    );
    AiSourceReference? openedReference;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              initialPrompt: '方源是谁？',
              agentContext: AgentContext(
                bookId: bookId,
                bookTitle: '测试书',
                currentChapterId: chapterId,
                currentPosition: 1,
              ),
              onOpenReference: (value) => openedReference = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('引用来源'), findsOneWidget);
    expect(find.text('第一章'), findsOneWidget);
    expect(find.textContaining('方源第一次出现'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.text('第一章'));
    await tester.pump();

    expect(openedReference?.chapterId, chapterId);
    expect(openedReference?.query, '方源');
    expect(openedReference?.chapterPosition, 0.0);
  });

  testWidgets('ask mode grants unread access only for the current request',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '防剧透测试书',
            filePath: 'spoiler-test.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final currentChapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '当前章节',
            content: const Value('当前只知道这些信息。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '未来章节',
            content: const Value('结局线索在未来章节。'),
            contentIndex: 1,
            sortOrder: 1,
          ),
        );
    final scriptedProvider = _ScriptedProvider([
      '{"action":"tool","tool":"search_current_book",'
          '"args":{"query":"结局线索","scope":"full"}}',
      '{"action":"tool","tool":"search_current_book",'
          '"args":{"query":"结局线索","scope":"full"}}',
      '{"action":"final","answer":"以下回答包含未读内容：结局线索已找到。"}',
    ]);
    final service = _FakeAIService(database, scriptedProvider);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              initialPrompt: '告诉我结局',
              agentContext: AgentContext(
                bookId: bookId,
                bookTitle: '防剧透测试书',
                currentChapterId: currentChapterId,
                currentPosition: 1,
                spoilerProtectionLevel: SpoilerProtectionLevel.ask,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('可能包含剧透'), findsOneWidget);
    expect(find.text('本次允许'), findsOneWidget);

    await tester.tap(find.text('本次允许'));
    await tester.pumpAndSettle();

    expect(find.textContaining('以下回答包含未读内容'), findsOneWidget);
    expect(find.text('未来章节'), findsOneWidget);
    expect(find.textContaining('未读正文'), findsOneWidget);
    expect(service.appendedRoles, ['user', 'assistant']);
    expect(scriptedProvider.histories, hasLength(3));
    expect(
      scriptedProvider.histories[1]!.first.content,
      contains('已经临时授权本次问题访问未读内容'),
    );
  });

  testWidgets('ask mode keeps the read boundary when permission is denied',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '拒绝授权测试书',
            filePath: 'deny-spoiler.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final currentChapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '当前章节',
            content: const Value('当前内容。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '未来章节',
            content: const Value('未来秘密。'),
            contentIndex: 1,
            sortOrder: 1,
          ),
        );
    final scriptedProvider = _ScriptedProvider([
      '{"action":"tool","tool":"search_current_book",'
          '"args":{"query":"未来秘密","scope":"full"}}',
      '{"action":"final","answer":"未获授权，只能依据已读内容回答。"}',
    ]);
    final service = _FakeAIService(database, scriptedProvider);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              initialPrompt: '告诉我未来秘密',
              agentContext: AgentContext(
                bookId: bookId,
                currentChapterId: currentChapterId,
                currentPosition: 1,
                spoilerProtectionLevel: SpoilerProtectionLevel.ask,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('仅使用已读内容'));
    await tester.pumpAndSettle();

    expect(find.textContaining('未获授权'), findsOneWidget);
    expect(find.text('未来章节'), findsNothing);
    expect(service.appendedRoles, ['user', 'assistant']);
    expect(scriptedProvider.histories, hasLength(2));
  });

  testWidgets('book chat can override the global spoiler setting',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FakeAIService(database, _ImmediateProvider());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 17),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('防剧透：严格防剧透'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('允许全书'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('防剧透：允许全书'), findsOneWidget);
    expect(
      preferences.getString(SpoilerProtectionNotifier.bookOverridesKey),
      contains('"17":"fullBook"'),
    );
  });

  testWidgets('restores persisted tool activity and references after reopen',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'test.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final chapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '证据章节',
            content: const Value('此前还有一段铺垫。方源在这里留下了可供引用的证据。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final firstService = _FakeAIService(
      database,
      _ScriptedProvider([
        '{"action":"tool","tool":"search_current_book","args":{"query":"方源"}}',
        '{"action":"final","answer":"这是基于正文证据的回答。"}',
      ]),
    );

    AiSourceReference? openedReference;

    Widget panelFor(AIService service) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              initialPrompt: identical(service, firstService) ? '方源是谁？' : null,
              agentContext: AgentContext(
                bookId: bookId,
                bookTitle: '测试书',
                currentChapterId: chapterId,
                currentPosition: 1,
              ),
              onOpenReference: (value) => openedReference = value,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(panelFor(firstService));
    await tester.pumpAndSettle();

    final assistantIndex = firstService.appendedRoles.indexOf('assistant');
    expect(assistantIndex, greaterThanOrEqualTo(0));
    final persistedMetadata = firstService.appendedMetadataJson[assistantIndex];
    expect(persistedMetadata, isNotNull);
    expect(persistedMetadata, contains('toolEvents'));
    expect(persistedMetadata, contains('references'));

    final now = DateTime(2026, 1, 1);
    final reopenedService = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversations: [
        AiConversation(
          id: 1,
          bookId: bookId,
          title: '旧会话',
          createdAt: now,
        ),
      ],
      messages: [
        AiMessage(
          id: 1,
          conversationId: 1,
          role: 'assistant',
          content: firstService.appendedContents[assistantIndex],
          metadataJson: persistedMetadata,
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(panelFor(reopenedService));
    await tester.pumpAndSettle();

    expect(find.text('这是基于正文证据的回答。'), findsOneWidget);
    expect(find.text('引用来源'), findsOneWidget);
    expect(find.text('证据章节'), findsOneWidget);
    expect(find.textContaining('方源在这里留下'), findsOneWidget);
    expect(find.text('正在搜索当前书...'), findsOneWidget);

    await tester.tap(find.text('证据章节'));
    await tester.pump();

    expect(openedReference?.query, '方源');
    expect(openedReference?.chapterPosition, greaterThan(0));
  });

  testWidgets('opens the reader location when tapping a note source',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversations: [
        AiConversation(id: 1, bookId: 7, title: '旧会话', createdAt: now),
      ],
      messages: [
        AiMessage(
          id: 1,
          conversationId: 1,
          role: 'assistant',
          content: '根据笔记回答。',
          metadataJson: jsonEncode({
            'references': [
              const AiSourceReference(
                type: 'note',
                title: '笔记 #3',
                snippet: '这是一条来自章节的笔记。',
                chapterId: 9,
                noteId: 3,
              ).toJson(),
            ],
          }),
          createdAt: now,
        ),
      ],
    );
    AiSourceReference? openedReference;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: const AgentContext(bookId: 7),
              onOpenReference: (value) => openedReference = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('笔记 #3'));
    await tester.pump();

    expect(openedReference?.type, 'note');
    expect(openedReference?.chapterId, 9);
    expect(openedReference?.noteId, 3);
  });

  testWidgets('replays collapsed attachment content in follow-up history',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    const attachmentText = '这是重开会话后仍需要提供给模型的章节正文附件。';
    final now = DateTime(2026, 1, 1);
    final provider = _ScriptedProvider([
      '{"action":"final","answer":"继续分析。"}',
    ]);
    final service = _FakeAIService(
      database,
      provider,
      conversations: [
        AiConversation(id: 1, bookId: null, title: '旧会话', createdAt: now),
      ],
      messages: [
        AiMessage(
          id: 1,
          conversationId: 1,
          role: 'user',
          content: '分析本章内容',
          metadataJson: jsonEncode(const AiPromptDraft(
            instruction: '分析本章内容',
            attachments: [
              AiAttachment(
                id: 'chapter',
                title: '本章内容',
                content: attachmentText,
              ),
            ],
          ).toMetadataJson()),
          createdAt: now,
        ),
        AiMessage(
          id: 2,
          conversationId: 1,
          role: 'assistant',
          content: '已有分析。',
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '继续');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(provider.histories, isNotEmpty);
    final historyText =
        provider.histories.single!.map((message) => message.content).join('\n');
    expect(historyText, contains('分析本章内容'));
    expect(historyText, contains(attachmentText));
  });

  testWidgets('skips old compressed attachments before history decoding',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    final provider = _ScriptedProvider([
      '{"action":"final","answer":"继续分析。"}',
    ]);
    final oldMetadata = jsonEncode({
      'attachments': [
        {
          'id': 'old-compressed',
          'title': '旧附件',
          'kind': 'text',
          'contentEncoding': 'gzip+base64',
          'contentLength': 50000,
          'contentData': 'not-valid-base64',
        },
      ],
    });
    final recentMetadata = jsonEncode(AiPromptDraft(
      instruction: '分析最近附件',
      attachments: [
        AiAttachment(
          id: 'recent',
          title: '最近附件',
          content: List.filled(13000, '近').join(),
        ),
      ],
    ).toMetadataJson());
    final service = _FakeAIService(
      database,
      provider,
      conversations: [
        AiConversation(id: 1, bookId: null, title: '旧会话', createdAt: now),
      ],
      messages: [
        AiMessage(
          id: 1,
          conversationId: 1,
          role: 'user',
          content: '很早以前的分析',
          metadataJson: oldMetadata,
          createdAt: now,
        ),
        AiMessage(
          id: 2,
          conversationId: 1,
          role: 'assistant',
          content: '旧回答',
          createdAt: now,
        ),
        AiMessage(
          id: 3,
          conversationId: 1,
          role: 'user',
          content: '分析最近附件',
          metadataJson: recentMetadata,
          createdAt: now,
        ),
        AiMessage(
          id: 4,
          conversationId: 1,
          role: 'assistant',
          content: '最近回答',
          createdAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旧附件 · 约 50000 字'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '继续');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('旧附件 · 约 50000 字'), findsOneWidget);
    expect(find.text('旧附件 · 约 0 字'), findsNothing);
  });

  testWidgets('ignores stale messages from an earlier conversation switch',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    final delayedSecond = Completer<List<AiMessage>>();
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversations: [
        AiConversation(id: 1, bookId: null, title: 'First', createdAt: now),
        AiConversation(id: 2, bookId: null, title: 'Second', createdAt: now),
        AiConversation(id: 3, bookId: null, title: 'Third', createdAt: now),
      ],
      messageLoader: (conversationId) {
        if (conversationId == 2) return delayedSecond.future;
        return Future.value([
          AiMessage(
            id: conversationId,
            conversationId: conversationId,
            role: 'assistant',
            content: 'message-$conversationId',
            createdAt: now,
          ),
        ]);
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('会话列表'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Third'));
    await tester.pump();
    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();
    expect(find.text('message-3'), findsOneWidget);

    delayedSecond.complete([
      AiMessage(
        id: 2,
        conversationId: 2,
        role: 'assistant',
        content: 'stale-message-2',
        createdAt: now,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('message-3'), findsOneWidget);
    expect(find.text('stale-message-2'), findsNothing);
  });

  testWidgets('deleting a background conversation keeps the current chat',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    final conversations = <AiConversation>[
      AiConversation(id: 1, bookId: null, title: 'First', createdAt: now),
      AiConversation(id: 2, bookId: null, title: 'Second', createdAt: now),
      AiConversation(id: 3, bookId: null, title: 'Third', createdAt: now),
    ];
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversationsLoader: (_) async => List.of(conversations),
      messageLoader: (conversationId) async => [
        AiMessage(
          id: conversationId,
          conversationId: conversationId,
          role: 'assistant',
          content: 'message-$conversationId',
          createdAt: now,
        ),
      ],
      conversationDeleter: (id) async {
        conversations.removeWhere((conversation) => conversation.id == id);
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();
    expect(find.text('message-3'), findsOneWidget);

    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();
    final secondTile = find.ancestor(
      of: find.text('Second'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: secondTile,
        matching: find.byTooltip('删除会话'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(conversations.map((item) => item.id), [1, 3]);
    expect(find.text('message-3'), findsOneWidget);
    expect(find.text('message-1'), findsNothing);
  });

  testWidgets('clears a deleted current conversation when refresh fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    var conversationLoads = 0;
    var conversationCreates = 0;
    final conversations = <AiConversation>[
      AiConversation(id: 1, bookId: null, title: 'First', createdAt: now),
      AiConversation(id: 2, bookId: null, title: 'Second', createdAt: now),
    ];
    final service = _FakeAIService(
      database,
      _ImmediateProvider(),
      conversationsLoader: (_) async {
        conversationLoads++;
        if (conversationLoads > 2) {
          throw StateError('conversation refresh unavailable');
        }
        return List.of(conversations);
      },
      messageLoader: (conversationId) async => [
        AiMessage(
          id: conversationId,
          conversationId: conversationId,
          role: 'assistant',
          content: 'message-$conversationId',
          createdAt: now,
        ),
      ],
      conversationCreator: (title, bookId) async {
        conversationCreates++;
        return 9;
      },
      conversationDeleter: (id) async {
        conversations.removeWhere((conversation) => conversation.id == id);
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('message-1'), findsOneWidget);

    await tester.tap(find.byTooltip('会话列表'));
    await tester.pumpAndSettle();
    final firstTile = find.ancestor(
      of: find.text('First'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: firstTile,
        matching: find.byTooltip('删除会话'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('会话已删除，但刷新列表失败'), findsOneWidget);
    expect(find.text('message-1'), findsNothing);
    expect(find.text('开始对话'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(AiChatPanel)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '删除后新消息');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(conversationCreates, 1);
    expect(service.appendedConversationIds, [9, 9]);
    expect(service.appendedConversationIds, isNot(contains(1)));
  });

  testWidgets('selected persona is injected into agent system context',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    await database.into(database.aiPersonas).insert(
          AiPersonasCompanion.insert(
            name: '冷静人格',
            type: 'custom',
            systemPrompt: const Value('保持冷静，回答要克制。'),
            documentMarkdown: const Value('# 冷静人格\n\n只给必要结论。'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final provider = _ScriptedProvider([
      '{"action":"final","answer":"已按人格回答。"}',
    ]);
    final service = _FakeAIService(database, provider);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('冷静人格').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '你好');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(provider.histories, isNotEmpty);
    final systemPrompt = provider.histories.single!.first.content;
    expect(systemPrompt, contains('当前人格'));
    expect(systemPrompt, contains('保持冷静，回答要克制。'));
    expect(systemPrompt, contains('只给必要结论'));
  });

  testWidgets('restores the selected persona when the book panel reopens',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 1, 1);
    final personaId = await database.into(database.aiPersonas).insert(
          AiPersonasCompanion.insert(
            name: '持续人格',
            type: 'custom',
            systemPrompt: const Value('始终使用简短回答。'),
            documentMarkdown: const Value('# 持续人格'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final provider = _ScriptedProvider([
      '{"action":"final","answer":"已恢复人格。"}',
    ]);
    final service = _FakeAIService(database, provider);
    final selectionStore = MemoryAiPersonaSelectionStore();

    Widget buildPanel() => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            aiServiceProvider.overrideWithValue(service),
            aiPersonaSelectionStoreProvider.overrideWithValue(selectionStore),
            characterPersonaCheckpointStoreProvider.overrideWithValue(
              _NoopCheckpointStore(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiChatPanel(
                agentContext: AgentContext(bookId: 7, bookTitle: '测试书'),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildPanel());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('持续人格').last);
    await tester.pumpAndSettle();

    expect(selectionStore.read(7), personaId);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildPanel());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '重新打开后继续');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    final systemPrompt = provider.histories.single!.first.content;
    expect(systemPrompt, contains('持续人格'));
    expect(systemPrompt, contains('始终使用简短回答。'));
  });

  testWidgets('clears a saved persona that is no longer available',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FakeAIService(database, _ImmediateProvider());
    final selectionStore = MemoryAiPersonaSelectionStore();
    await selectionStore.write(7, 999);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          aiPersonaSelectionStoreProvider.overrideWithValue(selectionStore),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 7),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(selectionStore.read(7), isNull);
    expect(find.text('开始对话'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('character persona generation requires confirmation',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ScriptedProvider(const []);
    final service = _FakeAIService(database, provider);
    final assetService = _CheckpointAssetService(database, service);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
          aiAssetServiceProvider.overrideWithValue(assetService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 7, bookTitle: '测试书'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从当前书生成角色人格'));
    await tester.pumpAndSettle();

    expect(find.text('输入角色名'), findsOneWidget);
    final characterField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '例如：方源',
    );
    await tester.enterText(characterField, '方源');
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();

    expect(find.text('生成角色人格'), findsOneWidget);
    expect(find.textContaining('2 个片段'), findsOneWidget);
    expect(find.textContaining('1.2 万字正文'), findsOneWidget);
    expect(find.textContaining('额外消耗 token'), findsOneWidget);

    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();

    expect(find.text('输入角色名'), findsNothing);
    expect(provider.completePrompts, isEmpty);
    expect(assetService.calls, 0);
  });

  testWidgets('PDF persona preparation explains local work and can cancel',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FakeAIService(database, _ScriptedProvider(const []));
    final assetService = _CheckpointAssetService(
      database,
      service,
      pendingPreparationPages: 120,
      blockPreparationUntilCancelled: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
          aiAssetServiceProvider.overrideWithValue(assetService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 7, bookTitle: 'PDF 测试书'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从当前书生成角色人格'));
    await tester.pumpAndSettle();
    final characterField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '例如：方源',
    );
    await tester.enterText(characterField, 'Alice');
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();

    expect(find.text('准备 PDF 正文'), findsOneWidget);
    expect(find.textContaining('120 页'), findsOneWidget);
    expect(find.textContaining('不会调用 AI'), findsOneWidget);
    expect(find.textContaining('不消耗 token'), findsOneWidget);
    await tester.tap(find.text('开始准备'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('80/120 页'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();

    expect(assetService.preparationCancelled, isTrue);
    expect(assetService.calls, 0);
    expect(find.text('已取消 PDF 正文准备'), findsOneWidget);
    expect(find.textContaining('额外消耗 token'), findsNothing);
  });

  testWidgets('PDF preparation finishes before the token confirmation',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _FakeAIService(database, _ScriptedProvider(const []));
    final assetService = _CheckpointAssetService(
      database,
      service,
      pendingPreparationPages: 3,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
          aiAssetServiceProvider.overrideWithValue(assetService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 7, bookTitle: 'PDF 测试书'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从当前书生成角色人格'));
    await tester.pumpAndSettle();
    final characterField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '例如：方源',
    );
    await tester.enterText(characterField, 'Alice');
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始准备'));
    await tester.pumpAndSettle();

    expect(find.text('准备 PDF 正文'), findsNothing);
    expect(find.text('生成角色人格'), findsOneWidget);
    expect(find.textContaining('2 个片段'), findsOneWidget);
    expect(find.textContaining('额外消耗 token'), findsOneWidget);
    expect(assetService.calls, 0);

    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
  });

  testWidgets('keeps persona generation successful when list refresh fails',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    var personaLoads = 0;
    final service = _FakeAIService(
      database,
      _ScriptedProvider(const []),
      personasLoader: (_) async {
        personaLoads++;
        if (personaLoads > 2) {
          throw StateError('persona refresh unavailable');
        }
        return const [];
      },
    );
    final assetService = _CheckpointAssetService(
      database,
      service,
      cancelFirstGeneration: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
          aiAssetServiceProvider.overrideWithValue(assetService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 7, bookTitle: '测试书'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从当前书生成角色人格'));
    await tester.pumpAndSettle();
    final characterField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '例如：方源',
    );
    await tester.enterText(characterField, '方源');
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续').last);
    await tester.pumpAndSettle();

    expect(assetService.calls, 1);
    expect(find.textContaining('角色人格已生成，但刷新列表失败'), findsOneWidget);
    expect(find.textContaining('生成失败'), findsNothing);
    expect(find.text('继续'), findsNothing);
  });

  testWidgets('cancelled character generation can resume from its checkpoint',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ScriptedProvider(const []);
    final service = _FakeAIService(database, provider);
    final assetService = _CheckpointAssetService(database, service);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
          aiAssetServiceProvider.overrideWithValue(assetService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 7, bookTitle: '测试书'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从当前书生成角色人格'));
    await tester.pumpAndSettle();
    final characterField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '例如：方源',
    );
    await tester.enterText(characterField, '方源');
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 个片段'), findsOneWidget);
    await tester.tap(find.text('继续').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('可稍后从检查点继续'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(assetService.calls, 1);

    ScaffoldMessenger.of(tester.element(find.byType(AiChatPanel)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    expect(find.text('继续生成“方源”人格'), findsOneWidget);
    await tester.tap(find.text('继续生成“方源”人格'));
    await tester.pumpAndSettle();

    expect(find.text('继续生成角色人格'), findsOneWidget);
    expect(find.textContaining('已完成 1/2 个正文片段'), findsOneWidget);
    await tester.tap(find.text('继续').last);
    await tester.pumpAndSettle();

    expect(assetService.calls, 2);
    expect(assetService.receivedResumeFrom, isNotNull);
    expect(assetService.receivedResumeFrom!.nextEvidenceIndex, 1);
    expect(find.text('角色人格已生成'), findsOneWidget);
  });

  testWidgets('restores and can discard a persisted generation checkpoint',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _ScriptedProvider(const []);
    final service = _FakeAIService(database, provider);
    final assetService = _CheckpointAssetService(
      database,
      service,
      initialCheckpoint: CharacterPersonaGenerationCheckpoint(
        bookId: 7,
        characterName: '白凝冰',
        totalEvidenceTasks: 4,
        nextEvidenceIndex: 2,
        evidence: const ['证据一', '证据二'],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiServiceProvider.overrideWithValue(service),
          characterPersonaCheckpointStoreProvider.overrideWithValue(
            _NoopCheckpointStore(),
          ),
          aiAssetServiceProvider.overrideWithValue(assetService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatPanel(
              agentContext: AgentContext(bookId: 7, bookTitle: '测试书'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    expect(find.text('继续生成“白凝冰”人格'), findsOneWidget);
    expect(find.byTooltip('放弃未完成生成'), findsOneWidget);

    await tester.tap(find.byTooltip('放弃未完成生成'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未完成生成'), findsOneWidget);
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();

    expect(assetService.deletedBookId, 7);
    expect(find.text('已删除未完成的角色人格进度'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(AiChatPanel)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 人格'));
    await tester.pumpAndSettle();
    expect(find.text('继续生成“白凝冰”人格'), findsNothing);
  });
}

class _FakeAIService extends AIService {
  final AIProvider provider;
  final appendedRoles = <String>[];
  final appendedConversationIds = <int>[];
  final appendedContents = <String>[];
  final appendedMetadataJson = <String?>[];
  final List<AiConversation> conversations;
  final List<AiMessage> messages;
  final Future<List<AiConversation>> Function(int? bookId)? conversationsLoader;
  final Future<List<AiPersona>> Function(int? bookId)? personasLoader;
  final Future<List<AiMessage>> Function(int conversationId)? messageLoader;
  final Future<int> Function(String title, int? bookId)? conversationCreator;
  final Future<void> Function(int conversationId)? conversationDeleter;
  int assistantSaveFailures;

  /// false 模拟「一个 Provider 都没配」。
  bool hasProvider;

  _FakeAIService(
    AppDatabase database,
    this.provider, {
    this.conversations = const [],
    this.messages = const [],
    this.conversationsLoader,
    this.personasLoader,
    this.messageLoader,
    this.conversationCreator,
    this.conversationDeleter,
    this.assistantSaveFailures = 0,
    this.hasProvider = true,
  }) : super(AiDao(database));

  @override
  Future<List<AiConversation>> getConversations({int? bookId}) async {
    final loader = conversationsLoader;
    if (loader != null) return loader(bookId);
    return conversations;
  }

  @override
  Future<List<AiPersona>> getPersonas({int? bookId}) async {
    final loader = personasLoader;
    if (loader != null) return loader(bookId);
    return super.getPersonas(bookId: bookId);
  }

  @override
  Future<List<AiMessage>> getMessages(int conversationId) async {
    final loader = messageLoader;
    if (loader != null) return loader(conversationId);
    return messages
        .where((message) => message.conversationId == conversationId)
        .toList();
  }

  @override
  Future<void> deleteConversation(int id) async {
    final deleter = conversationDeleter;
    if (deleter != null) return deleter(id);
    return super.deleteConversation(id);
  }

  @override
  Future<int> createConversation(String title, {int? bookId}) async {
    final creator = conversationCreator;
    if (creator != null) return creator(title, bookId);
    return 1;
  }

  @override
  Future<void> appendMessage(int conversationId, String role, String content,
      {String? metadataJson}) async {
    if (role == 'assistant' && assistantSaveFailures > 0) {
      assistantSaveFailures--;
      throw StateError('assistant persistence unavailable');
    }
    appendedConversationIds.add(conversationId);
    appendedRoles.add(role);
    appendedContents.add(content);
    appendedMetadataJson.add(metadataJson);
  }

  @override
  Future<AIProvider?> getDefaultProvider() async =>
      hasProvider ? provider : null;
}

class _ControlledProvider implements AIProvider {
  late final _controller = StreamController<String>(
    onCancel: () {
      if (!cancelled.isCompleted) cancelled.complete();
    },
  );
  final listened = Completer<void>();
  final cancelled = Completer<void>();

  @override
  String get name => 'controlled';

  @override
  String get type => 'controlled';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async => '';

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) {
    if (!listened.isCompleted) listened.complete();
    return _controller.stream;
  }

  @override
  Future<String> complete(String prompt) async => '';

  @override
  Future<bool> testConnection() async => true;

  void emit(String chunk) => _controller.add(chunk);

  Future<void> close() => _controller.close();
}

class _ImmediateProvider implements AIProvider {
  int calls = 0;

  @override
  String get name => 'immediate';

  @override
  String get type => 'immediate';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async {
    calls++;
    return '{"action":"final","answer":"已收到。"}';
  }

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) =>
      const Stream.empty();

  @override
  Future<String> complete(String prompt) async => '';

  @override
  Future<bool> testConnection() async => true;
}

class _RetryProvider implements AIProvider {
  int calls = 0;

  @override
  String get name => 'retry';

  @override
  String get type => 'retry';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async {
    calls++;
    if (calls == 1) throw StateError('temporary failure');
    return '{"action":"final","answer":"重试成功"}';
  }

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) =>
      const Stream.empty();

  @override
  Future<String> complete(String prompt) async => '';

  @override
  Future<bool> testConnection() async => true;
}

class _ScriptedProvider implements AIProvider {
  final List<String> responses;
  final histories = <List<ChatMessage>?>[];
  final completePrompts = <String>[];

  _ScriptedProvider(this.responses);

  @override
  String get name => 'scripted';

  @override
  String get type => 'scripted';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async {
    histories.add(history == null ? null : List.of(history));
    if (responses.isEmpty) {
      return '{"action":"final","answer":""}';
    }
    return responses.removeAt(0);
  }

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) =>
      const Stream.empty();

  @override
  Future<String> complete(String prompt) async {
    completePrompts.add(prompt);
    return '';
  }

  @override
  Future<bool> testConnection() async => true;
}

class _CheckpointAssetService extends AIAssetService {
  int calls = 0;
  CharacterPersonaGenerationCheckpoint? receivedResumeFrom;
  final CharacterPersonaGenerationCheckpoint? initialCheckpoint;
  final bool cancelFirstGeneration;
  final int pendingPreparationPages;
  final bool blockPreparationUntilCancelled;
  bool preparationCancelled = false;
  int? deletedBookId;

  _CheckpointAssetService(
    AppDatabase database,
    AIService aiService, {
    this.initialCheckpoint,
    this.cancelFirstGeneration = true,
    this.pendingPreparationPages = 0,
    this.blockPreparationUntilCancelled = false,
  }) : super(aiService: aiService, bookDao: BookDao(database));

  @override
  Future<int> pendingLocalContentPreparationPages(int bookId) async {
    return pendingPreparationPages;
  }

  @override
  Future<CharacterPersonaGenerationCheckpoint?> loadCharacterPersonaCheckpoint(
      int bookId) async {
    return initialCheckpoint?.bookId == bookId ? initialCheckpoint : null;
  }

  @override
  Future<void> deleteCharacterPersonaCheckpoint(int bookId) async {
    deletedBookId = bookId;
  }

  @override
  Future<CharacterPersonaGenerationEstimate>
      estimateCharacterPersonaGeneration({
    required int bookId,
    required String characterName,
    CharacterPersonaGenerationCheckpoint? resumeFrom,
    AIRequestCancellation? cancellation,
    void Function(String status)? onProgress,
  }) async {
    if (pendingPreparationPages > 0) {
      onProgress?.call(
        '正在准备 PDF 正文（$pendingPreparationPages/$pendingPreparationPages 页）...',
      );
    }
    if (blockPreparationUntilCancelled) {
      onProgress?.call('正在准备 PDF 正文（80/$pendingPreparationPages 页）...');
      final activeCancellation = cancellation!;
      await activeCancellation.whenCancelled;
      preparationCancelled = true;
      throw AIRequestCancelledException(activeCancellation.reason);
    }
    final completed = resumeFrom?.nextEvidenceIndex ?? 0;
    return CharacterPersonaGenerationEstimate.preview(
      bookId: bookId,
      characterName: characterName,
      totalChapters: 10,
      matchingChapters: 2,
      totalEvidenceTasks: 2,
      completedEvidenceTasks: completed,
      totalInputCharacters: 12000,
      remainingInputCharacters: completed == 0 ? 12000 : 4000,
    );
  }

  @override
  Future<int> generateCharacterPersona({
    required int bookId,
    required String characterName,
    void Function(String status)? onProgress,
    bool Function()? shouldCancel,
    AIRequestCancellation? cancellation,
    CharacterPersonaGenerationEstimate? estimate,
    CharacterPersonaGenerationCheckpoint? resumeFrom,
    void Function(CharacterPersonaGenerationCheckpoint checkpoint)?
        onCheckpoint,
  }) async {
    calls++;
    receivedResumeFrom = resumeFrom;
    if (cancelFirstGeneration && calls == 1) {
      onCheckpoint?.call(CharacterPersonaGenerationCheckpoint(
        bookId: bookId,
        characterName: characterName,
        totalEvidenceTasks: 2,
        nextEvidenceIndex: 1,
        evidence: const ['第一段证据'],
      ));
      throw const AIAssetCancelledException();
    }
    onCheckpoint?.call(CharacterPersonaGenerationCheckpoint(
      bookId: bookId,
      characterName: characterName,
      totalEvidenceTasks: 2,
      nextEvidenceIndex: 2,
      evidence: const ['第一段证据', '第二段证据'],
      finalDocument: '# 已生成角色人格',
    ));
    return 1;
  }
}

class _NoopCheckpointStore extends CharacterPersonaCheckpointStore {
  @override
  Future<void> save(CharacterPersonaGenerationCheckpoint checkpoint) async {}

  @override
  Future<CharacterPersonaGenerationCheckpoint?> loadForBook(
    int bookId, {
    DateTime? now,
  }) async {
    return null;
  }

  @override
  Future<void> deleteForBook(int bookId) async {}

  @override
  Future<int> cleanupExpired({DateTime? now}) async => 0;
}
