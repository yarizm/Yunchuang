// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _coverPathMeta =
      const VerificationMeta('coverPath');
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
      'cover_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
      'format', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 10),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileHashMeta =
      const VerificationMeta('fileHash');
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
      'file_hash', aliasedName, true,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 64, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _seriesNameMeta =
      const VerificationMeta('seriesName');
  @override
  late final GeneratedColumn<String> seriesName = GeneratedColumn<String>(
      'series_name', aliasedName, true,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _seriesIndexMeta =
      const VerificationMeta('seriesIndex');
  @override
  late final GeneratedColumn<double> seriesIndex = GeneratedColumn<double>(
      'series_index', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _readingStatusMeta =
      const VerificationMeta('readingStatus');
  @override
  late final GeneratedColumn<String> readingStatus = GeneratedColumn<String>(
      'reading_status', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints:
          'CHECK (reading_status IS NULL OR reading_status IN (\'unread\', \'reading\', \'finished\', \'paused\'))');
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        author,
        coverPath,
        filePath,
        format,
        fileSize,
        description,
        fileHash,
        seriesName,
        seriesIndex,
        readingStatus,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(Insertable<Book> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    }
    if (data.containsKey('cover_path')) {
      context.handle(_coverPathMeta,
          coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta,
          format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('file_hash')) {
      context.handle(_fileHashMeta,
          fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta));
    }
    if (data.containsKey('series_name')) {
      context.handle(
          _seriesNameMeta,
          seriesName.isAcceptableOrUnknown(
              data['series_name']!, _seriesNameMeta));
    }
    if (data.containsKey('series_index')) {
      context.handle(
          _seriesIndexMeta,
          seriesIndex.isAcceptableOrUnknown(
              data['series_index']!, _seriesIndexMeta));
    }
    if (data.containsKey('reading_status')) {
      context.handle(
          _readingStatusMeta,
          readingStatus.isAcceptableOrUnknown(
              data['reading_status']!, _readingStatusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      coverPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_path']),
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      format: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      fileHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_hash']),
      seriesName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}series_name']),
      seriesIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}series_index']),
      readingStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reading_status']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String title;
  final String author;
  final String? coverPath;
  final String filePath;
  final String format;
  final int fileSize;
  final String? description;
  final String? fileHash;
  final String? seriesName;
  final double? seriesIndex;
  final String? readingStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Book(
      {required this.id,
      required this.title,
      required this.author,
      this.coverPath,
      required this.filePath,
      required this.format,
      required this.fileSize,
      this.description,
      this.fileHash,
      this.seriesName,
      this.seriesIndex,
      this.readingStatus,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['file_path'] = Variable<String>(filePath);
    map['format'] = Variable<String>(format);
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || fileHash != null) {
      map['file_hash'] = Variable<String>(fileHash);
    }
    if (!nullToAbsent || seriesName != null) {
      map['series_name'] = Variable<String>(seriesName);
    }
    if (!nullToAbsent || seriesIndex != null) {
      map['series_index'] = Variable<double>(seriesIndex);
    }
    if (!nullToAbsent || readingStatus != null) {
      map['reading_status'] = Variable<String>(readingStatus);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      filePath: Value(filePath),
      format: Value(format),
      fileSize: Value(fileSize),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      fileHash: fileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(fileHash),
      seriesName: seriesName == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesName),
      seriesIndex: seriesIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesIndex),
      readingStatus: readingStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(readingStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Book.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      filePath: serializer.fromJson<String>(json['filePath']),
      format: serializer.fromJson<String>(json['format']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      description: serializer.fromJson<String?>(json['description']),
      fileHash: serializer.fromJson<String?>(json['fileHash']),
      seriesName: serializer.fromJson<String?>(json['seriesName']),
      seriesIndex: serializer.fromJson<double?>(json['seriesIndex']),
      readingStatus: serializer.fromJson<String?>(json['readingStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'coverPath': serializer.toJson<String?>(coverPath),
      'filePath': serializer.toJson<String>(filePath),
      'format': serializer.toJson<String>(format),
      'fileSize': serializer.toJson<int>(fileSize),
      'description': serializer.toJson<String?>(description),
      'fileHash': serializer.toJson<String?>(fileHash),
      'seriesName': serializer.toJson<String?>(seriesName),
      'seriesIndex': serializer.toJson<double?>(seriesIndex),
      'readingStatus': serializer.toJson<String?>(readingStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Book copyWith(
          {int? id,
          String? title,
          String? author,
          Value<String?> coverPath = const Value.absent(),
          String? filePath,
          String? format,
          int? fileSize,
          Value<String?> description = const Value.absent(),
          Value<String?> fileHash = const Value.absent(),
          Value<String?> seriesName = const Value.absent(),
          Value<double?> seriesIndex = const Value.absent(),
          Value<String?> readingStatus = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        coverPath: coverPath.present ? coverPath.value : this.coverPath,
        filePath: filePath ?? this.filePath,
        format: format ?? this.format,
        fileSize: fileSize ?? this.fileSize,
        description: description.present ? description.value : this.description,
        fileHash: fileHash.present ? fileHash.value : this.fileHash,
        seriesName: seriesName.present ? seriesName.value : this.seriesName,
        seriesIndex: seriesIndex.present ? seriesIndex.value : this.seriesIndex,
        readingStatus:
            readingStatus.present ? readingStatus.value : this.readingStatus,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      format: data.format.present ? data.format.value : this.format,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      description:
          data.description.present ? data.description.value : this.description,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      seriesName:
          data.seriesName.present ? data.seriesName.value : this.seriesName,
      seriesIndex:
          data.seriesIndex.present ? data.seriesIndex.value : this.seriesIndex,
      readingStatus: data.readingStatus.present
          ? data.readingStatus.value
          : this.readingStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('fileSize: $fileSize, ')
          ..write('description: $description, ')
          ..write('fileHash: $fileHash, ')
          ..write('seriesName: $seriesName, ')
          ..write('seriesIndex: $seriesIndex, ')
          ..write('readingStatus: $readingStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      author,
      coverPath,
      filePath,
      format,
      fileSize,
      description,
      fileHash,
      seriesName,
      seriesIndex,
      readingStatus,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverPath == this.coverPath &&
          other.filePath == this.filePath &&
          other.format == this.format &&
          other.fileSize == this.fileSize &&
          other.description == this.description &&
          other.fileHash == this.fileHash &&
          other.seriesName == this.seriesName &&
          other.seriesIndex == this.seriesIndex &&
          other.readingStatus == this.readingStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String?> coverPath;
  final Value<String> filePath;
  final Value<String> format;
  final Value<int> fileSize;
  final Value<String?> description;
  final Value<String?> fileHash;
  final Value<String?> seriesName;
  final Value<double?> seriesIndex;
  final Value<String?> readingStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.filePath = const Value.absent(),
    this.format = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.description = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.seriesName = const Value.absent(),
    this.seriesIndex = const Value.absent(),
    this.readingStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    required String filePath,
    required String format,
    required int fileSize,
    this.description = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.seriesName = const Value.absent(),
    this.seriesIndex = const Value.absent(),
    this.readingStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : title = Value(title),
        filePath = Value(filePath),
        format = Value(format),
        fileSize = Value(fileSize);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverPath,
    Expression<String>? filePath,
    Expression<String>? format,
    Expression<int>? fileSize,
    Expression<String>? description,
    Expression<String>? fileHash,
    Expression<String>? seriesName,
    Expression<double>? seriesIndex,
    Expression<String>? readingStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverPath != null) 'cover_path': coverPath,
      if (filePath != null) 'file_path': filePath,
      if (format != null) 'format': format,
      if (fileSize != null) 'file_size': fileSize,
      if (description != null) 'description': description,
      if (fileHash != null) 'file_hash': fileHash,
      if (seriesName != null) 'series_name': seriesName,
      if (seriesIndex != null) 'series_index': seriesIndex,
      if (readingStatus != null) 'reading_status': readingStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BooksCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? author,
      Value<String?>? coverPath,
      Value<String>? filePath,
      Value<String>? format,
      Value<int>? fileSize,
      Value<String?>? description,
      Value<String?>? fileHash,
      Value<String?>? seriesName,
      Value<double?>? seriesIndex,
      Value<String?>? readingStatus,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      description: description ?? this.description,
      fileHash: fileHash ?? this.fileHash,
      seriesName: seriesName ?? this.seriesName,
      seriesIndex: seriesIndex ?? this.seriesIndex,
      readingStatus: readingStatus ?? this.readingStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (seriesName.present) {
      map['series_name'] = Variable<String>(seriesName.value);
    }
    if (seriesIndex.present) {
      map['series_index'] = Variable<double>(seriesIndex.value);
    }
    if (readingStatus.present) {
      map['reading_status'] = Variable<String>(readingStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('filePath: $filePath, ')
          ..write('format: $format, ')
          ..write('fileSize: $fileSize, ')
          ..write('description: $description, ')
          ..write('fileHash: $fileHash, ')
          ..write('seriesName: $seriesName, ')
          ..write('seriesIndex: $seriesIndex, ')
          ..write('readingStatus: $readingStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BookCollectionsTable extends BookCollections
    with TableInfo<$BookCollectionsTable, BookCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, sortOrder, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_collections';
  @override
  VerificationContext validateIntegrity(Insertable<BookCollection> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookCollection(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BookCollectionsTable createAlias(String alias) {
    return $BookCollectionsTable(attachedDatabase, alias);
  }
}

class BookCollection extends DataClass implements Insertable<BookCollection> {
  final int id;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BookCollection(
      {required this.id,
      required this.name,
      required this.sortOrder,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookCollectionsCompanion toCompanion(bool nullToAbsent) {
    return BookCollectionsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookCollection.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookCollection(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookCollection copyWith(
          {int? id,
          String? name,
          int? sortOrder,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      BookCollection(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BookCollection copyWithCompanion(BookCollectionsCompanion data) {
    return BookCollection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookCollection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookCollection &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookCollectionsCompanion extends UpdateCompanion<BookCollection> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BookCollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookCollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<BookCollection> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookCollectionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<int>? sortOrder,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return BookCollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BookCollectionItemsTable extends BookCollectionItems
    with TableInfo<$BookCollectionItemsTable, BookCollectionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookCollectionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta =
      const VerificationMeta('collectionId');
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
      'collection_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES book_collections (id) ON DELETE CASCADE'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [collectionId, bookId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_collection_items';
  @override
  VerificationContext validateIntegrity(Insertable<BookCollectionItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
          _collectionIdMeta,
          collectionId.isAcceptableOrUnknown(
              data['collection_id']!, _collectionIdMeta));
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, bookId};
  @override
  BookCollectionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookCollectionItem(
      collectionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}collection_id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $BookCollectionItemsTable createAlias(String alias) {
    return $BookCollectionItemsTable(attachedDatabase, alias);
  }
}

class BookCollectionItem extends DataClass
    implements Insertable<BookCollectionItem> {
  final int collectionId;
  final int bookId;
  final DateTime addedAt;
  const BookCollectionItem(
      {required this.collectionId,
      required this.bookId,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<int>(collectionId);
    map['book_id'] = Variable<int>(bookId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  BookCollectionItemsCompanion toCompanion(bool nullToAbsent) {
    return BookCollectionItemsCompanion(
      collectionId: Value(collectionId),
      bookId: Value(bookId),
      addedAt: Value(addedAt),
    );
  }

  factory BookCollectionItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookCollectionItem(
      collectionId: serializer.fromJson<int>(json['collectionId']),
      bookId: serializer.fromJson<int>(json['bookId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<int>(collectionId),
      'bookId': serializer.toJson<int>(bookId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  BookCollectionItem copyWith(
          {int? collectionId, int? bookId, DateTime? addedAt}) =>
      BookCollectionItem(
        collectionId: collectionId ?? this.collectionId,
        bookId: bookId ?? this.bookId,
        addedAt: addedAt ?? this.addedAt,
      );
  BookCollectionItem copyWithCompanion(BookCollectionItemsCompanion data) {
    return BookCollectionItem(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookCollectionItem(')
          ..write('collectionId: $collectionId, ')
          ..write('bookId: $bookId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, bookId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookCollectionItem &&
          other.collectionId == this.collectionId &&
          other.bookId == this.bookId &&
          other.addedAt == this.addedAt);
}

class BookCollectionItemsCompanion extends UpdateCompanion<BookCollectionItem> {
  final Value<int> collectionId;
  final Value<int> bookId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const BookCollectionItemsCompanion({
    this.collectionId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookCollectionItemsCompanion.insert({
    required int collectionId,
    required int bookId,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : collectionId = Value(collectionId),
        bookId = Value(bookId);
  static Insertable<BookCollectionItem> custom({
    Expression<int>? collectionId,
    Expression<int>? bookId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (bookId != null) 'book_id': bookId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookCollectionItemsCompanion copyWith(
      {Value<int>? collectionId,
      Value<int>? bookId,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return BookCollectionItemsCompanion(
      collectionId: collectionId ?? this.collectionId,
      bookId: bookId ?? this.bookId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookCollectionItemsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('bookId: $bookId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookTtsSettingsTable extends BookTtsSettings
    with TableInfo<$BookTtsSettingsTable, BookTtsSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookTtsSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _languageMeta =
      const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
      'language', aliasedName, true,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _voiceNameMeta =
      const VerificationMeta('voiceName');
  @override
  late final GeneratedColumn<String> voiceName = GeneratedColumn<String>(
      'voice_name', aliasedName, true,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 300),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _voiceLocaleMeta =
      const VerificationMeta('voiceLocale');
  @override
  late final GeneratedColumn<String> voiceLocale = GeneratedColumn<String>(
      'voice_locale', aliasedName, true,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _speechRateMeta =
      const VerificationMeta('speechRate');
  @override
  late final GeneratedColumn<double> speechRate = GeneratedColumn<double>(
      'speech_rate', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT 0.5 CHECK (speech_rate >= 0.1 AND speech_rate <= 1.0)',
      defaultValue: const CustomExpression('0.5'));
  static const VerificationMeta _sleepTimerOptionMeta =
      const VerificationMeta('sleepTimerOption');
  @override
  late final GeneratedColumn<String> sleepTimerOption = GeneratedColumn<String>(
      'sleep_timer_option', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT \'off\' CHECK (sleep_timer_option IN (\'off\', \'minutes15\', \'minutes30\', \'minutes60\', \'endOfChapter\'))',
      defaultValue: const CustomExpression('\'off\''));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        bookId,
        language,
        voiceName,
        voiceLocale,
        speechRate,
        sleepTimerOption,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_tts_settings';
  @override
  VerificationContext validateIntegrity(Insertable<BookTtsSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('language')) {
      context.handle(_languageMeta,
          language.isAcceptableOrUnknown(data['language']!, _languageMeta));
    }
    if (data.containsKey('voice_name')) {
      context.handle(_voiceNameMeta,
          voiceName.isAcceptableOrUnknown(data['voice_name']!, _voiceNameMeta));
    }
    if (data.containsKey('voice_locale')) {
      context.handle(
          _voiceLocaleMeta,
          voiceLocale.isAcceptableOrUnknown(
              data['voice_locale']!, _voiceLocaleMeta));
    }
    if (data.containsKey('speech_rate')) {
      context.handle(
          _speechRateMeta,
          speechRate.isAcceptableOrUnknown(
              data['speech_rate']!, _speechRateMeta));
    }
    if (data.containsKey('sleep_timer_option')) {
      context.handle(
          _sleepTimerOptionMeta,
          sleepTimerOption.isAcceptableOrUnknown(
              data['sleep_timer_option']!, _sleepTimerOptionMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  BookTtsSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookTtsSetting(
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id'])!,
      language: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}language']),
      voiceName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}voice_name']),
      voiceLocale: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}voice_locale']),
      speechRate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}speech_rate'])!,
      sleepTimerOption: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sleep_timer_option'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BookTtsSettingsTable createAlias(String alias) {
    return $BookTtsSettingsTable(attachedDatabase, alias);
  }
}

class BookTtsSetting extends DataClass implements Insertable<BookTtsSetting> {
  final int bookId;
  final String? language;
  final String? voiceName;
  final String? voiceLocale;
  final double speechRate;
  final String sleepTimerOption;
  final DateTime updatedAt;
  const BookTtsSetting(
      {required this.bookId,
      this.language,
      this.voiceName,
      this.voiceLocale,
      required this.speechRate,
      required this.sleepTimerOption,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<int>(bookId);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || voiceName != null) {
      map['voice_name'] = Variable<String>(voiceName);
    }
    if (!nullToAbsent || voiceLocale != null) {
      map['voice_locale'] = Variable<String>(voiceLocale);
    }
    map['speech_rate'] = Variable<double>(speechRate);
    map['sleep_timer_option'] = Variable<String>(sleepTimerOption);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookTtsSettingsCompanion toCompanion(bool nullToAbsent) {
    return BookTtsSettingsCompanion(
      bookId: Value(bookId),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      voiceName: voiceName == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceName),
      voiceLocale: voiceLocale == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceLocale),
      speechRate: Value(speechRate),
      sleepTimerOption: Value(sleepTimerOption),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookTtsSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookTtsSetting(
      bookId: serializer.fromJson<int>(json['bookId']),
      language: serializer.fromJson<String?>(json['language']),
      voiceName: serializer.fromJson<String?>(json['voiceName']),
      voiceLocale: serializer.fromJson<String?>(json['voiceLocale']),
      speechRate: serializer.fromJson<double>(json['speechRate']),
      sleepTimerOption: serializer.fromJson<String>(json['sleepTimerOption']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<int>(bookId),
      'language': serializer.toJson<String?>(language),
      'voiceName': serializer.toJson<String?>(voiceName),
      'voiceLocale': serializer.toJson<String?>(voiceLocale),
      'speechRate': serializer.toJson<double>(speechRate),
      'sleepTimerOption': serializer.toJson<String>(sleepTimerOption),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookTtsSetting copyWith(
          {int? bookId,
          Value<String?> language = const Value.absent(),
          Value<String?> voiceName = const Value.absent(),
          Value<String?> voiceLocale = const Value.absent(),
          double? speechRate,
          String? sleepTimerOption,
          DateTime? updatedAt}) =>
      BookTtsSetting(
        bookId: bookId ?? this.bookId,
        language: language.present ? language.value : this.language,
        voiceName: voiceName.present ? voiceName.value : this.voiceName,
        voiceLocale: voiceLocale.present ? voiceLocale.value : this.voiceLocale,
        speechRate: speechRate ?? this.speechRate,
        sleepTimerOption: sleepTimerOption ?? this.sleepTimerOption,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BookTtsSetting copyWithCompanion(BookTtsSettingsCompanion data) {
    return BookTtsSetting(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      language: data.language.present ? data.language.value : this.language,
      voiceName: data.voiceName.present ? data.voiceName.value : this.voiceName,
      voiceLocale:
          data.voiceLocale.present ? data.voiceLocale.value : this.voiceLocale,
      speechRate:
          data.speechRate.present ? data.speechRate.value : this.speechRate,
      sleepTimerOption: data.sleepTimerOption.present
          ? data.sleepTimerOption.value
          : this.sleepTimerOption,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookTtsSetting(')
          ..write('bookId: $bookId, ')
          ..write('language: $language, ')
          ..write('voiceName: $voiceName, ')
          ..write('voiceLocale: $voiceLocale, ')
          ..write('speechRate: $speechRate, ')
          ..write('sleepTimerOption: $sleepTimerOption, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, language, voiceName, voiceLocale,
      speechRate, sleepTimerOption, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookTtsSetting &&
          other.bookId == this.bookId &&
          other.language == this.language &&
          other.voiceName == this.voiceName &&
          other.voiceLocale == this.voiceLocale &&
          other.speechRate == this.speechRate &&
          other.sleepTimerOption == this.sleepTimerOption &&
          other.updatedAt == this.updatedAt);
}

class BookTtsSettingsCompanion extends UpdateCompanion<BookTtsSetting> {
  final Value<int> bookId;
  final Value<String?> language;
  final Value<String?> voiceName;
  final Value<String?> voiceLocale;
  final Value<double> speechRate;
  final Value<String> sleepTimerOption;
  final Value<DateTime> updatedAt;
  const BookTtsSettingsCompanion({
    this.bookId = const Value.absent(),
    this.language = const Value.absent(),
    this.voiceName = const Value.absent(),
    this.voiceLocale = const Value.absent(),
    this.speechRate = const Value.absent(),
    this.sleepTimerOption = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookTtsSettingsCompanion.insert({
    this.bookId = const Value.absent(),
    this.language = const Value.absent(),
    this.voiceName = const Value.absent(),
    this.voiceLocale = const Value.absent(),
    this.speechRate = const Value.absent(),
    this.sleepTimerOption = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<BookTtsSetting> custom({
    Expression<int>? bookId,
    Expression<String>? language,
    Expression<String>? voiceName,
    Expression<String>? voiceLocale,
    Expression<double>? speechRate,
    Expression<String>? sleepTimerOption,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (language != null) 'language': language,
      if (voiceName != null) 'voice_name': voiceName,
      if (voiceLocale != null) 'voice_locale': voiceLocale,
      if (speechRate != null) 'speech_rate': speechRate,
      if (sleepTimerOption != null) 'sleep_timer_option': sleepTimerOption,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookTtsSettingsCompanion copyWith(
      {Value<int>? bookId,
      Value<String?>? language,
      Value<String?>? voiceName,
      Value<String?>? voiceLocale,
      Value<double>? speechRate,
      Value<String>? sleepTimerOption,
      Value<DateTime>? updatedAt}) {
    return BookTtsSettingsCompanion(
      bookId: bookId ?? this.bookId,
      language: language ?? this.language,
      voiceName: voiceName ?? this.voiceName,
      voiceLocale: voiceLocale ?? this.voiceLocale,
      speechRate: speechRate ?? this.speechRate,
      sleepTimerOption: sleepTimerOption ?? this.sleepTimerOption,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (voiceName.present) {
      map['voice_name'] = Variable<String>(voiceName.value);
    }
    if (voiceLocale.present) {
      map['voice_locale'] = Variable<String>(voiceLocale.value);
    }
    if (speechRate.present) {
      map['speech_rate'] = Variable<double>(speechRate.value);
    }
    if (sleepTimerOption.present) {
      map['sleep_timer_option'] = Variable<String>(sleepTimerOption.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookTtsSettingsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('language: $language, ')
          ..write('voiceName: $voiceName, ')
          ..write('voiceLocale: $voiceLocale, ')
          ..write('speechRate: $speechRate, ')
          ..write('sleepTimerOption: $sleepTimerOption, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BookReadingSettingsTable extends BookReadingSettings
    with TableInfo<$BookReadingSettingsTable, BookReadingSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookReadingSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _fontSizeMeta =
      const VerificationMeta('fontSize');
  @override
  late final GeneratedColumn<double> fontSize = GeneratedColumn<double>(
      'font_size', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL CHECK (font_size >= 12 AND font_size <= 28)');
  static const VerificationMeta _lineHeightMeta =
      const VerificationMeta('lineHeight');
  @override
  late final GeneratedColumn<double> lineHeight = GeneratedColumn<double>(
      'line_height', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL CHECK (line_height >= 1.2 AND line_height <= 2.5)');
  static const VerificationMeta _marginMeta = const VerificationMeta('margin');
  @override
  late final GeneratedColumn<double> margin = GeneratedColumn<double>(
      'margin', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL CHECK (margin >= 8 AND margin <= 48)');
  static const VerificationMeta _fontFamilyMeta =
      const VerificationMeta('fontFamily');
  @override
  late final GeneratedColumn<String> fontFamily = GeneratedColumn<String>(
      'font_family', aliasedName, true,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _paragraphSpacingMeta =
      const VerificationMeta('paragraphSpacing');
  @override
  late final GeneratedColumn<double> paragraphSpacing = GeneratedColumn<double>(
      'paragraph_spacing', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL CHECK (paragraph_spacing >= 0 AND paragraph_spacing <= 32)');
  static const VerificationMeta _letterSpacingMeta =
      const VerificationMeta('letterSpacing');
  @override
  late final GeneratedColumn<double> letterSpacing = GeneratedColumn<double>(
      'letter_spacing', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL CHECK (letter_spacing >= -1 AND letter_spacing <= 3)');
  static const VerificationMeta _wordSpacingMeta =
      const VerificationMeta('wordSpacing');
  @override
  late final GeneratedColumn<double> wordSpacing = GeneratedColumn<double>(
      'word_spacing', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT 0 CHECK (word_spacing >= -1 AND word_spacing <= 8)',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _boldTextMeta =
      const VerificationMeta('boldText');
  @override
  late final GeneratedColumn<bool> boldText = GeneratedColumn<bool>(
      'bold_text', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("bold_text" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _textAlignmentMeta =
      const VerificationMeta('textAlignment');
  @override
  late final GeneratedColumn<String> textAlignment = GeneratedColumn<String>(
      'text_alignment', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT \'start\' CHECK (text_alignment IN (\'start\', \'justify\'))',
      defaultValue: const CustomExpression('\'start\''));
  static const VerificationMeta _paragraphIndentMeta =
      const VerificationMeta('paragraphIndent');
  @override
  late final GeneratedColumn<int> paragraphIndent = GeneratedColumn<int>(
      'paragraph_indent', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT 0 CHECK (paragraph_indent >= 0 AND paragraph_indent <= 4)',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _pdfCropAmountMeta =
      const VerificationMeta('pdfCropAmount');
  @override
  late final GeneratedColumn<double> pdfCropAmount = GeneratedColumn<double>(
      'pdf_crop_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT 0 CHECK (pdf_crop_amount >= 0 AND pdf_crop_amount <= 0.2)',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _pdfContrastMeta =
      const VerificationMeta('pdfContrast');
  @override
  late final GeneratedColumn<double> pdfContrast = GeneratedColumn<double>(
      'pdf_contrast', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT 1 CHECK (pdf_contrast >= 1 AND pdf_contrast <= 2)',
      defaultValue: const CustomExpression('1'));
  static const VerificationMeta _pdfPageLayoutMeta =
      const VerificationMeta('pdfPageLayout');
  @override
  late final GeneratedColumn<String> pdfPageLayout = GeneratedColumn<String>(
      'pdf_page_layout', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT \'single\' CHECK (pdf_page_layout IN (\'single\', \'double\'))',
      defaultValue: const CustomExpression('\'single\''));
  static const VerificationMeta _topContentPaddingMeta =
      const VerificationMeta('topContentPadding');
  @override
  late final GeneratedColumn<double> topContentPadding = GeneratedColumn<
          double>('top_content_padding', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL CHECK (top_content_padding >= 0 AND top_content_padding <= 96)');
  static const VerificationMeta _pageTurnEffectMeta =
      const VerificationMeta('pageTurnEffect');
  @override
  late final GeneratedColumn<String> pageTurnEffect = GeneratedColumn<String>(
      'page_turn_effect', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL CHECK (page_turn_effect IN (\'curl\', \'slide\', \'plain\'))');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        bookId,
        fontSize,
        lineHeight,
        margin,
        fontFamily,
        paragraphSpacing,
        letterSpacing,
        wordSpacing,
        boldText,
        textAlignment,
        paragraphIndent,
        pdfCropAmount,
        pdfContrast,
        pdfPageLayout,
        topContentPadding,
        pageTurnEffect,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_reading_settings';
  @override
  VerificationContext validateIntegrity(Insertable<BookReadingSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('font_size')) {
      context.handle(_fontSizeMeta,
          fontSize.isAcceptableOrUnknown(data['font_size']!, _fontSizeMeta));
    } else if (isInserting) {
      context.missing(_fontSizeMeta);
    }
    if (data.containsKey('line_height')) {
      context.handle(
          _lineHeightMeta,
          lineHeight.isAcceptableOrUnknown(
              data['line_height']!, _lineHeightMeta));
    } else if (isInserting) {
      context.missing(_lineHeightMeta);
    }
    if (data.containsKey('margin')) {
      context.handle(_marginMeta,
          margin.isAcceptableOrUnknown(data['margin']!, _marginMeta));
    } else if (isInserting) {
      context.missing(_marginMeta);
    }
    if (data.containsKey('font_family')) {
      context.handle(
          _fontFamilyMeta,
          fontFamily.isAcceptableOrUnknown(
              data['font_family']!, _fontFamilyMeta));
    }
    if (data.containsKey('paragraph_spacing')) {
      context.handle(
          _paragraphSpacingMeta,
          paragraphSpacing.isAcceptableOrUnknown(
              data['paragraph_spacing']!, _paragraphSpacingMeta));
    } else if (isInserting) {
      context.missing(_paragraphSpacingMeta);
    }
    if (data.containsKey('letter_spacing')) {
      context.handle(
          _letterSpacingMeta,
          letterSpacing.isAcceptableOrUnknown(
              data['letter_spacing']!, _letterSpacingMeta));
    } else if (isInserting) {
      context.missing(_letterSpacingMeta);
    }
    if (data.containsKey('word_spacing')) {
      context.handle(
          _wordSpacingMeta,
          wordSpacing.isAcceptableOrUnknown(
              data['word_spacing']!, _wordSpacingMeta));
    }
    if (data.containsKey('bold_text')) {
      context.handle(_boldTextMeta,
          boldText.isAcceptableOrUnknown(data['bold_text']!, _boldTextMeta));
    }
    if (data.containsKey('text_alignment')) {
      context.handle(
          _textAlignmentMeta,
          textAlignment.isAcceptableOrUnknown(
              data['text_alignment']!, _textAlignmentMeta));
    }
    if (data.containsKey('paragraph_indent')) {
      context.handle(
          _paragraphIndentMeta,
          paragraphIndent.isAcceptableOrUnknown(
              data['paragraph_indent']!, _paragraphIndentMeta));
    }
    if (data.containsKey('pdf_crop_amount')) {
      context.handle(
          _pdfCropAmountMeta,
          pdfCropAmount.isAcceptableOrUnknown(
              data['pdf_crop_amount']!, _pdfCropAmountMeta));
    }
    if (data.containsKey('pdf_contrast')) {
      context.handle(
          _pdfContrastMeta,
          pdfContrast.isAcceptableOrUnknown(
              data['pdf_contrast']!, _pdfContrastMeta));
    }
    if (data.containsKey('pdf_page_layout')) {
      context.handle(
          _pdfPageLayoutMeta,
          pdfPageLayout.isAcceptableOrUnknown(
              data['pdf_page_layout']!, _pdfPageLayoutMeta));
    }
    if (data.containsKey('top_content_padding')) {
      context.handle(
          _topContentPaddingMeta,
          topContentPadding.isAcceptableOrUnknown(
              data['top_content_padding']!, _topContentPaddingMeta));
    } else if (isInserting) {
      context.missing(_topContentPaddingMeta);
    }
    if (data.containsKey('page_turn_effect')) {
      context.handle(
          _pageTurnEffectMeta,
          pageTurnEffect.isAcceptableOrUnknown(
              data['page_turn_effect']!, _pageTurnEffectMeta));
    } else if (isInserting) {
      context.missing(_pageTurnEffectMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  BookReadingSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookReadingSetting(
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id'])!,
      fontSize: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}font_size'])!,
      lineHeight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}line_height'])!,
      margin: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}margin'])!,
      fontFamily: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}font_family']),
      paragraphSpacing: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}paragraph_spacing'])!,
      letterSpacing: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}letter_spacing'])!,
      wordSpacing: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}word_spacing'])!,
      boldText: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}bold_text'])!,
      textAlignment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text_alignment'])!,
      paragraphIndent: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paragraph_indent'])!,
      pdfCropAmount: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}pdf_crop_amount'])!,
      pdfContrast: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}pdf_contrast'])!,
      pdfPageLayout: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}pdf_page_layout'])!,
      topContentPadding: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}top_content_padding'])!,
      pageTurnEffect: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}page_turn_effect'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BookReadingSettingsTable createAlias(String alias) {
    return $BookReadingSettingsTable(attachedDatabase, alias);
  }
}

class BookReadingSetting extends DataClass
    implements Insertable<BookReadingSetting> {
  final int bookId;
  final double fontSize;
  final double lineHeight;
  final double margin;
  final String? fontFamily;
  final double paragraphSpacing;
  final double letterSpacing;
  final double wordSpacing;
  final bool boldText;
  final String textAlignment;
  final int paragraphIndent;
  final double pdfCropAmount;
  final double pdfContrast;
  final String pdfPageLayout;
  final double topContentPadding;
  final String pageTurnEffect;
  final DateTime updatedAt;
  const BookReadingSetting(
      {required this.bookId,
      required this.fontSize,
      required this.lineHeight,
      required this.margin,
      this.fontFamily,
      required this.paragraphSpacing,
      required this.letterSpacing,
      required this.wordSpacing,
      required this.boldText,
      required this.textAlignment,
      required this.paragraphIndent,
      required this.pdfCropAmount,
      required this.pdfContrast,
      required this.pdfPageLayout,
      required this.topContentPadding,
      required this.pageTurnEffect,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<int>(bookId);
    map['font_size'] = Variable<double>(fontSize);
    map['line_height'] = Variable<double>(lineHeight);
    map['margin'] = Variable<double>(margin);
    if (!nullToAbsent || fontFamily != null) {
      map['font_family'] = Variable<String>(fontFamily);
    }
    map['paragraph_spacing'] = Variable<double>(paragraphSpacing);
    map['letter_spacing'] = Variable<double>(letterSpacing);
    map['word_spacing'] = Variable<double>(wordSpacing);
    map['bold_text'] = Variable<bool>(boldText);
    map['text_alignment'] = Variable<String>(textAlignment);
    map['paragraph_indent'] = Variable<int>(paragraphIndent);
    map['pdf_crop_amount'] = Variable<double>(pdfCropAmount);
    map['pdf_contrast'] = Variable<double>(pdfContrast);
    map['pdf_page_layout'] = Variable<String>(pdfPageLayout);
    map['top_content_padding'] = Variable<double>(topContentPadding);
    map['page_turn_effect'] = Variable<String>(pageTurnEffect);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookReadingSettingsCompanion toCompanion(bool nullToAbsent) {
    return BookReadingSettingsCompanion(
      bookId: Value(bookId),
      fontSize: Value(fontSize),
      lineHeight: Value(lineHeight),
      margin: Value(margin),
      fontFamily: fontFamily == null && nullToAbsent
          ? const Value.absent()
          : Value(fontFamily),
      paragraphSpacing: Value(paragraphSpacing),
      letterSpacing: Value(letterSpacing),
      wordSpacing: Value(wordSpacing),
      boldText: Value(boldText),
      textAlignment: Value(textAlignment),
      paragraphIndent: Value(paragraphIndent),
      pdfCropAmount: Value(pdfCropAmount),
      pdfContrast: Value(pdfContrast),
      pdfPageLayout: Value(pdfPageLayout),
      topContentPadding: Value(topContentPadding),
      pageTurnEffect: Value(pageTurnEffect),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookReadingSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookReadingSetting(
      bookId: serializer.fromJson<int>(json['bookId']),
      fontSize: serializer.fromJson<double>(json['fontSize']),
      lineHeight: serializer.fromJson<double>(json['lineHeight']),
      margin: serializer.fromJson<double>(json['margin']),
      fontFamily: serializer.fromJson<String?>(json['fontFamily']),
      paragraphSpacing: serializer.fromJson<double>(json['paragraphSpacing']),
      letterSpacing: serializer.fromJson<double>(json['letterSpacing']),
      wordSpacing: serializer.fromJson<double>(json['wordSpacing']),
      boldText: serializer.fromJson<bool>(json['boldText']),
      textAlignment: serializer.fromJson<String>(json['textAlignment']),
      paragraphIndent: serializer.fromJson<int>(json['paragraphIndent']),
      pdfCropAmount: serializer.fromJson<double>(json['pdfCropAmount']),
      pdfContrast: serializer.fromJson<double>(json['pdfContrast']),
      pdfPageLayout: serializer.fromJson<String>(json['pdfPageLayout']),
      topContentPadding: serializer.fromJson<double>(json['topContentPadding']),
      pageTurnEffect: serializer.fromJson<String>(json['pageTurnEffect']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<int>(bookId),
      'fontSize': serializer.toJson<double>(fontSize),
      'lineHeight': serializer.toJson<double>(lineHeight),
      'margin': serializer.toJson<double>(margin),
      'fontFamily': serializer.toJson<String?>(fontFamily),
      'paragraphSpacing': serializer.toJson<double>(paragraphSpacing),
      'letterSpacing': serializer.toJson<double>(letterSpacing),
      'wordSpacing': serializer.toJson<double>(wordSpacing),
      'boldText': serializer.toJson<bool>(boldText),
      'textAlignment': serializer.toJson<String>(textAlignment),
      'paragraphIndent': serializer.toJson<int>(paragraphIndent),
      'pdfCropAmount': serializer.toJson<double>(pdfCropAmount),
      'pdfContrast': serializer.toJson<double>(pdfContrast),
      'pdfPageLayout': serializer.toJson<String>(pdfPageLayout),
      'topContentPadding': serializer.toJson<double>(topContentPadding),
      'pageTurnEffect': serializer.toJson<String>(pageTurnEffect),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookReadingSetting copyWith(
          {int? bookId,
          double? fontSize,
          double? lineHeight,
          double? margin,
          Value<String?> fontFamily = const Value.absent(),
          double? paragraphSpacing,
          double? letterSpacing,
          double? wordSpacing,
          bool? boldText,
          String? textAlignment,
          int? paragraphIndent,
          double? pdfCropAmount,
          double? pdfContrast,
          String? pdfPageLayout,
          double? topContentPadding,
          String? pageTurnEffect,
          DateTime? updatedAt}) =>
      BookReadingSetting(
        bookId: bookId ?? this.bookId,
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        margin: margin ?? this.margin,
        fontFamily: fontFamily.present ? fontFamily.value : this.fontFamily,
        paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        wordSpacing: wordSpacing ?? this.wordSpacing,
        boldText: boldText ?? this.boldText,
        textAlignment: textAlignment ?? this.textAlignment,
        paragraphIndent: paragraphIndent ?? this.paragraphIndent,
        pdfCropAmount: pdfCropAmount ?? this.pdfCropAmount,
        pdfContrast: pdfContrast ?? this.pdfContrast,
        pdfPageLayout: pdfPageLayout ?? this.pdfPageLayout,
        topContentPadding: topContentPadding ?? this.topContentPadding,
        pageTurnEffect: pageTurnEffect ?? this.pageTurnEffect,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BookReadingSetting copyWithCompanion(BookReadingSettingsCompanion data) {
    return BookReadingSetting(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      fontSize: data.fontSize.present ? data.fontSize.value : this.fontSize,
      lineHeight:
          data.lineHeight.present ? data.lineHeight.value : this.lineHeight,
      margin: data.margin.present ? data.margin.value : this.margin,
      fontFamily:
          data.fontFamily.present ? data.fontFamily.value : this.fontFamily,
      paragraphSpacing: data.paragraphSpacing.present
          ? data.paragraphSpacing.value
          : this.paragraphSpacing,
      letterSpacing: data.letterSpacing.present
          ? data.letterSpacing.value
          : this.letterSpacing,
      wordSpacing:
          data.wordSpacing.present ? data.wordSpacing.value : this.wordSpacing,
      boldText: data.boldText.present ? data.boldText.value : this.boldText,
      textAlignment: data.textAlignment.present
          ? data.textAlignment.value
          : this.textAlignment,
      paragraphIndent: data.paragraphIndent.present
          ? data.paragraphIndent.value
          : this.paragraphIndent,
      pdfCropAmount: data.pdfCropAmount.present
          ? data.pdfCropAmount.value
          : this.pdfCropAmount,
      pdfContrast:
          data.pdfContrast.present ? data.pdfContrast.value : this.pdfContrast,
      pdfPageLayout: data.pdfPageLayout.present
          ? data.pdfPageLayout.value
          : this.pdfPageLayout,
      topContentPadding: data.topContentPadding.present
          ? data.topContentPadding.value
          : this.topContentPadding,
      pageTurnEffect: data.pageTurnEffect.present
          ? data.pageTurnEffect.value
          : this.pageTurnEffect,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookReadingSetting(')
          ..write('bookId: $bookId, ')
          ..write('fontSize: $fontSize, ')
          ..write('lineHeight: $lineHeight, ')
          ..write('margin: $margin, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('paragraphSpacing: $paragraphSpacing, ')
          ..write('letterSpacing: $letterSpacing, ')
          ..write('wordSpacing: $wordSpacing, ')
          ..write('boldText: $boldText, ')
          ..write('textAlignment: $textAlignment, ')
          ..write('paragraphIndent: $paragraphIndent, ')
          ..write('pdfCropAmount: $pdfCropAmount, ')
          ..write('pdfContrast: $pdfContrast, ')
          ..write('pdfPageLayout: $pdfPageLayout, ')
          ..write('topContentPadding: $topContentPadding, ')
          ..write('pageTurnEffect: $pageTurnEffect, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      bookId,
      fontSize,
      lineHeight,
      margin,
      fontFamily,
      paragraphSpacing,
      letterSpacing,
      wordSpacing,
      boldText,
      textAlignment,
      paragraphIndent,
      pdfCropAmount,
      pdfContrast,
      pdfPageLayout,
      topContentPadding,
      pageTurnEffect,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookReadingSetting &&
          other.bookId == this.bookId &&
          other.fontSize == this.fontSize &&
          other.lineHeight == this.lineHeight &&
          other.margin == this.margin &&
          other.fontFamily == this.fontFamily &&
          other.paragraphSpacing == this.paragraphSpacing &&
          other.letterSpacing == this.letterSpacing &&
          other.wordSpacing == this.wordSpacing &&
          other.boldText == this.boldText &&
          other.textAlignment == this.textAlignment &&
          other.paragraphIndent == this.paragraphIndent &&
          other.pdfCropAmount == this.pdfCropAmount &&
          other.pdfContrast == this.pdfContrast &&
          other.pdfPageLayout == this.pdfPageLayout &&
          other.topContentPadding == this.topContentPadding &&
          other.pageTurnEffect == this.pageTurnEffect &&
          other.updatedAt == this.updatedAt);
}

class BookReadingSettingsCompanion extends UpdateCompanion<BookReadingSetting> {
  final Value<int> bookId;
  final Value<double> fontSize;
  final Value<double> lineHeight;
  final Value<double> margin;
  final Value<String?> fontFamily;
  final Value<double> paragraphSpacing;
  final Value<double> letterSpacing;
  final Value<double> wordSpacing;
  final Value<bool> boldText;
  final Value<String> textAlignment;
  final Value<int> paragraphIndent;
  final Value<double> pdfCropAmount;
  final Value<double> pdfContrast;
  final Value<String> pdfPageLayout;
  final Value<double> topContentPadding;
  final Value<String> pageTurnEffect;
  final Value<DateTime> updatedAt;
  const BookReadingSettingsCompanion({
    this.bookId = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.lineHeight = const Value.absent(),
    this.margin = const Value.absent(),
    this.fontFamily = const Value.absent(),
    this.paragraphSpacing = const Value.absent(),
    this.letterSpacing = const Value.absent(),
    this.wordSpacing = const Value.absent(),
    this.boldText = const Value.absent(),
    this.textAlignment = const Value.absent(),
    this.paragraphIndent = const Value.absent(),
    this.pdfCropAmount = const Value.absent(),
    this.pdfContrast = const Value.absent(),
    this.pdfPageLayout = const Value.absent(),
    this.topContentPadding = const Value.absent(),
    this.pageTurnEffect = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookReadingSettingsCompanion.insert({
    this.bookId = const Value.absent(),
    required double fontSize,
    required double lineHeight,
    required double margin,
    this.fontFamily = const Value.absent(),
    required double paragraphSpacing,
    required double letterSpacing,
    this.wordSpacing = const Value.absent(),
    this.boldText = const Value.absent(),
    this.textAlignment = const Value.absent(),
    this.paragraphIndent = const Value.absent(),
    this.pdfCropAmount = const Value.absent(),
    this.pdfContrast = const Value.absent(),
    this.pdfPageLayout = const Value.absent(),
    required double topContentPadding,
    required String pageTurnEffect,
    this.updatedAt = const Value.absent(),
  })  : fontSize = Value(fontSize),
        lineHeight = Value(lineHeight),
        margin = Value(margin),
        paragraphSpacing = Value(paragraphSpacing),
        letterSpacing = Value(letterSpacing),
        topContentPadding = Value(topContentPadding),
        pageTurnEffect = Value(pageTurnEffect);
  static Insertable<BookReadingSetting> custom({
    Expression<int>? bookId,
    Expression<double>? fontSize,
    Expression<double>? lineHeight,
    Expression<double>? margin,
    Expression<String>? fontFamily,
    Expression<double>? paragraphSpacing,
    Expression<double>? letterSpacing,
    Expression<double>? wordSpacing,
    Expression<bool>? boldText,
    Expression<String>? textAlignment,
    Expression<int>? paragraphIndent,
    Expression<double>? pdfCropAmount,
    Expression<double>? pdfContrast,
    Expression<String>? pdfPageLayout,
    Expression<double>? topContentPadding,
    Expression<String>? pageTurnEffect,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (fontSize != null) 'font_size': fontSize,
      if (lineHeight != null) 'line_height': lineHeight,
      if (margin != null) 'margin': margin,
      if (fontFamily != null) 'font_family': fontFamily,
      if (paragraphSpacing != null) 'paragraph_spacing': paragraphSpacing,
      if (letterSpacing != null) 'letter_spacing': letterSpacing,
      if (wordSpacing != null) 'word_spacing': wordSpacing,
      if (boldText != null) 'bold_text': boldText,
      if (textAlignment != null) 'text_alignment': textAlignment,
      if (paragraphIndent != null) 'paragraph_indent': paragraphIndent,
      if (pdfCropAmount != null) 'pdf_crop_amount': pdfCropAmount,
      if (pdfContrast != null) 'pdf_contrast': pdfContrast,
      if (pdfPageLayout != null) 'pdf_page_layout': pdfPageLayout,
      if (topContentPadding != null) 'top_content_padding': topContentPadding,
      if (pageTurnEffect != null) 'page_turn_effect': pageTurnEffect,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookReadingSettingsCompanion copyWith(
      {Value<int>? bookId,
      Value<double>? fontSize,
      Value<double>? lineHeight,
      Value<double>? margin,
      Value<String?>? fontFamily,
      Value<double>? paragraphSpacing,
      Value<double>? letterSpacing,
      Value<double>? wordSpacing,
      Value<bool>? boldText,
      Value<String>? textAlignment,
      Value<int>? paragraphIndent,
      Value<double>? pdfCropAmount,
      Value<double>? pdfContrast,
      Value<String>? pdfPageLayout,
      Value<double>? topContentPadding,
      Value<String>? pageTurnEffect,
      Value<DateTime>? updatedAt}) {
    return BookReadingSettingsCompanion(
      bookId: bookId ?? this.bookId,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      margin: margin ?? this.margin,
      fontFamily: fontFamily ?? this.fontFamily,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      boldText: boldText ?? this.boldText,
      textAlignment: textAlignment ?? this.textAlignment,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      pdfCropAmount: pdfCropAmount ?? this.pdfCropAmount,
      pdfContrast: pdfContrast ?? this.pdfContrast,
      pdfPageLayout: pdfPageLayout ?? this.pdfPageLayout,
      topContentPadding: topContentPadding ?? this.topContentPadding,
      pageTurnEffect: pageTurnEffect ?? this.pageTurnEffect,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (fontSize.present) {
      map['font_size'] = Variable<double>(fontSize.value);
    }
    if (lineHeight.present) {
      map['line_height'] = Variable<double>(lineHeight.value);
    }
    if (margin.present) {
      map['margin'] = Variable<double>(margin.value);
    }
    if (fontFamily.present) {
      map['font_family'] = Variable<String>(fontFamily.value);
    }
    if (paragraphSpacing.present) {
      map['paragraph_spacing'] = Variable<double>(paragraphSpacing.value);
    }
    if (letterSpacing.present) {
      map['letter_spacing'] = Variable<double>(letterSpacing.value);
    }
    if (wordSpacing.present) {
      map['word_spacing'] = Variable<double>(wordSpacing.value);
    }
    if (boldText.present) {
      map['bold_text'] = Variable<bool>(boldText.value);
    }
    if (textAlignment.present) {
      map['text_alignment'] = Variable<String>(textAlignment.value);
    }
    if (paragraphIndent.present) {
      map['paragraph_indent'] = Variable<int>(paragraphIndent.value);
    }
    if (pdfCropAmount.present) {
      map['pdf_crop_amount'] = Variable<double>(pdfCropAmount.value);
    }
    if (pdfContrast.present) {
      map['pdf_contrast'] = Variable<double>(pdfContrast.value);
    }
    if (pdfPageLayout.present) {
      map['pdf_page_layout'] = Variable<String>(pdfPageLayout.value);
    }
    if (topContentPadding.present) {
      map['top_content_padding'] = Variable<double>(topContentPadding.value);
    }
    if (pageTurnEffect.present) {
      map['page_turn_effect'] = Variable<String>(pageTurnEffect.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookReadingSettingsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('fontSize: $fontSize, ')
          ..write('lineHeight: $lineHeight, ')
          ..write('margin: $margin, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('paragraphSpacing: $paragraphSpacing, ')
          ..write('letterSpacing: $letterSpacing, ')
          ..write('wordSpacing: $wordSpacing, ')
          ..write('boldText: $boldText, ')
          ..write('textAlignment: $textAlignment, ')
          ..write('paragraphIndent: $paragraphIndent, ')
          ..write('pdfCropAmount: $pdfCropAmount, ')
          ..write('pdfContrast: $pdfContrast, ')
          ..write('pdfPageLayout: $pdfPageLayout, ')
          ..write('topContentPadding: $topContentPadding, ')
          ..write('pageTurnEffect: $pageTurnEffect, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contentIndexMeta =
      const VerificationMeta('contentIndex');
  @override
  late final GeneratedColumn<int> contentIndex = GeneratedColumn<int>(
      'content_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, bookId, title, content, contentIndex, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(Insertable<Chapter> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('content_index')) {
      context.handle(
          _contentIndexMeta,
          contentIndex.isAcceptableOrUnknown(
              data['content_index']!, _contentIndexMeta));
    } else if (isInserting) {
      context.missing(_contentIndexMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      contentIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}content_index'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final int id;
  final int bookId;
  final String title;
  final String? content;
  final int contentIndex;
  final int sortOrder;
  const Chapter(
      {required this.id,
      required this.bookId,
      required this.title,
      this.content,
      required this.contentIndex,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['content_index'] = Variable<int>(contentIndex);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      title: Value(title),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      contentIndex: Value(contentIndex),
      sortOrder: Value(sortOrder),
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String?>(json['content']),
      contentIndex: serializer.fromJson<int>(json['contentIndex']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String?>(content),
      'contentIndex': serializer.toJson<int>(contentIndex),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Chapter copyWith(
          {int? id,
          int? bookId,
          String? title,
          Value<String?> content = const Value.absent(),
          int? contentIndex,
          int? sortOrder}) =>
      Chapter(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        title: title ?? this.title,
        content: content.present ? content.value : this.content,
        contentIndex: contentIndex ?? this.contentIndex,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      contentIndex: data.contentIndex.present
          ? data.contentIndex.value
          : this.contentIndex,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentIndex: $contentIndex, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, title, content, contentIndex, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.content == this.content &&
          other.contentIndex == this.contentIndex &&
          other.sortOrder == this.sortOrder);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<String> title;
  final Value<String?> content;
  final Value<int> contentIndex;
  final Value<int> sortOrder;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.contentIndex = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    required String title,
    this.content = const Value.absent(),
    required int contentIndex,
    required int sortOrder,
  })  : bookId = Value(bookId),
        title = Value(title),
        contentIndex = Value(contentIndex),
        sortOrder = Value(sortOrder);
  static Insertable<Chapter> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? contentIndex,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (contentIndex != null) 'content_index': contentIndex,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ChaptersCompanion copyWith(
      {Value<int>? id,
      Value<int>? bookId,
      Value<String>? title,
      Value<String?>? content,
      Value<int>? contentIndex,
      Value<int>? sortOrder}) {
    return ChaptersCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      content: content ?? this.content,
      contentIndex: contentIndex ?? this.contentIndex,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (contentIndex.present) {
      map['content_index'] = Variable<int>(contentIndex.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentIndex: $contentIndex, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $VocabularyEntriesTable extends VocabularyEntries
    with TableInfo<$VocabularyEntriesTable, VocabularyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VocabularyEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
      'chapter_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES chapters (id) ON DELETE SET NULL'));
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<String> term = GeneratedColumn<String>(
      'term', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _normalizedTermMeta =
      const VerificationMeta('normalizedTerm');
  @override
  late final GeneratedColumn<String> normalizedTerm = GeneratedColumn<String>(
      'normalized_term', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _definitionMeta =
      const VerificationMeta('definition');
  @override
  late final GeneratedColumn<String> definition = GeneratedColumn<String>(
      'definition', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contextTextMeta =
      const VerificationMeta('contextText');
  @override
  late final GeneratedColumn<String> contextText = GeneratedColumn<String>(
      'context_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _positionStartMeta =
      const VerificationMeta('positionStart');
  @override
  late final GeneratedColumn<int> positionStart = GeneratedColumn<int>(
      'position_start', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _positionEndMeta =
      const VerificationMeta('positionEnd');
  @override
  late final GeneratedColumn<int> positionEnd = GeneratedColumn<int>(
      'position_end', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        chapterId,
        term,
        normalizedTerm,
        definition,
        contextText,
        positionStart,
        positionEnd,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vocabulary_entries';
  @override
  VerificationContext validateIntegrity(Insertable<VocabularyEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    }
    if (data.containsKey('term')) {
      context.handle(
          _termMeta, term.isAcceptableOrUnknown(data['term']!, _termMeta));
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('normalized_term')) {
      context.handle(
          _normalizedTermMeta,
          normalizedTerm.isAcceptableOrUnknown(
              data['normalized_term']!, _normalizedTermMeta));
    } else if (isInserting) {
      context.missing(_normalizedTermMeta);
    }
    if (data.containsKey('definition')) {
      context.handle(
          _definitionMeta,
          definition.isAcceptableOrUnknown(
              data['definition']!, _definitionMeta));
    }
    if (data.containsKey('context_text')) {
      context.handle(
          _contextTextMeta,
          contextText.isAcceptableOrUnknown(
              data['context_text']!, _contextTextMeta));
    }
    if (data.containsKey('position_start')) {
      context.handle(
          _positionStartMeta,
          positionStart.isAcceptableOrUnknown(
              data['position_start']!, _positionStartMeta));
    }
    if (data.containsKey('position_end')) {
      context.handle(
          _positionEndMeta,
          positionEnd.isAcceptableOrUnknown(
              data['position_end']!, _positionEndMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {bookId, normalizedTerm},
      ];
  @override
  VocabularyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VocabularyEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id'])!,
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_id']),
      term: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}term'])!,
      normalizedTerm: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_term'])!,
      definition: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}definition']),
      contextText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_text']),
      positionStart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_start']),
      positionEnd: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_end']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $VocabularyEntriesTable createAlias(String alias) {
    return $VocabularyEntriesTable(attachedDatabase, alias);
  }
}

class VocabularyEntry extends DataClass implements Insertable<VocabularyEntry> {
  final int id;
  final int bookId;
  final int? chapterId;
  final String term;
  final String normalizedTerm;
  final String? definition;
  final String? contextText;
  final int? positionStart;
  final int? positionEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  const VocabularyEntry(
      {required this.id,
      required this.bookId,
      this.chapterId,
      required this.term,
      required this.normalizedTerm,
      this.definition,
      this.contextText,
      this.positionStart,
      this.positionEnd,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    if (!nullToAbsent || chapterId != null) {
      map['chapter_id'] = Variable<int>(chapterId);
    }
    map['term'] = Variable<String>(term);
    map['normalized_term'] = Variable<String>(normalizedTerm);
    if (!nullToAbsent || definition != null) {
      map['definition'] = Variable<String>(definition);
    }
    if (!nullToAbsent || contextText != null) {
      map['context_text'] = Variable<String>(contextText);
    }
    if (!nullToAbsent || positionStart != null) {
      map['position_start'] = Variable<int>(positionStart);
    }
    if (!nullToAbsent || positionEnd != null) {
      map['position_end'] = Variable<int>(positionEnd);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VocabularyEntriesCompanion toCompanion(bool nullToAbsent) {
    return VocabularyEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: chapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterId),
      term: Value(term),
      normalizedTerm: Value(normalizedTerm),
      definition: definition == null && nullToAbsent
          ? const Value.absent()
          : Value(definition),
      contextText: contextText == null && nullToAbsent
          ? const Value.absent()
          : Value(contextText),
      positionStart: positionStart == null && nullToAbsent
          ? const Value.absent()
          : Value(positionStart),
      positionEnd: positionEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(positionEnd),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory VocabularyEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VocabularyEntry(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterId: serializer.fromJson<int?>(json['chapterId']),
      term: serializer.fromJson<String>(json['term']),
      normalizedTerm: serializer.fromJson<String>(json['normalizedTerm']),
      definition: serializer.fromJson<String?>(json['definition']),
      contextText: serializer.fromJson<String?>(json['contextText']),
      positionStart: serializer.fromJson<int?>(json['positionStart']),
      positionEnd: serializer.fromJson<int?>(json['positionEnd']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'chapterId': serializer.toJson<int?>(chapterId),
      'term': serializer.toJson<String>(term),
      'normalizedTerm': serializer.toJson<String>(normalizedTerm),
      'definition': serializer.toJson<String?>(definition),
      'contextText': serializer.toJson<String?>(contextText),
      'positionStart': serializer.toJson<int?>(positionStart),
      'positionEnd': serializer.toJson<int?>(positionEnd),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VocabularyEntry copyWith(
          {int? id,
          int? bookId,
          Value<int?> chapterId = const Value.absent(),
          String? term,
          String? normalizedTerm,
          Value<String?> definition = const Value.absent(),
          Value<String?> contextText = const Value.absent(),
          Value<int?> positionStart = const Value.absent(),
          Value<int?> positionEnd = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      VocabularyEntry(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        chapterId: chapterId.present ? chapterId.value : this.chapterId,
        term: term ?? this.term,
        normalizedTerm: normalizedTerm ?? this.normalizedTerm,
        definition: definition.present ? definition.value : this.definition,
        contextText: contextText.present ? contextText.value : this.contextText,
        positionStart:
            positionStart.present ? positionStart.value : this.positionStart,
        positionEnd: positionEnd.present ? positionEnd.value : this.positionEnd,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  VocabularyEntry copyWithCompanion(VocabularyEntriesCompanion data) {
    return VocabularyEntry(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      term: data.term.present ? data.term.value : this.term,
      normalizedTerm: data.normalizedTerm.present
          ? data.normalizedTerm.value
          : this.normalizedTerm,
      definition:
          data.definition.present ? data.definition.value : this.definition,
      contextText:
          data.contextText.present ? data.contextText.value : this.contextText,
      positionStart: data.positionStart.present
          ? data.positionStart.value
          : this.positionStart,
      positionEnd:
          data.positionEnd.present ? data.positionEnd.value : this.positionEnd,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntry(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('term: $term, ')
          ..write('normalizedTerm: $normalizedTerm, ')
          ..write('definition: $definition, ')
          ..write('contextText: $contextText, ')
          ..write('positionStart: $positionStart, ')
          ..write('positionEnd: $positionEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      bookId,
      chapterId,
      term,
      normalizedTerm,
      definition,
      contextText,
      positionStart,
      positionEnd,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VocabularyEntry &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.term == this.term &&
          other.normalizedTerm == this.normalizedTerm &&
          other.definition == this.definition &&
          other.contextText == this.contextText &&
          other.positionStart == this.positionStart &&
          other.positionEnd == this.positionEnd &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VocabularyEntriesCompanion extends UpdateCompanion<VocabularyEntry> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<int?> chapterId;
  final Value<String> term;
  final Value<String> normalizedTerm;
  final Value<String?> definition;
  final Value<String?> contextText;
  final Value<int?> positionStart;
  final Value<int?> positionEnd;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const VocabularyEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.term = const Value.absent(),
    this.normalizedTerm = const Value.absent(),
    this.definition = const Value.absent(),
    this.contextText = const Value.absent(),
    this.positionStart = const Value.absent(),
    this.positionEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VocabularyEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    this.chapterId = const Value.absent(),
    required String term,
    required String normalizedTerm,
    this.definition = const Value.absent(),
    this.contextText = const Value.absent(),
    this.positionStart = const Value.absent(),
    this.positionEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : bookId = Value(bookId),
        term = Value(term),
        normalizedTerm = Value(normalizedTerm);
  static Insertable<VocabularyEntry> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<int>? chapterId,
    Expression<String>? term,
    Expression<String>? normalizedTerm,
    Expression<String>? definition,
    Expression<String>? contextText,
    Expression<int>? positionStart,
    Expression<int>? positionEnd,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (term != null) 'term': term,
      if (normalizedTerm != null) 'normalized_term': normalizedTerm,
      if (definition != null) 'definition': definition,
      if (contextText != null) 'context_text': contextText,
      if (positionStart != null) 'position_start': positionStart,
      if (positionEnd != null) 'position_end': positionEnd,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VocabularyEntriesCompanion copyWith(
      {Value<int>? id,
      Value<int>? bookId,
      Value<int?>? chapterId,
      Value<String>? term,
      Value<String>? normalizedTerm,
      Value<String?>? definition,
      Value<String?>? contextText,
      Value<int?>? positionStart,
      Value<int?>? positionEnd,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return VocabularyEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      term: term ?? this.term,
      normalizedTerm: normalizedTerm ?? this.normalizedTerm,
      definition: definition ?? this.definition,
      contextText: contextText ?? this.contextText,
      positionStart: positionStart ?? this.positionStart,
      positionEnd: positionEnd ?? this.positionEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (term.present) {
      map['term'] = Variable<String>(term.value);
    }
    if (normalizedTerm.present) {
      map['normalized_term'] = Variable<String>(normalizedTerm.value);
    }
    if (definition.present) {
      map['definition'] = Variable<String>(definition.value);
    }
    if (contextText.present) {
      map['context_text'] = Variable<String>(contextText.value);
    }
    if (positionStart.present) {
      map['position_start'] = Variable<int>(positionStart.value);
    }
    if (positionEnd.present) {
      map['position_end'] = Variable<int>(positionEnd.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VocabularyEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('term: $term, ')
          ..write('normalizedTerm: $normalizedTerm, ')
          ..write('definition: $definition, ')
          ..write('contextText: $contextText, ')
          ..write('positionStart: $positionStart, ')
          ..write('positionEnd: $positionEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DictionarySourcesTable extends DictionarySources
    with TableInfo<$DictionarySourcesTable, DictionarySource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionarySourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _formatVersionMeta =
      const VerificationMeta('formatVersion');
  @override
  late final GeneratedColumn<String> formatVersion = GeneratedColumn<String>(
      'format_version', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 20),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _sameTypeSequenceMeta =
      const VerificationMeta('sameTypeSequence');
  @override
  late final GeneratedColumn<String> sameTypeSequence = GeneratedColumn<String>(
      'same_type_sequence', aliasedName, true,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: false);
  static const VerificationMeta _dataFilePathMeta =
      const VerificationMeta('dataFilePath');
  @override
  late final GeneratedColumn<String> dataFilePath = GeneratedColumn<String>(
      'data_file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entryCountMeta =
      const VerificationMeta('entryCount');
  @override
  late final GeneratedColumn<int> entryCount = GeneratedColumn<int>(
      'entry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isReadyMeta =
      const VerificationMeta('isReady');
  @override
  late final GeneratedColumn<bool> isReady = GeneratedColumn<bool>(
      'is_ready', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_ready" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        formatVersion,
        sameTypeSequence,
        dataFilePath,
        entryCount,
        enabled,
        isReady,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_sources';
  @override
  VerificationContext validateIntegrity(Insertable<DictionarySource> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('format_version')) {
      context.handle(
          _formatVersionMeta,
          formatVersion.isAcceptableOrUnknown(
              data['format_version']!, _formatVersionMeta));
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('same_type_sequence')) {
      context.handle(
          _sameTypeSequenceMeta,
          sameTypeSequence.isAcceptableOrUnknown(
              data['same_type_sequence']!, _sameTypeSequenceMeta));
    }
    if (data.containsKey('data_file_path')) {
      context.handle(
          _dataFilePathMeta,
          dataFilePath.isAcceptableOrUnknown(
              data['data_file_path']!, _dataFilePathMeta));
    } else if (isInserting) {
      context.missing(_dataFilePathMeta);
    }
    if (data.containsKey('entry_count')) {
      context.handle(
          _entryCountMeta,
          entryCount.isAcceptableOrUnknown(
              data['entry_count']!, _entryCountMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('is_ready')) {
      context.handle(_isReadyMeta,
          isReady.isAcceptableOrUnknown(data['is_ready']!, _isReadyMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DictionarySource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionarySource(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      formatVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}format_version'])!,
      sameTypeSequence: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}same_type_sequence']),
      dataFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_file_path'])!,
      entryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}entry_count'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      isReady: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_ready'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DictionarySourcesTable createAlias(String alias) {
    return $DictionarySourcesTable(attachedDatabase, alias);
  }
}

class DictionarySource extends DataClass
    implements Insertable<DictionarySource> {
  final int id;
  final String name;
  final String? description;
  final String formatVersion;
  final String? sameTypeSequence;
  final String dataFilePath;
  final int entryCount;
  final bool enabled;
  final bool isReady;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DictionarySource(
      {required this.id,
      required this.name,
      this.description,
      required this.formatVersion,
      this.sameTypeSequence,
      required this.dataFilePath,
      required this.entryCount,
      required this.enabled,
      required this.isReady,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['format_version'] = Variable<String>(formatVersion);
    if (!nullToAbsent || sameTypeSequence != null) {
      map['same_type_sequence'] = Variable<String>(sameTypeSequence);
    }
    map['data_file_path'] = Variable<String>(dataFilePath);
    map['entry_count'] = Variable<int>(entryCount);
    map['enabled'] = Variable<bool>(enabled);
    map['is_ready'] = Variable<bool>(isReady);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DictionarySourcesCompanion toCompanion(bool nullToAbsent) {
    return DictionarySourcesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      formatVersion: Value(formatVersion),
      sameTypeSequence: sameTypeSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sameTypeSequence),
      dataFilePath: Value(dataFilePath),
      entryCount: Value(entryCount),
      enabled: Value(enabled),
      isReady: Value(isReady),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DictionarySource.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionarySource(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      formatVersion: serializer.fromJson<String>(json['formatVersion']),
      sameTypeSequence: serializer.fromJson<String?>(json['sameTypeSequence']),
      dataFilePath: serializer.fromJson<String>(json['dataFilePath']),
      entryCount: serializer.fromJson<int>(json['entryCount']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      isReady: serializer.fromJson<bool>(json['isReady']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'formatVersion': serializer.toJson<String>(formatVersion),
      'sameTypeSequence': serializer.toJson<String?>(sameTypeSequence),
      'dataFilePath': serializer.toJson<String>(dataFilePath),
      'entryCount': serializer.toJson<int>(entryCount),
      'enabled': serializer.toJson<bool>(enabled),
      'isReady': serializer.toJson<bool>(isReady),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DictionarySource copyWith(
          {int? id,
          String? name,
          Value<String?> description = const Value.absent(),
          String? formatVersion,
          Value<String?> sameTypeSequence = const Value.absent(),
          String? dataFilePath,
          int? entryCount,
          bool? enabled,
          bool? isReady,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      DictionarySource(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        formatVersion: formatVersion ?? this.formatVersion,
        sameTypeSequence: sameTypeSequence.present
            ? sameTypeSequence.value
            : this.sameTypeSequence,
        dataFilePath: dataFilePath ?? this.dataFilePath,
        entryCount: entryCount ?? this.entryCount,
        enabled: enabled ?? this.enabled,
        isReady: isReady ?? this.isReady,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DictionarySource copyWithCompanion(DictionarySourcesCompanion data) {
    return DictionarySource(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      sameTypeSequence: data.sameTypeSequence.present
          ? data.sameTypeSequence.value
          : this.sameTypeSequence,
      dataFilePath: data.dataFilePath.present
          ? data.dataFilePath.value
          : this.dataFilePath,
      entryCount:
          data.entryCount.present ? data.entryCount.value : this.entryCount,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      isReady: data.isReady.present ? data.isReady.value : this.isReady,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionarySource(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('sameTypeSequence: $sameTypeSequence, ')
          ..write('dataFilePath: $dataFilePath, ')
          ..write('entryCount: $entryCount, ')
          ..write('enabled: $enabled, ')
          ..write('isReady: $isReady, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      description,
      formatVersion,
      sameTypeSequence,
      dataFilePath,
      entryCount,
      enabled,
      isReady,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionarySource &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.formatVersion == this.formatVersion &&
          other.sameTypeSequence == this.sameTypeSequence &&
          other.dataFilePath == this.dataFilePath &&
          other.entryCount == this.entryCount &&
          other.enabled == this.enabled &&
          other.isReady == this.isReady &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DictionarySourcesCompanion extends UpdateCompanion<DictionarySource> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> formatVersion;
  final Value<String?> sameTypeSequence;
  final Value<String> dataFilePath;
  final Value<int> entryCount;
  final Value<bool> enabled;
  final Value<bool> isReady;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DictionarySourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.sameTypeSequence = const Value.absent(),
    this.dataFilePath = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isReady = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DictionarySourcesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required String formatVersion,
    this.sameTypeSequence = const Value.absent(),
    required String dataFilePath,
    this.entryCount = const Value.absent(),
    this.enabled = const Value.absent(),
    this.isReady = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : name = Value(name),
        formatVersion = Value(formatVersion),
        dataFilePath = Value(dataFilePath);
  static Insertable<DictionarySource> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? formatVersion,
    Expression<String>? sameTypeSequence,
    Expression<String>? dataFilePath,
    Expression<int>? entryCount,
    Expression<bool>? enabled,
    Expression<bool>? isReady,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (formatVersion != null) 'format_version': formatVersion,
      if (sameTypeSequence != null) 'same_type_sequence': sameTypeSequence,
      if (dataFilePath != null) 'data_file_path': dataFilePath,
      if (entryCount != null) 'entry_count': entryCount,
      if (enabled != null) 'enabled': enabled,
      if (isReady != null) 'is_ready': isReady,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DictionarySourcesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? formatVersion,
      Value<String?>? sameTypeSequence,
      Value<String>? dataFilePath,
      Value<int>? entryCount,
      Value<bool>? enabled,
      Value<bool>? isReady,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return DictionarySourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      formatVersion: formatVersion ?? this.formatVersion,
      sameTypeSequence: sameTypeSequence ?? this.sameTypeSequence,
      dataFilePath: dataFilePath ?? this.dataFilePath,
      entryCount: entryCount ?? this.entryCount,
      enabled: enabled ?? this.enabled,
      isReady: isReady ?? this.isReady,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<String>(formatVersion.value);
    }
    if (sameTypeSequence.present) {
      map['same_type_sequence'] = Variable<String>(sameTypeSequence.value);
    }
    if (dataFilePath.present) {
      map['data_file_path'] = Variable<String>(dataFilePath.value);
    }
    if (entryCount.present) {
      map['entry_count'] = Variable<int>(entryCount.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (isReady.present) {
      map['is_ready'] = Variable<bool>(isReady.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionarySourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('sameTypeSequence: $sameTypeSequence, ')
          ..write('dataFilePath: $dataFilePath, ')
          ..write('entryCount: $entryCount, ')
          ..write('enabled: $enabled, ')
          ..write('isReady: $isReady, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DictionaryEntriesTable extends DictionaryEntries
    with TableInfo<$DictionaryEntriesTable, DictionaryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
      'source_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES dictionary_sources (id) ON DELETE CASCADE'));
  static const VerificationMeta _entryIndexMeta =
      const VerificationMeta('entryIndex');
  @override
  late final GeneratedColumn<int> entryIndex = GeneratedColumn<int>(
      'entry_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _headwordMeta =
      const VerificationMeta('headword');
  @override
  late final GeneratedColumn<String> headword = GeneratedColumn<String>(
      'headword', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _normalizedHeadwordMeta =
      const VerificationMeta('normalizedHeadword');
  @override
  late final GeneratedColumn<String> normalizedHeadword =
      GeneratedColumn<String>('normalized_headword', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
              minTextLength: 1, maxTextLength: 500),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _dataOffsetMeta =
      const VerificationMeta('dataOffset');
  @override
  late final GeneratedColumn<int> dataOffset = GeneratedColumn<int>(
      'data_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dataSizeMeta =
      const VerificationMeta('dataSize');
  @override
  late final GeneratedColumn<int> dataSize = GeneratedColumn<int>(
      'data_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sourceId,
        entryIndex,
        headword,
        normalizedHeadword,
        dataOffset,
        dataSize
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_entries';
  @override
  VerificationContext validateIntegrity(Insertable<DictionaryEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('entry_index')) {
      context.handle(
          _entryIndexMeta,
          entryIndex.isAcceptableOrUnknown(
              data['entry_index']!, _entryIndexMeta));
    } else if (isInserting) {
      context.missing(_entryIndexMeta);
    }
    if (data.containsKey('headword')) {
      context.handle(_headwordMeta,
          headword.isAcceptableOrUnknown(data['headword']!, _headwordMeta));
    } else if (isInserting) {
      context.missing(_headwordMeta);
    }
    if (data.containsKey('normalized_headword')) {
      context.handle(
          _normalizedHeadwordMeta,
          normalizedHeadword.isAcceptableOrUnknown(
              data['normalized_headword']!, _normalizedHeadwordMeta));
    } else if (isInserting) {
      context.missing(_normalizedHeadwordMeta);
    }
    if (data.containsKey('data_offset')) {
      context.handle(
          _dataOffsetMeta,
          dataOffset.isAcceptableOrUnknown(
              data['data_offset']!, _dataOffsetMeta));
    } else if (isInserting) {
      context.missing(_dataOffsetMeta);
    }
    if (data.containsKey('data_size')) {
      context.handle(_dataSizeMeta,
          dataSize.isAcceptableOrUnknown(data['data_size']!, _dataSizeMeta));
    } else if (isInserting) {
      context.missing(_dataSizeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {sourceId, entryIndex},
      ];
  @override
  DictionaryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_id'])!,
      entryIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}entry_index'])!,
      headword: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}headword'])!,
      normalizedHeadword: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_headword'])!,
      dataOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}data_offset'])!,
      dataSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}data_size'])!,
    );
  }

  @override
  $DictionaryEntriesTable createAlias(String alias) {
    return $DictionaryEntriesTable(attachedDatabase, alias);
  }
}

class DictionaryEntry extends DataClass implements Insertable<DictionaryEntry> {
  final int id;
  final int sourceId;
  final int entryIndex;
  final String headword;
  final String normalizedHeadword;
  final int dataOffset;
  final int dataSize;
  const DictionaryEntry(
      {required this.id,
      required this.sourceId,
      required this.entryIndex,
      required this.headword,
      required this.normalizedHeadword,
      required this.dataOffset,
      required this.dataSize});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<int>(sourceId);
    map['entry_index'] = Variable<int>(entryIndex);
    map['headword'] = Variable<String>(headword);
    map['normalized_headword'] = Variable<String>(normalizedHeadword);
    map['data_offset'] = Variable<int>(dataOffset);
    map['data_size'] = Variable<int>(dataSize);
    return map;
  }

  DictionaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DictionaryEntriesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      entryIndex: Value(entryIndex),
      headword: Value(headword),
      normalizedHeadword: Value(normalizedHeadword),
      dataOffset: Value(dataOffset),
      dataSize: Value(dataSize),
    );
  }

  factory DictionaryEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryEntry(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      entryIndex: serializer.fromJson<int>(json['entryIndex']),
      headword: serializer.fromJson<String>(json['headword']),
      normalizedHeadword:
          serializer.fromJson<String>(json['normalizedHeadword']),
      dataOffset: serializer.fromJson<int>(json['dataOffset']),
      dataSize: serializer.fromJson<int>(json['dataSize']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<int>(sourceId),
      'entryIndex': serializer.toJson<int>(entryIndex),
      'headword': serializer.toJson<String>(headword),
      'normalizedHeadword': serializer.toJson<String>(normalizedHeadword),
      'dataOffset': serializer.toJson<int>(dataOffset),
      'dataSize': serializer.toJson<int>(dataSize),
    };
  }

  DictionaryEntry copyWith(
          {int? id,
          int? sourceId,
          int? entryIndex,
          String? headword,
          String? normalizedHeadword,
          int? dataOffset,
          int? dataSize}) =>
      DictionaryEntry(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        entryIndex: entryIndex ?? this.entryIndex,
        headword: headword ?? this.headword,
        normalizedHeadword: normalizedHeadword ?? this.normalizedHeadword,
        dataOffset: dataOffset ?? this.dataOffset,
        dataSize: dataSize ?? this.dataSize,
      );
  DictionaryEntry copyWithCompanion(DictionaryEntriesCompanion data) {
    return DictionaryEntry(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      entryIndex:
          data.entryIndex.present ? data.entryIndex.value : this.entryIndex,
      headword: data.headword.present ? data.headword.value : this.headword,
      normalizedHeadword: data.normalizedHeadword.present
          ? data.normalizedHeadword.value
          : this.normalizedHeadword,
      dataOffset:
          data.dataOffset.present ? data.dataOffset.value : this.dataOffset,
      dataSize: data.dataSize.present ? data.dataSize.value : this.dataSize,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryEntry(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('entryIndex: $entryIndex, ')
          ..write('headword: $headword, ')
          ..write('normalizedHeadword: $normalizedHeadword, ')
          ..write('dataOffset: $dataOffset, ')
          ..write('dataSize: $dataSize')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, entryIndex, headword,
      normalizedHeadword, dataOffset, dataSize);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryEntry &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.entryIndex == this.entryIndex &&
          other.headword == this.headword &&
          other.normalizedHeadword == this.normalizedHeadword &&
          other.dataOffset == this.dataOffset &&
          other.dataSize == this.dataSize);
}

class DictionaryEntriesCompanion extends UpdateCompanion<DictionaryEntry> {
  final Value<int> id;
  final Value<int> sourceId;
  final Value<int> entryIndex;
  final Value<String> headword;
  final Value<String> normalizedHeadword;
  final Value<int> dataOffset;
  final Value<int> dataSize;
  const DictionaryEntriesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.entryIndex = const Value.absent(),
    this.headword = const Value.absent(),
    this.normalizedHeadword = const Value.absent(),
    this.dataOffset = const Value.absent(),
    this.dataSize = const Value.absent(),
  });
  DictionaryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int sourceId,
    required int entryIndex,
    required String headword,
    required String normalizedHeadword,
    required int dataOffset,
    required int dataSize,
  })  : sourceId = Value(sourceId),
        entryIndex = Value(entryIndex),
        headword = Value(headword),
        normalizedHeadword = Value(normalizedHeadword),
        dataOffset = Value(dataOffset),
        dataSize = Value(dataSize);
  static Insertable<DictionaryEntry> custom({
    Expression<int>? id,
    Expression<int>? sourceId,
    Expression<int>? entryIndex,
    Expression<String>? headword,
    Expression<String>? normalizedHeadword,
    Expression<int>? dataOffset,
    Expression<int>? dataSize,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (entryIndex != null) 'entry_index': entryIndex,
      if (headword != null) 'headword': headword,
      if (normalizedHeadword != null) 'normalized_headword': normalizedHeadword,
      if (dataOffset != null) 'data_offset': dataOffset,
      if (dataSize != null) 'data_size': dataSize,
    });
  }

  DictionaryEntriesCompanion copyWith(
      {Value<int>? id,
      Value<int>? sourceId,
      Value<int>? entryIndex,
      Value<String>? headword,
      Value<String>? normalizedHeadword,
      Value<int>? dataOffset,
      Value<int>? dataSize}) {
    return DictionaryEntriesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      entryIndex: entryIndex ?? this.entryIndex,
      headword: headword ?? this.headword,
      normalizedHeadword: normalizedHeadword ?? this.normalizedHeadword,
      dataOffset: dataOffset ?? this.dataOffset,
      dataSize: dataSize ?? this.dataSize,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (entryIndex.present) {
      map['entry_index'] = Variable<int>(entryIndex.value);
    }
    if (headword.present) {
      map['headword'] = Variable<String>(headword.value);
    }
    if (normalizedHeadword.present) {
      map['normalized_headword'] = Variable<String>(normalizedHeadword.value);
    }
    if (dataOffset.present) {
      map['data_offset'] = Variable<int>(dataOffset.value);
    }
    if (dataSize.present) {
      map['data_size'] = Variable<int>(dataSize.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('entryIndex: $entryIndex, ')
          ..write('headword: $headword, ')
          ..write('normalizedHeadword: $normalizedHeadword, ')
          ..write('dataOffset: $dataOffset, ')
          ..write('dataSize: $dataSize')
          ..write(')'))
        .toString();
  }
}

class $DictionaryAliasesTable extends DictionaryAliases
    with TableInfo<$DictionaryAliasesTable, DictionaryAliase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
      'source_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES dictionary_sources (id) ON DELETE CASCADE'));
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
      'alias', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _normalizedAliasMeta =
      const VerificationMeta('normalizedAlias');
  @override
  late final GeneratedColumn<String> normalizedAlias = GeneratedColumn<String>(
      'normalized_alias', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _targetEntryIndexMeta =
      const VerificationMeta('targetEntryIndex');
  @override
  late final GeneratedColumn<int> targetEntryIndex = GeneratedColumn<int>(
      'target_entry_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sourceId, alias, normalizedAlias, targetEntryIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_aliases';
  @override
  VerificationContext validateIntegrity(Insertable<DictionaryAliase> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
          _aliasMeta, alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta));
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('normalized_alias')) {
      context.handle(
          _normalizedAliasMeta,
          normalizedAlias.isAcceptableOrUnknown(
              data['normalized_alias']!, _normalizedAliasMeta));
    } else if (isInserting) {
      context.missing(_normalizedAliasMeta);
    }
    if (data.containsKey('target_entry_index')) {
      context.handle(
          _targetEntryIndexMeta,
          targetEntryIndex.isAcceptableOrUnknown(
              data['target_entry_index']!, _targetEntryIndexMeta));
    } else if (isInserting) {
      context.missing(_targetEntryIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {sourceId, normalizedAlias, targetEntryIndex},
      ];
  @override
  DictionaryAliase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryAliase(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_id'])!,
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias'])!,
      normalizedAlias: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_alias'])!,
      targetEntryIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}target_entry_index'])!,
    );
  }

  @override
  $DictionaryAliasesTable createAlias(String alias) {
    return $DictionaryAliasesTable(attachedDatabase, alias);
  }
}

class DictionaryAliase extends DataClass
    implements Insertable<DictionaryAliase> {
  final int id;
  final int sourceId;
  final String alias;
  final String normalizedAlias;
  final int targetEntryIndex;
  const DictionaryAliase(
      {required this.id,
      required this.sourceId,
      required this.alias,
      required this.normalizedAlias,
      required this.targetEntryIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<int>(sourceId);
    map['alias'] = Variable<String>(alias);
    map['normalized_alias'] = Variable<String>(normalizedAlias);
    map['target_entry_index'] = Variable<int>(targetEntryIndex);
    return map;
  }

  DictionaryAliasesCompanion toCompanion(bool nullToAbsent) {
    return DictionaryAliasesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      alias: Value(alias),
      normalizedAlias: Value(normalizedAlias),
      targetEntryIndex: Value(targetEntryIndex),
    );
  }

  factory DictionaryAliase.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryAliase(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      alias: serializer.fromJson<String>(json['alias']),
      normalizedAlias: serializer.fromJson<String>(json['normalizedAlias']),
      targetEntryIndex: serializer.fromJson<int>(json['targetEntryIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<int>(sourceId),
      'alias': serializer.toJson<String>(alias),
      'normalizedAlias': serializer.toJson<String>(normalizedAlias),
      'targetEntryIndex': serializer.toJson<int>(targetEntryIndex),
    };
  }

  DictionaryAliase copyWith(
          {int? id,
          int? sourceId,
          String? alias,
          String? normalizedAlias,
          int? targetEntryIndex}) =>
      DictionaryAliase(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        alias: alias ?? this.alias,
        normalizedAlias: normalizedAlias ?? this.normalizedAlias,
        targetEntryIndex: targetEntryIndex ?? this.targetEntryIndex,
      );
  DictionaryAliase copyWithCompanion(DictionaryAliasesCompanion data) {
    return DictionaryAliase(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      alias: data.alias.present ? data.alias.value : this.alias,
      normalizedAlias: data.normalizedAlias.present
          ? data.normalizedAlias.value
          : this.normalizedAlias,
      targetEntryIndex: data.targetEntryIndex.present
          ? data.targetEntryIndex.value
          : this.targetEntryIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryAliase(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('alias: $alias, ')
          ..write('normalizedAlias: $normalizedAlias, ')
          ..write('targetEntryIndex: $targetEntryIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sourceId, alias, normalizedAlias, targetEntryIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryAliase &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.alias == this.alias &&
          other.normalizedAlias == this.normalizedAlias &&
          other.targetEntryIndex == this.targetEntryIndex);
}

class DictionaryAliasesCompanion extends UpdateCompanion<DictionaryAliase> {
  final Value<int> id;
  final Value<int> sourceId;
  final Value<String> alias;
  final Value<String> normalizedAlias;
  final Value<int> targetEntryIndex;
  const DictionaryAliasesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.alias = const Value.absent(),
    this.normalizedAlias = const Value.absent(),
    this.targetEntryIndex = const Value.absent(),
  });
  DictionaryAliasesCompanion.insert({
    this.id = const Value.absent(),
    required int sourceId,
    required String alias,
    required String normalizedAlias,
    required int targetEntryIndex,
  })  : sourceId = Value(sourceId),
        alias = Value(alias),
        normalizedAlias = Value(normalizedAlias),
        targetEntryIndex = Value(targetEntryIndex);
  static Insertable<DictionaryAliase> custom({
    Expression<int>? id,
    Expression<int>? sourceId,
    Expression<String>? alias,
    Expression<String>? normalizedAlias,
    Expression<int>? targetEntryIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (alias != null) 'alias': alias,
      if (normalizedAlias != null) 'normalized_alias': normalizedAlias,
      if (targetEntryIndex != null) 'target_entry_index': targetEntryIndex,
    });
  }

  DictionaryAliasesCompanion copyWith(
      {Value<int>? id,
      Value<int>? sourceId,
      Value<String>? alias,
      Value<String>? normalizedAlias,
      Value<int>? targetEntryIndex}) {
    return DictionaryAliasesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      alias: alias ?? this.alias,
      normalizedAlias: normalizedAlias ?? this.normalizedAlias,
      targetEntryIndex: targetEntryIndex ?? this.targetEntryIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (normalizedAlias.present) {
      map['normalized_alias'] = Variable<String>(normalizedAlias.value);
    }
    if (targetEntryIndex.present) {
      map['target_entry_index'] = Variable<int>(targetEntryIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryAliasesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('alias: $alias, ')
          ..write('normalizedAlias: $normalizedAlias, ')
          ..write('targetEntryIndex: $targetEntryIndex')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
      'chapter_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES chapters (id) ON DELETE SET NULL'));
  static const VerificationMeta _positionInChapterMeta =
      const VerificationMeta('positionInChapter');
  @override
  late final GeneratedColumn<double> positionInChapter =
      GeneratedColumn<double>('position_in_chapter', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _percentageMeta =
      const VerificationMeta('percentage');
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
      'percentage', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _totalReadingSecondsMeta =
      const VerificationMeta('totalReadingSeconds');
  @override
  late final GeneratedColumn<int> totalReadingSeconds = GeneratedColumn<int>(
      'total_reading_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastReadAtMeta =
      const VerificationMeta('lastReadAt');
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
      'last_read_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        bookId,
        chapterId,
        positionInChapter,
        percentage,
        totalReadingSeconds,
        lastReadAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
      Insertable<ReadingProgressData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    }
    if (data.containsKey('position_in_chapter')) {
      context.handle(
          _positionInChapterMeta,
          positionInChapter.isAcceptableOrUnknown(
              data['position_in_chapter']!, _positionInChapterMeta));
    }
    if (data.containsKey('percentage')) {
      context.handle(
          _percentageMeta,
          percentage.isAcceptableOrUnknown(
              data['percentage']!, _percentageMeta));
    }
    if (data.containsKey('total_reading_seconds')) {
      context.handle(
          _totalReadingSecondsMeta,
          totalReadingSeconds.isAcceptableOrUnknown(
              data['total_reading_seconds']!, _totalReadingSecondsMeta));
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
          _lastReadAtMeta,
          lastReadAt.isAcceptableOrUnknown(
              data['last_read_at']!, _lastReadAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressData(
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id'])!,
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_id']),
      positionInChapter: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}position_in_chapter'])!,
      percentage: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}percentage'])!,
      totalReadingSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_reading_seconds'])!,
      lastReadAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_read_at'])!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressData extends DataClass
    implements Insertable<ReadingProgressData> {
  final int bookId;
  final int? chapterId;
  final double positionInChapter;
  final double percentage;
  final int totalReadingSeconds;
  final DateTime lastReadAt;
  const ReadingProgressData(
      {required this.bookId,
      this.chapterId,
      required this.positionInChapter,
      required this.percentage,
      required this.totalReadingSeconds,
      required this.lastReadAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<int>(bookId);
    if (!nullToAbsent || chapterId != null) {
      map['chapter_id'] = Variable<int>(chapterId);
    }
    map['position_in_chapter'] = Variable<double>(positionInChapter);
    map['percentage'] = Variable<double>(percentage);
    map['total_reading_seconds'] = Variable<int>(totalReadingSeconds);
    map['last_read_at'] = Variable<DateTime>(lastReadAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      bookId: Value(bookId),
      chapterId: chapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterId),
      positionInChapter: Value(positionInChapter),
      percentage: Value(percentage),
      totalReadingSeconds: Value(totalReadingSeconds),
      lastReadAt: Value(lastReadAt),
    );
  }

  factory ReadingProgressData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressData(
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterId: serializer.fromJson<int?>(json['chapterId']),
      positionInChapter: serializer.fromJson<double>(json['positionInChapter']),
      percentage: serializer.fromJson<double>(json['percentage']),
      totalReadingSeconds:
          serializer.fromJson<int>(json['totalReadingSeconds']),
      lastReadAt: serializer.fromJson<DateTime>(json['lastReadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<int>(bookId),
      'chapterId': serializer.toJson<int?>(chapterId),
      'positionInChapter': serializer.toJson<double>(positionInChapter),
      'percentage': serializer.toJson<double>(percentage),
      'totalReadingSeconds': serializer.toJson<int>(totalReadingSeconds),
      'lastReadAt': serializer.toJson<DateTime>(lastReadAt),
    };
  }

  ReadingProgressData copyWith(
          {int? bookId,
          Value<int?> chapterId = const Value.absent(),
          double? positionInChapter,
          double? percentage,
          int? totalReadingSeconds,
          DateTime? lastReadAt}) =>
      ReadingProgressData(
        bookId: bookId ?? this.bookId,
        chapterId: chapterId.present ? chapterId.value : this.chapterId,
        positionInChapter: positionInChapter ?? this.positionInChapter,
        percentage: percentage ?? this.percentage,
        totalReadingSeconds: totalReadingSeconds ?? this.totalReadingSeconds,
        lastReadAt: lastReadAt ?? this.lastReadAt,
      );
  ReadingProgressData copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      positionInChapter: data.positionInChapter.present
          ? data.positionInChapter.value
          : this.positionInChapter,
      percentage:
          data.percentage.present ? data.percentage.value : this.percentage,
      totalReadingSeconds: data.totalReadingSeconds.present
          ? data.totalReadingSeconds.value
          : this.totalReadingSeconds,
      lastReadAt:
          data.lastReadAt.present ? data.lastReadAt.value : this.lastReadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressData(')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('positionInChapter: $positionInChapter, ')
          ..write('percentage: $percentage, ')
          ..write('totalReadingSeconds: $totalReadingSeconds, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, chapterId, positionInChapter,
      percentage, totalReadingSeconds, lastReadAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressData &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.positionInChapter == this.positionInChapter &&
          other.percentage == this.percentage &&
          other.totalReadingSeconds == this.totalReadingSeconds &&
          other.lastReadAt == this.lastReadAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressData> {
  final Value<int> bookId;
  final Value<int?> chapterId;
  final Value<double> positionInChapter;
  final Value<double> percentage;
  final Value<int> totalReadingSeconds;
  final Value<DateTime> lastReadAt;
  const ReadingProgressCompanion({
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.positionInChapter = const Value.absent(),
    this.percentage = const Value.absent(),
    this.totalReadingSeconds = const Value.absent(),
    this.lastReadAt = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.positionInChapter = const Value.absent(),
    this.percentage = const Value.absent(),
    this.totalReadingSeconds = const Value.absent(),
    this.lastReadAt = const Value.absent(),
  });
  static Insertable<ReadingProgressData> custom({
    Expression<int>? bookId,
    Expression<int>? chapterId,
    Expression<double>? positionInChapter,
    Expression<double>? percentage,
    Expression<int>? totalReadingSeconds,
    Expression<DateTime>? lastReadAt,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (positionInChapter != null) 'position_in_chapter': positionInChapter,
      if (percentage != null) 'percentage': percentage,
      if (totalReadingSeconds != null)
        'total_reading_seconds': totalReadingSeconds,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
    });
  }

  ReadingProgressCompanion copyWith(
      {Value<int>? bookId,
      Value<int?>? chapterId,
      Value<double>? positionInChapter,
      Value<double>? percentage,
      Value<int>? totalReadingSeconds,
      Value<DateTime>? lastReadAt}) {
    return ReadingProgressCompanion(
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      positionInChapter: positionInChapter ?? this.positionInChapter,
      percentage: percentage ?? this.percentage,
      totalReadingSeconds: totalReadingSeconds ?? this.totalReadingSeconds,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (positionInChapter.present) {
      map['position_in_chapter'] = Variable<double>(positionInChapter.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
    }
    if (totalReadingSeconds.present) {
      map['total_reading_seconds'] = Variable<int>(totalReadingSeconds.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('positionInChapter: $positionInChapter, ')
          ..write('percentage: $percentage, ')
          ..write('totalReadingSeconds: $totalReadingSeconds, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingSessionsTable extends ReadingSessions
    with TableInfo<$ReadingSessionsTable, ReadingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE SET NULL'));
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 10, maxTextLength: 10),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _secondsMeta =
      const VerificationMeta('seconds');
  @override
  late final GeneratedColumn<int> seconds = GeneratedColumn<int>(
      'seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, bookId, date, seconds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<ReadingSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('seconds')) {
      context.handle(_secondsMeta,
          seconds.isAcceptableOrUnknown(data['seconds']!, _secondsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingSession(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id']),
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      seconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seconds'])!,
    );
  }

  @override
  $ReadingSessionsTable createAlias(String alias) {
    return $ReadingSessionsTable(attachedDatabase, alias);
  }
}

class ReadingSession extends DataClass implements Insertable<ReadingSession> {
  final int id;
  final int? bookId;

  /// 本地自然日，格式 yyyy-MM-dd，由 `localDateString()` 生成。
  final String date;
  final int seconds;
  const ReadingSession(
      {required this.id,
      this.bookId,
      required this.date,
      required this.seconds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<int>(bookId);
    }
    map['date'] = Variable<String>(date);
    map['seconds'] = Variable<int>(seconds);
    return map;
  }

  ReadingSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingSessionsCompanion(
      id: Value(id),
      bookId:
          bookId == null && nullToAbsent ? const Value.absent() : Value(bookId),
      date: Value(date),
      seconds: Value(seconds),
    );
  }

  factory ReadingSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingSession(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int?>(json['bookId']),
      date: serializer.fromJson<String>(json['date']),
      seconds: serializer.fromJson<int>(json['seconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int?>(bookId),
      'date': serializer.toJson<String>(date),
      'seconds': serializer.toJson<int>(seconds),
    };
  }

  ReadingSession copyWith(
          {int? id,
          Value<int?> bookId = const Value.absent(),
          String? date,
          int? seconds}) =>
      ReadingSession(
        id: id ?? this.id,
        bookId: bookId.present ? bookId.value : this.bookId,
        date: date ?? this.date,
        seconds: seconds ?? this.seconds,
      );
  ReadingSession copyWithCompanion(ReadingSessionsCompanion data) {
    return ReadingSession(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      date: data.date.present ? data.date.value : this.date,
      seconds: data.seconds.present ? data.seconds.value : this.seconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSession(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('seconds: $seconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, date, seconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingSession &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.date == this.date &&
          other.seconds == this.seconds);
}

class ReadingSessionsCompanion extends UpdateCompanion<ReadingSession> {
  final Value<int> id;
  final Value<int?> bookId;
  final Value<String> date;
  final Value<int> seconds;
  const ReadingSessionsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.date = const Value.absent(),
    this.seconds = const Value.absent(),
  });
  ReadingSessionsCompanion.insert({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    required String date,
    this.seconds = const Value.absent(),
  }) : date = Value(date);
  static Insertable<ReadingSession> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<String>? date,
    Expression<int>? seconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (date != null) 'date': date,
      if (seconds != null) 'seconds': seconds,
    });
  }

  ReadingSessionsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? bookId,
      Value<String>? date,
      Value<int>? seconds}) {
    return ReadingSessionsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
      seconds: seconds ?? this.seconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (seconds.present) {
      map['seconds'] = Variable<int>(seconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('seconds: $seconds')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE CASCADE'));
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
      'chapter_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES chapters (id) ON DELETE SET NULL'));
  static const VerificationMeta _selectedTextMeta =
      const VerificationMeta('selectedText');
  @override
  late final GeneratedColumn<String> selectedText = GeneratedColumn<String>(
      'selected_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pageNumberMeta =
      const VerificationMeta('pageNumber');
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
      'page_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _positionStartMeta =
      const VerificationMeta('positionStart');
  @override
  late final GeneratedColumn<int> positionStart = GeneratedColumn<int>(
      'position_start', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _positionEndMeta =
      const VerificationMeta('positionEnd');
  @override
  late final GeneratedColumn<int> positionEnd = GeneratedColumn<int>(
      'position_end', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('note'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        chapterId,
        selectedText,
        content,
        pageNumber,
        positionStart,
        positionEnd,
        createdAt,
        updatedAt,
        type
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(Insertable<Note> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    }
    if (data.containsKey('selected_text')) {
      context.handle(
          _selectedTextMeta,
          selectedText.isAcceptableOrUnknown(
              data['selected_text']!, _selectedTextMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('page_number')) {
      context.handle(
          _pageNumberMeta,
          pageNumber.isAcceptableOrUnknown(
              data['page_number']!, _pageNumberMeta));
    }
    if (data.containsKey('position_start')) {
      context.handle(
          _positionStartMeta,
          positionStart.isAcceptableOrUnknown(
              data['position_start']!, _positionStartMeta));
    }
    if (data.containsKey('position_end')) {
      context.handle(
          _positionEndMeta,
          positionEnd.isAcceptableOrUnknown(
              data['position_end']!, _positionEndMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id'])!,
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chapter_id']),
      selectedText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}selected_text']),
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      pageNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_number']),
      positionStart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_start']),
      positionEnd: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_end']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;
  final int bookId;
  final int? chapterId;
  final String? selectedText;
  final String? content;
  final int? pageNumber;
  final int? positionStart;
  final int? positionEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type;
  const Note(
      {required this.id,
      required this.bookId,
      this.chapterId,
      this.selectedText,
      this.content,
      this.pageNumber,
      this.positionStart,
      this.positionEnd,
      required this.createdAt,
      required this.updatedAt,
      required this.type});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    if (!nullToAbsent || chapterId != null) {
      map['chapter_id'] = Variable<int>(chapterId);
    }
    if (!nullToAbsent || selectedText != null) {
      map['selected_text'] = Variable<String>(selectedText);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    if (!nullToAbsent || positionStart != null) {
      map['position_start'] = Variable<int>(positionStart);
    }
    if (!nullToAbsent || positionEnd != null) {
      map['position_end'] = Variable<int>(positionEnd);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['type'] = Variable<String>(type);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: chapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterId),
      selectedText: selectedText == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedText),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      positionStart: positionStart == null && nullToAbsent
          ? const Value.absent()
          : Value(positionStart),
      positionEnd: positionEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(positionEnd),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      type: Value(type),
    );
  }

  factory Note.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterId: serializer.fromJson<int?>(json['chapterId']),
      selectedText: serializer.fromJson<String?>(json['selectedText']),
      content: serializer.fromJson<String?>(json['content']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      positionStart: serializer.fromJson<int?>(json['positionStart']),
      positionEnd: serializer.fromJson<int?>(json['positionEnd']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      type: serializer.fromJson<String>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'chapterId': serializer.toJson<int?>(chapterId),
      'selectedText': serializer.toJson<String?>(selectedText),
      'content': serializer.toJson<String?>(content),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'positionStart': serializer.toJson<int?>(positionStart),
      'positionEnd': serializer.toJson<int?>(positionEnd),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'type': serializer.toJson<String>(type),
    };
  }

  Note copyWith(
          {int? id,
          int? bookId,
          Value<int?> chapterId = const Value.absent(),
          Value<String?> selectedText = const Value.absent(),
          Value<String?> content = const Value.absent(),
          Value<int?> pageNumber = const Value.absent(),
          Value<int?> positionStart = const Value.absent(),
          Value<int?> positionEnd = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          String? type}) =>
      Note(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        chapterId: chapterId.present ? chapterId.value : this.chapterId,
        selectedText:
            selectedText.present ? selectedText.value : this.selectedText,
        content: content.present ? content.value : this.content,
        pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
        positionStart:
            positionStart.present ? positionStart.value : this.positionStart,
        positionEnd: positionEnd.present ? positionEnd.value : this.positionEnd,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        type: type ?? this.type,
      );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      selectedText: data.selectedText.present
          ? data.selectedText.value
          : this.selectedText,
      content: data.content.present ? data.content.value : this.content,
      pageNumber:
          data.pageNumber.present ? data.pageNumber.value : this.pageNumber,
      positionStart: data.positionStart.present
          ? data.positionStart.value
          : this.positionStart,
      positionEnd:
          data.positionEnd.present ? data.positionEnd.value : this.positionEnd,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('selectedText: $selectedText, ')
          ..write('content: $content, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('positionStart: $positionStart, ')
          ..write('positionEnd: $positionEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, chapterId, selectedText, content,
      pageNumber, positionStart, positionEnd, createdAt, updatedAt, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.selectedText == this.selectedText &&
          other.content == this.content &&
          other.pageNumber == this.pageNumber &&
          other.positionStart == this.positionStart &&
          other.positionEnd == this.positionEnd &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.type == this.type);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<int?> chapterId;
  final Value<String?> selectedText;
  final Value<String?> content;
  final Value<int?> pageNumber;
  final Value<int?> positionStart;
  final Value<int?> positionEnd;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> type;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.content = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.positionStart = const Value.absent(),
    this.positionEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.type = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    this.chapterId = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.content = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.positionStart = const Value.absent(),
    this.positionEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.type = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<int>? chapterId,
    Expression<String>? selectedText,
    Expression<String>? content,
    Expression<int>? pageNumber,
    Expression<int>? positionStart,
    Expression<int>? positionEnd,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? type,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (selectedText != null) 'selected_text': selectedText,
      if (content != null) 'content': content,
      if (pageNumber != null) 'page_number': pageNumber,
      if (positionStart != null) 'position_start': positionStart,
      if (positionEnd != null) 'position_end': positionEnd,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (type != null) 'type': type,
    });
  }

  NotesCompanion copyWith(
      {Value<int>? id,
      Value<int>? bookId,
      Value<int?>? chapterId,
      Value<String?>? selectedText,
      Value<String?>? content,
      Value<int?>? pageNumber,
      Value<int?>? positionStart,
      Value<int?>? positionEnd,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? type}) {
    return NotesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      selectedText: selectedText ?? this.selectedText,
      content: content ?? this.content,
      pageNumber: pageNumber ?? this.pageNumber,
      positionStart: positionStart ?? this.positionStart,
      positionEnd: positionEnd ?? this.positionEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (selectedText.present) {
      map['selected_text'] = Variable<String>(selectedText.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (positionStart.present) {
      map['position_start'] = Variable<int>(positionStart.value);
    }
    if (positionEnd.present) {
      map['position_end'] = Variable<int>(positionEnd.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('selectedText: $selectedText, ')
          ..write('content: $content, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('positionStart: $positionStart, ')
          ..write('positionEnd: $positionEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, color, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final String? color;
  final DateTime createdAt;
  const Tag(
      {required this.id,
      required this.name,
      this.color,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tag copyWith(
          {int? id,
          String? name,
          Value<String?> color = const Value.absent(),
          DateTime? createdAt}) =>
      Tag(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color.present ? color.value : this.color,
        createdAt: createdAt ?? this.createdAt,
      );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> color;
  final Value<DateTime> createdAt;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TagsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? color,
      Value<DateTime>? createdAt}) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $NoteTagsTable extends NoteTags with TableInfo<$NoteTagsTable, NoteTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
      'note_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES notes (id) ON DELETE CASCADE'));
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tags (id) ON DELETE CASCADE'));
  @override
  List<GeneratedColumn> get $columns => [noteId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tags';
  @override
  VerificationContext validateIntegrity(Insertable<NoteTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(_noteIdMeta,
          noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta));
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, tagId};
  @override
  NoteTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTag(
      noteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}note_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $NoteTagsTable createAlias(String alias) {
    return $NoteTagsTable(attachedDatabase, alias);
  }
}

class NoteTag extends DataClass implements Insertable<NoteTag> {
  final int noteId;
  final int tagId;
  const NoteTag({required this.noteId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<int>(noteId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  NoteTagsCompanion toCompanion(bool nullToAbsent) {
    return NoteTagsCompanion(
      noteId: Value(noteId),
      tagId: Value(tagId),
    );
  }

  factory NoteTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTag(
      noteId: serializer.fromJson<int>(json['noteId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<int>(noteId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  NoteTag copyWith({int? noteId, int? tagId}) => NoteTag(
        noteId: noteId ?? this.noteId,
        tagId: tagId ?? this.tagId,
      );
  NoteTag copyWithCompanion(NoteTagsCompanion data) {
    return NoteTag(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTag(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTag &&
          other.noteId == this.noteId &&
          other.tagId == this.tagId);
}

class NoteTagsCompanion extends UpdateCompanion<NoteTag> {
  final Value<int> noteId;
  final Value<int> tagId;
  final Value<int> rowid;
  const NoteTagsCompanion({
    this.noteId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagsCompanion.insert({
    required int noteId,
    required int tagId,
    this.rowid = const Value.absent(),
  })  : noteId = Value(noteId),
        tagId = Value(tagId);
  static Insertable<NoteTag> custom({
    Expression<int>? noteId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagsCompanion copyWith(
      {Value<int>? noteId, Value<int>? tagId, Value<int>? rowid}) {
    return NoteTagsCompanion(
      noteId: noteId ?? this.noteId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagsCompanion(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteRelationsTable extends NoteRelations
    with TableInfo<$NoteRelationsTable, NoteRelation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteRelationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteId1Meta =
      const VerificationMeta('noteId1');
  @override
  late final GeneratedColumn<int> noteId1 = GeneratedColumn<int>(
      'note_id1', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES notes (id) ON DELETE CASCADE'));
  static const VerificationMeta _noteId2Meta =
      const VerificationMeta('noteId2');
  @override
  late final GeneratedColumn<int> noteId2 = GeneratedColumn<int>(
      'note_id2', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES notes (id) ON DELETE CASCADE'));
  @override
  List<GeneratedColumn> get $columns => [noteId1, noteId2];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_relations';
  @override
  VerificationContext validateIntegrity(Insertable<NoteRelation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id1')) {
      context.handle(_noteId1Meta,
          noteId1.isAcceptableOrUnknown(data['note_id1']!, _noteId1Meta));
    } else if (isInserting) {
      context.missing(_noteId1Meta);
    }
    if (data.containsKey('note_id2')) {
      context.handle(_noteId2Meta,
          noteId2.isAcceptableOrUnknown(data['note_id2']!, _noteId2Meta));
    } else if (isInserting) {
      context.missing(_noteId2Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId1, noteId2};
  @override
  NoteRelation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRelation(
      noteId1: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}note_id1'])!,
      noteId2: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}note_id2'])!,
    );
  }

  @override
  $NoteRelationsTable createAlias(String alias) {
    return $NoteRelationsTable(attachedDatabase, alias);
  }
}

class NoteRelation extends DataClass implements Insertable<NoteRelation> {
  final int noteId1;
  final int noteId2;
  const NoteRelation({required this.noteId1, required this.noteId2});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id1'] = Variable<int>(noteId1);
    map['note_id2'] = Variable<int>(noteId2);
    return map;
  }

  NoteRelationsCompanion toCompanion(bool nullToAbsent) {
    return NoteRelationsCompanion(
      noteId1: Value(noteId1),
      noteId2: Value(noteId2),
    );
  }

  factory NoteRelation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRelation(
      noteId1: serializer.fromJson<int>(json['noteId1']),
      noteId2: serializer.fromJson<int>(json['noteId2']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId1': serializer.toJson<int>(noteId1),
      'noteId2': serializer.toJson<int>(noteId2),
    };
  }

  NoteRelation copyWith({int? noteId1, int? noteId2}) => NoteRelation(
        noteId1: noteId1 ?? this.noteId1,
        noteId2: noteId2 ?? this.noteId2,
      );
  NoteRelation copyWithCompanion(NoteRelationsCompanion data) {
    return NoteRelation(
      noteId1: data.noteId1.present ? data.noteId1.value : this.noteId1,
      noteId2: data.noteId2.present ? data.noteId2.value : this.noteId2,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRelation(')
          ..write('noteId1: $noteId1, ')
          ..write('noteId2: $noteId2')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId1, noteId2);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRelation &&
          other.noteId1 == this.noteId1 &&
          other.noteId2 == this.noteId2);
}

class NoteRelationsCompanion extends UpdateCompanion<NoteRelation> {
  final Value<int> noteId1;
  final Value<int> noteId2;
  final Value<int> rowid;
  const NoteRelationsCompanion({
    this.noteId1 = const Value.absent(),
    this.noteId2 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteRelationsCompanion.insert({
    required int noteId1,
    required int noteId2,
    this.rowid = const Value.absent(),
  })  : noteId1 = Value(noteId1),
        noteId2 = Value(noteId2);
  static Insertable<NoteRelation> custom({
    Expression<int>? noteId1,
    Expression<int>? noteId2,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId1 != null) 'note_id1': noteId1,
      if (noteId2 != null) 'note_id2': noteId2,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteRelationsCompanion copyWith(
      {Value<int>? noteId1, Value<int>? noteId2, Value<int>? rowid}) {
    return NoteRelationsCompanion(
      noteId1: noteId1 ?? this.noteId1,
      noteId2: noteId2 ?? this.noteId2,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId1.present) {
      map['note_id1'] = Variable<int>(noteId1.value);
    }
    if (noteId2.present) {
      map['note_id2'] = Variable<int>(noteId2.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteRelationsCompanion(')
          ..write('noteId1: $noteId1, ')
          ..write('noteId2: $noteId2, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiProvidersTable extends AiProviders
    with TableInfo<$AiProvidersTable, AiProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 20),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _baseUrlMeta =
      const VerificationMeta('baseUrl');
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
      'base_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
      'api_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modelNameMeta =
      const VerificationMeta('modelName');
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
      'model_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _extraConfigMeta =
      const VerificationMeta('extraConfig');
  @override
  late final GeneratedColumn<String> extraConfig = GeneratedColumn<String>(
      'extra_config', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, type, baseUrl, apiKey, modelName, isDefault, extraConfig];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_providers';
  @override
  VerificationContext validateIntegrity(Insertable<AiProvider> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(_baseUrlMeta,
          baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta));
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('api_key')) {
      context.handle(_apiKeyMeta,
          apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta));
    }
    if (data.containsKey('model_name')) {
      context.handle(_modelNameMeta,
          modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta));
    } else if (isInserting) {
      context.missing(_modelNameMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('extra_config')) {
      context.handle(
          _extraConfigMeta,
          extraConfig.isAcceptableOrUnknown(
              data['extra_config']!, _extraConfigMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiProvider(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      baseUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_url'])!,
      apiKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_key']),
      modelName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_name'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      extraConfig: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extra_config']),
    );
  }

  @override
  $AiProvidersTable createAlias(String alias) {
    return $AiProvidersTable(attachedDatabase, alias);
  }
}

class AiProvider extends DataClass implements Insertable<AiProvider> {
  final int id;
  final String name;
  final String type;
  final String baseUrl;
  final String? apiKey;
  final String modelName;
  final bool isDefault;
  final String? extraConfig;
  const AiProvider(
      {required this.id,
      required this.name,
      required this.type,
      required this.baseUrl,
      this.apiKey,
      required this.modelName,
      required this.isDefault,
      this.extraConfig});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['base_url'] = Variable<String>(baseUrl);
    if (!nullToAbsent || apiKey != null) {
      map['api_key'] = Variable<String>(apiKey);
    }
    map['model_name'] = Variable<String>(modelName);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || extraConfig != null) {
      map['extra_config'] = Variable<String>(extraConfig);
    }
    return map;
  }

  AiProvidersCompanion toCompanion(bool nullToAbsent) {
    return AiProvidersCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      baseUrl: Value(baseUrl),
      apiKey:
          apiKey == null && nullToAbsent ? const Value.absent() : Value(apiKey),
      modelName: Value(modelName),
      isDefault: Value(isDefault),
      extraConfig: extraConfig == null && nullToAbsent
          ? const Value.absent()
          : Value(extraConfig),
    );
  }

  factory AiProvider.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiProvider(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      apiKey: serializer.fromJson<String?>(json['apiKey']),
      modelName: serializer.fromJson<String>(json['modelName']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      extraConfig: serializer.fromJson<String?>(json['extraConfig']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'apiKey': serializer.toJson<String?>(apiKey),
      'modelName': serializer.toJson<String>(modelName),
      'isDefault': serializer.toJson<bool>(isDefault),
      'extraConfig': serializer.toJson<String?>(extraConfig),
    };
  }

  AiProvider copyWith(
          {int? id,
          String? name,
          String? type,
          String? baseUrl,
          Value<String?> apiKey = const Value.absent(),
          String? modelName,
          bool? isDefault,
          Value<String?> extraConfig = const Value.absent()}) =>
      AiProvider(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey.present ? apiKey.value : this.apiKey,
        modelName: modelName ?? this.modelName,
        isDefault: isDefault ?? this.isDefault,
        extraConfig: extraConfig.present ? extraConfig.value : this.extraConfig,
      );
  AiProvider copyWithCompanion(AiProvidersCompanion data) {
    return AiProvider(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      extraConfig:
          data.extraConfig.present ? data.extraConfig.value : this.extraConfig,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiProvider(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('modelName: $modelName, ')
          ..write('isDefault: $isDefault, ')
          ..write('extraConfig: $extraConfig')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, type, baseUrl, apiKey, modelName, isDefault, extraConfig);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiProvider &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.baseUrl == this.baseUrl &&
          other.apiKey == this.apiKey &&
          other.modelName == this.modelName &&
          other.isDefault == this.isDefault &&
          other.extraConfig == this.extraConfig);
}

class AiProvidersCompanion extends UpdateCompanion<AiProvider> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> baseUrl;
  final Value<String?> apiKey;
  final Value<String> modelName;
  final Value<bool> isDefault;
  final Value<String?> extraConfig;
  const AiProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.modelName = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.extraConfig = const Value.absent(),
  });
  AiProvidersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    required String baseUrl,
    this.apiKey = const Value.absent(),
    required String modelName,
    this.isDefault = const Value.absent(),
    this.extraConfig = const Value.absent(),
  })  : name = Value(name),
        type = Value(type),
        baseUrl = Value(baseUrl),
        modelName = Value(modelName);
  static Insertable<AiProvider> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? baseUrl,
    Expression<String>? apiKey,
    Expression<String>? modelName,
    Expression<bool>? isDefault,
    Expression<String>? extraConfig,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (baseUrl != null) 'base_url': baseUrl,
      if (apiKey != null) 'api_key': apiKey,
      if (modelName != null) 'model_name': modelName,
      if (isDefault != null) 'is_default': isDefault,
      if (extraConfig != null) 'extra_config': extraConfig,
    });
  }

  AiProvidersCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? type,
      Value<String>? baseUrl,
      Value<String?>? apiKey,
      Value<String>? modelName,
      Value<bool>? isDefault,
      Value<String?>? extraConfig}) {
    return AiProvidersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      isDefault: isDefault ?? this.isDefault,
      extraConfig: extraConfig ?? this.extraConfig,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (extraConfig.present) {
      map['extra_config'] = Variable<String>(extraConfig.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiProvidersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('modelName: $modelName, ')
          ..write('isDefault: $isDefault, ')
          ..write('extraConfig: $extraConfig')
          ..write(')'))
        .toString();
  }
}

class $AiConversationsTable extends AiConversations
    with TableInfo<$AiConversationsTable, AiConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE SET NULL'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, bookId, title, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_conversations';
  @override
  VerificationContext validateIntegrity(Insertable<AiConversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AiConversationsTable createAlias(String alias) {
    return $AiConversationsTable(attachedDatabase, alias);
  }
}

class AiConversation extends DataClass implements Insertable<AiConversation> {
  final int id;
  final int? bookId;
  final String? title;
  final DateTime createdAt;
  const AiConversation(
      {required this.id, this.bookId, this.title, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<int>(bookId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AiConversationsCompanion toCompanion(bool nullToAbsent) {
    return AiConversationsCompanion(
      id: Value(id),
      bookId:
          bookId == null && nullToAbsent ? const Value.absent() : Value(bookId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      createdAt: Value(createdAt),
    );
  }

  factory AiConversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConversation(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int?>(json['bookId']),
      title: serializer.fromJson<String?>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int?>(bookId),
      'title': serializer.toJson<String?>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiConversation copyWith(
          {int? id,
          Value<int?> bookId = const Value.absent(),
          Value<String?> title = const Value.absent(),
          DateTime? createdAt}) =>
      AiConversation(
        id: id ?? this.id,
        bookId: bookId.present ? bookId.value : this.bookId,
        title: title.present ? title.value : this.title,
        createdAt: createdAt ?? this.createdAt,
      );
  AiConversation copyWithCompanion(AiConversationsCompanion data) {
    return AiConversation(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConversation(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, title, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConversation &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.createdAt == this.createdAt);
}

class AiConversationsCompanion extends UpdateCompanion<AiConversation> {
  final Value<int> id;
  final Value<int?> bookId;
  final Value<String?> title;
  final Value<DateTime> createdAt;
  const AiConversationsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AiConversationsCompanion.insert({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  static Insertable<AiConversation> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AiConversationsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? bookId,
      Value<String?>? title,
      Value<DateTime>? createdAt}) {
    return AiConversationsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConversationsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AiMessagesTable extends AiMessages
    with TableInfo<$AiMessagesTable, AiMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES ai_conversations (id) ON DELETE CASCADE'));
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 20),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataJsonMeta =
      const VerificationMeta('metadataJson');
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
      'metadata_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, conversationId, role, content, metadataJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_messages';
  @override
  VerificationContext validateIntegrity(Insertable<AiMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
          _metadataJsonMeta,
          metadataJson.isAcceptableOrUnknown(
              data['metadata_json']!, _metadataJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conversation_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      metadataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AiMessagesTable createAlias(String alias) {
    return $AiMessagesTable(attachedDatabase, alias);
  }
}

class AiMessage extends DataClass implements Insertable<AiMessage> {
  final int id;
  final int conversationId;
  final String role;
  final String content;
  final String? metadataJson;
  final DateTime createdAt;
  const AiMessage(
      {required this.id,
      required this.conversationId,
      required this.role,
      required this.content,
      this.metadataJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AiMessagesCompanion toCompanion(bool nullToAbsent) {
    return AiMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      createdAt: Value(createdAt),
    );
  }

  factory AiMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiMessage(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiMessage copyWith(
          {int? id,
          int? conversationId,
          String? role,
          String? content,
          Value<String?> metadataJson = const Value.absent(),
          DateTime? createdAt}) =>
      AiMessage(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        role: role ?? this.role,
        content: content ?? this.content,
        metadataJson:
            metadataJson.present ? metadataJson.value : this.metadataJson,
        createdAt: createdAt ?? this.createdAt,
      );
  AiMessage copyWithCompanion(AiMessagesCompanion data) {
    return AiMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, conversationId, role, content, metadataJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt);
}

class AiMessagesCompanion extends UpdateCompanion<AiMessage> {
  final Value<int> id;
  final Value<int> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String?> metadataJson;
  final Value<DateTime> createdAt;
  const AiMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AiMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required String role,
    required String content,
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : conversationId = Value(conversationId),
        role = Value(role),
        content = Value(content);
  static Insertable<AiMessage> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AiMessagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? conversationId,
      Value<String>? role,
      Value<String>? content,
      Value<String?>? metadataJson,
      Value<DateTime>? createdAt}) {
    return AiMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AiSkillsTable extends AiSkills with TableInfo<$AiSkillsTable, AiSkill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiSkillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _contentMarkdownMeta =
      const VerificationMeta('contentMarkdown');
  @override
  late final GeneratedColumn<String> contentMarkdown = GeneratedColumn<String>(
      'content_markdown', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _allowedToolsJsonMeta =
      const VerificationMeta('allowedToolsJson');
  @override
  late final GeneratedColumn<String> allowedToolsJson = GeneratedColumn<String>(
      'allowed_tools_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        contentMarkdown,
        allowedToolsJson,
        enabled,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_skills';
  @override
  VerificationContext validateIntegrity(Insertable<AiSkill> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('content_markdown')) {
      context.handle(
          _contentMarkdownMeta,
          contentMarkdown.isAcceptableOrUnknown(
              data['content_markdown']!, _contentMarkdownMeta));
    } else if (isInserting) {
      context.missing(_contentMarkdownMeta);
    }
    if (data.containsKey('allowed_tools_json')) {
      context.handle(
          _allowedToolsJsonMeta,
          allowedToolsJson.isAcceptableOrUnknown(
              data['allowed_tools_json']!, _allowedToolsJsonMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiSkill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiSkill(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      contentMarkdown: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}content_markdown'])!,
      allowedToolsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}allowed_tools_json'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AiSkillsTable createAlias(String alias) {
    return $AiSkillsTable(attachedDatabase, alias);
  }
}

class AiSkill extends DataClass implements Insertable<AiSkill> {
  final int id;
  final String name;
  final String description;
  final String contentMarkdown;
  final String allowedToolsJson;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiSkill(
      {required this.id,
      required this.name,
      required this.description,
      required this.contentMarkdown,
      required this.allowedToolsJson,
      required this.enabled,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['content_markdown'] = Variable<String>(contentMarkdown);
    map['allowed_tools_json'] = Variable<String>(allowedToolsJson);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiSkillsCompanion toCompanion(bool nullToAbsent) {
    return AiSkillsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      contentMarkdown: Value(contentMarkdown),
      allowedToolsJson: Value(allowedToolsJson),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiSkill.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiSkill(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      contentMarkdown: serializer.fromJson<String>(json['contentMarkdown']),
      allowedToolsJson: serializer.fromJson<String>(json['allowedToolsJson']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'contentMarkdown': serializer.toJson<String>(contentMarkdown),
      'allowedToolsJson': serializer.toJson<String>(allowedToolsJson),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiSkill copyWith(
          {int? id,
          String? name,
          String? description,
          String? contentMarkdown,
          String? allowedToolsJson,
          bool? enabled,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      AiSkill(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        contentMarkdown: contentMarkdown ?? this.contentMarkdown,
        allowedToolsJson: allowedToolsJson ?? this.allowedToolsJson,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AiSkill copyWithCompanion(AiSkillsCompanion data) {
    return AiSkill(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      contentMarkdown: data.contentMarkdown.present
          ? data.contentMarkdown.value
          : this.contentMarkdown,
      allowedToolsJson: data.allowedToolsJson.present
          ? data.allowedToolsJson.value
          : this.allowedToolsJson,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiSkill(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('contentMarkdown: $contentMarkdown, ')
          ..write('allowedToolsJson: $allowedToolsJson, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, contentMarkdown,
      allowedToolsJson, enabled, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiSkill &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.contentMarkdown == this.contentMarkdown &&
          other.allowedToolsJson == this.allowedToolsJson &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiSkillsCompanion extends UpdateCompanion<AiSkill> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> contentMarkdown;
  final Value<String> allowedToolsJson;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AiSkillsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.contentMarkdown = const Value.absent(),
    this.allowedToolsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AiSkillsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required String contentMarkdown,
    this.allowedToolsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : name = Value(name),
        contentMarkdown = Value(contentMarkdown);
  static Insertable<AiSkill> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? contentMarkdown,
    Expression<String>? allowedToolsJson,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (contentMarkdown != null) 'content_markdown': contentMarkdown,
      if (allowedToolsJson != null) 'allowed_tools_json': allowedToolsJson,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AiSkillsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? description,
      Value<String>? contentMarkdown,
      Value<String>? allowedToolsJson,
      Value<bool>? enabled,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return AiSkillsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      contentMarkdown: contentMarkdown ?? this.contentMarkdown,
      allowedToolsJson: allowedToolsJson ?? this.allowedToolsJson,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (contentMarkdown.present) {
      map['content_markdown'] = Variable<String>(contentMarkdown.value);
    }
    if (allowedToolsJson.present) {
      map['allowed_tools_json'] = Variable<String>(allowedToolsJson.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiSkillsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('contentMarkdown: $contentMarkdown, ')
          ..write('allowedToolsJson: $allowedToolsJson, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AiPersonasTable extends AiPersonas
    with TableInfo<$AiPersonasTable, AiPersona> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiPersonasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 20),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
      'book_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES books (id) ON DELETE SET NULL'));
  static const VerificationMeta _characterNameMeta =
      const VerificationMeta('characterName');
  @override
  late final GeneratedColumn<String> characterName = GeneratedColumn<String>(
      'character_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _systemPromptMeta =
      const VerificationMeta('systemPrompt');
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
      'system_prompt', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _documentMarkdownMeta =
      const VerificationMeta('documentMarkdown');
  @override
  late final GeneratedColumn<String> documentMarkdown = GeneratedColumn<String>(
      'document_markdown', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        type,
        bookId,
        characterName,
        systemPrompt,
        documentMarkdown,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_personas';
  @override
  VerificationContext validateIntegrity(Insertable<AiPersona> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('character_name')) {
      context.handle(
          _characterNameMeta,
          characterName.isAcceptableOrUnknown(
              data['character_name']!, _characterNameMeta));
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
          _systemPromptMeta,
          systemPrompt.isAcceptableOrUnknown(
              data['system_prompt']!, _systemPromptMeta));
    }
    if (data.containsKey('document_markdown')) {
      context.handle(
          _documentMarkdownMeta,
          documentMarkdown.isAcceptableOrUnknown(
              data['document_markdown']!, _documentMarkdownMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiPersona map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiPersona(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}book_id']),
      characterName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}character_name']),
      systemPrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}system_prompt'])!,
      documentMarkdown: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}document_markdown'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AiPersonasTable createAlias(String alias) {
    return $AiPersonasTable(attachedDatabase, alias);
  }
}

class AiPersona extends DataClass implements Insertable<AiPersona> {
  final int id;
  final String name;
  final String type;
  final int? bookId;
  final String? characterName;
  final String systemPrompt;
  final String documentMarkdown;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AiPersona(
      {required this.id,
      required this.name,
      required this.type,
      this.bookId,
      this.characterName,
      required this.systemPrompt,
      required this.documentMarkdown,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<int>(bookId);
    }
    if (!nullToAbsent || characterName != null) {
      map['character_name'] = Variable<String>(characterName);
    }
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['document_markdown'] = Variable<String>(documentMarkdown);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AiPersonasCompanion toCompanion(bool nullToAbsent) {
    return AiPersonasCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      bookId:
          bookId == null && nullToAbsent ? const Value.absent() : Value(bookId),
      characterName: characterName == null && nullToAbsent
          ? const Value.absent()
          : Value(characterName),
      systemPrompt: Value(systemPrompt),
      documentMarkdown: Value(documentMarkdown),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiPersona.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiPersona(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      bookId: serializer.fromJson<int?>(json['bookId']),
      characterName: serializer.fromJson<String?>(json['characterName']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      documentMarkdown: serializer.fromJson<String>(json['documentMarkdown']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'bookId': serializer.toJson<int?>(bookId),
      'characterName': serializer.toJson<String?>(characterName),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'documentMarkdown': serializer.toJson<String>(documentMarkdown),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AiPersona copyWith(
          {int? id,
          String? name,
          String? type,
          Value<int?> bookId = const Value.absent(),
          Value<String?> characterName = const Value.absent(),
          String? systemPrompt,
          String? documentMarkdown,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      AiPersona(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        bookId: bookId.present ? bookId.value : this.bookId,
        characterName:
            characterName.present ? characterName.value : this.characterName,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        documentMarkdown: documentMarkdown ?? this.documentMarkdown,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AiPersona copyWithCompanion(AiPersonasCompanion data) {
    return AiPersona(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      characterName: data.characterName.present
          ? data.characterName.value
          : this.characterName,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      documentMarkdown: data.documentMarkdown.present
          ? data.documentMarkdown.value
          : this.documentMarkdown,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiPersona(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('bookId: $bookId, ')
          ..write('characterName: $characterName, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('documentMarkdown: $documentMarkdown, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, bookId, characterName,
      systemPrompt, documentMarkdown, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiPersona &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.bookId == this.bookId &&
          other.characterName == this.characterName &&
          other.systemPrompt == this.systemPrompt &&
          other.documentMarkdown == this.documentMarkdown &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiPersonasCompanion extends UpdateCompanion<AiPersona> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<int?> bookId;
  final Value<String?> characterName;
  final Value<String> systemPrompt;
  final Value<String> documentMarkdown;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AiPersonasCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.bookId = const Value.absent(),
    this.characterName = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.documentMarkdown = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AiPersonasCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    this.bookId = const Value.absent(),
    this.characterName = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.documentMarkdown = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : name = Value(name),
        type = Value(type);
  static Insertable<AiPersona> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? bookId,
    Expression<String>? characterName,
    Expression<String>? systemPrompt,
    Expression<String>? documentMarkdown,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (bookId != null) 'book_id': bookId,
      if (characterName != null) 'character_name': characterName,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (documentMarkdown != null) 'document_markdown': documentMarkdown,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AiPersonasCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? type,
      Value<int?>? bookId,
      Value<String?>? characterName,
      Value<String>? systemPrompt,
      Value<String>? documentMarkdown,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return AiPersonasCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      bookId: bookId ?? this.bookId,
      characterName: characterName ?? this.characterName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      documentMarkdown: documentMarkdown ?? this.documentMarkdown,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (characterName.present) {
      map['character_name'] = Variable<String>(characterName.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (documentMarkdown.present) {
      map['document_markdown'] = Variable<String>(documentMarkdown.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiPersonasCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('bookId: $bookId, ')
          ..write('characterName: $characterName, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('documentMarkdown: $documentMarkdown, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $BookCollectionsTable bookCollections =
      $BookCollectionsTable(this);
  late final $BookCollectionItemsTable bookCollectionItems =
      $BookCollectionItemsTable(this);
  late final $BookTtsSettingsTable bookTtsSettings =
      $BookTtsSettingsTable(this);
  late final $BookReadingSettingsTable bookReadingSettings =
      $BookReadingSettingsTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $VocabularyEntriesTable vocabularyEntries =
      $VocabularyEntriesTable(this);
  late final $DictionarySourcesTable dictionarySources =
      $DictionarySourcesTable(this);
  late final $DictionaryEntriesTable dictionaryEntries =
      $DictionaryEntriesTable(this);
  late final $DictionaryAliasesTable dictionaryAliases =
      $DictionaryAliasesTable(this);
  late final $ReadingProgressTable readingProgress =
      $ReadingProgressTable(this);
  late final $ReadingSessionsTable readingSessions =
      $ReadingSessionsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $NoteTagsTable noteTags = $NoteTagsTable(this);
  late final $NoteRelationsTable noteRelations = $NoteRelationsTable(this);
  late final $AiProvidersTable aiProviders = $AiProvidersTable(this);
  late final $AiConversationsTable aiConversations =
      $AiConversationsTable(this);
  late final $AiMessagesTable aiMessages = $AiMessagesTable(this);
  late final $AiSkillsTable aiSkills = $AiSkillsTable(this);
  late final $AiPersonasTable aiPersonas = $AiPersonasTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        books,
        bookCollections,
        bookCollectionItems,
        bookTtsSettings,
        bookReadingSettings,
        chapters,
        vocabularyEntries,
        dictionarySources,
        dictionaryEntries,
        dictionaryAliases,
        readingProgress,
        readingSessions,
        notes,
        tags,
        noteTags,
        noteRelations,
        aiProviders,
        aiConversations,
        aiMessages,
        aiSkills,
        aiPersonas
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('book_collections',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('book_collection_items', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('book_collection_items', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('book_tts_settings', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('book_reading_settings', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('chapters', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('vocabulary_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('chapters',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('vocabulary_entries', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('dictionary_sources',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('dictionary_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('dictionary_sources',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('dictionary_aliases', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reading_progress', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('chapters',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reading_progress', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reading_sessions', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('notes', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('chapters',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('notes', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('notes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('note_tags', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tags',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('note_tags', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('notes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('note_relations', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('notes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('note_relations', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('ai_conversations', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('ai_conversations',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('ai_messages', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('books',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('ai_personas', kind: UpdateKind.update),
            ],
          ),
        ],
      );
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  required String title,
  Value<String> author,
  Value<String?> coverPath,
  required String filePath,
  required String format,
  required int fileSize,
  Value<String?> description,
  Value<String?> fileHash,
  Value<String?> seriesName,
  Value<double?> seriesIndex,
  Value<String?> readingStatus,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> author,
  Value<String?> coverPath,
  Value<String> filePath,
  Value<String> format,
  Value<int> fileSize,
  Value<String?> description,
  Value<String?> fileHash,
  Value<String?> seriesName,
  Value<double?> seriesIndex,
  Value<String?> readingStatus,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, Book> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookCollectionItemsTable,
      List<BookCollectionItem>> _bookCollectionItemsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.bookCollectionItems,
          aliasName: 'books__id__book_collection_items__book_id');

  $$BookCollectionItemsTableProcessedTableManager get bookCollectionItemsRefs {
    final manager =
        $$BookCollectionItemsTableTableManager($_db, $_db.bookCollectionItems)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_bookCollectionItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$BookTtsSettingsTable, List<BookTtsSetting>>
      _bookTtsSettingsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.bookTtsSettings,
              aliasName: 'books__id__book_tts_settings__book_id');

  $$BookTtsSettingsTableProcessedTableManager get bookTtsSettingsRefs {
    final manager =
        $$BookTtsSettingsTableTableManager($_db, $_db.bookTtsSettings)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_bookTtsSettingsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$BookReadingSettingsTable,
      List<BookReadingSetting>> _bookReadingSettingsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.bookReadingSettings,
          aliasName: 'books__id__book_reading_settings__book_id');

  $$BookReadingSettingsTableProcessedTableManager get bookReadingSettingsRefs {
    final manager =
        $$BookReadingSettingsTableTableManager($_db, $_db.bookReadingSettings)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_bookReadingSettingsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ChaptersTable, List<Chapter>> _chaptersRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.chapters,
          aliasName: 'books__id__chapters__book_id');

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager($_db, $_db.chapters)
        .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$VocabularyEntriesTable, List<VocabularyEntry>>
      _vocabularyEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.vocabularyEntries,
              aliasName: 'books__id__vocabulary_entries__book_id');

  $$VocabularyEntriesTableProcessedTableManager get vocabularyEntriesRefs {
    final manager =
        $$VocabularyEntriesTableTableManager($_db, $_db.vocabularyEntries)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_vocabularyEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReadingProgressTable, List<ReadingProgressData>>
      _readingProgressRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.readingProgress,
              aliasName: 'books__id__reading_progress__book_id');

  $$ReadingProgressTableProcessedTableManager get readingProgressRefs {
    final manager =
        $$ReadingProgressTableTableManager($_db, $_db.readingProgress)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_readingProgressRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReadingSessionsTable, List<ReadingSession>>
      _readingSessionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.readingSessions,
              aliasName: 'books__id__reading_sessions__book_id');

  $$ReadingSessionsTableProcessedTableManager get readingSessionsRefs {
    final manager =
        $$ReadingSessionsTableTableManager($_db, $_db.readingSessions)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_readingSessionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.notes,
          aliasName: 'books__id__notes__book_id');

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager($_db, $_db.notes)
        .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AiConversationsTable, List<AiConversation>>
      _aiConversationsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.aiConversations,
              aliasName: 'books__id__ai_conversations__book_id');

  $$AiConversationsTableProcessedTableManager get aiConversationsRefs {
    final manager =
        $$AiConversationsTableTableManager($_db, $_db.aiConversations)
            .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_aiConversationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AiPersonasTable, List<AiPersona>>
      _aiPersonasRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.aiPersonas,
              aliasName: 'books__id__ai_personas__book_id');

  $$AiPersonasTableProcessedTableManager get aiPersonasRefs {
    final manager = $$AiPersonasTableTableManager($_db, $_db.aiPersonas)
        .filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_aiPersonasRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileHash => $composableBuilder(
      column: $table.fileHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seriesName => $composableBuilder(
      column: $table.seriesName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get seriesIndex => $composableBuilder(
      column: $table.seriesIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get readingStatus => $composableBuilder(
      column: $table.readingStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> bookCollectionItemsRefs(
      Expression<bool> Function($$BookCollectionItemsTableFilterComposer f) f) {
    final $$BookCollectionItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bookCollectionItems,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookCollectionItemsTableFilterComposer(
              $db: $db,
              $table: $db.bookCollectionItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> bookTtsSettingsRefs(
      Expression<bool> Function($$BookTtsSettingsTableFilterComposer f) f) {
    final $$BookTtsSettingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bookTtsSettings,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookTtsSettingsTableFilterComposer(
              $db: $db,
              $table: $db.bookTtsSettings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> bookReadingSettingsRefs(
      Expression<bool> Function($$BookReadingSettingsTableFilterComposer f) f) {
    final $$BookReadingSettingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bookReadingSettings,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookReadingSettingsTableFilterComposer(
              $db: $db,
              $table: $db.bookReadingSettings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> chaptersRefs(
      Expression<bool> Function($$ChaptersTableFilterComposer f) f) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableFilterComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> vocabularyEntriesRefs(
      Expression<bool> Function($$VocabularyEntriesTableFilterComposer f) f) {
    final $$VocabularyEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.vocabularyEntries,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VocabularyEntriesTableFilterComposer(
              $db: $db,
              $table: $db.vocabularyEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> readingProgressRefs(
      Expression<bool> Function($$ReadingProgressTableFilterComposer f) f) {
    final $$ReadingProgressTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingProgress,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingProgressTableFilterComposer(
              $db: $db,
              $table: $db.readingProgress,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> readingSessionsRefs(
      Expression<bool> Function($$ReadingSessionsTableFilterComposer f) f) {
    final $$ReadingSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingSessions,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingSessionsTableFilterComposer(
              $db: $db,
              $table: $db.readingSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> notesRefs(
      Expression<bool> Function($$NotesTableFilterComposer f) f) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableFilterComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> aiConversationsRefs(
      Expression<bool> Function($$AiConversationsTableFilterComposer f) f) {
    final $$AiConversationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aiConversations,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiConversationsTableFilterComposer(
              $db: $db,
              $table: $db.aiConversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> aiPersonasRefs(
      Expression<bool> Function($$AiPersonasTableFilterComposer f) f) {
    final $$AiPersonasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aiPersonas,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiPersonasTableFilterComposer(
              $db: $db,
              $table: $db.aiPersonas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverPath => $composableBuilder(
      column: $table.coverPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format => $composableBuilder(
      column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileHash => $composableBuilder(
      column: $table.fileHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seriesName => $composableBuilder(
      column: $table.seriesName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get seriesIndex => $composableBuilder(
      column: $table.seriesIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get readingStatus => $composableBuilder(
      column: $table.readingStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get seriesName => $composableBuilder(
      column: $table.seriesName, builder: (column) => column);

  GeneratedColumn<double> get seriesIndex => $composableBuilder(
      column: $table.seriesIndex, builder: (column) => column);

  GeneratedColumn<String> get readingStatus => $composableBuilder(
      column: $table.readingStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> bookCollectionItemsRefs<T extends Object>(
      Expression<T> Function($$BookCollectionItemsTableAnnotationComposer a)
          f) {
    final $$BookCollectionItemsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.bookCollectionItems,
            getReferencedColumn: (t) => t.bookId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BookCollectionItemsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.bookCollectionItems,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> bookTtsSettingsRefs<T extends Object>(
      Expression<T> Function($$BookTtsSettingsTableAnnotationComposer a) f) {
    final $$BookTtsSettingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bookTtsSettings,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookTtsSettingsTableAnnotationComposer(
              $db: $db,
              $table: $db.bookTtsSettings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> bookReadingSettingsRefs<T extends Object>(
      Expression<T> Function($$BookReadingSettingsTableAnnotationComposer a)
          f) {
    final $$BookReadingSettingsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.bookReadingSettings,
            getReferencedColumn: (t) => t.bookId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BookReadingSettingsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.bookReadingSettings,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> chaptersRefs<T extends Object>(
      Expression<T> Function($$ChaptersTableAnnotationComposer a) f) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableAnnotationComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> vocabularyEntriesRefs<T extends Object>(
      Expression<T> Function($$VocabularyEntriesTableAnnotationComposer a) f) {
    final $$VocabularyEntriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.vocabularyEntries,
            getReferencedColumn: (t) => t.bookId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$VocabularyEntriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.vocabularyEntries,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> readingProgressRefs<T extends Object>(
      Expression<T> Function($$ReadingProgressTableAnnotationComposer a) f) {
    final $$ReadingProgressTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingProgress,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingProgressTableAnnotationComposer(
              $db: $db,
              $table: $db.readingProgress,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> readingSessionsRefs<T extends Object>(
      Expression<T> Function($$ReadingSessionsTableAnnotationComposer a) f) {
    final $$ReadingSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingSessions,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.readingSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
      Expression<T> Function($$NotesTableAnnotationComposer a) f) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableAnnotationComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> aiConversationsRefs<T extends Object>(
      Expression<T> Function($$AiConversationsTableAnnotationComposer a) f) {
    final $$AiConversationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aiConversations,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiConversationsTableAnnotationComposer(
              $db: $db,
              $table: $db.aiConversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> aiPersonasRefs<T extends Object>(
      Expression<T> Function($$AiPersonasTableAnnotationComposer a) f) {
    final $$AiPersonasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aiPersonas,
        getReferencedColumn: (t) => t.bookId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiPersonasTableAnnotationComposer(
              $db: $db,
              $table: $db.aiPersonas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BooksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BooksTable,
    Book,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (Book, $$BooksTableReferences),
    Book,
    PrefetchHooks Function(
        {bool bookCollectionItemsRefs,
        bool bookTtsSettingsRefs,
        bool bookReadingSettingsRefs,
        bool chaptersRefs,
        bool vocabularyEntriesRefs,
        bool readingProgressRefs,
        bool readingSessionsRefs,
        bool notesRefs,
        bool aiConversationsRefs,
        bool aiPersonasRefs})> {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String?> coverPath = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> format = const Value.absent(),
            Value<int> fileSize = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> fileHash = const Value.absent(),
            Value<String?> seriesName = const Value.absent(),
            Value<double?> seriesIndex = const Value.absent(),
            Value<String?> readingStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BooksCompanion(
            id: id,
            title: title,
            author: author,
            coverPath: coverPath,
            filePath: filePath,
            format: format,
            fileSize: fileSize,
            description: description,
            fileHash: fileHash,
            seriesName: seriesName,
            seriesIndex: seriesIndex,
            readingStatus: readingStatus,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            Value<String> author = const Value.absent(),
            Value<String?> coverPath = const Value.absent(),
            required String filePath,
            required String format,
            required int fileSize,
            Value<String?> description = const Value.absent(),
            Value<String?> fileHash = const Value.absent(),
            Value<String?> seriesName = const Value.absent(),
            Value<double?> seriesIndex = const Value.absent(),
            Value<String?> readingStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BooksCompanion.insert(
            id: id,
            title: title,
            author: author,
            coverPath: coverPath,
            filePath: filePath,
            format: format,
            fileSize: fileSize,
            description: description,
            fileHash: fileHash,
            seriesName: seriesName,
            seriesIndex: seriesIndex,
            readingStatus: readingStatus,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$BooksTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {bookCollectionItemsRefs = false,
              bookTtsSettingsRefs = false,
              bookReadingSettingsRefs = false,
              chaptersRefs = false,
              vocabularyEntriesRefs = false,
              readingProgressRefs = false,
              readingSessionsRefs = false,
              notesRefs = false,
              aiConversationsRefs = false,
              aiPersonasRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (bookCollectionItemsRefs) db.bookCollectionItems,
                if (bookTtsSettingsRefs) db.bookTtsSettings,
                if (bookReadingSettingsRefs) db.bookReadingSettings,
                if (chaptersRefs) db.chapters,
                if (vocabularyEntriesRefs) db.vocabularyEntries,
                if (readingProgressRefs) db.readingProgress,
                if (readingSessionsRefs) db.readingSessions,
                if (notesRefs) db.notes,
                if (aiConversationsRefs) db.aiConversations,
                if (aiPersonasRefs) db.aiPersonas
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (bookCollectionItemsRefs)
                    await $_getPrefetchedData<Book, $BooksTable,
                            BookCollectionItem>(
                        currentTable: table,
                        referencedTable: $$BooksTableReferences
                            ._bookCollectionItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .bookCollectionItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (bookTtsSettingsRefs)
                    await $_getPrefetchedData<Book, $BooksTable,
                            BookTtsSetting>(
                        currentTable: table,
                        referencedTable: $$BooksTableReferences
                            ._bookTtsSettingsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .bookTtsSettingsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (bookReadingSettingsRefs)
                    await $_getPrefetchedData<Book, $BooksTable,
                            BookReadingSetting>(
                        currentTable: table,
                        referencedTable: $$BooksTableReferences
                            ._bookReadingSettingsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .bookReadingSettingsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (chaptersRefs)
                    await $_getPrefetchedData<Book, $BooksTable, Chapter>(
                        currentTable: table,
                        referencedTable:
                            $$BooksTableReferences._chaptersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0).chaptersRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (vocabularyEntriesRefs)
                    await $_getPrefetchedData<Book, $BooksTable,
                            VocabularyEntry>(
                        currentTable: table,
                        referencedTable: $$BooksTableReferences
                            ._vocabularyEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .vocabularyEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (readingProgressRefs)
                    await $_getPrefetchedData<Book, $BooksTable,
                            ReadingProgressData>(
                        currentTable: table,
                        referencedTable: $$BooksTableReferences
                            ._readingProgressRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .readingProgressRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (readingSessionsRefs)
                    await $_getPrefetchedData<Book, $BooksTable,
                            ReadingSession>(
                        currentTable: table,
                        referencedTable: $$BooksTableReferences
                            ._readingSessionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .readingSessionsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (notesRefs)
                    await $_getPrefetchedData<Book, $BooksTable, Note>(
                        currentTable: table,
                        referencedTable:
                            $$BooksTableReferences._notesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0).notesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (aiConversationsRefs)
                    await $_getPrefetchedData<Book, $BooksTable,
                            AiConversation>(
                        currentTable: table,
                        referencedTable: $$BooksTableReferences
                            ._aiConversationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .aiConversationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items),
                  if (aiPersonasRefs)
                    await $_getPrefetchedData<Book, $BooksTable, AiPersona>(
                        currentTable: table,
                        referencedTable:
                            $$BooksTableReferences._aiPersonasRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BooksTableReferences(db, table, p0)
                                .aiPersonasRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.bookId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BooksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BooksTable,
    Book,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (Book, $$BooksTableReferences),
    Book,
    PrefetchHooks Function(
        {bool bookCollectionItemsRefs,
        bool bookTtsSettingsRefs,
        bool bookReadingSettingsRefs,
        bool chaptersRefs,
        bool vocabularyEntriesRefs,
        bool readingProgressRefs,
        bool readingSessionsRefs,
        bool notesRefs,
        bool aiConversationsRefs,
        bool aiPersonasRefs})>;
typedef $$BookCollectionsTableCreateCompanionBuilder = BookCollectionsCompanion
    Function({
  Value<int> id,
  required String name,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BookCollectionsTableUpdateCompanionBuilder = BookCollectionsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$BookCollectionsTableReferences extends BaseReferences<
    _$AppDatabase, $BookCollectionsTable, BookCollection> {
  $$BookCollectionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookCollectionItemsTable,
      List<BookCollectionItem>> _bookCollectionItemsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.bookCollectionItems,
          aliasName:
              'book_collections__id__book_collection_items__collection_id');

  $$BookCollectionItemsTableProcessedTableManager get bookCollectionItemsRefs {
    final manager = $$BookCollectionItemsTableTableManager(
            $_db, $_db.bookCollectionItems)
        .filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_bookCollectionItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BookCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> bookCollectionItemsRefs(
      Expression<bool> Function($$BookCollectionItemsTableFilterComposer f) f) {
    final $$BookCollectionItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.bookCollectionItems,
        getReferencedColumn: (t) => t.collectionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookCollectionItemsTableFilterComposer(
              $db: $db,
              $table: $db.bookCollectionItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BookCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BookCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> bookCollectionItemsRefs<T extends Object>(
      Expression<T> Function($$BookCollectionItemsTableAnnotationComposer a)
          f) {
    final $$BookCollectionItemsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.bookCollectionItems,
            getReferencedColumn: (t) => t.collectionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BookCollectionItemsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.bookCollectionItems,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$BookCollectionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookCollectionsTable,
    BookCollection,
    $$BookCollectionsTableFilterComposer,
    $$BookCollectionsTableOrderingComposer,
    $$BookCollectionsTableAnnotationComposer,
    $$BookCollectionsTableCreateCompanionBuilder,
    $$BookCollectionsTableUpdateCompanionBuilder,
    (BookCollection, $$BookCollectionsTableReferences),
    BookCollection,
    PrefetchHooks Function({bool bookCollectionItemsRefs})> {
  $$BookCollectionsTableTableManager(
      _$AppDatabase db, $BookCollectionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BookCollectionsCompanion(
            id: id,
            name: name,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BookCollectionsCompanion.insert(
            id: id,
            name: name,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BookCollectionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookCollectionItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (bookCollectionItemsRefs) db.bookCollectionItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (bookCollectionItemsRefs)
                    await $_getPrefetchedData<BookCollection,
                            $BookCollectionsTable, BookCollectionItem>(
                        currentTable: table,
                        referencedTable: $$BookCollectionsTableReferences
                            ._bookCollectionItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BookCollectionsTableReferences(db, table, p0)
                                .bookCollectionItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.collectionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BookCollectionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookCollectionsTable,
    BookCollection,
    $$BookCollectionsTableFilterComposer,
    $$BookCollectionsTableOrderingComposer,
    $$BookCollectionsTableAnnotationComposer,
    $$BookCollectionsTableCreateCompanionBuilder,
    $$BookCollectionsTableUpdateCompanionBuilder,
    (BookCollection, $$BookCollectionsTableReferences),
    BookCollection,
    PrefetchHooks Function({bool bookCollectionItemsRefs})>;
typedef $$BookCollectionItemsTableCreateCompanionBuilder
    = BookCollectionItemsCompanion Function({
  required int collectionId,
  required int bookId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});
typedef $$BookCollectionItemsTableUpdateCompanionBuilder
    = BookCollectionItemsCompanion Function({
  Value<int> collectionId,
  Value<int> bookId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

final class $$BookCollectionItemsTableReferences extends BaseReferences<
    _$AppDatabase, $BookCollectionItemsTable, BookCollectionItem> {
  $$BookCollectionItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BookCollectionsTable _collectionIdTable(_$AppDatabase db) =>
      db.bookCollections.createAlias(
          'book_collection_items__collection_id__book_collections__id');

  $$BookCollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<int>('collection_id')!;

    final manager =
        $$BookCollectionsTableTableManager($_db, $_db.bookCollections)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('book_collection_items__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BookCollectionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $BookCollectionItemsTable> {
  $$BookCollectionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));

  $$BookCollectionsTableFilterComposer get collectionId {
    final $$BookCollectionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.collectionId,
        referencedTable: $db.bookCollections,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookCollectionsTableFilterComposer(
              $db: $db,
              $table: $db.bookCollections,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookCollectionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookCollectionItemsTable> {
  $$BookCollectionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  $$BookCollectionsTableOrderingComposer get collectionId {
    final $$BookCollectionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.collectionId,
        referencedTable: $db.bookCollections,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookCollectionsTableOrderingComposer(
              $db: $db,
              $table: $db.bookCollections,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookCollectionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookCollectionItemsTable> {
  $$BookCollectionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$BookCollectionsTableAnnotationComposer get collectionId {
    final $$BookCollectionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.collectionId,
        referencedTable: $db.bookCollections,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BookCollectionsTableAnnotationComposer(
              $db: $db,
              $table: $db.bookCollections,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookCollectionItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookCollectionItemsTable,
    BookCollectionItem,
    $$BookCollectionItemsTableFilterComposer,
    $$BookCollectionItemsTableOrderingComposer,
    $$BookCollectionItemsTableAnnotationComposer,
    $$BookCollectionItemsTableCreateCompanionBuilder,
    $$BookCollectionItemsTableUpdateCompanionBuilder,
    (BookCollectionItem, $$BookCollectionItemsTableReferences),
    BookCollectionItem,
    PrefetchHooks Function({bool collectionId, bool bookId})> {
  $$BookCollectionItemsTableTableManager(
      _$AppDatabase db, $BookCollectionItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookCollectionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookCollectionItemsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookCollectionItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> collectionId = const Value.absent(),
            Value<int> bookId = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookCollectionItemsCompanion(
            collectionId: collectionId,
            bookId: bookId,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int collectionId,
            required int bookId,
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookCollectionItemsCompanion.insert(
            collectionId: collectionId,
            bookId: bookId,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BookCollectionItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({collectionId = false, bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (collectionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.collectionId,
                    referencedTable: $$BookCollectionItemsTableReferences
                        ._collectionIdTable(db),
                    referencedColumn: $$BookCollectionItemsTableReferences
                        ._collectionIdTable(db)
                        .id,
                  ) as T;
                }
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$BookCollectionItemsTableReferences._bookIdTable(db),
                    referencedColumn: $$BookCollectionItemsTableReferences
                        ._bookIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BookCollectionItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookCollectionItemsTable,
    BookCollectionItem,
    $$BookCollectionItemsTableFilterComposer,
    $$BookCollectionItemsTableOrderingComposer,
    $$BookCollectionItemsTableAnnotationComposer,
    $$BookCollectionItemsTableCreateCompanionBuilder,
    $$BookCollectionItemsTableUpdateCompanionBuilder,
    (BookCollectionItem, $$BookCollectionItemsTableReferences),
    BookCollectionItem,
    PrefetchHooks Function({bool collectionId, bool bookId})>;
typedef $$BookTtsSettingsTableCreateCompanionBuilder = BookTtsSettingsCompanion
    Function({
  Value<int> bookId,
  Value<String?> language,
  Value<String?> voiceName,
  Value<String?> voiceLocale,
  Value<double> speechRate,
  Value<String> sleepTimerOption,
  Value<DateTime> updatedAt,
});
typedef $$BookTtsSettingsTableUpdateCompanionBuilder = BookTtsSettingsCompanion
    Function({
  Value<int> bookId,
  Value<String?> language,
  Value<String?> voiceName,
  Value<String?> voiceLocale,
  Value<double> speechRate,
  Value<String> sleepTimerOption,
  Value<DateTime> updatedAt,
});

final class $$BookTtsSettingsTableReferences extends BaseReferences<
    _$AppDatabase, $BookTtsSettingsTable, BookTtsSetting> {
  $$BookTtsSettingsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('book_tts_settings__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BookTtsSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $BookTtsSettingsTable> {
  $$BookTtsSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get voiceName => $composableBuilder(
      column: $table.voiceName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get voiceLocale => $composableBuilder(
      column: $table.voiceLocale, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get speechRate => $composableBuilder(
      column: $table.speechRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sleepTimerOption => $composableBuilder(
      column: $table.sleepTimerOption,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookTtsSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookTtsSettingsTable> {
  $$BookTtsSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get language => $composableBuilder(
      column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get voiceName => $composableBuilder(
      column: $table.voiceName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get voiceLocale => $composableBuilder(
      column: $table.voiceLocale, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get speechRate => $composableBuilder(
      column: $table.speechRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sleepTimerOption => $composableBuilder(
      column: $table.sleepTimerOption,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookTtsSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookTtsSettingsTable> {
  $$BookTtsSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get voiceName =>
      $composableBuilder(column: $table.voiceName, builder: (column) => column);

  GeneratedColumn<String> get voiceLocale => $composableBuilder(
      column: $table.voiceLocale, builder: (column) => column);

  GeneratedColumn<double> get speechRate => $composableBuilder(
      column: $table.speechRate, builder: (column) => column);

  GeneratedColumn<String> get sleepTimerOption => $composableBuilder(
      column: $table.sleepTimerOption, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookTtsSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookTtsSettingsTable,
    BookTtsSetting,
    $$BookTtsSettingsTableFilterComposer,
    $$BookTtsSettingsTableOrderingComposer,
    $$BookTtsSettingsTableAnnotationComposer,
    $$BookTtsSettingsTableCreateCompanionBuilder,
    $$BookTtsSettingsTableUpdateCompanionBuilder,
    (BookTtsSetting, $$BookTtsSettingsTableReferences),
    BookTtsSetting,
    PrefetchHooks Function({bool bookId})> {
  $$BookTtsSettingsTableTableManager(
      _$AppDatabase db, $BookTtsSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookTtsSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookTtsSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookTtsSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> bookId = const Value.absent(),
            Value<String?> language = const Value.absent(),
            Value<String?> voiceName = const Value.absent(),
            Value<String?> voiceLocale = const Value.absent(),
            Value<double> speechRate = const Value.absent(),
            Value<String> sleepTimerOption = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BookTtsSettingsCompanion(
            bookId: bookId,
            language: language,
            voiceName: voiceName,
            voiceLocale: voiceLocale,
            speechRate: speechRate,
            sleepTimerOption: sleepTimerOption,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> bookId = const Value.absent(),
            Value<String?> language = const Value.absent(),
            Value<String?> voiceName = const Value.absent(),
            Value<String?> voiceLocale = const Value.absent(),
            Value<double> speechRate = const Value.absent(),
            Value<String> sleepTimerOption = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BookTtsSettingsCompanion.insert(
            bookId: bookId,
            language: language,
            voiceName: voiceName,
            voiceLocale: voiceLocale,
            speechRate: speechRate,
            sleepTimerOption: sleepTimerOption,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BookTtsSettingsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$BookTtsSettingsTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$BookTtsSettingsTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BookTtsSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookTtsSettingsTable,
    BookTtsSetting,
    $$BookTtsSettingsTableFilterComposer,
    $$BookTtsSettingsTableOrderingComposer,
    $$BookTtsSettingsTableAnnotationComposer,
    $$BookTtsSettingsTableCreateCompanionBuilder,
    $$BookTtsSettingsTableUpdateCompanionBuilder,
    (BookTtsSetting, $$BookTtsSettingsTableReferences),
    BookTtsSetting,
    PrefetchHooks Function({bool bookId})>;
typedef $$BookReadingSettingsTableCreateCompanionBuilder
    = BookReadingSettingsCompanion Function({
  Value<int> bookId,
  required double fontSize,
  required double lineHeight,
  required double margin,
  Value<String?> fontFamily,
  required double paragraphSpacing,
  required double letterSpacing,
  Value<double> wordSpacing,
  Value<bool> boldText,
  Value<String> textAlignment,
  Value<int> paragraphIndent,
  Value<double> pdfCropAmount,
  Value<double> pdfContrast,
  Value<String> pdfPageLayout,
  required double topContentPadding,
  required String pageTurnEffect,
  Value<DateTime> updatedAt,
});
typedef $$BookReadingSettingsTableUpdateCompanionBuilder
    = BookReadingSettingsCompanion Function({
  Value<int> bookId,
  Value<double> fontSize,
  Value<double> lineHeight,
  Value<double> margin,
  Value<String?> fontFamily,
  Value<double> paragraphSpacing,
  Value<double> letterSpacing,
  Value<double> wordSpacing,
  Value<bool> boldText,
  Value<String> textAlignment,
  Value<int> paragraphIndent,
  Value<double> pdfCropAmount,
  Value<double> pdfContrast,
  Value<String> pdfPageLayout,
  Value<double> topContentPadding,
  Value<String> pageTurnEffect,
  Value<DateTime> updatedAt,
});

final class $$BookReadingSettingsTableReferences extends BaseReferences<
    _$AppDatabase, $BookReadingSettingsTable, BookReadingSetting> {
  $$BookReadingSettingsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('book_reading_settings__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BookReadingSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $BookReadingSettingsTable> {
  $$BookReadingSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get fontSize => $composableBuilder(
      column: $table.fontSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lineHeight => $composableBuilder(
      column: $table.lineHeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get margin => $composableBuilder(
      column: $table.margin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fontFamily => $composableBuilder(
      column: $table.fontFamily, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get paragraphSpacing => $composableBuilder(
      column: $table.paragraphSpacing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get letterSpacing => $composableBuilder(
      column: $table.letterSpacing, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get wordSpacing => $composableBuilder(
      column: $table.wordSpacing, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get boldText => $composableBuilder(
      column: $table.boldText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get textAlignment => $composableBuilder(
      column: $table.textAlignment, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paragraphIndent => $composableBuilder(
      column: $table.paragraphIndent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get pdfCropAmount => $composableBuilder(
      column: $table.pdfCropAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get pdfContrast => $composableBuilder(
      column: $table.pdfContrast, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pdfPageLayout => $composableBuilder(
      column: $table.pdfPageLayout, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get topContentPadding => $composableBuilder(
      column: $table.topContentPadding,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pageTurnEffect => $composableBuilder(
      column: $table.pageTurnEffect,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookReadingSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookReadingSettingsTable> {
  $$BookReadingSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get fontSize => $composableBuilder(
      column: $table.fontSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lineHeight => $composableBuilder(
      column: $table.lineHeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get margin => $composableBuilder(
      column: $table.margin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fontFamily => $composableBuilder(
      column: $table.fontFamily, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get paragraphSpacing => $composableBuilder(
      column: $table.paragraphSpacing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get letterSpacing => $composableBuilder(
      column: $table.letterSpacing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get wordSpacing => $composableBuilder(
      column: $table.wordSpacing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get boldText => $composableBuilder(
      column: $table.boldText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get textAlignment => $composableBuilder(
      column: $table.textAlignment,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paragraphIndent => $composableBuilder(
      column: $table.paragraphIndent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get pdfCropAmount => $composableBuilder(
      column: $table.pdfCropAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get pdfContrast => $composableBuilder(
      column: $table.pdfContrast, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pdfPageLayout => $composableBuilder(
      column: $table.pdfPageLayout,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get topContentPadding => $composableBuilder(
      column: $table.topContentPadding,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pageTurnEffect => $composableBuilder(
      column: $table.pageTurnEffect,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookReadingSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookReadingSettingsTable> {
  $$BookReadingSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get fontSize =>
      $composableBuilder(column: $table.fontSize, builder: (column) => column);

  GeneratedColumn<double> get lineHeight => $composableBuilder(
      column: $table.lineHeight, builder: (column) => column);

  GeneratedColumn<double> get margin =>
      $composableBuilder(column: $table.margin, builder: (column) => column);

  GeneratedColumn<String> get fontFamily => $composableBuilder(
      column: $table.fontFamily, builder: (column) => column);

  GeneratedColumn<double> get paragraphSpacing => $composableBuilder(
      column: $table.paragraphSpacing, builder: (column) => column);

  GeneratedColumn<double> get letterSpacing => $composableBuilder(
      column: $table.letterSpacing, builder: (column) => column);

  GeneratedColumn<double> get wordSpacing => $composableBuilder(
      column: $table.wordSpacing, builder: (column) => column);

  GeneratedColumn<bool> get boldText =>
      $composableBuilder(column: $table.boldText, builder: (column) => column);

  GeneratedColumn<String> get textAlignment => $composableBuilder(
      column: $table.textAlignment, builder: (column) => column);

  GeneratedColumn<int> get paragraphIndent => $composableBuilder(
      column: $table.paragraphIndent, builder: (column) => column);

  GeneratedColumn<double> get pdfCropAmount => $composableBuilder(
      column: $table.pdfCropAmount, builder: (column) => column);

  GeneratedColumn<double> get pdfContrast => $composableBuilder(
      column: $table.pdfContrast, builder: (column) => column);

  GeneratedColumn<String> get pdfPageLayout => $composableBuilder(
      column: $table.pdfPageLayout, builder: (column) => column);

  GeneratedColumn<double> get topContentPadding => $composableBuilder(
      column: $table.topContentPadding, builder: (column) => column);

  GeneratedColumn<String> get pageTurnEffect => $composableBuilder(
      column: $table.pageTurnEffect, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BookReadingSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookReadingSettingsTable,
    BookReadingSetting,
    $$BookReadingSettingsTableFilterComposer,
    $$BookReadingSettingsTableOrderingComposer,
    $$BookReadingSettingsTableAnnotationComposer,
    $$BookReadingSettingsTableCreateCompanionBuilder,
    $$BookReadingSettingsTableUpdateCompanionBuilder,
    (BookReadingSetting, $$BookReadingSettingsTableReferences),
    BookReadingSetting,
    PrefetchHooks Function({bool bookId})> {
  $$BookReadingSettingsTableTableManager(
      _$AppDatabase db, $BookReadingSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookReadingSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookReadingSettingsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookReadingSettingsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> bookId = const Value.absent(),
            Value<double> fontSize = const Value.absent(),
            Value<double> lineHeight = const Value.absent(),
            Value<double> margin = const Value.absent(),
            Value<String?> fontFamily = const Value.absent(),
            Value<double> paragraphSpacing = const Value.absent(),
            Value<double> letterSpacing = const Value.absent(),
            Value<double> wordSpacing = const Value.absent(),
            Value<bool> boldText = const Value.absent(),
            Value<String> textAlignment = const Value.absent(),
            Value<int> paragraphIndent = const Value.absent(),
            Value<double> pdfCropAmount = const Value.absent(),
            Value<double> pdfContrast = const Value.absent(),
            Value<String> pdfPageLayout = const Value.absent(),
            Value<double> topContentPadding = const Value.absent(),
            Value<String> pageTurnEffect = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BookReadingSettingsCompanion(
            bookId: bookId,
            fontSize: fontSize,
            lineHeight: lineHeight,
            margin: margin,
            fontFamily: fontFamily,
            paragraphSpacing: paragraphSpacing,
            letterSpacing: letterSpacing,
            wordSpacing: wordSpacing,
            boldText: boldText,
            textAlignment: textAlignment,
            paragraphIndent: paragraphIndent,
            pdfCropAmount: pdfCropAmount,
            pdfContrast: pdfContrast,
            pdfPageLayout: pdfPageLayout,
            topContentPadding: topContentPadding,
            pageTurnEffect: pageTurnEffect,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> bookId = const Value.absent(),
            required double fontSize,
            required double lineHeight,
            required double margin,
            Value<String?> fontFamily = const Value.absent(),
            required double paragraphSpacing,
            required double letterSpacing,
            Value<double> wordSpacing = const Value.absent(),
            Value<bool> boldText = const Value.absent(),
            Value<String> textAlignment = const Value.absent(),
            Value<int> paragraphIndent = const Value.absent(),
            Value<double> pdfCropAmount = const Value.absent(),
            Value<double> pdfContrast = const Value.absent(),
            Value<String> pdfPageLayout = const Value.absent(),
            required double topContentPadding,
            required String pageTurnEffect,
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BookReadingSettingsCompanion.insert(
            bookId: bookId,
            fontSize: fontSize,
            lineHeight: lineHeight,
            margin: margin,
            fontFamily: fontFamily,
            paragraphSpacing: paragraphSpacing,
            letterSpacing: letterSpacing,
            wordSpacing: wordSpacing,
            boldText: boldText,
            textAlignment: textAlignment,
            paragraphIndent: paragraphIndent,
            pdfCropAmount: pdfCropAmount,
            pdfContrast: pdfContrast,
            pdfPageLayout: pdfPageLayout,
            topContentPadding: topContentPadding,
            pageTurnEffect: pageTurnEffect,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BookReadingSettingsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$BookReadingSettingsTableReferences._bookIdTable(db),
                    referencedColumn: $$BookReadingSettingsTableReferences
                        ._bookIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BookReadingSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookReadingSettingsTable,
    BookReadingSetting,
    $$BookReadingSettingsTableFilterComposer,
    $$BookReadingSettingsTableOrderingComposer,
    $$BookReadingSettingsTableAnnotationComposer,
    $$BookReadingSettingsTableCreateCompanionBuilder,
    $$BookReadingSettingsTableUpdateCompanionBuilder,
    (BookReadingSetting, $$BookReadingSettingsTableReferences),
    BookReadingSetting,
    PrefetchHooks Function({bool bookId})>;
typedef $$ChaptersTableCreateCompanionBuilder = ChaptersCompanion Function({
  Value<int> id,
  required int bookId,
  required String title,
  Value<String?> content,
  required int contentIndex,
  required int sortOrder,
});
typedef $$ChaptersTableUpdateCompanionBuilder = ChaptersCompanion Function({
  Value<int> id,
  Value<int> bookId,
  Value<String> title,
  Value<String?> content,
  Value<int> contentIndex,
  Value<int> sortOrder,
});

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, Chapter> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('chapters__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$VocabularyEntriesTable, List<VocabularyEntry>>
      _vocabularyEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.vocabularyEntries,
              aliasName: 'chapters__id__vocabulary_entries__chapter_id');

  $$VocabularyEntriesTableProcessedTableManager get vocabularyEntriesRefs {
    final manager =
        $$VocabularyEntriesTableTableManager($_db, $_db.vocabularyEntries)
            .filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_vocabularyEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReadingProgressTable, List<ReadingProgressData>>
      _readingProgressRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.readingProgress,
              aliasName: 'chapters__id__reading_progress__chapter_id');

  $$ReadingProgressTableProcessedTableManager get readingProgressRefs {
    final manager =
        $$ReadingProgressTableTableManager($_db, $_db.readingProgress)
            .filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_readingProgressRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.notes,
          aliasName: 'chapters__id__notes__chapter_id');

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager($_db, $_db.notes)
        .filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contentIndex => $composableBuilder(
      column: $table.contentIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> vocabularyEntriesRefs(
      Expression<bool> Function($$VocabularyEntriesTableFilterComposer f) f) {
    final $$VocabularyEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.vocabularyEntries,
        getReferencedColumn: (t) => t.chapterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VocabularyEntriesTableFilterComposer(
              $db: $db,
              $table: $db.vocabularyEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> readingProgressRefs(
      Expression<bool> Function($$ReadingProgressTableFilterComposer f) f) {
    final $$ReadingProgressTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingProgress,
        getReferencedColumn: (t) => t.chapterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingProgressTableFilterComposer(
              $db: $db,
              $table: $db.readingProgress,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> notesRefs(
      Expression<bool> Function($$NotesTableFilterComposer f) f) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.chapterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableFilterComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contentIndex => $composableBuilder(
      column: $table.contentIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get contentIndex => $composableBuilder(
      column: $table.contentIndex, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> vocabularyEntriesRefs<T extends Object>(
      Expression<T> Function($$VocabularyEntriesTableAnnotationComposer a) f) {
    final $$VocabularyEntriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.vocabularyEntries,
            getReferencedColumn: (t) => t.chapterId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$VocabularyEntriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.vocabularyEntries,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> readingProgressRefs<T extends Object>(
      Expression<T> Function($$ReadingProgressTableAnnotationComposer a) f) {
    final $$ReadingProgressTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.readingProgress,
        getReferencedColumn: (t) => t.chapterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReadingProgressTableAnnotationComposer(
              $db: $db,
              $table: $db.readingProgress,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
      Expression<T> Function($$NotesTableAnnotationComposer a) f) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.chapterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableAnnotationComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ChaptersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChaptersTable,
    Chapter,
    $$ChaptersTableFilterComposer,
    $$ChaptersTableOrderingComposer,
    $$ChaptersTableAnnotationComposer,
    $$ChaptersTableCreateCompanionBuilder,
    $$ChaptersTableUpdateCompanionBuilder,
    (Chapter, $$ChaptersTableReferences),
    Chapter,
    PrefetchHooks Function(
        {bool bookId,
        bool vocabularyEntriesRefs,
        bool readingProgressRefs,
        bool notesRefs})> {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> bookId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<int> contentIndex = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              ChaptersCompanion(
            id: id,
            bookId: bookId,
            title: title,
            content: content,
            contentIndex: contentIndex,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int bookId,
            required String title,
            Value<String?> content = const Value.absent(),
            required int contentIndex,
            required int sortOrder,
          }) =>
              ChaptersCompanion.insert(
            id: id,
            bookId: bookId,
            title: title,
            content: content,
            contentIndex: contentIndex,
            sortOrder: sortOrder,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ChaptersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {bookId = false,
              vocabularyEntriesRefs = false,
              readingProgressRefs = false,
              notesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (vocabularyEntriesRefs) db.vocabularyEntries,
                if (readingProgressRefs) db.readingProgress,
                if (notesRefs) db.notes
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable: $$ChaptersTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$ChaptersTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (vocabularyEntriesRefs)
                    await $_getPrefetchedData<Chapter, $ChaptersTable,
                            VocabularyEntry>(
                        currentTable: table,
                        referencedTable: $$ChaptersTableReferences
                            ._vocabularyEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ChaptersTableReferences(db, table, p0)
                                .vocabularyEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.chapterId == item.id),
                        typedResults: items),
                  if (readingProgressRefs)
                    await $_getPrefetchedData<Chapter, $ChaptersTable,
                            ReadingProgressData>(
                        currentTable: table,
                        referencedTable: $$ChaptersTableReferences
                            ._readingProgressRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ChaptersTableReferences(db, table, p0)
                                .readingProgressRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.chapterId == item.id),
                        typedResults: items),
                  if (notesRefs)
                    await $_getPrefetchedData<Chapter, $ChaptersTable, Note>(
                        currentTable: table,
                        referencedTable:
                            $$ChaptersTableReferences._notesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ChaptersTableReferences(db, table, p0).notesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.chapterId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ChaptersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChaptersTable,
    Chapter,
    $$ChaptersTableFilterComposer,
    $$ChaptersTableOrderingComposer,
    $$ChaptersTableAnnotationComposer,
    $$ChaptersTableCreateCompanionBuilder,
    $$ChaptersTableUpdateCompanionBuilder,
    (Chapter, $$ChaptersTableReferences),
    Chapter,
    PrefetchHooks Function(
        {bool bookId,
        bool vocabularyEntriesRefs,
        bool readingProgressRefs,
        bool notesRefs})>;
typedef $$VocabularyEntriesTableCreateCompanionBuilder
    = VocabularyEntriesCompanion Function({
  Value<int> id,
  required int bookId,
  Value<int?> chapterId,
  required String term,
  required String normalizedTerm,
  Value<String?> definition,
  Value<String?> contextText,
  Value<int?> positionStart,
  Value<int?> positionEnd,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$VocabularyEntriesTableUpdateCompanionBuilder
    = VocabularyEntriesCompanion Function({
  Value<int> id,
  Value<int> bookId,
  Value<int?> chapterId,
  Value<String> term,
  Value<String> normalizedTerm,
  Value<String?> definition,
  Value<String?> contextText,
  Value<int?> positionStart,
  Value<int?> positionEnd,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$VocabularyEntriesTableReferences extends BaseReferences<
    _$AppDatabase, $VocabularyEntriesTable, VocabularyEntry> {
  $$VocabularyEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('vocabulary_entries__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('vocabulary_entries__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager? get chapterId {
    final $_column = $_itemColumn<int>('chapter_id');
    if ($_column == null) return null;
    final manager = $$ChaptersTableTableManager($_db, $_db.chapters)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$VocabularyEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get term => $composableBuilder(
      column: $table.term, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedTerm => $composableBuilder(
      column: $table.normalizedTerm,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get definition => $composableBuilder(
      column: $table.definition, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextText => $composableBuilder(
      column: $table.contextText, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionStart => $composableBuilder(
      column: $table.positionStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionEnd => $composableBuilder(
      column: $table.positionEnd, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableFilterComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VocabularyEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get term => $composableBuilder(
      column: $table.term, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedTerm => $composableBuilder(
      column: $table.normalizedTerm,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get definition => $composableBuilder(
      column: $table.definition, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextText => $composableBuilder(
      column: $table.contextText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionStart => $composableBuilder(
      column: $table.positionStart,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionEnd => $composableBuilder(
      column: $table.positionEnd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableOrderingComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VocabularyEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VocabularyEntriesTable> {
  $$VocabularyEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get normalizedTerm => $composableBuilder(
      column: $table.normalizedTerm, builder: (column) => column);

  GeneratedColumn<String> get definition => $composableBuilder(
      column: $table.definition, builder: (column) => column);

  GeneratedColumn<String> get contextText => $composableBuilder(
      column: $table.contextText, builder: (column) => column);

  GeneratedColumn<int> get positionStart => $composableBuilder(
      column: $table.positionStart, builder: (column) => column);

  GeneratedColumn<int> get positionEnd => $composableBuilder(
      column: $table.positionEnd, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableAnnotationComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VocabularyEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VocabularyEntriesTable,
    VocabularyEntry,
    $$VocabularyEntriesTableFilterComposer,
    $$VocabularyEntriesTableOrderingComposer,
    $$VocabularyEntriesTableAnnotationComposer,
    $$VocabularyEntriesTableCreateCompanionBuilder,
    $$VocabularyEntriesTableUpdateCompanionBuilder,
    (VocabularyEntry, $$VocabularyEntriesTableReferences),
    VocabularyEntry,
    PrefetchHooks Function({bool bookId, bool chapterId})> {
  $$VocabularyEntriesTableTableManager(
      _$AppDatabase db, $VocabularyEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VocabularyEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VocabularyEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VocabularyEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> bookId = const Value.absent(),
            Value<int?> chapterId = const Value.absent(),
            Value<String> term = const Value.absent(),
            Value<String> normalizedTerm = const Value.absent(),
            Value<String?> definition = const Value.absent(),
            Value<String?> contextText = const Value.absent(),
            Value<int?> positionStart = const Value.absent(),
            Value<int?> positionEnd = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              VocabularyEntriesCompanion(
            id: id,
            bookId: bookId,
            chapterId: chapterId,
            term: term,
            normalizedTerm: normalizedTerm,
            definition: definition,
            contextText: contextText,
            positionStart: positionStart,
            positionEnd: positionEnd,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int bookId,
            Value<int?> chapterId = const Value.absent(),
            required String term,
            required String normalizedTerm,
            Value<String?> definition = const Value.absent(),
            Value<String?> contextText = const Value.absent(),
            Value<int?> positionStart = const Value.absent(),
            Value<int?> positionEnd = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              VocabularyEntriesCompanion.insert(
            id: id,
            bookId: bookId,
            chapterId: chapterId,
            term: term,
            normalizedTerm: normalizedTerm,
            definition: definition,
            contextText: contextText,
            positionStart: positionStart,
            positionEnd: positionEnd,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$VocabularyEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false, chapterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$VocabularyEntriesTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$VocabularyEntriesTableReferences._bookIdTable(db).id,
                  ) as T;
                }
                if (chapterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.chapterId,
                    referencedTable:
                        $$VocabularyEntriesTableReferences._chapterIdTable(db),
                    referencedColumn: $$VocabularyEntriesTableReferences
                        ._chapterIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$VocabularyEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $VocabularyEntriesTable,
    VocabularyEntry,
    $$VocabularyEntriesTableFilterComposer,
    $$VocabularyEntriesTableOrderingComposer,
    $$VocabularyEntriesTableAnnotationComposer,
    $$VocabularyEntriesTableCreateCompanionBuilder,
    $$VocabularyEntriesTableUpdateCompanionBuilder,
    (VocabularyEntry, $$VocabularyEntriesTableReferences),
    VocabularyEntry,
    PrefetchHooks Function({bool bookId, bool chapterId})>;
typedef $$DictionarySourcesTableCreateCompanionBuilder
    = DictionarySourcesCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  required String formatVersion,
  Value<String?> sameTypeSequence,
  required String dataFilePath,
  Value<int> entryCount,
  Value<bool> enabled,
  Value<bool> isReady,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$DictionarySourcesTableUpdateCompanionBuilder
    = DictionarySourcesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<String> formatVersion,
  Value<String?> sameTypeSequence,
  Value<String> dataFilePath,
  Value<int> entryCount,
  Value<bool> enabled,
  Value<bool> isReady,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$DictionarySourcesTableReferences extends BaseReferences<
    _$AppDatabase, $DictionarySourcesTable, DictionarySource> {
  $$DictionarySourcesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DictionaryEntriesTable, List<DictionaryEntry>>
      _dictionaryEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.dictionaryEntries,
              aliasName:
                  'dictionary_sources__id__dictionary_entries__source_id');

  $$DictionaryEntriesTableProcessedTableManager get dictionaryEntriesRefs {
    final manager =
        $$DictionaryEntriesTableTableManager($_db, $_db.dictionaryEntries)
            .filter((f) => f.sourceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_dictionaryEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DictionaryAliasesTable, List<DictionaryAliase>>
      _dictionaryAliasesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.dictionaryAliases,
              aliasName:
                  'dictionary_sources__id__dictionary_aliases__source_id');

  $$DictionaryAliasesTableProcessedTableManager get dictionaryAliasesRefs {
    final manager =
        $$DictionaryAliasesTableTableManager($_db, $_db.dictionaryAliases)
            .filter((f) => f.sourceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_dictionaryAliasesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$DictionarySourcesTableFilterComposer
    extends Composer<_$AppDatabase, $DictionarySourcesTable> {
  $$DictionarySourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get formatVersion => $composableBuilder(
      column: $table.formatVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sameTypeSequence => $composableBuilder(
      column: $table.sameTypeSequence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataFilePath => $composableBuilder(
      column: $table.dataFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get entryCount => $composableBuilder(
      column: $table.entryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isReady => $composableBuilder(
      column: $table.isReady, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> dictionaryEntriesRefs(
      Expression<bool> Function($$DictionaryEntriesTableFilterComposer f) f) {
    final $$DictionaryEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dictionaryEntries,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DictionaryEntriesTableFilterComposer(
              $db: $db,
              $table: $db.dictionaryEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> dictionaryAliasesRefs(
      Expression<bool> Function($$DictionaryAliasesTableFilterComposer f) f) {
    final $$DictionaryAliasesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dictionaryAliases,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DictionaryAliasesTableFilterComposer(
              $db: $db,
              $table: $db.dictionaryAliases,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DictionarySourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $DictionarySourcesTable> {
  $$DictionarySourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get formatVersion => $composableBuilder(
      column: $table.formatVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sameTypeSequence => $composableBuilder(
      column: $table.sameTypeSequence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataFilePath => $composableBuilder(
      column: $table.dataFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get entryCount => $composableBuilder(
      column: $table.entryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isReady => $composableBuilder(
      column: $table.isReady, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DictionarySourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DictionarySourcesTable> {
  $$DictionarySourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get formatVersion => $composableBuilder(
      column: $table.formatVersion, builder: (column) => column);

  GeneratedColumn<String> get sameTypeSequence => $composableBuilder(
      column: $table.sameTypeSequence, builder: (column) => column);

  GeneratedColumn<String> get dataFilePath => $composableBuilder(
      column: $table.dataFilePath, builder: (column) => column);

  GeneratedColumn<int> get entryCount => $composableBuilder(
      column: $table.entryCount, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get isReady =>
      $composableBuilder(column: $table.isReady, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> dictionaryEntriesRefs<T extends Object>(
      Expression<T> Function($$DictionaryEntriesTableAnnotationComposer a) f) {
    final $$DictionaryEntriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.dictionaryEntries,
            getReferencedColumn: (t) => t.sourceId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$DictionaryEntriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.dictionaryEntries,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> dictionaryAliasesRefs<T extends Object>(
      Expression<T> Function($$DictionaryAliasesTableAnnotationComposer a) f) {
    final $$DictionaryAliasesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.dictionaryAliases,
            getReferencedColumn: (t) => t.sourceId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$DictionaryAliasesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.dictionaryAliases,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$DictionarySourcesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DictionarySourcesTable,
    DictionarySource,
    $$DictionarySourcesTableFilterComposer,
    $$DictionarySourcesTableOrderingComposer,
    $$DictionarySourcesTableAnnotationComposer,
    $$DictionarySourcesTableCreateCompanionBuilder,
    $$DictionarySourcesTableUpdateCompanionBuilder,
    (DictionarySource, $$DictionarySourcesTableReferences),
    DictionarySource,
    PrefetchHooks Function(
        {bool dictionaryEntriesRefs, bool dictionaryAliasesRefs})> {
  $$DictionarySourcesTableTableManager(
      _$AppDatabase db, $DictionarySourcesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionarySourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionarySourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionarySourcesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> formatVersion = const Value.absent(),
            Value<String?> sameTypeSequence = const Value.absent(),
            Value<String> dataFilePath = const Value.absent(),
            Value<int> entryCount = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<bool> isReady = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              DictionarySourcesCompanion(
            id: id,
            name: name,
            description: description,
            formatVersion: formatVersion,
            sameTypeSequence: sameTypeSequence,
            dataFilePath: dataFilePath,
            entryCount: entryCount,
            enabled: enabled,
            isReady: isReady,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> description = const Value.absent(),
            required String formatVersion,
            Value<String?> sameTypeSequence = const Value.absent(),
            required String dataFilePath,
            Value<int> entryCount = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<bool> isReady = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              DictionarySourcesCompanion.insert(
            id: id,
            name: name,
            description: description,
            formatVersion: formatVersion,
            sameTypeSequence: sameTypeSequence,
            dataFilePath: dataFilePath,
            entryCount: entryCount,
            enabled: enabled,
            isReady: isReady,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DictionarySourcesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {dictionaryEntriesRefs = false, dictionaryAliasesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (dictionaryEntriesRefs) db.dictionaryEntries,
                if (dictionaryAliasesRefs) db.dictionaryAliases
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dictionaryEntriesRefs)
                    await $_getPrefetchedData<DictionarySource,
                            $DictionarySourcesTable, DictionaryEntry>(
                        currentTable: table,
                        referencedTable: $$DictionarySourcesTableReferences
                            ._dictionaryEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DictionarySourcesTableReferences(db, table, p0)
                                .dictionaryEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.sourceId == item.id),
                        typedResults: items),
                  if (dictionaryAliasesRefs)
                    await $_getPrefetchedData<DictionarySource,
                            $DictionarySourcesTable, DictionaryAliase>(
                        currentTable: table,
                        referencedTable: $$DictionarySourcesTableReferences
                            ._dictionaryAliasesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DictionarySourcesTableReferences(db, table, p0)
                                .dictionaryAliasesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.sourceId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$DictionarySourcesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DictionarySourcesTable,
    DictionarySource,
    $$DictionarySourcesTableFilterComposer,
    $$DictionarySourcesTableOrderingComposer,
    $$DictionarySourcesTableAnnotationComposer,
    $$DictionarySourcesTableCreateCompanionBuilder,
    $$DictionarySourcesTableUpdateCompanionBuilder,
    (DictionarySource, $$DictionarySourcesTableReferences),
    DictionarySource,
    PrefetchHooks Function(
        {bool dictionaryEntriesRefs, bool dictionaryAliasesRefs})>;
typedef $$DictionaryEntriesTableCreateCompanionBuilder
    = DictionaryEntriesCompanion Function({
  Value<int> id,
  required int sourceId,
  required int entryIndex,
  required String headword,
  required String normalizedHeadword,
  required int dataOffset,
  required int dataSize,
});
typedef $$DictionaryEntriesTableUpdateCompanionBuilder
    = DictionaryEntriesCompanion Function({
  Value<int> id,
  Value<int> sourceId,
  Value<int> entryIndex,
  Value<String> headword,
  Value<String> normalizedHeadword,
  Value<int> dataOffset,
  Value<int> dataSize,
});

final class $$DictionaryEntriesTableReferences extends BaseReferences<
    _$AppDatabase, $DictionaryEntriesTable, DictionaryEntry> {
  $$DictionaryEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $DictionarySourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.dictionarySources
          .createAlias('dictionary_entries__source_id__dictionary_sources__id');

  $$DictionarySourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<int>('source_id')!;

    final manager =
        $$DictionarySourcesTableTableManager($_db, $_db.dictionarySources)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DictionaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTable> {
  $$DictionaryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get entryIndex => $composableBuilder(
      column: $table.entryIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get headword => $composableBuilder(
      column: $table.headword, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedHeadword => $composableBuilder(
      column: $table.normalizedHeadword,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dataOffset => $composableBuilder(
      column: $table.dataOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dataSize => $composableBuilder(
      column: $table.dataSize, builder: (column) => ColumnFilters(column));

  $$DictionarySourcesTableFilterComposer get sourceId {
    final $$DictionarySourcesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.dictionarySources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DictionarySourcesTableFilterComposer(
              $db: $db,
              $table: $db.dictionarySources,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DictionaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTable> {
  $$DictionaryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get entryIndex => $composableBuilder(
      column: $table.entryIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get headword => $composableBuilder(
      column: $table.headword, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedHeadword => $composableBuilder(
      column: $table.normalizedHeadword,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dataOffset => $composableBuilder(
      column: $table.dataOffset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dataSize => $composableBuilder(
      column: $table.dataSize, builder: (column) => ColumnOrderings(column));

  $$DictionarySourcesTableOrderingComposer get sourceId {
    final $$DictionarySourcesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.dictionarySources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DictionarySourcesTableOrderingComposer(
              $db: $db,
              $table: $db.dictionarySources,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DictionaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTable> {
  $$DictionaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get entryIndex => $composableBuilder(
      column: $table.entryIndex, builder: (column) => column);

  GeneratedColumn<String> get headword =>
      $composableBuilder(column: $table.headword, builder: (column) => column);

  GeneratedColumn<String> get normalizedHeadword => $composableBuilder(
      column: $table.normalizedHeadword, builder: (column) => column);

  GeneratedColumn<int> get dataOffset => $composableBuilder(
      column: $table.dataOffset, builder: (column) => column);

  GeneratedColumn<int> get dataSize =>
      $composableBuilder(column: $table.dataSize, builder: (column) => column);

  $$DictionarySourcesTableAnnotationComposer get sourceId {
    final $$DictionarySourcesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sourceId,
            referencedTable: $db.dictionarySources,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$DictionarySourcesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.dictionarySources,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$DictionaryEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DictionaryEntriesTable,
    DictionaryEntry,
    $$DictionaryEntriesTableFilterComposer,
    $$DictionaryEntriesTableOrderingComposer,
    $$DictionaryEntriesTableAnnotationComposer,
    $$DictionaryEntriesTableCreateCompanionBuilder,
    $$DictionaryEntriesTableUpdateCompanionBuilder,
    (DictionaryEntry, $$DictionaryEntriesTableReferences),
    DictionaryEntry,
    PrefetchHooks Function({bool sourceId})> {
  $$DictionaryEntriesTableTableManager(
      _$AppDatabase db, $DictionaryEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionaryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionaryEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sourceId = const Value.absent(),
            Value<int> entryIndex = const Value.absent(),
            Value<String> headword = const Value.absent(),
            Value<String> normalizedHeadword = const Value.absent(),
            Value<int> dataOffset = const Value.absent(),
            Value<int> dataSize = const Value.absent(),
          }) =>
              DictionaryEntriesCompanion(
            id: id,
            sourceId: sourceId,
            entryIndex: entryIndex,
            headword: headword,
            normalizedHeadword: normalizedHeadword,
            dataOffset: dataOffset,
            dataSize: dataSize,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sourceId,
            required int entryIndex,
            required String headword,
            required String normalizedHeadword,
            required int dataOffset,
            required int dataSize,
          }) =>
              DictionaryEntriesCompanion.insert(
            id: id,
            sourceId: sourceId,
            entryIndex: entryIndex,
            headword: headword,
            normalizedHeadword: normalizedHeadword,
            dataOffset: dataOffset,
            dataSize: dataSize,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DictionaryEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sourceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sourceId,
                    referencedTable:
                        $$DictionaryEntriesTableReferences._sourceIdTable(db),
                    referencedColumn: $$DictionaryEntriesTableReferences
                        ._sourceIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DictionaryEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DictionaryEntriesTable,
    DictionaryEntry,
    $$DictionaryEntriesTableFilterComposer,
    $$DictionaryEntriesTableOrderingComposer,
    $$DictionaryEntriesTableAnnotationComposer,
    $$DictionaryEntriesTableCreateCompanionBuilder,
    $$DictionaryEntriesTableUpdateCompanionBuilder,
    (DictionaryEntry, $$DictionaryEntriesTableReferences),
    DictionaryEntry,
    PrefetchHooks Function({bool sourceId})>;
typedef $$DictionaryAliasesTableCreateCompanionBuilder
    = DictionaryAliasesCompanion Function({
  Value<int> id,
  required int sourceId,
  required String alias,
  required String normalizedAlias,
  required int targetEntryIndex,
});
typedef $$DictionaryAliasesTableUpdateCompanionBuilder
    = DictionaryAliasesCompanion Function({
  Value<int> id,
  Value<int> sourceId,
  Value<String> alias,
  Value<String> normalizedAlias,
  Value<int> targetEntryIndex,
});

final class $$DictionaryAliasesTableReferences extends BaseReferences<
    _$AppDatabase, $DictionaryAliasesTable, DictionaryAliase> {
  $$DictionaryAliasesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $DictionarySourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.dictionarySources
          .createAlias('dictionary_aliases__source_id__dictionary_sources__id');

  $$DictionarySourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<int>('source_id')!;

    final manager =
        $$DictionarySourcesTableTableManager($_db, $_db.dictionarySources)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DictionaryAliasesTableFilterComposer
    extends Composer<_$AppDatabase, $DictionaryAliasesTable> {
  $$DictionaryAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedAlias => $composableBuilder(
      column: $table.normalizedAlias,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetEntryIndex => $composableBuilder(
      column: $table.targetEntryIndex,
      builder: (column) => ColumnFilters(column));

  $$DictionarySourcesTableFilterComposer get sourceId {
    final $$DictionarySourcesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.dictionarySources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DictionarySourcesTableFilterComposer(
              $db: $db,
              $table: $db.dictionarySources,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DictionaryAliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $DictionaryAliasesTable> {
  $$DictionaryAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedAlias => $composableBuilder(
      column: $table.normalizedAlias,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetEntryIndex => $composableBuilder(
      column: $table.targetEntryIndex,
      builder: (column) => ColumnOrderings(column));

  $$DictionarySourcesTableOrderingComposer get sourceId {
    final $$DictionarySourcesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.dictionarySources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DictionarySourcesTableOrderingComposer(
              $db: $db,
              $table: $db.dictionarySources,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DictionaryAliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DictionaryAliasesTable> {
  $$DictionaryAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get normalizedAlias => $composableBuilder(
      column: $table.normalizedAlias, builder: (column) => column);

  GeneratedColumn<int> get targetEntryIndex => $composableBuilder(
      column: $table.targetEntryIndex, builder: (column) => column);

  $$DictionarySourcesTableAnnotationComposer get sourceId {
    final $$DictionarySourcesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sourceId,
            referencedTable: $db.dictionarySources,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$DictionarySourcesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.dictionarySources,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$DictionaryAliasesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DictionaryAliasesTable,
    DictionaryAliase,
    $$DictionaryAliasesTableFilterComposer,
    $$DictionaryAliasesTableOrderingComposer,
    $$DictionaryAliasesTableAnnotationComposer,
    $$DictionaryAliasesTableCreateCompanionBuilder,
    $$DictionaryAliasesTableUpdateCompanionBuilder,
    (DictionaryAliase, $$DictionaryAliasesTableReferences),
    DictionaryAliase,
    PrefetchHooks Function({bool sourceId})> {
  $$DictionaryAliasesTableTableManager(
      _$AppDatabase db, $DictionaryAliasesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionaryAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionaryAliasesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sourceId = const Value.absent(),
            Value<String> alias = const Value.absent(),
            Value<String> normalizedAlias = const Value.absent(),
            Value<int> targetEntryIndex = const Value.absent(),
          }) =>
              DictionaryAliasesCompanion(
            id: id,
            sourceId: sourceId,
            alias: alias,
            normalizedAlias: normalizedAlias,
            targetEntryIndex: targetEntryIndex,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sourceId,
            required String alias,
            required String normalizedAlias,
            required int targetEntryIndex,
          }) =>
              DictionaryAliasesCompanion.insert(
            id: id,
            sourceId: sourceId,
            alias: alias,
            normalizedAlias: normalizedAlias,
            targetEntryIndex: targetEntryIndex,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DictionaryAliasesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sourceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sourceId,
                    referencedTable:
                        $$DictionaryAliasesTableReferences._sourceIdTable(db),
                    referencedColumn: $$DictionaryAliasesTableReferences
                        ._sourceIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DictionaryAliasesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DictionaryAliasesTable,
    DictionaryAliase,
    $$DictionaryAliasesTableFilterComposer,
    $$DictionaryAliasesTableOrderingComposer,
    $$DictionaryAliasesTableAnnotationComposer,
    $$DictionaryAliasesTableCreateCompanionBuilder,
    $$DictionaryAliasesTableUpdateCompanionBuilder,
    (DictionaryAliase, $$DictionaryAliasesTableReferences),
    DictionaryAliase,
    PrefetchHooks Function({bool sourceId})>;
typedef $$ReadingProgressTableCreateCompanionBuilder = ReadingProgressCompanion
    Function({
  Value<int> bookId,
  Value<int?> chapterId,
  Value<double> positionInChapter,
  Value<double> percentage,
  Value<int> totalReadingSeconds,
  Value<DateTime> lastReadAt,
});
typedef $$ReadingProgressTableUpdateCompanionBuilder = ReadingProgressCompanion
    Function({
  Value<int> bookId,
  Value<int?> chapterId,
  Value<double> positionInChapter,
  Value<double> percentage,
  Value<int> totalReadingSeconds,
  Value<DateTime> lastReadAt,
});

final class $$ReadingProgressTableReferences extends BaseReferences<
    _$AppDatabase, $ReadingProgressTable, ReadingProgressData> {
  $$ReadingProgressTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('reading_progress__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('reading_progress__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager? get chapterId {
    final $_column = $_itemColumn<int>('chapter_id');
    if ($_column == null) return null;
    final manager = $$ChaptersTableTableManager($_db, $_db.chapters)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get positionInChapter => $composableBuilder(
      column: $table.positionInChapter,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get percentage => $composableBuilder(
      column: $table.percentage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalReadingSeconds => $composableBuilder(
      column: $table.totalReadingSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableFilterComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get positionInChapter => $composableBuilder(
      column: $table.positionInChapter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get percentage => $composableBuilder(
      column: $table.percentage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalReadingSeconds => $composableBuilder(
      column: $table.totalReadingSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableOrderingComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get positionInChapter => $composableBuilder(
      column: $table.positionInChapter, builder: (column) => column);

  GeneratedColumn<double> get percentage => $composableBuilder(
      column: $table.percentage, builder: (column) => column);

  GeneratedColumn<int> get totalReadingSeconds => $composableBuilder(
      column: $table.totalReadingSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableAnnotationComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingProgressTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReadingProgressTable,
    ReadingProgressData,
    $$ReadingProgressTableFilterComposer,
    $$ReadingProgressTableOrderingComposer,
    $$ReadingProgressTableAnnotationComposer,
    $$ReadingProgressTableCreateCompanionBuilder,
    $$ReadingProgressTableUpdateCompanionBuilder,
    (ReadingProgressData, $$ReadingProgressTableReferences),
    ReadingProgressData,
    PrefetchHooks Function({bool bookId, bool chapterId})> {
  $$ReadingProgressTableTableManager(
      _$AppDatabase db, $ReadingProgressTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> bookId = const Value.absent(),
            Value<int?> chapterId = const Value.absent(),
            Value<double> positionInChapter = const Value.absent(),
            Value<double> percentage = const Value.absent(),
            Value<int> totalReadingSeconds = const Value.absent(),
            Value<DateTime> lastReadAt = const Value.absent(),
          }) =>
              ReadingProgressCompanion(
            bookId: bookId,
            chapterId: chapterId,
            positionInChapter: positionInChapter,
            percentage: percentage,
            totalReadingSeconds: totalReadingSeconds,
            lastReadAt: lastReadAt,
          ),
          createCompanionCallback: ({
            Value<int> bookId = const Value.absent(),
            Value<int?> chapterId = const Value.absent(),
            Value<double> positionInChapter = const Value.absent(),
            Value<double> percentage = const Value.absent(),
            Value<int> totalReadingSeconds = const Value.absent(),
            Value<DateTime> lastReadAt = const Value.absent(),
          }) =>
              ReadingProgressCompanion.insert(
            bookId: bookId,
            chapterId: chapterId,
            positionInChapter: positionInChapter,
            percentage: percentage,
            totalReadingSeconds: totalReadingSeconds,
            lastReadAt: lastReadAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReadingProgressTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false, chapterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$ReadingProgressTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$ReadingProgressTableReferences._bookIdTable(db).id,
                  ) as T;
                }
                if (chapterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.chapterId,
                    referencedTable:
                        $$ReadingProgressTableReferences._chapterIdTable(db),
                    referencedColumn:
                        $$ReadingProgressTableReferences._chapterIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ReadingProgressTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReadingProgressTable,
    ReadingProgressData,
    $$ReadingProgressTableFilterComposer,
    $$ReadingProgressTableOrderingComposer,
    $$ReadingProgressTableAnnotationComposer,
    $$ReadingProgressTableCreateCompanionBuilder,
    $$ReadingProgressTableUpdateCompanionBuilder,
    (ReadingProgressData, $$ReadingProgressTableReferences),
    ReadingProgressData,
    PrefetchHooks Function({bool bookId, bool chapterId})>;
typedef $$ReadingSessionsTableCreateCompanionBuilder = ReadingSessionsCompanion
    Function({
  Value<int> id,
  Value<int?> bookId,
  required String date,
  Value<int> seconds,
});
typedef $$ReadingSessionsTableUpdateCompanionBuilder = ReadingSessionsCompanion
    Function({
  Value<int> id,
  Value<int?> bookId,
  Value<String> date,
  Value<int> seconds,
});

final class $$ReadingSessionsTableReferences extends BaseReferences<
    _$AppDatabase, $ReadingSessionsTable, ReadingSession> {
  $$ReadingSessionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('reading_sessions__book_id__books__id');

  $$BooksTableProcessedTableManager? get bookId {
    final $_column = $_itemColumn<int>('book_id');
    if ($_column == null) return null;
    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReadingSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seconds => $composableBuilder(
      column: $table.seconds, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seconds => $composableBuilder(
      column: $table.seconds, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get seconds =>
      $composableBuilder(column: $table.seconds, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReadingSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReadingSessionsTable,
    ReadingSession,
    $$ReadingSessionsTableFilterComposer,
    $$ReadingSessionsTableOrderingComposer,
    $$ReadingSessionsTableAnnotationComposer,
    $$ReadingSessionsTableCreateCompanionBuilder,
    $$ReadingSessionsTableUpdateCompanionBuilder,
    (ReadingSession, $$ReadingSessionsTableReferences),
    ReadingSession,
    PrefetchHooks Function({bool bookId})> {
  $$ReadingSessionsTableTableManager(
      _$AppDatabase db, $ReadingSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> bookId = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<int> seconds = const Value.absent(),
          }) =>
              ReadingSessionsCompanion(
            id: id,
            bookId: bookId,
            date: date,
            seconds: seconds,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> bookId = const Value.absent(),
            required String date,
            Value<int> seconds = const Value.absent(),
          }) =>
              ReadingSessionsCompanion.insert(
            id: id,
            bookId: bookId,
            date: date,
            seconds: seconds,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReadingSessionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$ReadingSessionsTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$ReadingSessionsTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ReadingSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReadingSessionsTable,
    ReadingSession,
    $$ReadingSessionsTableFilterComposer,
    $$ReadingSessionsTableOrderingComposer,
    $$ReadingSessionsTableAnnotationComposer,
    $$ReadingSessionsTableCreateCompanionBuilder,
    $$ReadingSessionsTableUpdateCompanionBuilder,
    (ReadingSession, $$ReadingSessionsTableReferences),
    ReadingSession,
    PrefetchHooks Function({bool bookId})>;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  required int bookId,
  Value<int?> chapterId,
  Value<String?> selectedText,
  Value<String?> content,
  Value<int?> pageNumber,
  Value<int?> positionStart,
  Value<int?> positionEnd,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> type,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  Value<int> bookId,
  Value<int?> chapterId,
  Value<String?> selectedText,
  Value<String?> content,
  Value<int?> pageNumber,
  Value<int?> positionStart,
  Value<int?> positionEnd,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> type,
});

final class $$NotesTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('notes__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('notes__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager? get chapterId {
    final $_column = $_itemColumn<int>('chapter_id');
    if ($_column == null) return null;
    final manager = $$ChaptersTableTableManager($_db, $_db.chapters)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$NoteTagsTable, List<NoteTag>> _noteTagsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.noteTags,
          aliasName: 'notes__id__note_tags__note_id');

  $$NoteTagsTableProcessedTableManager get noteTagsRefs {
    final manager = $$NoteTagsTableTableManager($_db, $_db.noteTags)
        .filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$NoteRelationsTable, List<NoteRelation>>
      _relationsFromTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.noteRelations,
              aliasName: 'notes__id__note_relations__note_id1');

  $$NoteRelationsTableProcessedTableManager get relationsFrom {
    final manager = $$NoteRelationsTableTableManager($_db, $_db.noteRelations)
        .filter((f) => f.noteId1.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_relationsFromTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$NoteRelationsTable, List<NoteRelation>>
      _relationsToTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.noteRelations,
              aliasName: 'notes__id__note_relations__note_id2');

  $$NoteRelationsTableProcessedTableManager get relationsTo {
    final manager = $$NoteRelationsTableTableManager($_db, $_db.noteRelations)
        .filter((f) => f.noteId2.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_relationsToTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get selectedText => $composableBuilder(
      column: $table.selectedText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionStart => $composableBuilder(
      column: $table.positionStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionEnd => $composableBuilder(
      column: $table.positionEnd, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableFilterComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> noteTagsRefs(
      Expression<bool> Function($$NoteTagsTableFilterComposer f) f) {
    final $$NoteTagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteTags,
        getReferencedColumn: (t) => t.noteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteTagsTableFilterComposer(
              $db: $db,
              $table: $db.noteTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> relationsFrom(
      Expression<bool> Function($$NoteRelationsTableFilterComposer f) f) {
    final $$NoteRelationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteRelations,
        getReferencedColumn: (t) => t.noteId1,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteRelationsTableFilterComposer(
              $db: $db,
              $table: $db.noteRelations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> relationsTo(
      Expression<bool> Function($$NoteRelationsTableFilterComposer f) f) {
    final $$NoteRelationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteRelations,
        getReferencedColumn: (t) => t.noteId2,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteRelationsTableFilterComposer(
              $db: $db,
              $table: $db.noteRelations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get selectedText => $composableBuilder(
      column: $table.selectedText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionStart => $composableBuilder(
      column: $table.positionStart,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionEnd => $composableBuilder(
      column: $table.positionEnd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableOrderingComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get selectedText => $composableBuilder(
      column: $table.selectedText, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
      column: $table.pageNumber, builder: (column) => column);

  GeneratedColumn<int> get positionStart => $composableBuilder(
      column: $table.positionStart, builder: (column) => column);

  GeneratedColumn<int> get positionEnd => $composableBuilder(
      column: $table.positionEnd, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chapterId,
        referencedTable: $db.chapters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChaptersTableAnnotationComposer(
              $db: $db,
              $table: $db.chapters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> noteTagsRefs<T extends Object>(
      Expression<T> Function($$NoteTagsTableAnnotationComposer a) f) {
    final $$NoteTagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteTags,
        getReferencedColumn: (t) => t.noteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteTagsTableAnnotationComposer(
              $db: $db,
              $table: $db.noteTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> relationsFrom<T extends Object>(
      Expression<T> Function($$NoteRelationsTableAnnotationComposer a) f) {
    final $$NoteRelationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteRelations,
        getReferencedColumn: (t) => t.noteId1,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteRelationsTableAnnotationComposer(
              $db: $db,
              $table: $db.noteRelations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> relationsTo<T extends Object>(
      Expression<T> Function($$NoteRelationsTableAnnotationComposer a) f) {
    final $$NoteRelationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteRelations,
        getReferencedColumn: (t) => t.noteId2,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteRelationsTableAnnotationComposer(
              $db: $db,
              $table: $db.noteRelations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$NotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotesTable,
    Note,
    $$NotesTableFilterComposer,
    $$NotesTableOrderingComposer,
    $$NotesTableAnnotationComposer,
    $$NotesTableCreateCompanionBuilder,
    $$NotesTableUpdateCompanionBuilder,
    (Note, $$NotesTableReferences),
    Note,
    PrefetchHooks Function(
        {bool bookId,
        bool chapterId,
        bool noteTagsRefs,
        bool relationsFrom,
        bool relationsTo})> {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> bookId = const Value.absent(),
            Value<int?> chapterId = const Value.absent(),
            Value<String?> selectedText = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<int?> pageNumber = const Value.absent(),
            Value<int?> positionStart = const Value.absent(),
            Value<int?> positionEnd = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> type = const Value.absent(),
          }) =>
              NotesCompanion(
            id: id,
            bookId: bookId,
            chapterId: chapterId,
            selectedText: selectedText,
            content: content,
            pageNumber: pageNumber,
            positionStart: positionStart,
            positionEnd: positionEnd,
            createdAt: createdAt,
            updatedAt: updatedAt,
            type: type,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int bookId,
            Value<int?> chapterId = const Value.absent(),
            Value<String?> selectedText = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<int?> pageNumber = const Value.absent(),
            Value<int?> positionStart = const Value.absent(),
            Value<int?> positionEnd = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> type = const Value.absent(),
          }) =>
              NotesCompanion.insert(
            id: id,
            bookId: bookId,
            chapterId: chapterId,
            selectedText: selectedText,
            content: content,
            pageNumber: pageNumber,
            positionStart: positionStart,
            positionEnd: positionEnd,
            createdAt: createdAt,
            updatedAt: updatedAt,
            type: type,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$NotesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {bookId = false,
              chapterId = false,
              noteTagsRefs = false,
              relationsFrom = false,
              relationsTo = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (noteTagsRefs) db.noteTags,
                if (relationsFrom) db.noteRelations,
                if (relationsTo) db.noteRelations
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable: $$NotesTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$NotesTableReferences._bookIdTable(db).id,
                  ) as T;
                }
                if (chapterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.chapterId,
                    referencedTable: $$NotesTableReferences._chapterIdTable(db),
                    referencedColumn:
                        $$NotesTableReferences._chapterIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteTagsRefs)
                    await $_getPrefetchedData<Note, $NotesTable, NoteTag>(
                        currentTable: table,
                        referencedTable:
                            $$NotesTableReferences._noteTagsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$NotesTableReferences(db, table, p0).noteTagsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.noteId == item.id),
                        typedResults: items),
                  if (relationsFrom)
                    await $_getPrefetchedData<Note, $NotesTable, NoteRelation>(
                        currentTable: table,
                        referencedTable:
                            $$NotesTableReferences._relationsFromTable(db),
                        managerFromTypedResult: (p0) =>
                            $$NotesTableReferences(db, table, p0).relationsFrom,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.noteId1 == item.id),
                        typedResults: items),
                  if (relationsTo)
                    await $_getPrefetchedData<Note, $NotesTable, NoteRelation>(
                        currentTable: table,
                        referencedTable:
                            $$NotesTableReferences._relationsToTable(db),
                        managerFromTypedResult: (p0) =>
                            $$NotesTableReferences(db, table, p0).relationsTo,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.noteId2 == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$NotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotesTable,
    Note,
    $$NotesTableFilterComposer,
    $$NotesTableOrderingComposer,
    $$NotesTableAnnotationComposer,
    $$NotesTableCreateCompanionBuilder,
    $$NotesTableUpdateCompanionBuilder,
    (Note, $$NotesTableReferences),
    Note,
    PrefetchHooks Function(
        {bool bookId,
        bool chapterId,
        bool noteTagsRefs,
        bool relationsFrom,
        bool relationsTo})>;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> color,
  Value<DateTime> createdAt,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> color,
  Value<DateTime> createdAt,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteTagsTable, List<NoteTag>> _noteTagsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.noteTags,
          aliasName: 'tags__id__note_tags__tag_id');

  $$NoteTagsTableProcessedTableManager get noteTagsRefs {
    final manager = $$NoteTagsTableTableManager($_db, $_db.noteTags)
        .filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> noteTagsRefs(
      Expression<bool> Function($$NoteTagsTableFilterComposer f) f) {
    final $$NoteTagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteTags,
        getReferencedColumn: (t) => t.tagId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteTagsTableFilterComposer(
              $db: $db,
              $table: $db.noteTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> noteTagsRefs<T extends Object>(
      Expression<T> Function($$NoteTagsTableAnnotationComposer a) f) {
    final $$NoteTagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteTags,
        getReferencedColumn: (t) => t.tagId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteTagsTableAnnotationComposer(
              $db: $db,
              $table: $db.noteTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, $$TagsTableReferences),
    Tag,
    PrefetchHooks Function({bool noteTagsRefs})> {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TagsCompanion(
            id: id,
            name: name,
            color: color,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> color = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TagsCompanion.insert(
            id: id,
            name: name,
            color: color,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$TagsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({noteTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteTagsRefs) db.noteTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, NoteTag>(
                        currentTable: table,
                        referencedTable:
                            $$TagsTableReferences._noteTagsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TagsTableReferences(db, table, p0).noteTagsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tagId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, $$TagsTableReferences),
    Tag,
    PrefetchHooks Function({bool noteTagsRefs})>;
typedef $$NoteTagsTableCreateCompanionBuilder = NoteTagsCompanion Function({
  required int noteId,
  required int tagId,
  Value<int> rowid,
});
typedef $$NoteTagsTableUpdateCompanionBuilder = NoteTagsCompanion Function({
  Value<int> noteId,
  Value<int> tagId,
  Value<int> rowid,
});

final class $$NoteTagsTableReferences
    extends BaseReferences<_$AppDatabase, $NoteTagsTable, NoteTag> {
  $$NoteTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$AppDatabase db) =>
      db.notes.createAlias('note_tags__note_id__notes__id');

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NotesTableTableManager($_db, $_db.notes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('note_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager($_db, $_db.tags)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$NoteTagsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableFilterComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableFilterComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableOrderingComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableOrderingComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTagsTable> {
  $$NoteTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableAnnotationComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableAnnotationComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteTagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NoteTagsTable,
    NoteTag,
    $$NoteTagsTableFilterComposer,
    $$NoteTagsTableOrderingComposer,
    $$NoteTagsTableAnnotationComposer,
    $$NoteTagsTableCreateCompanionBuilder,
    $$NoteTagsTableUpdateCompanionBuilder,
    (NoteTag, $$NoteTagsTableReferences),
    NoteTag,
    PrefetchHooks Function({bool noteId, bool tagId})> {
  $$NoteTagsTableTableManager(_$AppDatabase db, $NoteTagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> noteId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteTagsCompanion(
            noteId: noteId,
            tagId: tagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int noteId,
            required int tagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteTagsCompanion.insert(
            noteId: noteId,
            tagId: tagId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$NoteTagsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({noteId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (noteId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.noteId,
                    referencedTable: $$NoteTagsTableReferences._noteIdTable(db),
                    referencedColumn:
                        $$NoteTagsTableReferences._noteIdTable(db).id,
                  ) as T;
                }
                if (tagId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tagId,
                    referencedTable: $$NoteTagsTableReferences._tagIdTable(db),
                    referencedColumn:
                        $$NoteTagsTableReferences._tagIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$NoteTagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NoteTagsTable,
    NoteTag,
    $$NoteTagsTableFilterComposer,
    $$NoteTagsTableOrderingComposer,
    $$NoteTagsTableAnnotationComposer,
    $$NoteTagsTableCreateCompanionBuilder,
    $$NoteTagsTableUpdateCompanionBuilder,
    (NoteTag, $$NoteTagsTableReferences),
    NoteTag,
    PrefetchHooks Function({bool noteId, bool tagId})>;
typedef $$NoteRelationsTableCreateCompanionBuilder = NoteRelationsCompanion
    Function({
  required int noteId1,
  required int noteId2,
  Value<int> rowid,
});
typedef $$NoteRelationsTableUpdateCompanionBuilder = NoteRelationsCompanion
    Function({
  Value<int> noteId1,
  Value<int> noteId2,
  Value<int> rowid,
});

final class $$NoteRelationsTableReferences
    extends BaseReferences<_$AppDatabase, $NoteRelationsTable, NoteRelation> {
  $$NoteRelationsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteId1Table(_$AppDatabase db) =>
      db.notes.createAlias('note_relations__note_id1__notes__id');

  $$NotesTableProcessedTableManager get noteId1 {
    final $_column = $_itemColumn<int>('note_id1')!;

    final manager = $$NotesTableTableManager($_db, $_db.notes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteId1Table($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $NotesTable _noteId2Table(_$AppDatabase db) =>
      db.notes.createAlias('note_relations__note_id2__notes__id');

  $$NotesTableProcessedTableManager get noteId2 {
    final $_column = $_itemColumn<int>('note_id2')!;

    final manager = $$NotesTableTableManager($_db, $_db.notes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteId2Table($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$NoteRelationsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteRelationsTable> {
  $$NoteRelationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableFilterComposer get noteId1 {
    final $$NotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId1,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableFilterComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$NotesTableFilterComposer get noteId2 {
    final $$NotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId2,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableFilterComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteRelationsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteRelationsTable> {
  $$NoteRelationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableOrderingComposer get noteId1 {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId1,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableOrderingComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$NotesTableOrderingComposer get noteId2 {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId2,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableOrderingComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteRelationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteRelationsTable> {
  $$NoteRelationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableAnnotationComposer get noteId1 {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId1,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableAnnotationComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$NotesTableAnnotationComposer get noteId2 {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId2,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableAnnotationComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteRelationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NoteRelationsTable,
    NoteRelation,
    $$NoteRelationsTableFilterComposer,
    $$NoteRelationsTableOrderingComposer,
    $$NoteRelationsTableAnnotationComposer,
    $$NoteRelationsTableCreateCompanionBuilder,
    $$NoteRelationsTableUpdateCompanionBuilder,
    (NoteRelation, $$NoteRelationsTableReferences),
    NoteRelation,
    PrefetchHooks Function({bool noteId1, bool noteId2})> {
  $$NoteRelationsTableTableManager(_$AppDatabase db, $NoteRelationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteRelationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteRelationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteRelationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> noteId1 = const Value.absent(),
            Value<int> noteId2 = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteRelationsCompanion(
            noteId1: noteId1,
            noteId2: noteId2,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int noteId1,
            required int noteId2,
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteRelationsCompanion.insert(
            noteId1: noteId1,
            noteId2: noteId2,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$NoteRelationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({noteId1 = false, noteId2 = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (noteId1) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.noteId1,
                    referencedTable:
                        $$NoteRelationsTableReferences._noteId1Table(db),
                    referencedColumn:
                        $$NoteRelationsTableReferences._noteId1Table(db).id,
                  ) as T;
                }
                if (noteId2) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.noteId2,
                    referencedTable:
                        $$NoteRelationsTableReferences._noteId2Table(db),
                    referencedColumn:
                        $$NoteRelationsTableReferences._noteId2Table(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$NoteRelationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NoteRelationsTable,
    NoteRelation,
    $$NoteRelationsTableFilterComposer,
    $$NoteRelationsTableOrderingComposer,
    $$NoteRelationsTableAnnotationComposer,
    $$NoteRelationsTableCreateCompanionBuilder,
    $$NoteRelationsTableUpdateCompanionBuilder,
    (NoteRelation, $$NoteRelationsTableReferences),
    NoteRelation,
    PrefetchHooks Function({bool noteId1, bool noteId2})>;
typedef $$AiProvidersTableCreateCompanionBuilder = AiProvidersCompanion
    Function({
  Value<int> id,
  required String name,
  required String type,
  required String baseUrl,
  Value<String?> apiKey,
  required String modelName,
  Value<bool> isDefault,
  Value<String?> extraConfig,
});
typedef $$AiProvidersTableUpdateCompanionBuilder = AiProvidersCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String> type,
  Value<String> baseUrl,
  Value<String?> apiKey,
  Value<String> modelName,
  Value<bool> isDefault,
  Value<String?> extraConfig,
});

class $$AiProvidersTableFilterComposer
    extends Composer<_$AppDatabase, $AiProvidersTable> {
  $$AiProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modelName => $composableBuilder(
      column: $table.modelName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extraConfig => $composableBuilder(
      column: $table.extraConfig, builder: (column) => ColumnFilters(column));
}

class $$AiProvidersTableOrderingComposer
    extends Composer<_$AppDatabase, $AiProvidersTable> {
  $$AiProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modelName => $composableBuilder(
      column: $table.modelName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extraConfig => $composableBuilder(
      column: $table.extraConfig, builder: (column) => ColumnOrderings(column));
}

class $$AiProvidersTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiProvidersTable> {
  $$AiProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get extraConfig => $composableBuilder(
      column: $table.extraConfig, builder: (column) => column);
}

class $$AiProvidersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AiProvidersTable,
    AiProvider,
    $$AiProvidersTableFilterComposer,
    $$AiProvidersTableOrderingComposer,
    $$AiProvidersTableAnnotationComposer,
    $$AiProvidersTableCreateCompanionBuilder,
    $$AiProvidersTableUpdateCompanionBuilder,
    (AiProvider, BaseReferences<_$AppDatabase, $AiProvidersTable, AiProvider>),
    AiProvider,
    PrefetchHooks Function()> {
  $$AiProvidersTableTableManager(_$AppDatabase db, $AiProvidersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> baseUrl = const Value.absent(),
            Value<String?> apiKey = const Value.absent(),
            Value<String> modelName = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<String?> extraConfig = const Value.absent(),
          }) =>
              AiProvidersCompanion(
            id: id,
            name: name,
            type: type,
            baseUrl: baseUrl,
            apiKey: apiKey,
            modelName: modelName,
            isDefault: isDefault,
            extraConfig: extraConfig,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String type,
            required String baseUrl,
            Value<String?> apiKey = const Value.absent(),
            required String modelName,
            Value<bool> isDefault = const Value.absent(),
            Value<String?> extraConfig = const Value.absent(),
          }) =>
              AiProvidersCompanion.insert(
            id: id,
            name: name,
            type: type,
            baseUrl: baseUrl,
            apiKey: apiKey,
            modelName: modelName,
            isDefault: isDefault,
            extraConfig: extraConfig,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AiProvidersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AiProvidersTable,
    AiProvider,
    $$AiProvidersTableFilterComposer,
    $$AiProvidersTableOrderingComposer,
    $$AiProvidersTableAnnotationComposer,
    $$AiProvidersTableCreateCompanionBuilder,
    $$AiProvidersTableUpdateCompanionBuilder,
    (AiProvider, BaseReferences<_$AppDatabase, $AiProvidersTable, AiProvider>),
    AiProvider,
    PrefetchHooks Function()>;
typedef $$AiConversationsTableCreateCompanionBuilder = AiConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> bookId,
  Value<String?> title,
  Value<DateTime> createdAt,
});
typedef $$AiConversationsTableUpdateCompanionBuilder = AiConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> bookId,
  Value<String?> title,
  Value<DateTime> createdAt,
});

final class $$AiConversationsTableReferences extends BaseReferences<
    _$AppDatabase, $AiConversationsTable, AiConversation> {
  $$AiConversationsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('ai_conversations__book_id__books__id');

  $$BooksTableProcessedTableManager? get bookId {
    final $_column = $_itemColumn<int>('book_id');
    if ($_column == null) return null;
    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$AiMessagesTable, List<AiMessage>>
      _aiMessagesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.aiMessages,
              aliasName: 'ai_conversations__id__ai_messages__conversation_id');

  $$AiMessagesTableProcessedTableManager get aiMessagesRefs {
    final manager = $$AiMessagesTableTableManager($_db, $_db.aiMessages)
        .filter((f) => f.conversationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_aiMessagesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AiConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> aiMessagesRefs(
      Expression<bool> Function($$AiMessagesTableFilterComposer f) f) {
    final $$AiMessagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aiMessages,
        getReferencedColumn: (t) => t.conversationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiMessagesTableFilterComposer(
              $db: $db,
              $table: $db.aiMessages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AiConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AiConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> aiMessagesRefs<T extends Object>(
      Expression<T> Function($$AiMessagesTableAnnotationComposer a) f) {
    final $$AiMessagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aiMessages,
        getReferencedColumn: (t) => t.conversationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiMessagesTableAnnotationComposer(
              $db: $db,
              $table: $db.aiMessages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AiConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AiConversationsTable,
    AiConversation,
    $$AiConversationsTableFilterComposer,
    $$AiConversationsTableOrderingComposer,
    $$AiConversationsTableAnnotationComposer,
    $$AiConversationsTableCreateCompanionBuilder,
    $$AiConversationsTableUpdateCompanionBuilder,
    (AiConversation, $$AiConversationsTableReferences),
    AiConversation,
    PrefetchHooks Function({bool bookId, bool aiMessagesRefs})> {
  $$AiConversationsTableTableManager(
      _$AppDatabase db, $AiConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> bookId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AiConversationsCompanion(
            id: id,
            bookId: bookId,
            title: title,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> bookId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AiConversationsCompanion.insert(
            id: id,
            bookId: bookId,
            title: title,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AiConversationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false, aiMessagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (aiMessagesRefs) db.aiMessages],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$AiConversationsTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$AiConversationsTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (aiMessagesRefs)
                    await $_getPrefetchedData<AiConversation,
                            $AiConversationsTable, AiMessage>(
                        currentTable: table,
                        referencedTable: $$AiConversationsTableReferences
                            ._aiMessagesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AiConversationsTableReferences(db, table, p0)
                                .aiMessagesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.conversationId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AiConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AiConversationsTable,
    AiConversation,
    $$AiConversationsTableFilterComposer,
    $$AiConversationsTableOrderingComposer,
    $$AiConversationsTableAnnotationComposer,
    $$AiConversationsTableCreateCompanionBuilder,
    $$AiConversationsTableUpdateCompanionBuilder,
    (AiConversation, $$AiConversationsTableReferences),
    AiConversation,
    PrefetchHooks Function({bool bookId, bool aiMessagesRefs})>;
typedef $$AiMessagesTableCreateCompanionBuilder = AiMessagesCompanion Function({
  Value<int> id,
  required int conversationId,
  required String role,
  required String content,
  Value<String?> metadataJson,
  Value<DateTime> createdAt,
});
typedef $$AiMessagesTableUpdateCompanionBuilder = AiMessagesCompanion Function({
  Value<int> id,
  Value<int> conversationId,
  Value<String> role,
  Value<String> content,
  Value<String?> metadataJson,
  Value<DateTime> createdAt,
});

final class $$AiMessagesTableReferences
    extends BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessage> {
  $$AiMessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AiConversationsTable _conversationIdTable(_$AppDatabase db) =>
      db.aiConversations
          .createAlias('ai_messages__conversation_id__ai_conversations__id');

  $$AiConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<int>('conversation_id')!;

    final manager =
        $$AiConversationsTableTableManager($_db, $_db.aiConversations)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AiMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$AiConversationsTableFilterComposer get conversationId {
    final $$AiConversationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.aiConversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiConversationsTableFilterComposer(
              $db: $db,
              $table: $db.aiConversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AiMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$AiConversationsTableOrderingComposer get conversationId {
    final $$AiConversationsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.aiConversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiConversationsTableOrderingComposer(
              $db: $db,
              $table: $db.aiConversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AiMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AiConversationsTableAnnotationComposer get conversationId {
    final $$AiConversationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.conversationId,
        referencedTable: $db.aiConversations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AiConversationsTableAnnotationComposer(
              $db: $db,
              $table: $db.aiConversations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AiMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AiMessagesTable,
    AiMessage,
    $$AiMessagesTableFilterComposer,
    $$AiMessagesTableOrderingComposer,
    $$AiMessagesTableAnnotationComposer,
    $$AiMessagesTableCreateCompanionBuilder,
    $$AiMessagesTableUpdateCompanionBuilder,
    (AiMessage, $$AiMessagesTableReferences),
    AiMessage,
    PrefetchHooks Function({bool conversationId})> {
  $$AiMessagesTableTableManager(_$AppDatabase db, $AiMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> conversationId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> metadataJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AiMessagesCompanion(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            metadataJson: metadataJson,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int conversationId,
            required String role,
            required String content,
            Value<String?> metadataJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AiMessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            metadataJson: metadataJson,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AiMessagesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (conversationId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.conversationId,
                    referencedTable:
                        $$AiMessagesTableReferences._conversationIdTable(db),
                    referencedColumn:
                        $$AiMessagesTableReferences._conversationIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AiMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AiMessagesTable,
    AiMessage,
    $$AiMessagesTableFilterComposer,
    $$AiMessagesTableOrderingComposer,
    $$AiMessagesTableAnnotationComposer,
    $$AiMessagesTableCreateCompanionBuilder,
    $$AiMessagesTableUpdateCompanionBuilder,
    (AiMessage, $$AiMessagesTableReferences),
    AiMessage,
    PrefetchHooks Function({bool conversationId})>;
typedef $$AiSkillsTableCreateCompanionBuilder = AiSkillsCompanion Function({
  Value<int> id,
  required String name,
  Value<String> description,
  required String contentMarkdown,
  Value<String> allowedToolsJson,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AiSkillsTableUpdateCompanionBuilder = AiSkillsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> description,
  Value<String> contentMarkdown,
  Value<String> allowedToolsJson,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$AiSkillsTableFilterComposer
    extends Composer<_$AppDatabase, $AiSkillsTable> {
  $$AiSkillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentMarkdown => $composableBuilder(
      column: $table.contentMarkdown,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get allowedToolsJson => $composableBuilder(
      column: $table.allowedToolsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AiSkillsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiSkillsTable> {
  $$AiSkillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentMarkdown => $composableBuilder(
      column: $table.contentMarkdown,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get allowedToolsJson => $composableBuilder(
      column: $table.allowedToolsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AiSkillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiSkillsTable> {
  $$AiSkillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get contentMarkdown => $composableBuilder(
      column: $table.contentMarkdown, builder: (column) => column);

  GeneratedColumn<String> get allowedToolsJson => $composableBuilder(
      column: $table.allowedToolsJson, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiSkillsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AiSkillsTable,
    AiSkill,
    $$AiSkillsTableFilterComposer,
    $$AiSkillsTableOrderingComposer,
    $$AiSkillsTableAnnotationComposer,
    $$AiSkillsTableCreateCompanionBuilder,
    $$AiSkillsTableUpdateCompanionBuilder,
    (AiSkill, BaseReferences<_$AppDatabase, $AiSkillsTable, AiSkill>),
    AiSkill,
    PrefetchHooks Function()> {
  $$AiSkillsTableTableManager(_$AppDatabase db, $AiSkillsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiSkillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiSkillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiSkillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> contentMarkdown = const Value.absent(),
            Value<String> allowedToolsJson = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AiSkillsCompanion(
            id: id,
            name: name,
            description: description,
            contentMarkdown: contentMarkdown,
            allowedToolsJson: allowedToolsJson,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> description = const Value.absent(),
            required String contentMarkdown,
            Value<String> allowedToolsJson = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AiSkillsCompanion.insert(
            id: id,
            name: name,
            description: description,
            contentMarkdown: contentMarkdown,
            allowedToolsJson: allowedToolsJson,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AiSkillsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AiSkillsTable,
    AiSkill,
    $$AiSkillsTableFilterComposer,
    $$AiSkillsTableOrderingComposer,
    $$AiSkillsTableAnnotationComposer,
    $$AiSkillsTableCreateCompanionBuilder,
    $$AiSkillsTableUpdateCompanionBuilder,
    (AiSkill, BaseReferences<_$AppDatabase, $AiSkillsTable, AiSkill>),
    AiSkill,
    PrefetchHooks Function()>;
typedef $$AiPersonasTableCreateCompanionBuilder = AiPersonasCompanion Function({
  Value<int> id,
  required String name,
  required String type,
  Value<int?> bookId,
  Value<String?> characterName,
  Value<String> systemPrompt,
  Value<String> documentMarkdown,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AiPersonasTableUpdateCompanionBuilder = AiPersonasCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> type,
  Value<int?> bookId,
  Value<String?> characterName,
  Value<String> systemPrompt,
  Value<String> documentMarkdown,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$AiPersonasTableReferences
    extends BaseReferences<_$AppDatabase, $AiPersonasTable, AiPersona> {
  $$AiPersonasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('ai_personas__book_id__books__id');

  $$BooksTableProcessedTableManager? get bookId {
    final $_column = $_itemColumn<int>('book_id');
    if ($_column == null) return null;
    final manager = $$BooksTableTableManager($_db, $_db.books)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AiPersonasTableFilterComposer
    extends Composer<_$AppDatabase, $AiPersonasTable> {
  $$AiPersonasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get characterName => $composableBuilder(
      column: $table.characterName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get systemPrompt => $composableBuilder(
      column: $table.systemPrompt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get documentMarkdown => $composableBuilder(
      column: $table.documentMarkdown,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableFilterComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AiPersonasTableOrderingComposer
    extends Composer<_$AppDatabase, $AiPersonasTable> {
  $$AiPersonasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get characterName => $composableBuilder(
      column: $table.characterName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
      column: $table.systemPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get documentMarkdown => $composableBuilder(
      column: $table.documentMarkdown,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableOrderingComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AiPersonasTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiPersonasTable> {
  $$AiPersonasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get characterName => $composableBuilder(
      column: $table.characterName, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
      column: $table.systemPrompt, builder: (column) => column);

  GeneratedColumn<String> get documentMarkdown => $composableBuilder(
      column: $table.documentMarkdown, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.bookId,
        referencedTable: $db.books,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BooksTableAnnotationComposer(
              $db: $db,
              $table: $db.books,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AiPersonasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AiPersonasTable,
    AiPersona,
    $$AiPersonasTableFilterComposer,
    $$AiPersonasTableOrderingComposer,
    $$AiPersonasTableAnnotationComposer,
    $$AiPersonasTableCreateCompanionBuilder,
    $$AiPersonasTableUpdateCompanionBuilder,
    (AiPersona, $$AiPersonasTableReferences),
    AiPersona,
    PrefetchHooks Function({bool bookId})> {
  $$AiPersonasTableTableManager(_$AppDatabase db, $AiPersonasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiPersonasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiPersonasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiPersonasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int?> bookId = const Value.absent(),
            Value<String?> characterName = const Value.absent(),
            Value<String> systemPrompt = const Value.absent(),
            Value<String> documentMarkdown = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AiPersonasCompanion(
            id: id,
            name: name,
            type: type,
            bookId: bookId,
            characterName: characterName,
            systemPrompt: systemPrompt,
            documentMarkdown: documentMarkdown,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String type,
            Value<int?> bookId = const Value.absent(),
            Value<String?> characterName = const Value.absent(),
            Value<String> systemPrompt = const Value.absent(),
            Value<String> documentMarkdown = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AiPersonasCompanion.insert(
            id: id,
            name: name,
            type: type,
            bookId: bookId,
            characterName: characterName,
            systemPrompt: systemPrompt,
            documentMarkdown: documentMarkdown,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AiPersonasTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (bookId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.bookId,
                    referencedTable:
                        $$AiPersonasTableReferences._bookIdTable(db),
                    referencedColumn:
                        $$AiPersonasTableReferences._bookIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AiPersonasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AiPersonasTable,
    AiPersona,
    $$AiPersonasTableFilterComposer,
    $$AiPersonasTableOrderingComposer,
    $$AiPersonasTableAnnotationComposer,
    $$AiPersonasTableCreateCompanionBuilder,
    $$AiPersonasTableUpdateCompanionBuilder,
    (AiPersona, $$AiPersonasTableReferences),
    AiPersona,
    PrefetchHooks Function({bool bookId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$BookCollectionsTableTableManager get bookCollections =>
      $$BookCollectionsTableTableManager(_db, _db.bookCollections);
  $$BookCollectionItemsTableTableManager get bookCollectionItems =>
      $$BookCollectionItemsTableTableManager(_db, _db.bookCollectionItems);
  $$BookTtsSettingsTableTableManager get bookTtsSettings =>
      $$BookTtsSettingsTableTableManager(_db, _db.bookTtsSettings);
  $$BookReadingSettingsTableTableManager get bookReadingSettings =>
      $$BookReadingSettingsTableTableManager(_db, _db.bookReadingSettings);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$VocabularyEntriesTableTableManager get vocabularyEntries =>
      $$VocabularyEntriesTableTableManager(_db, _db.vocabularyEntries);
  $$DictionarySourcesTableTableManager get dictionarySources =>
      $$DictionarySourcesTableTableManager(_db, _db.dictionarySources);
  $$DictionaryEntriesTableTableManager get dictionaryEntries =>
      $$DictionaryEntriesTableTableManager(_db, _db.dictionaryEntries);
  $$DictionaryAliasesTableTableManager get dictionaryAliases =>
      $$DictionaryAliasesTableTableManager(_db, _db.dictionaryAliases);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$ReadingSessionsTableTableManager get readingSessions =>
      $$ReadingSessionsTableTableManager(_db, _db.readingSessions);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$NoteTagsTableTableManager get noteTags =>
      $$NoteTagsTableTableManager(_db, _db.noteTags);
  $$NoteRelationsTableTableManager get noteRelations =>
      $$NoteRelationsTableTableManager(_db, _db.noteRelations);
  $$AiProvidersTableTableManager get aiProviders =>
      $$AiProvidersTableTableManager(_db, _db.aiProviders);
  $$AiConversationsTableTableManager get aiConversations =>
      $$AiConversationsTableTableManager(_db, _db.aiConversations);
  $$AiMessagesTableTableManager get aiMessages =>
      $$AiMessagesTableTableManager(_db, _db.aiMessages);
  $$AiSkillsTableTableManager get aiSkills =>
      $$AiSkillsTableTableManager(_db, _db.aiSkills);
  $$AiPersonasTableTableManager get aiPersonas =>
      $$AiPersonasTableTableManager(_db, _db.aiPersonas);
}
