import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'character_persona_checkpoint.dart';

class CharacterPersonaCheckpointStore {
  static const retention = Duration(days: 30);
  static const maxCheckpointChars = 8 * 1024 * 1024;

  final Future<Directory> Function() _directoryProvider;

  CharacterPersonaCheckpointStore({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory;

  Future<void> save(CharacterPersonaGenerationCheckpoint checkpoint) async {
    final directory = await _ensureDirectory();
    final target = _checkpointFile(directory, checkpoint.bookId);
    final temporary = File('${target.path}.tmp');
    final encoded = jsonEncode(checkpoint.toJson());
    if (encoded.length > maxCheckpointChars) {
      throw const FileSystemException('角色人格生成检查点过大，无法保存。');
    }
    await temporary.writeAsString(encoded, flush: true);
    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
    }
  }

  Future<CharacterPersonaGenerationCheckpoint?> loadForBook(
    int bookId, {
    DateTime? now,
  }) async {
    final directory = await _ensureDirectory();
    final file = _checkpointFile(directory, bookId);
    if (!await file.exists()) return null;
    try {
      final encoded = await file.readAsString();
      if (encoded.length > maxCheckpointChars) {
        throw const FormatException('Checkpoint is too large.');
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw const FormatException('Checkpoint must be a JSON object.');
      }
      final checkpoint = CharacterPersonaGenerationCheckpoint.fromJson(
        decoded.cast<String, dynamic>(),
      );
      if (checkpoint.bookId != bookId || _isExpired(checkpoint, now)) {
        await file.delete();
        return null;
      }
      return checkpoint;
    } catch (_) {
      if (await file.exists()) await file.delete();
      return null;
    }
  }

  Future<void> deleteForBook(int bookId) async {
    final directory = await _ensureDirectory();
    final file = _checkpointFile(directory, bookId);
    final temporary = File('${file.path}.tmp');
    if (await file.exists()) await file.delete();
    if (await temporary.exists()) await temporary.delete();
  }

  Future<int> cleanupExpired({DateTime? now}) async {
    final directory = await _ensureDirectory();
    var deleted = 0;
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final match = RegExp(r'book_(\d+)\.json$').firstMatch(entity.path);
      if (match == null) {
        await entity.delete();
        deleted++;
        continue;
      }
      final bookId = int.parse(match.group(1)!);
      final checkpoint = await loadForBook(bookId, now: now);
      if (checkpoint == null) deleted++;
    }
    return deleted;
  }

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'ai_persona_checkpoints'));
  }

  Future<Directory> _ensureDirectory() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  File _checkpointFile(Directory directory, int bookId) {
    return File(p.join(directory.path, 'book_$bookId.json'));
  }

  bool _isExpired(
    CharacterPersonaGenerationCheckpoint checkpoint,
    DateTime? now,
  ) {
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    return effectiveNow.difference(checkpoint.updatedAt.toUtc()) > retention;
  }
}
