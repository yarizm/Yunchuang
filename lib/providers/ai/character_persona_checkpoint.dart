class CharacterPersonaGenerationCheckpoint {
  static const formatVersion = 2;
  static const minimumSupportedFormatVersion = 1;
  static const currentPipelineVersion = 2;

  final int bookId;
  final String characterName;
  final int totalEvidenceTasks;
  final int pipelineVersion;
  final String? sourceFingerprint;
  final int nextEvidenceIndex;
  final List<String> evidence;
  final int nextMergeBatchIndex;
  final List<String> mergedBatches;
  final int reductionRound;
  final List<String> reductionInput;
  final int nextReductionBatchIndex;
  final List<String> reducedEvidence;
  final String? finalEvidenceText;
  final String? finalDocument;
  final DateTime updatedAt;

  CharacterPersonaGenerationCheckpoint({
    required this.bookId,
    required this.characterName,
    required this.totalEvidenceTasks,
    this.pipelineVersion = currentPipelineVersion,
    this.sourceFingerprint,
    this.nextEvidenceIndex = 0,
    List<String> evidence = const [],
    this.nextMergeBatchIndex = 0,
    List<String> mergedBatches = const [],
    this.reductionRound = 0,
    List<String> reductionInput = const [],
    this.nextReductionBatchIndex = 0,
    List<String> reducedEvidence = const [],
    this.finalEvidenceText,
    this.finalDocument,
    DateTime? updatedAt,
  })  : evidence = List.unmodifiable(evidence),
        mergedBatches = List.unmodifiable(mergedBatches),
        reductionInput = List.unmodifiable(reductionInput),
        reducedEvidence = List.unmodifiable(reducedEvidence),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasReductionProgress =>
      reductionInput.isNotEmpty ||
      nextReductionBatchIndex != 0 ||
      reducedEvidence.isNotEmpty ||
      finalEvidenceText != null;

  CharacterPersonaGenerationCheckpoint copyWith({
    int? nextEvidenceIndex,
    List<String>? evidence,
    int? nextMergeBatchIndex,
    List<String>? mergedBatches,
    int? reductionRound,
    List<String>? reductionInput,
    int? nextReductionBatchIndex,
    List<String>? reducedEvidence,
    String? finalEvidenceText,
    String? finalDocument,
    String? sourceFingerprint,
  }) {
    return CharacterPersonaGenerationCheckpoint(
      bookId: bookId,
      characterName: characterName,
      totalEvidenceTasks: totalEvidenceTasks,
      pipelineVersion: pipelineVersion,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      nextEvidenceIndex: nextEvidenceIndex ?? this.nextEvidenceIndex,
      evidence: evidence ?? this.evidence,
      nextMergeBatchIndex: nextMergeBatchIndex ?? this.nextMergeBatchIndex,
      mergedBatches: mergedBatches ?? this.mergedBatches,
      reductionRound: reductionRound ?? this.reductionRound,
      reductionInput: reductionInput ?? this.reductionInput,
      nextReductionBatchIndex:
          nextReductionBatchIndex ?? this.nextReductionBatchIndex,
      reducedEvidence: reducedEvidence ?? this.reducedEvidence,
      finalEvidenceText: finalEvidenceText ?? this.finalEvidenceText,
      finalDocument: finalDocument ?? this.finalDocument,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': formatVersion,
        'pipelineVersion': pipelineVersion,
        'sourceFingerprint': sourceFingerprint,
        'bookId': bookId,
        'characterName': characterName,
        'totalEvidenceTasks': totalEvidenceTasks,
        'nextEvidenceIndex': nextEvidenceIndex,
        'evidence': evidence,
        'nextMergeBatchIndex': nextMergeBatchIndex,
        'mergedBatches': mergedBatches,
        'reductionRound': reductionRound,
        'reductionInput': reductionInput,
        'nextReductionBatchIndex': nextReductionBatchIndex,
        'reducedEvidence': reducedEvidence,
        'finalEvidenceText': finalEvidenceText,
        'finalDocument': finalDocument,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory CharacterPersonaGenerationCheckpoint.fromJson(
    Map<String, dynamic> json,
  ) {
    final version = _requiredInt(json, 'version');
    if (version < minimumSupportedFormatVersion || version > formatVersion) {
      throw const FormatException('Unsupported checkpoint version.');
    }
    final checkpoint = CharacterPersonaGenerationCheckpoint(
      bookId: _requiredInt(json, 'bookId'),
      characterName: _requiredString(json, 'characterName'),
      totalEvidenceTasks: _requiredInt(json, 'totalEvidenceTasks'),
      pipelineVersion: _optionalInt(json, 'pipelineVersion') ?? 1,
      sourceFingerprint: _optionalString(json, 'sourceFingerprint'),
      nextEvidenceIndex: _requiredInt(json, 'nextEvidenceIndex'),
      evidence: _requiredStringList(json, 'evidence'),
      nextMergeBatchIndex: _requiredInt(json, 'nextMergeBatchIndex'),
      mergedBatches: _requiredStringList(json, 'mergedBatches'),
      reductionRound: _optionalInt(json, 'reductionRound') ?? 0,
      reductionInput: _optionalStringList(json, 'reductionInput') ?? const [],
      nextReductionBatchIndex:
          _optionalInt(json, 'nextReductionBatchIndex') ?? 0,
      reducedEvidence: _optionalStringList(json, 'reducedEvidence') ?? const [],
      finalEvidenceText: _optionalString(json, 'finalEvidenceText'),
      finalDocument: _optionalString(json, 'finalDocument'),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
    );
    final validCounts = checkpoint.bookId > 0 &&
        checkpoint.characterName.trim().isNotEmpty &&
        checkpoint.pipelineVersion >= 1 &&
        checkpoint.pipelineVersion <= currentPipelineVersion &&
        (checkpoint.sourceFingerprint == null ||
            checkpoint.sourceFingerprint!.isNotEmpty &&
                checkpoint.sourceFingerprint!.length <= 128) &&
        checkpoint.totalEvidenceTasks > 0 &&
        checkpoint.nextEvidenceIndex >= 0 &&
        checkpoint.nextEvidenceIndex <= checkpoint.totalEvidenceTasks &&
        checkpoint.evidence.length == checkpoint.nextEvidenceIndex &&
        checkpoint.nextMergeBatchIndex >= 0 &&
        checkpoint.mergedBatches.length == checkpoint.nextMergeBatchIndex &&
        checkpoint.reductionRound >= 0 &&
        checkpoint.reductionRound <= 16 &&
        checkpoint.nextReductionBatchIndex >= 0 &&
        checkpoint.reducedEvidence.length ==
            checkpoint.nextReductionBatchIndex &&
        (checkpoint.reductionInput.isNotEmpty ||
            checkpoint.nextReductionBatchIndex == 0 &&
                checkpoint.reducedEvidence.isEmpty) &&
        (checkpoint.finalEvidenceText == null ||
            checkpoint.finalEvidenceText!.trim().isNotEmpty);
    if (!validCounts) {
      throw const FormatException('Invalid checkpoint progress.');
    }
    return checkpoint;
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Checkpoint field $key must be an integer.');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Checkpoint field $key must be an integer.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Checkpoint field $key must be a string.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Checkpoint field $key must be a string.');
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Checkpoint field $key must be a string list.');
  }
  return value.cast<String>();
}

List<String>? _optionalStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Checkpoint field $key must be a string list.');
  }
  return value.cast<String>();
}
