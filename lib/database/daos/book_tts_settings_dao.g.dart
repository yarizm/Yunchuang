// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_tts_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$BookTtsSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTable get books => attachedDatabase.books;
  $BookTtsSettingsTable get bookTtsSettings => attachedDatabase.bookTtsSettings;
  BookTtsSettingsDaoManager get managers => BookTtsSettingsDaoManager(this);
}

class BookTtsSettingsDaoManager {
  final _$BookTtsSettingsDaoMixin _db;
  BookTtsSettingsDaoManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$BookTtsSettingsTableTableManager get bookTtsSettings =>
      $$BookTtsSettingsTableTableManager(
          _db.attachedDatabase, _db.bookTtsSettings);
}
