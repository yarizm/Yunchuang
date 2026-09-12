import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/theme/glass_page_route.dart';
import 'package:yunchuang/widgets/app_background.dart';

void main() {
  Future<void> pumpAndPush(
    WidgetTester tester,
    GlassPageRoute<void> route,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    late BuildContext homeContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              homeContext = context;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      ),
    );
    Navigator.of(homeContext).push(route);
    await tester.pumpAndSettle();
  }

  // 以前这里铺一层 96% 不透明的 surface、路由不 opaque：全局背景被盖掉（「背景
  // 只有书架有」），下面那页还一直在画。现在每页自己画一层背景。
  testWidgets('推入的页面下面铺着全局背景，路由是 opaque 的', (tester) async {
    final route = GlassPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('pushed')),
    );
    await pumpAndPush(tester, route);

    expect(route.opaque, isTrue);
    expect(
      find.ancestor(
        of: find.text('pushed'),
        matching: find.byType(AppBackground),
      ),
      findsOneWidget,
    );
    // 底色来自当前主题，不是写死的。
    final base = find
        .descendant(
          of: find.byType(AppBackground),
          matching: find.byType(ColoredBox),
        )
        .first;
    expect(
      tester.widget<ColoredBox>(base).color,
      AppTheme.lightTheme.colorScheme.surface,
    );
    // 动画结束后下面那页不再参与绘制。
    expect(find.text('home', skipOffstage: true), findsNothing);
  });

  // 阅读器要把背景画在纸张主题里（底色是纸张色），路由就不能再铺一层。
  testWidgets('paintsOwnBackground 时路由不再铺背景', (tester) async {
    final route = GlassPageRoute<void>(
      paintsOwnBackground: true,
      builder: (_) => const Scaffold(body: Text('pushed')),
    );
    await pumpAndPush(tester, route);

    expect(
      find.ancestor(
        of: find.text('pushed'),
        matching: find.byType(AppBackground),
      ),
      findsNothing,
    );
  });
}
