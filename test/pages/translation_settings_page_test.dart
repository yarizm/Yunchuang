import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/settings/translation_settings_page.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/providers/translation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('requires privacy confirmation and persists translation settings',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: TranslationSettingsPage()),
      ),
    );

    await tester.tap(find.byKey(const Key('online-translation-switch')));
    await tester.pumpAndSettle();
    expect(find.text('启用在线翻译？'), findsOneWidget);
    expect(find.textContaining('选中的书籍文本才会发送'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(preferences.getBool(TranslationSettingsNotifier.enabledKey), isNull);

    await tester.tap(find.byKey(const Key('online-translation-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-enable-translation')));
    await tester.pumpAndSettle();
    expect(
      preferences.getBool(TranslationSettingsNotifier.enabledKey),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('translation-target-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文').last);
    await tester.pumpAndSettle();
    expect(
      preferences.getString(TranslationSettingsNotifier.targetLanguageKey),
      '繁體中文',
    );
  });
}
