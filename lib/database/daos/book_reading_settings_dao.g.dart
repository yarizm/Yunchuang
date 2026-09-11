// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_reading_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$BookReadingSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTable get books => attachedDatabase.books;
  $BookReadingSettingsTable get bookReadingSettings =>
      attachedDatabase.bookReadingSettings;
  BookReadingSettingsDaoManager get managers =>
      BookReadingSettingsDaoManager(this);
}

class BookReadingSettingsDaoManager {
  final _$BookReadingSettingsDaoMixin _db;
  BookReadingSettingsDaoManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db.attachedDatabase, _db.books);
  $$BookReadingSettingsTableTableManager get bookReadingSettings =>
      $$BookReadingSettingsTableTableManager(
          _db.attachedDatabase, _db.bookReadingSettings);
}
