import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/services/tts_playback_checkpoint_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves and restores the active TTS playback checkpoint', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = TtsPlaybackCheckpointStore(preferences);
    final updatedAt = DateTime.utc(2026, 7, 30, 8, 30);

    await store.save(
      TtsPlaybackCheckpoint(
        bookId: 7,
        chapterId: 11,
        characterOffset: 321,
        updatedAt: updatedAt,
      ),
    );
    final restored = await store.load(now: updatedAt);

    expect(restored?.bookId, 7);
    expect(restored?.chapterId, 11);
    expect(restored?.characterOffset, 321);
    expect(restored?.updatedAt, updatedAt);
  });

  test('drops expired and malformed checkpoints', () async {
    final expiredAt = DateTime.utc(2026, 7, 1);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = TtsPlaybackCheckpointStore(preferences);
    await store.save(
      TtsPlaybackCheckpoint(
        bookId: 7,
        chapterId: 11,
        characterOffset: 321,
        updatedAt: expiredAt,
      ),
    );

    expect(await store.load(now: DateTime.utc(2026, 7, 30)), isNull);
    expect(
      preferences.getString(TtsPlaybackCheckpointStore.storageKey),
      isNull,
    );

    await preferences.setString(
      TtsPlaybackCheckpointStore.storageKey,
      '{"bookId":"invalid"}',
    );

    expect(await store.load(), isNull);
    expect(
      preferences.getString(TtsPlaybackCheckpointStore.storageKey),
      isNull,
    );
  });

  test('only clears the checkpoint for the matching book', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = TtsPlaybackCheckpointStore(preferences);
    await store.save(
      TtsPlaybackCheckpoint(
        bookId: 7,
        chapterId: 11,
        characterOffset: 321,
        updatedAt: DateTime.now(),
      ),
    );

    await store.clearForBook(8);
    expect(await store.load(), isNotNull);

    await store.clearForBook(7);
    expect(await store.load(), isNull);
  });
}
