import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_provider.dart';

class TranslationSettings {
  final bool enabled;
  final String targetLanguage;

  const TranslationSettings({
    this.enabled = false,
    this.targetLanguage = '简体中文',
  });

  TranslationSettings copyWith({
    bool? enabled,
    String? targetLanguage,
  }) {
    return TranslationSettings(
      enabled: enabled ?? this.enabled,
      targetLanguage: targetLanguage ?? this.targetLanguage,
    );
  }
}

class TranslationSettingsNotifier extends Notifier<TranslationSettings> {
  static const enabledKey = 'onlineTranslationEnabled';
  static const targetLanguageKey = 'onlineTranslationTargetLanguage';

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  TranslationSettings build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return TranslationSettings(
      enabled: preferences.getBool(enabledKey) ?? false,
      targetLanguage: preferences.getString(targetLanguageKey) ?? '简体中文',
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await _preferences.setBool(enabledKey, enabled);
    state = state.copyWith(enabled: enabled);
  }

  Future<void> setTargetLanguage(String targetLanguage) async {
    await _preferences.setString(targetLanguageKey, targetLanguage);
    state = state.copyWith(targetLanguage: targetLanguage);
  }
}

final translationSettingsProvider =
    NotifierProvider<TranslationSettingsNotifier, TranslationSettings>(
  TranslationSettingsNotifier.new,
);
