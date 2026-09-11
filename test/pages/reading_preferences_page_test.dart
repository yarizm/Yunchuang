import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/settings/reading_preferences.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('theme selector stays horizontal on a narrow phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(393, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          home: ReadingPreferencesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日间'), findsNothing);
    expect(find.text('护眼'), findsNothing);
    expect(find.text('夜间'), findsNothing);
    expect(find.text('跟随系统'), findsNothing);
    expect(find.byTooltip('日间主题'), findsOneWidget);
    expect(find.byTooltip('护眼主题'), findsOneWidget);
    expect(find.byTooltip('夜间主题'), findsOneWidget);
    expect(find.byTooltip('跟随系统'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
