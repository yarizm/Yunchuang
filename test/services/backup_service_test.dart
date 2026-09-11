import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_tts_settings_dao.dart';
import 'package:yunchuang/database/daos/book_reading_settings_dao.dart';
import 'package:yunchuang/services/backup_service.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;

  setUpAll(() {
    // Backup tests intentionally open independent live, snapshot, and staged
    // databases at the same time.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('reading_backup_');
    database = AppDatabase.connect(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('exports and restores portable file paths', () async {
    final externalBook = File(p.join(tempDirectory.path, 'source.txt'));
    await externalBook.writeAsString('content');
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Portable',
            filePath: externalBook.path,
            format: 'txt',
            fileSize: await externalBook.length(),
            readingStatus: const Value('paused'),
            fileHash: const Value(
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            ),
            seriesName: const Value('测试系列'),
            seriesIndex: const Value(2),
          ),
        );
    final collectionId = await database.into(database.bookCollections).insert(
          BookCollectionsCompanion.insert(name: '随身书架'),
        );
    await database.into(database.bookCollectionItems).insert(
          BookCollectionItemsCompanion.insert(
            collectionId: collectionId,
            bookId: bookId,
          ),
        );
    await BookTtsSettingsDao(database).save(
      bookId: bookId,
      language: 'zh-TW',
      voiceName: 'Voice A',
      voiceLocale: 'zh-TW',
      speechRate: 0.8,
      sleepTimerOption: 'minutes30',
    );
    await BookReadingSettingsDao(database).save(
      bookId: bookId,
      fontSize: 21,
      lineHeight: 1.9,
      margin: 26,
      fontFamily: 'serif',
      paragraphSpacing: 16,
      letterSpacing: 0.7,
      wordSpacing: 1.1,
      boldText: true,
      textAlignment: 'justify',
      paragraphIndent: 2,
      pdfCropAmount: 0.1,
      pdfContrast: 1.5,
      pdfPageLayout: 'double',
      topContentPadding: 24,
      pageTurnEffect: 'slide',
    );
    await database.into(database.vocabularyEntries).insert(
          VocabularyEntriesCompanion.insert(
            bookId: bookId,
            term: 'portable',
            normalizedTerm: 'portable',
            definition: const Value('可移植'),
            contextText: const Value('A portable vocabulary entry.'),
          ),
        );
    final dictionaryData =
        File(p.join(tempDirectory.path, 'portable_dictionary.dict'));
    await dictionaryData.writeAsString('dictionary definition');
    final dictionaryId = await database.into(database.dictionarySources).insert(
          DictionarySourcesCompanion.insert(
            name: 'Portable Dictionary',
            formatVersion: '2.4.2',
            sameTypeSequence: const Value('m'),
            dataFilePath: dictionaryData.path,
            entryCount: const Value(1),
            enabled: const Value(true),
            isReady: const Value(true),
          ),
        );
    await database.into(database.dictionaryEntries).insert(
          DictionaryEntriesCompanion.insert(
            sourceId: dictionaryId,
            entryIndex: 0,
            headword: 'portable',
            normalizedHeadword: 'portable',
            dataOffset: 0,
            dataSize: await dictionaryData.length(),
          ),
        );
    final service = BackupService(
      database: database,
      appDirectoryProvider: () async => tempDirectory,
    );

    final archivePath = await service.exportBackup();
    final staged = await service.importBackup(archivePath);
    expect(staged.status, RestoreStatus.staged);

    final applied = await BackupService.applyPendingRestore(
      appDirectoryProvider: () async => tempDirectory,
    );
    expect(applied.status, RestoreStatus.applied);

    final restored = AppDatabase.forFile(
      File(p.join(tempDirectory.path, 'reading_offline.db')),
    );
    addTearDown(restored.close);
    final book = await restored.select(restored.books).getSingle();
    expect(book.filePath, startsWith(tempDirectory.path));
    expect(book.readingStatus, 'paused');
    expect(
      book.fileHash,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    expect(book.seriesName, '测试系列');
    expect(book.seriesIndex, 2);
    expect(await File(book.filePath).readAsString(), 'content');
    expect(
      (await restored.select(restored.bookCollections).getSingle()).name,
      '随身书架',
    );
    final membership =
        await restored.select(restored.bookCollectionItems).getSingle();
    expect(membership.bookId, book.id);
    expect(membership.collectionId, collectionId);
    final ttsSettings =
        await restored.select(restored.bookTtsSettings).getSingle();
    expect(ttsSettings.bookId, book.id);
    expect(ttsSettings.language, 'zh-TW');
    expect(ttsSettings.voiceName, 'Voice A');
    expect(ttsSettings.speechRate, 0.8);
    expect(ttsSettings.sleepTimerOption, 'minutes30');
    final readingSettings =
        await restored.select(restored.bookReadingSettings).getSingle();
    expect(readingSettings.bookId, book.id);
    expect(readingSettings.fontSize, 21);
    expect(readingSettings.fontFamily, 'serif');
    expect(readingSettings.pageTurnEffect, 'slide');
    expect(readingSettings.wordSpacing, 1.1);
    expect(readingSettings.boldText, isTrue);
    expect(readingSettings.textAlignment, 'justify');
    expect(readingSettings.paragraphIndent, 2);
    expect(readingSettings.pdfCropAmount, 0.1);
    expect(readingSettings.pdfContrast, 1.5);
    expect(readingSettings.pdfPageLayout, 'double');
    final vocabulary =
        await restored.select(restored.vocabularyEntries).getSingle();
    expect(vocabulary.bookId, book.id);
    expect(vocabulary.term, 'portable');
    expect(vocabulary.definition, '可移植');
    expect(vocabulary.contextText, 'A portable vocabulary entry.');
    final dictionary =
        await restored.select(restored.dictionarySources).getSingle();
    expect(dictionary.name, 'Portable Dictionary');
    expect(dictionary.dataFilePath, startsWith(tempDirectory.path));
    expect(await File(dictionary.dataFilePath).readAsString(),
        'dictionary definition');
    expect(
      (await restored.select(restored.dictionaryEntries).getSingle()).headword,
      'portable',
    );
  });

  test('preserves AI messages, skills, and personas across backup restore',
      () async {
    await database.into(database.aiProviders).insert(
          AiProvidersCompanion.insert(
            name: 'Test provider',
            type: 'openai',
            baseUrl: 'https://example.invalid/v1',
            apiKey: const Value('test-api-key'),
            modelName: 'test-model',
          ),
        );
    final conversationId = await database.into(database.aiConversations).insert(
          AiConversationsCompanion.insert(
            title: const Value('AI conversation'),
          ),
        );
    const messageMetadata =
        '{"attachments":[{"title":"Chapter content"}],"toolEvents":["Searched book"]}';
    await database.into(database.aiMessages).insert(
          AiMessagesCompanion.insert(
            conversationId: conversationId,
            role: 'user',
            content: 'Summarize this chapter.',
            metadataJson: const Value(messageMetadata),
          ),
        );
    await database.into(database.aiSkills).insert(
          AiSkillsCompanion.insert(
            name: 'Search skill',
            contentMarkdown: 'Search before answering.',
            allowedToolsJson: const Value('["search_current_book"]'),
          ),
        );
    await database.into(database.aiPersonas).insert(
          AiPersonasCompanion.insert(
            name: 'Character persona',
            type: 'character',
            characterName: const Value('Fang Yuan'),
            systemPrompt: const Value('Answer in character.'),
            documentMarkdown: const Value('# Character persona'),
          ),
        );
    final service = BackupService(
      database: database,
      appDirectoryProvider: () async => tempDirectory,
    );

    final archivePath = await service.exportBackup();
    await service.importBackup(archivePath);
    final applied = await BackupService.applyPendingRestore(
      appDirectoryProvider: () async => tempDirectory,
    );
    expect(applied.status, RestoreStatus.applied);

    final restored = AppDatabase.forFile(
      File(p.join(tempDirectory.path, 'reading_offline.db')),
    );
    addTearDown(restored.close);

    // 密钥不随备份走，但 provider 配置本身要还原回来——见下一个用例。
    final provider = await restored.select(restored.aiProviders).getSingle();
    expect(provider.apiKey, isNull);
    expect(provider.name, 'Test provider');
    expect(
      (await restored.select(restored.aiMessages).getSingle()).metadataJson,
      messageMetadata,
    );
    expect(
      (await restored.select(restored.aiSkills).getSingle()).allowedToolsJson,
      '["search_current_book"]',
    );
    final persona = await restored.select(restored.aiPersonas).getSingle();
    expect(persona.characterName, 'Fang Yuan');
    expect(persona.documentMarkdown, '# Character persona');
  });

  test('export strips AI credentials from the shared archive', () async {
    const secret = 'sk-live-must-not-leave-the-device';
    await database.into(database.aiProviders).insert(
          AiProvidersCompanion.insert(
            name: 'Cloud provider',
            type: 'openai',
            baseUrl: 'https://example.invalid/v1',
            apiKey: const Value(secret),
            modelName: 'test-model',
          ),
        );
    final service = BackupService(
      database: database,
      appDirectoryProvider: () async => tempDirectory,
    );

    final archivePath = await service.exportBackup();
    final archive = ZipDecoder().decodeBytes(
      await File(archivePath).readAsBytes(),
      verify: true,
    );
    final dbBytes = archive.files
        .singleWhere((entry) => entry.name == 'reading_offline.db')
        .content as List<int>;

    // 查整个文件的字节，不只查表：行被改写后旧值可能残留在页内空隙或空闲页中，
    // 而分享出去的是这个文件本身，不是一条 SELECT 的结果。
    expect(
      _containsAscii(dbBytes, secret),
      isFalse,
      reason: '备份文件的原始字节里仍能找到 API 密钥',
    );

    final snapshotFile = File(p.join(tempDirectory.path, 'redacted.db'));
    await snapshotFile.writeAsBytes(dbBytes, flush: true);
    final snapshot = AppDatabase.forFile(snapshotFile);
    addTearDown(snapshot.close);

    // 只清凭据：provider 配置要留着，还原后补填密钥就能继续用。
    final provider = await snapshot.select(snapshot.aiProviders).getSingle();
    expect(provider.apiKey, isNull);
    expect(provider.name, 'Cloud provider');
    expect(provider.baseUrl, 'https://example.invalid/v1');
    expect(provider.modelName, 'test-model');
  });

  test('exports portable root entries without staging directories', () async {
    final externalBook = File(p.join(tempDirectory.path, 'source file.txt'));
    final externalCover = File(p.join(tempDirectory.path, 'cover image.jpg'));
    await externalBook.writeAsString('content');
    await externalCover.writeAsString('cover');
    await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Archive Layout',
            filePath: externalBook.path,
            coverPath: Value(externalCover.path),
            format: 'txt',
            fileSize: await externalBook.length(),
          ),
        );
    final service = BackupService(
      database: database,
      appDirectoryProvider: () async => tempDirectory,
    );

    final archivePath = await service.exportBackup();
    final archive = ZipDecoder().decodeBytes(
      await File(archivePath).readAsBytes(),
      verify: true,
    );
    final names = archive.files
        .where((entry) => entry.isFile)
        .map((entry) => entry.name)
        .toSet();

    expect(names, contains('reading_offline.db'));
    expect(names, contains('manifest.json'));
    expect(names.any((name) => name.startsWith('payload/')), isFalse);
    expect(names.any((name) => name.startsWith('books/')), isTrue);
    expect(names.any((name) => name.startsWith('covers/')), isTrue);

    final dbEntry = archive.files.singleWhere(
      (entry) => entry.name == 'reading_offline.db',
    );
    final snapshotFile = File(p.join(tempDirectory.path, 'snapshot.db'));
    await snapshotFile.writeAsBytes(dbEntry.content as List<int>, flush: true);
    final snapshot = AppDatabase.forFile(snapshotFile);
    addTearDown(snapshot.close);

    final book = await snapshot.select(snapshot.books).getSingle();
    expect(book.filePath, startsWith('books/'));
    expect(book.coverPath, startsWith('covers/'));
  });

  test('rejects archive path traversal', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('../outside.txt', 3, [1, 2, 3]))
      ..addFile(ArchiveFile('reading_offline.db', 1, [0]));
    final zip = File(p.join(tempDirectory.path, 'malicious.zip'));
    await zip.writeAsBytes(ZipEncoder().encode(archive)!);
    final service = BackupService(
      database: database,
      appDirectoryProvider: () async => tempDirectory,
    );

    await expectLater(
      service.importBackup(zip.path),
      throwsA(isA<BackupException>()),
    );
    expect(File(p.join(tempDirectory.parent.path, 'outside.txt')).existsSync(),
        isFalse);
  });

  test('quarantines a pending restore that is missing its database', () async {
    final pendingDir = Directory(p.join(tempDirectory.path, 'restore_pending'));
    await pendingDir.create(recursive: true);

    final result = await BackupService.applyPendingRestore(
      appDirectoryProvider: () async => tempDirectory,
    );

    expect(result.status, RestoreStatus.failed);
    expect(await pendingDir.exists(), isFalse);
    expect(
      tempDirectory
          .listSync()
          .whereType<Directory>()
          .where((dir) => p.basename(dir.path).startsWith('restore_failed_')),
      isNotEmpty,
    );
  });

  test('quarantines a corrupt pending restore so startup can continue',
      () async {
    final pendingDir = Directory(p.join(tempDirectory.path, 'restore_pending'));
    await pendingDir.create(recursive: true);
    // A file that is not a valid SQLite database fails integrity_check; the
    // pending restore must be set aside instead of crashing every launch.
    await File(p.join(pendingDir.path, 'reading_offline.db'))
        .writeAsBytes(List<int>.filled(128, 0x7f), flush: true);

    final result = await BackupService.applyPendingRestore(
      appDirectoryProvider: () async => tempDirectory,
    );

    expect(result.status, RestoreStatus.failed);
    expect(await pendingDir.exists(), isFalse);
    final quarantined = tempDirectory
        .listSync()
        .whereType<Directory>()
        .where((dir) => p.basename(dir.path).startsWith('restore_failed_'))
        .toList();
    expect(quarantined, isNotEmpty);
    expect(
      await File(p.join(quarantined.first.path, 'reading_offline.db')).exists(),
      isTrue,
    );
  });

  // 自定义背景图不由数据库行引用，偏好里只存文件名，所以目录必须整份进备份，
  // 否则换设备恢复后偏好指向一个不存在的文件，背景默默消失。
  test('自定义背景图随备份导出并恢复', () async {
    final backgrounds = Directory(p.join(tempDirectory.path, 'backgrounds'));
    await backgrounds.create(recursive: true);
    final wallpaper = File(p.join(backgrounds.path, 'abc-123.png'));
    await wallpaper.writeAsBytes(const [137, 80, 78, 71, 1, 2, 3]);

    final service = BackupService(
      database: database,
      appDirectoryProvider: () async => tempDirectory,
    );
    final archivePath = await service.exportBackup();

    final archive = ZipDecoder().decodeBytes(await File(archivePath).readAsBytes());
    expect(
      archive.files.map((file) => file.name),
      contains('backgrounds/abc-123.png'),
    );

    // 抹掉现场，确认真是从备份里还原出来的。
    await backgrounds.delete(recursive: true);

    expect((await service.importBackup(archivePath)).status,
        RestoreStatus.staged);
    expect(
      (await BackupService.applyPendingRestore(
        appDirectoryProvider: () async => tempDirectory,
      ))
          .status,
      RestoreStatus.applied,
    );

    final restored = File(
      p.join(tempDirectory.path, 'backgrounds', 'abc-123.png'),
    );
    expect(await restored.exists(), isTrue);
    expect(await restored.readAsBytes(), [137, 80, 78, 71, 1, 2, 3]);
  });

  test('没设过背景图时备份里不出现 backgrounds 目录', () async {
    final service = BackupService(
      database: database,
      appDirectoryProvider: () async => tempDirectory,
    );
    final archivePath = await service.exportBackup();

    final archive = ZipDecoder().decodeBytes(await File(archivePath).readAsBytes());
    expect(
      archive.files.where((file) => file.name.startsWith('backgrounds/')),
      isEmpty,
    );
  });
}

bool _containsAscii(List<int> haystack, String needle) {
  final pattern = needle.codeUnits;
  for (var i = 0; i + pattern.length <= haystack.length; i++) {
    var matched = true;
    for (var j = 0; j < pattern.length; j++) {
      if (haystack[i + j] != pattern[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}
