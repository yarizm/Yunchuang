import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences_provider.dart';
import 'agent_models.dart';

class SpoilerProtectionSettings {
  final SpoilerProtectionLevel defaultLevel;
  final Map<int, SpoilerProtectionLevel> bookOverrides;

  const SpoilerProtectionSettings({
    this.defaultLevel = SpoilerProtectionLevel.strict,
    this.bookOverrides = const {},
  });

  SpoilerProtectionLevel levelFor(int? bookId) {
    if (bookId == null) return defaultLevel;
    return bookOverrides[bookId] ?? defaultLevel;
  }

  SpoilerProtectionLevel? overrideFor(int bookId) => bookOverrides[bookId];

  SpoilerProtectionSettings copyWith({
    SpoilerProtectionLevel? defaultLevel,
    Map<int, SpoilerProtectionLevel>? bookOverrides,
  }) {
    return SpoilerProtectionSettings(
      defaultLevel: defaultLevel ?? this.defaultLevel,
      bookOverrides: bookOverrides ?? this.bookOverrides,
    );
  }
}

class SpoilerProtectionNotifier extends Notifier<SpoilerProtectionSettings> {
  static const defaultLevelKey = 'aiSpoilerProtectionDefault';
  static const bookOverridesKey = 'aiSpoilerProtectionBookOverrides';

  @override
  SpoilerProtectionSettings build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return SpoilerProtectionSettings(
      defaultLevel: SpoilerProtectionLevel.fromWireName(
        preferences.getString(defaultLevelKey),
      ),
      bookOverrides: _decodeOverrides(
        preferences.getString(bookOverridesKey),
      ),
    );
  }

  void updateDefaultLevel(SpoilerProtectionLevel level) {
    state = state.copyWith(defaultLevel: level);
    ref
        .read(sharedPreferencesProvider)
        .setString(defaultLevelKey, level.wireName);
  }

  void updateBookLevel(int bookId, SpoilerProtectionLevel? level) {
    final updated = Map<int, SpoilerProtectionLevel>.of(state.bookOverrides);
    if (level == null) {
      updated.remove(bookId);
    } else {
      updated[bookId] = level;
    }
    state = state.copyWith(bookOverrides: Map.unmodifiable(updated));
    ref.read(sharedPreferencesProvider).setString(
          bookOverridesKey,
          jsonEncode({
            for (final entry in updated.entries)
              entry.key.toString(): entry.value.wireName,
          }),
        );
  }

  Map<int, SpoilerProtectionLevel> _decodeOverrides(String? value) {
    if (value == null || value.isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return const {};
      final result = <int, SpoilerProtectionLevel>{};
      for (final entry in decoded.entries) {
        final bookId = int.tryParse(entry.key.toString());
        if (bookId == null || bookId <= 0 || entry.value is! String) continue;
        final level = SpoilerProtectionLevel.values
            .where((item) => item.wireName == entry.value)
            .firstOrNull;
        if (level != null) result[bookId] = level;
      }
      return Map.unmodifiable(result);
    } catch (_) {
      return const {};
    }
  }
}

final spoilerProtectionProvider =
    NotifierProvider<SpoilerProtectionNotifier, SpoilerProtectionSettings>(
  SpoilerProtectionNotifier.new,
);
