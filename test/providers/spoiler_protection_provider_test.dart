import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/ai/agent_models.dart';
import 'package:yunchuang/providers/ai/spoiler_protection_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to strict and persists global and per-book settings',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );

    expect(
      container.read(spoilerProtectionProvider).defaultLevel,
      SpoilerProtectionLevel.strict,
    );
    expect(
      container.read(spoilerProtectionProvider).levelFor(7),
      SpoilerProtectionLevel.strict,
    );

    final notifier = container.read(spoilerProtectionProvider.notifier);
    notifier.updateDefaultLevel(SpoilerProtectionLevel.ask);
    notifier.updateBookLevel(7, SpoilerProtectionLevel.fullBook);
    await Future<void>.delayed(Duration.zero);
    container.dispose();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final restored = container.read(spoilerProtectionProvider);

    expect(restored.defaultLevel, SpoilerProtectionLevel.ask);
    expect(restored.overrideFor(7), SpoilerProtectionLevel.fullBook);
    expect(restored.levelFor(8), SpoilerProtectionLevel.ask);

    container.read(spoilerProtectionProvider.notifier).updateBookLevel(7, null);
    expect(
      container.read(spoilerProtectionProvider).levelFor(7),
      SpoilerProtectionLevel.ask,
    );
  });

  test('ignores corrupt per-book settings', () async {
    SharedPreferences.setMockInitialValues({
      SpoilerProtectionNotifier.defaultLevelKey: 'unknown',
      SpoilerProtectionNotifier.bookOverridesKey:
          '{"7":"fullBook","bad":"ask","8":"unknown"}',
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    final settings = container.read(spoilerProtectionProvider);
    expect(settings.defaultLevel, SpoilerProtectionLevel.strict);
    expect(settings.bookOverrides, {
      7: SpoilerProtectionLevel.fullBook,
    });
  });
}
