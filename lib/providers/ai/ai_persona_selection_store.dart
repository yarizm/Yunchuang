import 'package:shared_preferences/shared_preferences.dart';

abstract class AiPersonaSelectionStore {
  int? read(int? bookId);

  Future<void> write(int? bookId, int? personaId);
}

class MemoryAiPersonaSelectionStore implements AiPersonaSelectionStore {
  final Map<String, int> _selectedPersonaIds = {};

  @override
  int? read(int? bookId) => _selectedPersonaIds[_key(bookId)];

  @override
  Future<void> write(int? bookId, int? personaId) async {
    final key = _key(bookId);
    if (personaId == null) {
      _selectedPersonaIds.remove(key);
    } else {
      _selectedPersonaIds[key] = personaId;
    }
  }
}

class SharedPreferencesAiPersonaSelectionStore
    implements AiPersonaSelectionStore {
  final SharedPreferences preferences;

  const SharedPreferencesAiPersonaSelectionStore(this.preferences);

  @override
  int? read(int? bookId) => preferences.getInt(_key(bookId));

  @override
  Future<void> write(int? bookId, int? personaId) async {
    final key = _key(bookId);
    if (personaId == null) {
      await preferences.remove(key);
    } else {
      await preferences.setInt(key, personaId);
    }
  }
}

String _key(int? bookId) => bookId == null
    ? 'ai.selectedPersona.global'
    : 'ai.selectedPersona.book.$bookId';
