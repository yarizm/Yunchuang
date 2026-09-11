import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../services/note_service.dart';
import 'database_provider.dart';

final noteServiceProvider = Provider<NoteService>((ref) {
  return NoteService(
    ref.watch(noteDaoProvider),
    ref.watch(databaseProvider),
  );
});

final allNotesProvider = FutureProvider<List<Note>>((ref) async {
  return ref.watch(noteServiceProvider).getAllNotes();
});

final notesForBookProvider = FutureProvider.family<List<Note>, int>(
  (ref, bookId) async {
    return ref.watch(noteServiceProvider).getNotesForBook(bookId);
  },
);

final allTagsProvider = FutureProvider<List<Tag>>((ref) async {
  return ref.watch(noteServiceProvider).getAllTags();
});
