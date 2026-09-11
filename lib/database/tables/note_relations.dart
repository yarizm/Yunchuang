import 'package:drift/drift.dart';
import 'notes.dart';

class NoteRelations extends Table {
  @ReferenceName('relationsFrom')
  IntColumn get noteId1 =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('relationsTo')
  IntColumn get noteId2 =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {noteId1, noteId2};
}
