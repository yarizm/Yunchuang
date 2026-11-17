import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:yunchuang/theme/app_motion.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/theme/glass_page_route.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late ValueNotifier<bool> motion;

  Future<void> pumpHost(
    WidgetTester tester, {
    required bool enabled,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    navigatorKey = GlobalKey<NavigatorState>();
    motion = ValueNotifier(enabled);
    addTearDown(motion.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: motion,
              builder: (context, enabled, child) =>
                  AppMotion(enabled: enabled, child: child!),
              child: child,
            ),
          ),
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
  }

  /// 转场那一层：Opacity → ClipRRect → Transform。
  Finder transitionOf(String text) => find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Opacity &&
              widget.child is ClipRRect &&
              (widget.child! as ClipRRect).child is Transform,
        ),
      );

  ({double opacity, double scale, double dy, RRect? clip}) frameOf(
    WidgetTester tester,
    String text,
  ) {
    final opacity = tester.widget<Opacity>(transitionOf(text).first);
    final clip = opacity.child! as ClipRRect;
    final transform = clip.child! as Transform;
    return (
      opacity: opacity.opacity,
      // x 方向的缩放。getMaxScaleOnAxis 会把 z 轴的 1 也算进去。
      scale: transform.transform.storage[0],
      dy: transform.transform.storage[13],
      clip: clip.clipBehavior == Clip.none
          ? null
          : clip.clipper!.getClip(const Size(800, 600)),
    );
  }

  GlassPageRoute<void> pageRoute({Rect? expandFrom}) => GlassPageRoute<void>(
        expandFrom: expandFrom,
        builder: (_) => const _CountedPage(),
      );

  setUp(() => _CountedPage.created = 0);

  testWidgets('找不到 AppMotion 或系统移除了动画时按关闭算', (tester) async {
    late bool withoutScope;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            withoutScope = AppMotion.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(withoutScope, isFalse);

    await pumpHost(tester, enabled: true, disableAnimations: true);
    final context = tester.element(find.text('home'));
    expect(AppMotion.of(context), isFalse);
    expect(AppMotion.peek(context), isFalse);
  });

  testWidgets('界面动画开着时页面从下方升起淡入，停稳后不留变换', (tester) async {
    await pumpHost(tester, enabled: true);
    final route = pageRoute();
    navigatorKey.currentState!.push(route);
    await tester.pump();
    expect(route.transitionDuration, AppMotion.pageEnter);

    await tester.pump(const Duration(milliseconds: 150));
    final middle = frameOf(tester, 'page');
    expect(middle.opacity, inExclusiveRange(0, 1));
    expect(middle.dy, inExclusiveRange(0, 28));
    // 不缩放：缩放会让整页的字每帧重新光栅化。
    expect(middle.scale, 1);
    expect(middle.clip, isNull);

    await tester.pumpAndSettle();
    final settled = frameOf(tester, 'page');
    expect(settled.opacity, 1);
    expect(settled.dy, 0);
    expect(settled.scale, 1);
    expect(settled.clip, isNull);
  });

  testWidgets('界面动画关着时还是原来的淡入', (tester) async {
    await pumpHost(tester, enabled: false);
    final route = pageRoute(expandFrom: const Rect.fromLTWH(40, 60, 160, 260));
    navigatorKey.currentState!.push(route);
    await tester.pump();
    expect(route.transitionDuration, const Duration(milliseconds: 300));

    await tester.pump(const Duration(milliseconds: 150));
    final middle = frameOf(tester, 'page');
    expect(middle.opacity, closeTo(0.5, 0.05));
    expect(middle.scale, 1);
    expect(middle.dy, 0);
    expect(middle.clip, isNull);
  });

  testWidgets('系统开了移除动画时不放大', (tester) async {
    await pumpHost(tester, enabled: true, disableAnimations: true);
    final route = pageRoute();
    navigatorKey.currentState!.push(route);
    await tester.pump();
    expect(route.transitionDuration, const Duration(milliseconds: 300));
  });

  // 开关就在一个推入的页面（外观）上。转场结构要是跟着开关变，拨一下
  // 那一页就被卸载重建。
  testWidgets('打开的页面上拨动开关，页面不会重建', (tester) async {
    await pumpHost(tester, enabled: true);
    final route = pageRoute();
    navigatorKey.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(_CountedPage.created, 1);

    motion.value = false;
    await tester.pump();
    expect(_CountedPage.created, 1);
    // 转场在推入时定下：退出仍按开着时的样子走。
    expect(route.reverseTransitionDuration, AppMotion.pageExit);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('page'), findsNothing);
    expect(_CountedPage.created, 1);
  });

  testWidgets('打开书从卡片展开，没展开完就返回时缩回卡片', (tester) async {
    await pumpHost(tester, enabled: true);
    const origin = Rect.fromLTWH(40, 60, 160, 260);
    final route = pageRoute(expandFrom: origin);
    navigatorKey.currentState!.push(route);
    await tester.pump();
    expect(route.transitionDuration, AppMotion.bookOpen);

    await tester.pump(const Duration(milliseconds: 16));
    expect(frameOf(tester, 'page').scale, 1, reason: '页面不缩放，只张开裁剪框');
    expect(
      frameOf(tester, 'page').opacity,
      lessThan(0.02),
      reason: '先张开纸，正文等纸快铺满再淡入',
    );
    final start = frameOf(tester, 'page').clip!.outerRect;
    expect((start.center - origin.center).distance, lessThan(12));
    expect(start.width, lessThan(origin.width + 20));

    await tester.pump(const Duration(milliseconds: 200));
    final halfway = frameOf(tester, 'page').clip!.outerRect;
    expect(halfway.width, greaterThan(start.width));
    // 纸盖严之后页面就是不透明的：放进透明度图层要整页离屏重画。
    expect(frameOf(tester, 'page').opacity, 1);

    navigatorKey.currentState!.pop();
    await tester.pump();
    // 从一半倒回去只要一半的退出时长，取早一点的帧。
    await tester.pump(const Duration(milliseconds: 50));
    final back = frameOf(tester, 'page').clip!.outerRect;
    expect(back.width, lessThan(halfway.width));
    expect(
      (back.center - origin.center).distance,
      lessThan((halfway.center - origin.center).distance),
    );
    await tester.pumpAndSettle();
    expect(find.text('page'), findsNothing);
  });

  testWidgets('展开播完之后返回时原地沉下淡出，不再缩回卡片', (tester) async {
    await pumpHost(tester, enabled: true);
    final route = pageRoute(expandFrom: const Rect.fromLTWH(40, 60, 160, 260));
    navigatorKey.currentState!.push(route);
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final frame = frameOf(tester, 'page');
    expect(frame.clip, isNull);
    expect(frame.dy, greaterThan(0));
    expect(frame.scale, 1);
    expect(frame.opacity, inExclusiveRange(0, 1));
  });
}

class _CountedPage extends StatefulWidget {
  const _CountedPage();

  static int created = 0;

  @override
  State<_CountedPage> createState() => _CountedPageState();
}

class _CountedPageState extends State<_CountedPage> {
  @override
  void initState() {
    super.initState();
    _CountedPage.created++;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('page')));
  }
}
