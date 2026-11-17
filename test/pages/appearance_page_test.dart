import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/pages/settings/appearance_page.dart';
import 'package:yunchuang/providers/preferences_provider.dart';

void main() {
  testWidgets('外观页可以关掉界面动画', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: AppearancePage()),
      ),
    );

    final toggle = find.widgetWithText(SwitchListTile, '界面动画');
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(preferences.getBool('enhancedAnimations'), isFalse);
  });

  testWidgets('系统移除了动画时说明开关暂不生效', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const AppearancePage(),
        ),
      ),
    );

    expect(find.text('系统已开启「移除动画」，这里暂不生效'), findsOneWidget);
  });
}
