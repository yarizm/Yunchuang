import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/ai_dao.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/providers/ai/ai_provider.dart';
import 'package:yunchuang/providers/ai/ai_asset_service.dart';
import 'package:yunchuang/providers/ai/ai_service.dart';
import 'package:yunchuang/providers/ai/character_persona_checkpoint_store.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late AppDatabase database;
  late AIService aiService;
  late AIAssetService assetService;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
    aiService = AIService(AiDao(database));
    assetService = AIAssetService(
      aiService: aiService,
      bookDao: BookDao(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('imports declarative skill markdown and validates tool whitelist',
      () async {
    final skillId = await assetService.importSkillMarkdown('''
<!-- reading_offline_skill v1 {"name":"搜索助手","description":"只搜索当前书","allowedTools":["search_current_book"],"enabled":true} -->

回答书籍事实前必须先搜索当前书。
''');

    final skills = await aiService.getSkills();
    expect(skills.single.id, skillId);
    expect(skills.single.name, '搜索助手');
    expect(skills.single.allowedToolsJson, contains('search_current_book'));

    final exported = assetService.exportSkillMarkdown(skills.single);
    final reparsed = assetService.parseSkillMarkdown(exported);
    expect(reparsed.name.value, '搜索助手');
    expect(reparsed.description.value, '只搜索当前书');
    expect(reparsed.allowedToolsJson.value, contains('search_current_book'));

    expect(
      () => assetService.parseSkillMarkdown('''
<!-- reading_offline_skill v1 {"name":"危险 skill","allowedTools":["run_shell"]} -->

Do something.
'''),
      throwsA(isA<AIAssetFormatException>()),
    );
  });

  test('reports invalid skill metadata as asset format errors', () {
    expect(
      () => assetService.parseSkillMarkdown('''
<!-- reading_offline_skill v1 {"name": -->

# Bad
'''),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.parseSkillMarkdown('''
<!-- reading_offline_skill v1 ["not-object"] -->

# Bad
'''),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.parseSkillMarkdown('''
<!-- reading_offline_skill v1 {"name":"坏 Skill","allowedTools":"search_current_book"} -->

Bad.
'''),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.parseSkillMarkdown('''
<!-- reading_offline_skill v1 {"name":42,"enabled":"yes"} -->

Bad.
'''),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.parseSkillMarkdown('''
<!-- reading_offline_skill v1 {"name":"坏 Skill","allowedTools":[1]} -->

Bad.
'''),
      throwsA(isA<AIAssetFormatException>()),
    );
  });

  test('rejects oversized imported markdown files', () {
    final oversized = '<!-- reading_offline_skill v1 {"name":"过大 Skill"} -->\n'
        '${List.filled(
      AIAssetService.maxImportedMarkdownChars ~/ 2 + 1,
      '正文',
    ).join()}';

    expect(
      () => assetService.parseSkillMarkdown(oversized),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.validateImportFileSize(
        AIAssetService.maxImportedMarkdownBytes + 1,
      ),
      throwsA(isA<AIAssetFormatException>()),
    );
    expect(
      () => assetService.validateImportFileSize(
        AIAssetService.maxImportedMarkdownBytes,
      ),
      returnsNormally,
    );
  });

  test('imports plain markdown skill using the first heading as name', () {
    final parsed = assetService.parseSkillMarkdown('''
# 搜索优先助手

回答书籍事实前，优先使用本地搜索工具寻找证据。
''');

    expect(parsed.name.value, '搜索优先助手');
    expect(parsed.contentMarkdown.value, contains('本地搜索工具'));
    expect(parsed.allowedToolsJson.value, '[]');

    expect(
      () => assetService.parseSkillMarkdown('没有标题的普通文本'),
      throwsA(isA<AIAssetFormatException>()),
    );
  });

  test('exports and imports persona markdown metadata', () async {
    final personaId = await assetService.createCustomPersona(
      name: '冷静助手',
      systemPrompt: '比较 a > b，并保留 --> 字符。',
    );
    final persona = (await aiService.getPersonas())
        .singleWhere((item) => item.id == personaId);

    final markdown = assetService.exportPersonaMarkdown(persona);
    final parsed = assetService.parsePersonaMarkdown(markdown);

    expect(parsed.name.value, '冷静助手');
    expect(parsed.type.value, 'custom');
    expect(parsed.systemPrompt.value, '比较 a > b，并保留 --> 字符。');
    expect(parsed.documentMarkdown.value, contains('冷静助手'));
  });

  test('createCustomPersona validates required fields', () async {
    expect(
      () => assetService.createCustomPersona(
        name: '   ',
        systemPrompt: '回答要简洁。',
      ),
      throwsA(isA<AIAssetFormatException>()),
    );
    expect(
      () => assetService.createCustomPersona(
        name: '冷静助手',
        systemPrompt: '   ',
      ),
      throwsA(isA<AIAssetFormatException>()),
    );
    expect(
      () => assetService.createCustomPersona(
        name: '过长人格',
        systemPrompt: List.filled(
          AIAssetService.maxImportedMarkdownChars + 1,
          '字',
        ).join(),
      ),
      throwsA(isA<AIAssetFormatException>()),
    );
  });

  test('imports plain markdown as a custom persona using first heading', () {
    final parsed = assetService.parsePersonaMarkdown('''
# 方源人格

保持冷静、克制、目标明确。
''');

    expect(parsed.name.value, '方源人格');
    expect(parsed.type.value, 'custom');
    expect(parsed.documentMarkdown.value, contains('目标明确'));
  });

  test('rejects a persona without document content or a system prompt', () {
    expect(
      () => assetService.parsePersonaMarkdown('   \n\n'),
      throwsA(
        isA<AIAssetFormatException>().having(
          (error) => error.message,
          'message',
          contains('不能同时为空'),
        ),
      ),
    );
  });

  test('does not reuse exported local book ids when importing personas',
      () async {
    final personaId = await assetService.importPersonaMarkdown('''
<!-- reading_offline_persona v1 {"name":"方源人格","type":"character","bookId":999,"characterName":"方源","systemPrompt":"保持冷静。"} -->

# 方源人格

保持冷静、克制、目标明确。
''');

    final persona = (await aiService.getPersonas())
        .singleWhere((item) => item.id == personaId);
    expect(persona.bookId, isNull);

    final scoped = assetService.parsePersonaMarkdown(
      assetService.exportPersonaMarkdown(persona),
      bookId: 42,
    );
    expect(scoped.bookId.value, 42);
  });

  test('rejects unsupported persona type metadata', () {
    expect(
      () => assetService.parsePersonaMarkdown('''
<!-- reading_offline_persona v1 {"name":"坏人格","type":"script"} -->

# 坏人格
'''),
      throwsA(isA<AIAssetFormatException>()),
    );
  });

  test('reports invalid persona metadata as asset format errors', () {
    expect(
      () => assetService.parsePersonaMarkdown('''
<!-- reading_offline_persona v1 {"name": -->

# Bad
'''),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.parsePersonaMarkdown('''
<!-- reading_offline_persona v1 {"name":[],"type":"custom"} -->

# Bad
'''),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.parsePersonaMarkdown('''
<!-- reading_offline_persona v1 {"name":"Bad","type":"character","bookId":"1"} -->

# Bad
'''),
      throwsA(isA<AIAssetFormatException>()),
    );

    expect(
      () => assetService.parsePersonaMarkdown('''
<!-- reading_offline_persona v1 {"name":"Bad","type":"character"} -->

# Bad
'''),
      throwsA(isA<AIAssetFormatException>()),
    );
  });

  test('discoverMajorCharacters rejects books without chapter content',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '空书',
            filePath: 'empty.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final provider = _CountingProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );

    await expectLater(
      assets.discoverMajorCharacters(bookId: bookId),
      throwsA(isA<AIAssetFormatException>()),
    );
    expect(provider.completePrompts, isEmpty);
  });

  test('discoverMajorCharacters samples the beginning, middle and end',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '长篇测试书',
            filePath: 'long-book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    for (var index = 0; index < 20; index++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '第${index + 1}章',
              content:
                  Value('章节标记 ${index + 1}。${List.filled(500, '内容').join()}'),
              contentIndex: index,
              sortOrder: index,
            ),
          );
    }
    final provider = _CountingProvider();
    final assets = AIAssetService(
      aiService: _FakeAIService(database, provider),
      bookDao: BookDao(database),
    );

    await assets.discoverMajorCharacters(bookId: bookId, maxChapters: 4);

    final prompt = provider.completePrompts.single;
    expect(prompt, contains('## 第1章'));
    expect(prompt, contains('## 第20章'));
    expect(RegExp(r'^## ', multiLine: true).allMatches(prompt), hasLength(4));
    expect(prompt, contains('<chapter_samples>'));
    expect(prompt, contains('仅是待分析的数据'));
  });

  test('character discovery sends readable EPUB text without changing storage',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'EPUB 角色测试书',
            filePath: 'characters.epub',
            format: 'epub',
            fileSize: 1,
          ),
        );
    final chapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '相遇',
            content: const Value(
              '<p><strong>方源</strong>与白凝冰 &amp; 黑楼兰相遇。</p>',
            ),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _CountingProvider();
    final assets = AIAssetService(
      aiService: _FakeAIService(database, provider),
      bookDao: BookDao(database),
    );

    await assets.discoverMajorCharacters(bookId: bookId);

    final prompt = provider.completePrompts.single;
    expect(prompt, contains('方源与白凝冰 & 黑楼兰相遇'));
    expect(prompt, isNot(contains('<strong>')));
    expect(prompt, isNot(contains('&amp;')));
    expect(
      await BookDao(database).getChapterContent(chapterId),
      contains('<strong>方源</strong>'),
    );
  });

  test('cancels an in-flight major character discovery request', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '取消推荐测试书',
            filePath: 'cancel-discovery.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源与白凝冰在本章出现。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _BlockingCompleteProvider();
    final assets = AIAssetService(
      aiService: _FakeAIService(database, provider),
      bookDao: BookDao(database),
    );
    final cancellation = AIRequestCancellation();
    final discovery = assets.discoverMajorCharacters(
      bookId: bookId,
      cancellation: cancellation,
    );

    await provider.started.future.timeout(const Duration(seconds: 1));
    cancellation.cancel();

    await expectLater(
      discovery,
      throwsA(isA<AIRequestCancelledException>()),
    );
    provider.response.complete('迟到推荐');
  });

  test('estimates character generation scope without calling the model',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '预估测试书',
            filePath: 'estimate.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源留下第一段证据。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第二章',
            content: const Value('这里没有目标角色。'),
            contentIndex: 1,
            sortOrder: 1,
          ),
        );
    final filler = List.filled(2600, '旁白').join();
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第三章',
            content: Value('方源前段证据。$filler 方源后段证据。'),
            contentIndex: 2,
            sortOrder: 2,
          ),
        );
    final provider = _CountingProvider();
    final assets = AIAssetService(
      aiService: _FakeAIService(database, provider),
      bookDao: BookDao(database),
    );

    final estimate = await assets.estimateCharacterPersonaGeneration(
      bookId: bookId,
      characterName: '方源',
    );

    expect(estimate.totalChapters, 3);
    expect(estimate.matchingChapters, 2);
    expect(estimate.totalEvidenceTasks, 4);
    expect(estimate.remainingEvidenceTasks, 4);
    expect(estimate.totalInputCharacters,
        greaterThan(estimate.remainingEvidenceTasks));
    expect(estimate.remainingInputCharacters, estimate.totalInputCharacters);
    expect(provider.completePrompts, isEmpty);

    final resumed = await assets.estimateCharacterPersonaGeneration(
      bookId: bookId,
      characterName: '方源',
      resumeFrom: CharacterPersonaGenerationCheckpoint(
        bookId: bookId,
        characterName: '方源',
        totalEvidenceTasks: 4,
        nextEvidenceIndex: 1,
        evidence: const ['已完成证据'],
      ),
    );
    expect(resumed.completedEvidenceTasks, 1);
    expect(resumed.remainingEvidenceTasks, 3);
    expect(resumed.remainingInputCharacters,
        lessThan(resumed.totalInputCharacters));
  });

  test('matches Latin character names without case sensitivity', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Case Test',
            filePath: 'case-test.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: 'Chapter One',
            content: const Value('Harry entered the room and started talking.'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final assets = AIAssetService(
      aiService: _FakeAIService(database, _CountingProvider()),
      bookDao: BookDao(database),
    );

    final estimate = await assets.estimateCharacterPersonaGeneration(
      bookId: bookId,
      characterName: 'harry',
    );

    expect(estimate.matchingChapters, 1);
    expect(estimate.totalEvidenceTasks, 1);
  });

  test('character estimation indexes unread PDF pages before scanning',
      () async {
    final directory = await Directory.systemTemp.createTemp('ai_persona_pdf_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}persona.pdf',
    );
    await _writePdf(file, [
      'The opening contains no target.',
      'Alice protects her friend and speaks calmly.',
    ]);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'PDF Persona',
            filePath: file.path,
            format: 'pdf',
            fileSize: await file.length(),
          ),
        );
    for (var page = 0; page < 2; page++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: 'Page ${page + 1}',
              contentIndex: page,
              sortOrder: page,
            ),
          );
    }
    final assets = AIAssetService(
      aiService: _FakeAIService(database, _CountingProvider()),
      bookDao: BookDao(database),
    );

    expect(await assets.pendingLocalContentPreparationPages(bookId), 2);

    final estimate = await assets.estimateCharacterPersonaGeneration(
      bookId: bookId,
      characterName: 'Alice',
    );

    expect(estimate.totalChapters, 2);
    expect(estimate.matchingChapters, 1);
    expect(estimate.totalEvidenceTasks, 2);
    final cached = await BookDao(database).getChaptersForBook(bookId);
    expect(cached.every((chapter) => chapter.content != null), isTrue);
    expect(await assets.pendingLocalContentPreparationPages(bookId), 0);
  });

  test('rejects invalid merge and reduction progress during estimation',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '检查点预估测试书',
            filePath: 'estimate-checkpoint.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源出现并留下证据。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final assets = AIAssetService(
      aiService: _FakeAIService(database, _CountingProvider()),
      bookDao: BookDao(database),
    );

    Future<void> expectInvalid(
      CharacterPersonaGenerationCheckpoint checkpoint,
    ) async {
      await expectLater(
        assets.estimateCharacterPersonaGeneration(
          bookId: bookId,
          characterName: '方源',
          resumeFrom: checkpoint,
        ),
        throwsA(isA<AIAssetFormatException>()),
      );
    }

    await expectInvalid(CharacterPersonaGenerationCheckpoint(
      bookId: bookId,
      characterName: '方源',
      totalEvidenceTasks: 1,
      nextEvidenceIndex: 1,
      evidence: const ['## 第一章\n可靠证据'],
      nextMergeBatchIndex: 1,
      mergedBatches: const ['不应存在的单批合并进度'],
    ));
    await expectInvalid(CharacterPersonaGenerationCheckpoint(
      bookId: bookId,
      characterName: '方源',
      totalEvidenceTasks: 1,
      nextEvidenceIndex: 1,
      evidence: const ['## 第一章\n可靠证据'],
      reductionInput: const ['待压缩证据'],
      nextReductionBatchIndex: 2,
      reducedEvidence: const ['结果一', '结果二'],
    ));
  });

  test('generateCharacterPersona rejects missing character evidence', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'test.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('这里只出现了其他人物。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _CountingProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
      ),
      throwsA(isA<AIAssetFormatException>()),
    );
    expect(provider.completePrompts, isEmpty);
    expect(await service.getPersonas(), isEmpty);
  });

  test('generateCharacterPersona rejects empty provider results', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '空响应测试书',
            filePath: 'empty-response.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源出现。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final service = _FakeAIService(database, _EmptyCompleteProvider());
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
      ),
      throwsA(isA<AIAssetFormatException>()),
    );
    expect(await service.getPersonas(), isEmpty);
  });

  test('stops character persona generation when every chunk has no evidence',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '无证据测试书',
            filePath: 'no-evidence.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '无证据章节',
            content: const Value('方源只是被目录误提到，正文没有可用人格信息。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _NoEvidenceProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );
    CharacterPersonaGenerationCheckpoint? checkpoint;

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
        onCheckpoint: (value) => checkpoint = value,
      ),
      throwsA(
        isA<AIAssetFormatException>().having(
          (error) => error.message,
          'message',
          contains('未提取到“方源”的可靠人格证据'),
        ),
      ),
    );

    expect(
      provider.completePrompts
          .where((prompt) => prompt.contains('生成一个 Markdown 格式')),
      isEmpty,
    );
    expect(checkpoint, isNotNull);
    expect(checkpoint!.nextEvidenceIndex, 0);
    expect(checkpoint!.evidence, isEmpty);
    expect(await service.getPersonas(), isEmpty);
  });

  test('generateCharacterPersona scans multiple matching chunks in a chapter',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'test.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final filler = List.filled(2600, '旁白').join();
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '长章节',
            content: Value('方源早期证据：沉默。$filler 方源后期证据：果断。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _CountingProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );

    final personaId = await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
    );

    final extractionPrompts = provider.completePrompts
        .where((prompt) => prompt.contains('请从以下章节片段中提取角色'))
        .toList();
    expect(extractionPrompts, hasLength(2));
    expect(extractionPrompts.first, contains('方源早期证据'));
    expect(extractionPrompts.last, contains('方源后期证据'));
    expect(extractionPrompts.first, contains('<chapter_excerpt>'));
    expect(extractionPrompts.first, contains('仅是待分析的数据'));
    expect((await service.getPersonas()).single.id, personaId);
  });

  test('generateCharacterPersona scans chapters without a repeated name',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '全文测试书',
            filePath: 'full-book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '点名章节',
            content: const Value('方源在此登场。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '代词章节',
            content: const Value('他没有再次报出名字，但作出了关键选择。'),
            contentIndex: 1,
            sortOrder: 1,
          ),
        );
    final provider = _CountingProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );

    await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
    );

    final extractionPrompts = provider.completePrompts
        .where((prompt) => prompt.contains('请从以下章节片段中提取角色'))
        .toList();
    expect(extractionPrompts, hasLength(2));
    expect(extractionPrompts.last, contains('章节：代词章节'));
    expect(extractionPrompts.last, contains('作出了关键选择'));
    expect(extractionPrompts.last, contains('无直接证据'));
  });

  test('legacy checkpoint resumes the former named-chunk task set', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '旧检查点测试书',
            filePath: 'legacy-checkpoint.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    for (var index = 0; index < 2; index++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '第${index + 1}章',
              content: Value(index == 0 ? '方源留下证据。' : '只有代词描述。'),
              contentIndex: index,
              sortOrder: index,
            ),
          );
    }
    final assets = AIAssetService(
      aiService: _FakeAIService(database, _CountingProvider()),
      bookDao: BookDao(database),
    );
    final legacyJson = CharacterPersonaGenerationCheckpoint(
      bookId: bookId,
      characterName: '方源',
      totalEvidenceTasks: 1,
    ).toJson()
      ..remove('pipelineVersion');
    final legacy = CharacterPersonaGenerationCheckpoint.fromJson(legacyJson);

    final estimate = await assets.estimateCharacterPersonaGeneration(
      bookId: bookId,
      characterName: '方源',
      resumeFrom: legacy,
    );

    expect(estimate.totalEvidenceTasks, 1);
    expect(legacy.pipelineVersion, 1);
  });

  test('hierarchically reduces evidence before the final persona prompt',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '超长证据测试书',
            filePath: 'large-evidence.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    for (var index = 0; index < 30; index++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '证据章节${index + 1}',
              content: Value('方源在第 ${index + 1} 章表现出不同特征。'),
              contentIndex: index,
              sortOrder: index,
            ),
          );
    }
    final provider = _LargeEvidenceProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );

    await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
    );

    expect(
      provider.completePrompts
          .where((prompt) => prompt.contains('<evidence_reduction_batch>')),
      isNotEmpty,
    );
    final finalPrompt = provider.completePrompts.singleWhere(
      (prompt) => prompt.contains('<character_evidence>'),
    );
    final start = finalPrompt.indexOf('<character_evidence>') +
        '<character_evidence>'.length;
    final end = finalPrompt.indexOf('</character_evidence>');
    final finalEvidence = finalPrompt.substring(start, end).trim();
    expect(
      finalEvidence.length,
      lessThanOrEqualTo(AIAssetService.maxFinalCharacterEvidenceChars),
    );
  });

  test('omits explicit no-evidence results from merge prompts', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '空证据测试书',
            filePath: 'no-evidence.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '点名章节',
            content: const Value('方源出现。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '无证据章节',
            content: const Value('这里只描述天气。'),
            contentIndex: 1,
            sortOrder: 1,
          ),
        );
    final provider = _NoEvidenceProvider();
    final assets = AIAssetService(
      aiService: _FakeAIService(database, provider),
      bookDao: BookDao(database),
    );

    await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
    );

    final finalPrompt = provider.completePrompts.singleWhere(
      (prompt) => prompt.contains('<character_evidence>'),
    );
    expect(finalPrompt, isNot(contains('无证据章节 · 片段')));
  });

  test('cancels an in-flight character persona provider request', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '取消测试书',
            filePath: 'cancel.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源在这里留下了人格证据。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _BlockingCompleteProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );
    final cancellation = AIRequestCancellation();
    final generation = assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
      cancellation: cancellation,
    );

    await provider.started.future.timeout(const Duration(seconds: 1));
    cancellation.cancel();

    await expectLater(
      generation,
      throwsA(isA<AIAssetCancelledException>()),
    );
    provider.response.complete('迟到结果');
    expect(await service.getPersonas(), isEmpty);
  });

  test('resumes character evidence extraction without repeating completed work',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'resume.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    for (var index = 0; index < 2; index++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '第${index + 1}章',
              content: Value('方源在第${index + 1}章留下了人格证据。'),
              contentIndex: index,
              sortOrder: index,
            ),
          );
    }
    final provider = _FailOnceProvider(failOnCall: 2);
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );
    CharacterPersonaGenerationCheckpoint? checkpoint;

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
        onCheckpoint: (value) => checkpoint = value,
      ),
      throwsStateError,
    );
    expect(checkpoint, isNotNull);
    expect(checkpoint!.nextEvidenceIndex, 1);
    expect(checkpoint!.evidence, hasLength(1));

    final personaId = await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
      resumeFrom: checkpoint,
      onCheckpoint: (value) => checkpoint = value,
    );

    final extractionPrompts = provider.completePrompts
        .where((prompt) => prompt.contains('请从以下章节片段中提取角色'))
        .toList();
    expect(extractionPrompts, hasLength(3));
    expect(
      extractionPrompts.where((prompt) => prompt.contains('章节：第1章')),
      hasLength(1),
    );
    expect(
      extractionPrompts.where((prompt) => prompt.contains('章节：第2章')),
      hasLength(2),
    );
    expect((await service.getPersonas()).single.id, personaId);
  });

  test('resumes evidence merging from the latest completed batch', () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '长篇测试书',
            filePath: 'merge-resume.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    for (var index = 0; index < 20; index++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '证据章节${index + 1}',
              content: Value('方源在这里展现了第${index + 1}种行为模式。'),
              contentIndex: index,
              sortOrder: index,
            ),
          );
    }
    final provider = _FailOnceProvider(
      failOnCall: 22,
      extractionResult: List.filled(13000, '证').join(),
    );
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );
    CharacterPersonaGenerationCheckpoint? checkpoint;

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
        onCheckpoint: (value) => checkpoint = value,
      ),
      throwsStateError,
    );
    expect(checkpoint!.nextEvidenceIndex, 20);
    expect(checkpoint!.nextMergeBatchIndex, 1);
    expect(checkpoint!.mergedBatches, hasLength(1));

    await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
      resumeFrom: checkpoint,
      onCheckpoint: (value) => checkpoint = value,
    );

    final extractionPrompts = provider.completePrompts
        .where((prompt) => prompt.contains('请从以下章节片段中提取角色'));
    final mergePrompts = provider.completePrompts
        .where((prompt) => prompt.contains('请合并并去重以下角色'))
        .toList();
    expect(extractionPrompts, hasLength(20));
    expect(mergePrompts, hasLength(4));
    expect(
      mergePrompts.where((prompt) => prompt.contains('## 证据章节1 ·')),
      hasLength(1),
    );
    expect(await service.getPersonas(), hasLength(1));
  });

  test('resumes evidence reduction without repeating completed batches',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '压缩恢复测试书',
            filePath: 'reduction-resume.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    for (var index = 0; index < 40; index++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '压缩证据章节${index + 1}',
              content: Value('方源在第 ${index + 1} 章展现出不同特征。'),
              contentIndex: index,
              sortOrder: index,
            ),
          );
    }
    final provider = _FailOnceReductionProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );
    CharacterPersonaGenerationCheckpoint? checkpoint;

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
        onCheckpoint: (value) => checkpoint = value,
      ),
      throwsStateError,
    );

    expect(checkpoint, isNotNull);
    expect(checkpoint!.nextEvidenceIndex, 40);
    expect(checkpoint!.reductionInput, isNotEmpty);
    expect(checkpoint!.nextReductionBatchIndex, 1);
    expect(checkpoint!.reducedEvidence, hasLength(1));
    final completedReductionPrompt = provider.reductionPrompts.first;

    await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
      resumeFrom: checkpoint,
      onCheckpoint: (value) => checkpoint = value,
    );

    expect(
      provider.reductionPrompts
          .where((prompt) => prompt == completedReductionPrompt),
      hasLength(1),
    );
    expect(checkpoint!.finalEvidenceText, isNotEmpty);
    expect(await service.getPersonas(), hasLength(1));
  });

  test('saves a completed legacy checkpoint without calling the model again',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '旧检查点测试书',
            filePath: 'completed-legacy-checkpoint.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源出现并作出选择。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _CountingProvider();
    final service = _FakeAIService(database, provider);
    final assets = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
    );
    final completed = CharacterPersonaGenerationCheckpoint(
      bookId: bookId,
      characterName: '方源',
      totalEvidenceTasks: 1,
      pipelineVersion: 1,
      nextEvidenceIndex: 1,
      evidence: const ['## 第一章\n已有证据'],
      finalDocument: '# 方源人格\n\n已有最终文档',
    );

    await assets.generateCharacterPersona(
      bookId: bookId,
      characterName: '方源',
      resumeFrom: completed,
    );

    expect(provider.completePrompts, isEmpty);
    expect((await service.getPersonas()).single.documentMarkdown,
        '# 方源人格\n\n已有最终文档');
  });

  test('rejects stale character generation checkpoints before provider calls',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'stale.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源出现了。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final provider = _CountingProvider();
    final assets = AIAssetService(
      aiService: _FakeAIService(database, provider),
      bookDao: BookDao(database),
    );

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
        resumeFrom: CharacterPersonaGenerationCheckpoint(
          bookId: bookId + 1,
          characterName: '方源',
          totalEvidenceTasks: 1,
        ),
      ),
      throwsA(isA<AIAssetFormatException>()),
    );
    expect(provider.completePrompts, isEmpty);
  });

  test('rejects a checkpoint when chapter content changes at the same size',
      () async {
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '正文变化测试书',
            filePath: 'changed-content.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源表现得十分冷静。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );
    final secondChapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第二章',
            content: const Value('方源选择继续向前。'),
            contentIndex: 1,
            sortOrder: 1,
          ),
        );
    final provider = _FailOnceProvider(failOnCall: 2);
    final assets = AIAssetService(
      aiService: _FakeAIService(database, provider),
      bookDao: BookDao(database),
    );
    CharacterPersonaGenerationCheckpoint? checkpoint;

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
        onCheckpoint: (value) => checkpoint = value,
      ),
      throwsStateError,
    );
    expect(checkpoint, isNotNull);
    expect(checkpoint!.nextEvidenceIndex, 1);
    expect(checkpoint!.sourceFingerprint, startsWith('tasks-v1-'));
    final callsBeforeResume = provider.completePrompts.length;

    await (database.update(database.chapters)
          ..where((chapter) => chapter.id.equals(secondChapterId)))
        .write(
      const ChaptersCompanion(
        content: Value('方源选择暂时停下。'),
      ),
    );

    await expectLater(
      assets.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
        resumeFrom: checkpoint,
      ),
      throwsA(
        isA<AIAssetFormatException>().having(
          (error) => error.message,
          'message',
          contains('检查点已失效'),
        ),
      ),
    );
    expect(provider.completePrompts, hasLength(callsBeforeResume));
  });

  test('restores a persisted checkpoint in a new asset service instance',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('persona-service-resume-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final store = CharacterPersonaCheckpointStore(
      directoryProvider: () async => directory,
    );
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '重启恢复测试书',
            filePath: 'restart.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    for (var index = 0; index < 2; index++) {
      await database.into(database.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: '重启章节${index + 1}',
              content: Value('方源在章节 ${index + 1} 中留下证据。'),
              contentIndex: index,
              sortOrder: index,
            ),
          );
    }
    final provider = _FailOnceProvider(failOnCall: 2);
    final service = _FakeAIService(database, provider);
    final firstInstance = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
      checkpointStore: store,
    );

    await expectLater(
      firstInstance.generateCharacterPersona(
        bookId: bookId,
        characterName: '方源',
      ),
      throwsStateError,
    );

    final secondInstance = AIAssetService(
      aiService: service,
      bookDao: BookDao(database),
      checkpointStore: store,
    );
    final restored =
        await secondInstance.loadCharacterPersonaCheckpoint(bookId);
    expect(restored, isNotNull);
    expect(restored!.nextEvidenceIndex, 1);

    await secondInstance.generateCharacterPersona(
      bookId: bookId,
      characterName: restored.characterName,
      resumeFrom: restored,
    );

    expect(await store.loadForBook(bookId), isNull);
    expect(await service.getPersonas(bookId: bookId), hasLength(1));
    final firstChapterPrompts = provider.completePrompts.where(
      (prompt) => prompt.contains('章节：重启章节1'),
    );
    expect(firstChapterPrompts, hasLength(1));
  });
}

