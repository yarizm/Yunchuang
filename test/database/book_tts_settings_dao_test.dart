import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_tts_settings_dao.dart';

void main() {
  late AppDatabase database;
  late BookTtsSettingsDao dao;
  late int bookId;

  setUp(() async {
    database = AppDatabase.connect(NativeDatabase.memory());
    dao = BookTtsSettingsDao(database);
    bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '单书 TTS',
            filePath: 'tts.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
  });

  tearDown(() => database.close());

  test('creates, updates, watches, and resets one book profile', () async {
    final changes = <BookTtsSetting?>[];
    final subscription = dao.watchForBook(bookId).listen(changes.add);
    addTearDown(subscription.cancel);

    await dao.save(
      bookId: bookId,
      language: ' zh-TW ',
      voiceName: ' Voice A ',
      voiceLocale: ' zh-TW ',
      speechRate: 0.7,
      sleepTimerOption: 'minutes30',
    );
    var settings = await dao.getForBook(bookId);
    expect(settings?.language, 'zh-TW');
    expect(settings?.voiceName, 'Voice A');
    expect(settings?.voiceLocale, 'zh-TW');
    expect(settings?.speechRate, 0.7);
    expect(settings?.sleepTimerOption, 'minutes30');

    await dao.save(
      bookId: bookId,
      language: 'zh-CN',
      speechRate: 0.9,
      sleepTimerOption: 'off',
    );
    settings = await dao.getForBook(bookId);
    expect(settings?.language, 'zh-CN');
    expect(settings?.voiceName, isNull);
    expect(settings?.speechRate, 0.9);

    await dao.reset(bookId);
    expect(await dao.getForBook(bookId), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(changes.whereType<BookTtsSetting>(), hasLength(2));
    expect(changes.last, isNull);
  });

  test('validates rate, sleep option, and voice identity', () async {
    expect(
      dao.save(
        bookId: bookId,
        speechRate: 1.1,
        sleepTimerOption: 'off',
      ),
      throwsArgumentError,
    );
    expect(
      dao.save(
        bookId: bookId,
        speechRate: 0.5,
        sleepTimerOption: 'tomorrow',
      ),
      throwsArgumentError,
    );
    expect(
      dao.save(
        bookId: bookId,
        voiceName: 'Voice A',
        speechRate: 0.5,
        sleepTimerOption: 'off',
      ),
      throwsArgumentError,
    );
  });

  test('deleting a book cascades its TTS profile', () async {
    await dao.save(
      bookId: bookId,
      speechRate: 0.6,
      sleepTimerOption: 'endOfChapter',
    );

    await (database.delete(database.books)
          ..where((book) => book.id.equals(bookId)))
        .go();

    expect(await dao.getForBook(bookId), isNull);
  });
}
