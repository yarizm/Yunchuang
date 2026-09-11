import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/settings/settings_page.dart';
import 'package:yunchuang/providers/ai/spoiler_protection_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/widgets/glass_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('uses a stable settings surface without real-time blur',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsPage()),
      ),
    );

    final surface = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(surface.stable, isTrue);
    expect(surface.blur, 0);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();

    final afterScroll =
        tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(afterScroll.stable, isTrue);
    expect(afterScroll.blur, 0);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('opens AI asset management directly from settings',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsPage()),
      ),
    );

    expect(find.text('AI 扩展'), findsOneWidget);
    expect(find.text('管理 Skill、人格与导入导出'), findsOneWidget);

    await tester.tap(find.text('AI 扩展'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('AI 扩展'), findsWidgets);
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('人格'), findsOneWidget);
  });

  testWidgets('shows the vocabulary management entry', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsPage()),
      ),
    );

    expect(find.text('生词本'), findsOneWidget);
    expect(find.text('管理查词记录与导出'), findsOneWidget);
    expect(find.text('离线词典'), findsOneWidget);
    expect(find.text('导入与管理 StarDict'), findsOneWidget);
    expect(find.text('在线翻译'), findsOneWidget);
    expect(find.text('默认关闭，使用 AI Provider'), findsOneWidget);
  });

  testWidgets('opens AI reading safety and updates the global default',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );

    await tester.tap(find.text('AI 阅读安全'));
    await tester.pumpAndSettle();

    expect(find.text('严格防剧透'), findsOneWidget);
    expect(find.text('访问前询问'), findsOneWidget);
    expect(find.text('允许全书'), findsOneWidget);

    await tester.tap(find.text('允许全书'));
    await tester.pump();

    expect(
      preferences.getString(SpoilerProtectionNotifier.defaultLevelKey),
      'fullBook',
    );
  });
}
