import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yunchuang/providers/ai/character_persona_checkpoint.dart';
import 'package:yunchuang/providers/ai/character_persona_checkpoint_store.dart';

void main() {
  late Directory directory;
  late CharacterPersonaCheckpointStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('persona-checkpoints-');
    store = CharacterPersonaCheckpointStore(
      directoryProvider: () async => directory,
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists and restores every generation stage', () async {
    final updatedAt = DateTime.utc(2026, 7, 15, 8, 30);
    final checkpoint = CharacterPersonaGenerationCheckpoint(
      bookId: 7,
      characterName: '方源',
      totalEvidenceTasks: 3,
      sourceFingerprint: 'tasks-v1-12345678-90abcdef',
      nextEvidenceIndex: 3,
      evidence: const ['证据一', '证据二', '证据三'],
      nextMergeBatchIndex: 2,
      mergedBatches: const ['批次一', '批次二'],
      reductionRound: 1,
      reductionInput: const ['待压缩证据一', '待压缩证据二'],
      nextReductionBatchIndex: 1,
      reducedEvidence: const ['压缩结果一'],
      finalEvidenceText: '最终证据摘要',
      finalDocument: '# 方源人格',
      updatedAt: updatedAt,
    );

    await store.save(checkpoint);
    final restored = await store.loadForBook(
      7,
      now: DateTime.utc(2026, 7, 16),
    );

    expect(restored, isNotNull);
    expect(restored!.characterName, '方源');
    expect(
      restored.pipelineVersion,
      CharacterPersonaGenerationCheckpoint.currentPipelineVersion,
    );
    expect(restored.evidence, checkpoint.evidence);
    expect(restored.sourceFingerprint, checkpoint.sourceFingerprint);
    expect(restored.mergedBatches, checkpoint.mergedBatches);
    expect(restored.reductionRound, 1);
    expect(restored.reductionInput, checkpoint.reductionInput);
    expect(restored.nextReductionBatchIndex, 1);
    expect(restored.reducedEvidence, checkpoint.reducedEvidence);
    expect(restored.finalEvidenceText, '最终证据摘要');
    expect(restored.finalDocument, '# 方源人格');
    expect(restored.updatedAt, updatedAt);
  });

  test('deletes expired and corrupted checkpoints while loading', () async {
    await store.save(CharacterPersonaGenerationCheckpoint(
      bookId: 1,
      characterName: '过期角色',
      totalEvidenceTasks: 1,
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    expect(
      await store.loadForBook(1, now: DateTime.utc(2026, 2, 2)),
      isNull,
    );
    expect(File(p.join(directory.path, 'book_1.json')).existsSync(), isFalse);

    final corrupted = File(p.join(directory.path, 'book_2.json'));
    await corrupted.writeAsString('{not json');
    expect(await store.loadForBook(2), isNull);
    expect(corrupted.existsSync(), isFalse);
  });

  test('cleanup removes expired and unknown checkpoint files', () async {
    await store.save(CharacterPersonaGenerationCheckpoint(
      bookId: 3,
      characterName: '保留角色',
      totalEvidenceTasks: 1,
      updatedAt: DateTime.utc(2026, 7, 1),
    ));
    await store.save(CharacterPersonaGenerationCheckpoint(
      bookId: 4,
      characterName: '过期角色',
      totalEvidenceTasks: 1,
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    final unknown = File(p.join(directory.path, 'unknown.json'));
    await unknown.writeAsString('{}');

    final deleted = await store.cleanupExpired(
      now: DateTime.utc(2026, 7, 15),
    );

    expect(deleted, 2);
    expect(
      await store.loadForBook(3, now: DateTime.utc(2026, 7, 15)),
      isNotNull,
    );
    expect(await store.loadForBook(4), isNull);
    expect(unknown.existsSync(), isFalse);
  });

  test('model rejects malformed progress before it reaches the store', () {
    final json = CharacterPersonaGenerationCheckpoint(
      bookId: 5,
      characterName: '测试角色',
      totalEvidenceTasks: 2,
    ).toJson()
      ..['nextEvidenceIndex'] = 2
      ..['evidence'] = ['只有一条'];

    expect(
      () => CharacterPersonaGenerationCheckpoint.fromJson(json),
      throwsFormatException,
    );
  });

  test('loads legacy checkpoints without a pipeline version', () {
    final json = CharacterPersonaGenerationCheckpoint(
      bookId: 6,
      characterName: '旧角色',
      totalEvidenceTasks: 1,
    ).toJson()
      ..['version'] = 1
      ..remove('pipelineVersion')
      ..remove('sourceFingerprint')
      ..remove('reductionRound')
      ..remove('reductionInput')
      ..remove('nextReductionBatchIndex')
      ..remove('reducedEvidence')
      ..remove('finalEvidenceText');

    final restored = CharacterPersonaGenerationCheckpoint.fromJson(json);

    expect(restored.pipelineVersion, 1);
    expect(restored.sourceFingerprint, isNull);
    expect(restored.hasReductionProgress, isFalse);
  });

  test('rejects malformed evidence reduction progress', () {
    final json = CharacterPersonaGenerationCheckpoint(
      bookId: 8,
      characterName: '测试角色',
      totalEvidenceTasks: 1,
    ).toJson()
      ..['reductionInput'] = ['待压缩证据']
      ..['nextReductionBatchIndex'] = 2
      ..['reducedEvidence'] = ['只有一个结果'];

    expect(
      () => CharacterPersonaGenerationCheckpoint.fromJson(json),
      throwsFormatException,
    );
  });

  test('rejects a malformed source fingerprint field', () {
    final json = CharacterPersonaGenerationCheckpoint(
      bookId: 7,
      characterName: '测试角色',
      totalEvidenceTasks: 1,
    ).toJson()
      ..['sourceFingerprint'] = 42;

    expect(
      () => CharacterPersonaGenerationCheckpoint.fromJson(json),
      throwsFormatException,
    );

    final oversized = CharacterPersonaGenerationCheckpoint(
      bookId: 7,
      characterName: '测试角色',
      totalEvidenceTasks: 1,
    ).toJson()
      ..['sourceFingerprint'] = List.filled(129, 'a').join();
    expect(
      () => CharacterPersonaGenerationCheckpoint.fromJson(oversized),
      throwsFormatException,
    );
  });
}
