import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/app.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the real empty shelf', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.connect(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ReadingOfflineApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('还没有书'), findsOneWidget);
    expect(find.text('书架'), findsOneWidget);

    // 背景挂在 MaterialApp.builder 里才拿得到主题。挂错位置（比如包在
    // MaterialApp 外面）时 Theme.of 只能给出兜底主题，底色就不是这个值——
    // 这条断言钉住的是接线位置，不是 AppBackground 自己的逻辑。
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .any((box) => box.color == AppTheme.lightTheme.colorScheme.surface),
      isTrue,
      reason: '全局背景没有取到日间主题的 surface',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
  });
}
