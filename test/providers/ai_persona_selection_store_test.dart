import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/ai/ai_persona_selection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists persona selections independently for each book', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAiPersonaSelectionStore(preferences);

    await store.write(7, 11);
    await store.write(8, 12);
    await store.write(null, 13);

    final restored = SharedPreferencesAiPersonaSelectionStore(preferences);
    expect(restored.read(7), 11);
    expect(restored.read(8), 12);
    expect(restored.read(null), 13);

    await restored.write(7, null);
    expect(store.read(7), isNull);
    expect(store.read(8), 12);
    expect(store.read(null), 13);
  });
}
