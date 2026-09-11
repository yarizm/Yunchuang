import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/preferences_provider.dart';

final ttsPlaybackCheckpointStoreProvider =
    Provider<TtsPlaybackCheckpointStore>((ref) {
  return TtsPlaybackCheckpointStore(ref.watch(sharedPreferencesProvider));
});

@immutable
class TtsPlaybackCheckpoint {
  final int bookId;
  final int chapterId;
  final int characterOffset;
  final DateTime updatedAt;

  const TtsPlaybackCheckpoint({
    required this.bookId,
    required this.chapterId,
    required this.characterOffset,
    required this.updatedAt,
  });

  factory TtsPlaybackCheckpoint.fromJson(Map<String, dynamic> json) {
    final bookId = json['bookId'];
    final chapterId = json['chapterId'];
    final characterOffset = json['characterOffset'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (bookId is! int ||
        bookId <= 0 ||
        chapterId is! int ||
        chapterId <= 0 ||
        characterOffset is! int ||
        characterOffset < 0 ||
        updatedAt == null) {
      throw const FormatException('Invalid TTS playback checkpoint.');
    }
    return TtsPlaybackCheckpoint(
      bookId: bookId,
      chapterId: chapterId,
      characterOffset: characterOffset,
      updatedAt: updatedAt.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'bookId': bookId,
        'chapterId': chapterId,
        'characterOffset': characterOffset,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

class TtsPlaybackCheckpointStore {
  static const storageKey = 'ttsPlaybackCheckpointV1';
  static const retention = Duration(days: 14);

  final SharedPreferences _preferences;

  TtsPlaybackCheckpointStore(this._preferences);

  Future<void> save(TtsPlaybackCheckpoint checkpoint) async {
    await _preferences.setString(
      storageKey,
      jsonEncode(checkpoint.toJson()),
    );
  }

  Future<TtsPlaybackCheckpoint?> load({DateTime? now}) async {
    final encoded = _preferences.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw const FormatException('Checkpoint must be a JSON object.');
      }
      final checkpoint = TtsPlaybackCheckpoint.fromJson(
        decoded.cast<String, dynamic>(),
      );
      final effectiveNow = (now ?? DateTime.now()).toUtc();
      if (effectiveNow.difference(checkpoint.updatedAt) > retention) {
        await clear();
        return null;
      }
      return checkpoint;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await _preferences.remove(storageKey);
  }

  Future<void> clearForBook(int bookId) async {
    final checkpoint = await load();
    if (checkpoint?.bookId == bookId) {
      await clear();
    }
  }
}
