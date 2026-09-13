import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/book_dao.dart';
import '../database/daos/collection_dao.dart';
import '../database/daos/book_tts_settings_dao.dart';
import '../database/daos/book_reading_settings_dao.dart';
import '../database/daos/vocabulary_dao.dart';
import '../database/daos/dictionary_dao.dart';
import '../database/daos/note_dao.dart';
import '../database/daos/progress_dao.dart';
import '../database/daos/ai_dao.dart';
import '../services/book_service.dart';
import '../services/dictionary_service.dart';
import '../providers/ai/ai_service.dart';
import '../providers/ai/ai_usage.dart';
import 'preferences_provider.dart';
import '../providers/ai/ai_agent_service.dart';
import '../providers/ai/ai_asset_service.dart';
import '../providers/ai/ai_persona_selection_store.dart';
import '../providers/ai/character_persona_checkpoint_store.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final bookDaoProvider = Provider<BookDao>((ref) {
  return BookDao(ref.watch(databaseProvider));
});

final collectionDaoProvider = Provider<CollectionDao>((ref) {
  return CollectionDao(ref.watch(databaseProvider));
});

final bookTtsSettingsDaoProvider = Provider<BookTtsSettingsDao>((ref) {
  return BookTtsSettingsDao(ref.watch(databaseProvider));
});

final bookReadingSettingsDaoProvider = Provider<BookReadingSettingsDao>((ref) {
  return BookReadingSettingsDao(ref.watch(databaseProvider));
});

final vocabularyDaoProvider = Provider<VocabularyDao>((ref) {
  return VocabularyDao(ref.watch(databaseProvider));
});

final dictionaryDaoProvider = Provider<DictionaryDao>((ref) {
  return DictionaryDao(ref.watch(databaseProvider));
});

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return DictionaryService(ref.watch(dictionaryDaoProvider));
});

final dictionarySourcesProvider = StreamProvider<List<DictionarySource>>((ref) {
  return ref.watch(dictionaryServiceProvider).watchSources();
});

final noteDaoProvider = Provider<NoteDao>((ref) {
  return NoteDao(ref.watch(databaseProvider));
});

final progressDaoProvider = Provider<ProgressDao>((ref) {
  return ProgressDao(ref.watch(databaseProvider));
});

final allReadingProgressProvider =
    StreamProvider<Map<int, ReadingProgressData>>((ref) {
  return ref.watch(progressDaoProvider).watchAllProgress();
});

final aiDaoProvider = Provider<AiDao>((ref) {
  return AiDao(ref.watch(databaseProvider));
});

final bookServiceProvider = Provider<BookService>((ref) {
  return BookService(ref.watch(bookDaoProvider));
});

final aiServiceProvider = Provider<AIService>((ref) {
  final service = AIService(ref.watch(aiDaoProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// token 用量计数器。创建时把自己接到 AIService 上，所以得有人在启动时
/// 读它一下（MainShell 干这事），不然在打开用量页之前什么都记不到。
/// 不在 aiServiceProvider 里 watch 它：那样每个用到 AI 的测试都得先准备
/// SharedPreferences。
final aiUsageTrackerProvider = ChangeNotifierProvider<AiUsageTracker>((ref) {
  final tracker = AiUsageTracker(ref.watch(sharedPreferencesProvider));
  ref.watch(aiServiceProvider).usageSink = tracker;
  return tracker;
});

final aiAgentServiceProvider = Provider<AIAgentService>((ref) {
  return AIAgentService(
    aiService: ref.watch(aiServiceProvider),
    database: ref.watch(databaseProvider),
  );
});

final aiPersonaSelectionStoreProvider =
    Provider<AiPersonaSelectionStore>((ref) {
  return MemoryAiPersonaSelectionStore();
});

final characterPersonaCheckpointStoreProvider =
    Provider<CharacterPersonaCheckpointStore>((ref) {
  return CharacterPersonaCheckpointStore();
});

final aiAssetServiceProvider = Provider<AIAssetService>((ref) {
  return AIAssetService(
    aiService: ref.watch(aiServiceProvider),
    bookDao: ref.watch(bookDaoProvider),
    checkpointStore: ref.watch(characterPersonaCheckpointStoreProvider),
  );
});
