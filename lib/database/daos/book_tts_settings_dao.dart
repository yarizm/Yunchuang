import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/book_tts_settings.dart';

part 'book_tts_settings_dao.g.dart';

@DriftAccessor(tables: [BookTtsSettings])
class BookTtsSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$BookTtsSettingsDaoMixin {
  BookTtsSettingsDao(super.db);

  Future<BookTtsSetting?> getForBook(int bookId) {
    return (select(bookTtsSettings)
          ..where((settings) => settings.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Stream<BookTtsSetting?> watchForBook(int bookId) {
    return (select(bookTtsSettings)
          ..where((settings) => settings.bookId.equals(bookId)))
        .watchSingleOrNull();
  }

  Future<void> save({
    required int bookId,
    required double speechRate,
    required String sleepTimerOption,
    String? language,
    String? voiceName,
    String? voiceLocale,
  }) async {
    final normalizedLanguage = _normalizeOptional(language);
    final normalizedVoiceName = _normalizeOptional(voiceName);
    final normalizedVoiceLocale = _normalizeOptional(voiceLocale);
    if (speechRate < 0.1 || speechRate > 1.0 || speechRate.isNaN) {
      throw ArgumentError.value(speechRate, 'speechRate', '语速必须在 0.1 到 1.0 之间');
    }
    if (!_sleepTimerOptions.contains(sleepTimerOption)) {
      throw ArgumentError.value(
        sleepTimerOption,
        'sleepTimerOption',
        '不支持的睡眠定时选项',
      );
    }
    if ((normalizedVoiceName == null) != (normalizedVoiceLocale == null)) {
      throw ArgumentError('声音名称和语言区域必须同时提供');
    }

    await into(bookTtsSettings).insertOnConflictUpdate(
      BookTtsSettingsCompanion(
        bookId: Value(bookId),
        language: Value(normalizedLanguage),
        voiceName: Value(normalizedVoiceName),
        voiceLocale: Value(normalizedVoiceLocale),
        speechRate: Value(speechRate),
        sleepTimerOption: Value(sleepTimerOption),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reset(int bookId) {
    return (delete(bookTtsSettings)
          ..where((settings) => settings.bookId.equals(bookId)))
        .go();
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

const _sleepTimerOptions = {
  'off',
  'minutes15',
  'minutes30',
  'minutes60',
  'endOfChapter',
};