class _FakeAIService extends AIService {
  final AIProvider provider;

  _FakeAIService(AppDatabase database, this.provider) : super(AiDao(database));

  @override
  Future<AIProvider?> getDefaultProvider() async => provider;
}

Future<void> _writePdf(File file, List<String> pageTexts) async {
  final document = PdfDocument();
  try {
    for (final text in pageTexts) {
      document.pages.add().graphics.drawString(
            text,
            PdfStandardFont(PdfFontFamily.helvetica, 12),
          );
    }
    await file.writeAsBytes(await document.save(), flush: true);
  } finally {
    document.dispose();
  }
}

class _CountingProvider implements AIProvider {
  final completePrompts = <String>[];

  @override
  String get name => 'counting';

  @override
  String get type => 'counting';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async => '';

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) =>
      const Stream.empty();

  @override
  Future<String> complete(String prompt) async {
    completePrompts.add(prompt);
    return 'result';
  }

  @override
  Future<bool> testConnection() async => true;
}

class _BlockingCompleteProvider implements AIProvider {
  final started = Completer<void>();
  final response = Completer<String>();

  @override
  String get name => 'blocking-complete';

  @override
  String get type => 'blocking-complete';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async => '';

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) =>
      const Stream.empty();

  @override
  Future<String> complete(String prompt) {
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  @override
  Future<bool> testConnection() async => true;
}

