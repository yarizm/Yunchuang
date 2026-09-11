import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../database/app_database.dart';
import '../models/book_reading_status.dart';
import '../models/book_shelf_options.dart';
import '../services/book_service.dart';
import 'database_provider.dart';
import 'preferences_provider.dart';

final shelfStatusFilterProvider = StateProvider<BookReadingStatus?>(
  (ref) => null,
);

final selectedBookCollectionProvider = StateProvider<int?>((ref) => null);
final selectedBookSeriesProvider = StateProvider<String?>((ref) => null);

final selectedShelfBookIdsProvider =
    StateProvider.autoDispose<Set<int>>((ref) => const {});

class BookShelfPreferences {
  final BookSortMode sortMode;
  final BookShelfViewMode viewMode;

  const BookShelfPreferences({
    this.sortMode = BookSortMode.recentlyRead,
    this.viewMode = BookShelfViewMode.grid,
  });

  BookShelfPreferences copyWith({
    BookSortMode? sortMode,
    BookShelfViewMode? viewMode,
  }) {
    return BookShelfPreferences(
      sortMode: sortMode ?? this.sortMode,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

class BookShelfPreferencesNotifier extends Notifier<BookShelfPreferences> {
  static const _sortKey = 'bookShelfSortMode';
  static const _viewKey = 'bookShelfViewMode';

  @override
  BookShelfPreferences build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return BookShelfPreferences(
      sortMode: BookSortMode.fromStorage(preferences.getString(_sortKey)),
      viewMode: BookShelfViewMode.fromStorage(preferences.getString(_viewKey)),
    );
  }

  void updateSortMode(BookSortMode mode) {
    state = state.copyWith(sortMode: mode);
    ref.read(sharedPreferencesProvider).setString(_sortKey, mode.name);
  }

  void updateViewMode(BookShelfViewMode mode) {
    state = state.copyWith(viewMode: mode);
    ref.read(sharedPreferencesProvider).setString(_viewKey, mode.name);
  }
}

final bookShelfPreferencesProvider =
    NotifierProvider<BookShelfPreferencesNotifier, BookShelfPreferences>(
  BookShelfPreferencesNotifier.new,
);

final shelfBooksProvider = StreamProvider<List<Book>>((ref) {
  final collectionId = ref.watch(selectedBookCollectionProvider);
  final seriesName = ref.watch(selectedBookSeriesProvider);
  final readingStatus = ref.watch(shelfStatusFilterProvider);
  final sortMode = ref.watch(
    bookShelfPreferencesProvider.select((preferences) => preferences.sortMode),
  );
  return ref.watch(bookDaoProvider).watchShelfBooks(
        collectionId: collectionId,
        seriesName: seriesName,
        readingStatus: readingStatus,
        sortMode: sortMode,
      );
});

final bookSeriesProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(bookDaoProvider).watchSeriesNames();
});

final bookCollectionsProvider = StreamProvider<List<BookCollection>>((ref) {
  return ref.watch(collectionDaoProvider).watchCollections();
});

final collectionBookIdsProvider =
    StreamProvider.autoDispose.family<Set<int>, int>((ref, collectionId) {
  return ref
      .watch(collectionDaoProvider)
      .watchBookIdsForCollection(collectionId);
});

final bookCollectionIdsProvider =
    StreamProvider.autoDispose.family<Set<int>, int>((ref, bookId) {
  return ref.watch(collectionDaoProvider).watchCollectionIdsForBook(bookId);
});

final booksProvider = AsyncNotifierProvider<BooksNotifier, List<Book>>(
  BooksNotifier.new,
);

class BooksNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() async {
    return ref.watch(bookServiceProvider).getAllBooks();
  }

  Future<List<String>> pickBookFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedBookExtensions.toList(),
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return const [];
    return result.files
        .map((file) => file.path)
        .whereType<String>()
        .toList(growable: false);
  }

  Future<List<String>> pickBookDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择书籍文件夹',
    );
    if (path == null) return const [];
    return ref.read(bookServiceProvider).findSupportedBooksInDirectory(path);
  }

  Future<BookImportAnalysis> analyzeBookImport(String filePath) {
    return ref.read(bookServiceProvider).analyzeImport(filePath);
  }

  Future<Book> importBookFile(
    String filePath, {
    required BookImportAnalysis analysis,
    required DuplicateBookAction duplicateAction,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(bookServiceProvider);
      final imported = await service.importBook(
        filePath,
        analysis: analysis,
        duplicateAction: duplicateAction,
      );
      state = AsyncValue.data(await service.getAllBooks());
      return imported;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// 失败会往上抛，和 [deleteBooks] 一致：调用方要能给用户报错。
  Future<void> deleteBook(int bookId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(bookServiceProvider).deleteBook(bookId);
      state = AsyncValue.data(
        await ref.read(bookServiceProvider).getAllBooks(),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateBookMetadata(
    int bookId, {
    required String title,
    required String author,
    String? coverPath,
    required String? seriesName,
    required double? seriesIndex,
  }) async {
    await ref.read(bookServiceProvider).updateBookMetadata(
          bookId,
          title: title,
          author: author,
          coverPath: coverPath,
          seriesName: seriesName,
          seriesIndex: seriesIndex,
        );
    ref.invalidateSelf();
  }

  Future<void> updateReadingStatus(
    int bookId,
    BookReadingStatus? status,
  ) async {
    await ref.read(bookServiceProvider).updateBookReadingStatus(bookId, status);
    ref.invalidateSelf();
  }

  Future<void> updateReadingStatuses(
    Set<int> bookIds,
    BookReadingStatus? status,
  ) async {
    await ref
        .read(bookServiceProvider)
        .updateBooksReadingStatus(bookIds, status);
    ref.invalidateSelf();
  }

  Future<void> deleteBooks(Set<int> bookIds) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(bookServiceProvider).deleteBooks(bookIds);
      state = AsyncValue.data(
        await ref.read(bookServiceProvider).getAllBooks(),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