class _FailOnceProvider implements AIProvider {
  final int failOnCall;
  final String extractionResult;
  final completePrompts = <String>[];
  var _failed = false;

  _FailOnceProvider({
    required this.failOnCall,
    this.extractionResult = 'result',
  });

  @override
  String get name => 'fail-once';

  @override
  String get type => 'fail-once';

  @override
  Future<String> chat(String message, {List<ChatMessage>? history}) async => '';

  @override
  Stream<String> chatStream(String message, {List<ChatMessage>? history}) =>
      const Stream.empty();

  @override
  Future<String> complete(String prompt) async {
    completePrompts.add(prompt);
    if (!_failed && completePrompts.length == failOnCall) {
      _failed = true;
      throw StateError('temporary provider failure');
    }
    if (prompt.contains('请从以下章节片段中提取角色')) {
      return extractionResult;
    }
    return 'merged result';
  }

  @override
  Future<bool> testConnection() async => true;
}

class _LargeEvidenceProvider extends _CountingProvider {
  @override
  Future<String> complete(String prompt) async {
    completePrompts.add(prompt);
    if (prompt.contains('请从以下章节片段中提取角色')) {
      return List.filled(13000, '证').join();
    }
    if (prompt.contains('<evidence_reduction_batch>')) {
      return List.filled(4000, '缩').join();
    }
    if (prompt.contains('<evidence_batch>')) {
      return List.filled(10000, '并').join();
    }
    return '# 方源人格';
  }
}

class _FailOnceReductionProvider extends _CountingProvider {
  final reductionPrompts = <String>[];
  var _failed = false;

  @override
  Future<String> complete(String prompt) async {
    completePrompts.add(prompt);
    if (prompt.contains('请从以下章节片段中提取角色')) {
      return List.filled(2500, '证').join();
    }
    if (prompt.contains('<evidence_batch>')) {
      return List.filled(8000, '并').join();
    }
    if (prompt.contains('<evidence_reduction_batch>')) {
      reductionPrompts.add(prompt);
      if (!_failed && reductionPrompts.length == 2) {
        _failed = true;
        throw StateError('temporary reduction failure');
      }
      return List.filled(4000, '缩').join();
    }
    return '# 方源人格';
  }
}

class _NoEvidenceProvider extends _CountingProvider {
  @override
  Future<String> complete(String prompt) async {
    completePrompts.add(prompt);
    if (prompt.contains('章节：无证据章节')) return '无直接证据';
    if (prompt.contains('请从以下章节片段中提取角色')) return '可靠证据';
    return '# 方源人格';
  }
}

class _EmptyCompleteProvider extends _CountingProvider {
  @override
  Future<String> complete(String prompt) async => '   ';
}
