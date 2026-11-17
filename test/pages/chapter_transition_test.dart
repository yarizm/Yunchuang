import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/chapter_transition.dart';
import 'package:yunchuang/theme/app_motion.dart';

void main() {
  Widget host({
    required bool motion,
    required String chapter,
    double direction = 1,
  }) {
    return MaterialApp(
      builder: (context, child) => AppMotion(enabled: motion, child: child!),
      home: ChapterTransition(
        chapterKey: ValueKey(chapter),
        direction: direction,
        child: Center(child: Text(chapter)),
      ),
    );
  }

  double? opacityOf(WidgetTester tester, String chapter) {
    final fade = find.ancestor(
      of: find.text(chapter),
      matching: find.byType(FadeTransition),
    );
    if (fade.evaluate().isEmpty) return null;
    return tester.widget<FadeTransition>(fade.first).opacity.value;
  }

  // 翻页模式的页面不铺底色。两章要是同时以较高的不透明度叠着画，字会糊在
  // 一起：之前旧章停在 0.9、新章从 0.96 起，换章那 0.4 秒两层字全叠着。
  testWidgets('换章时旧章先淡出、新章再淡入，两章的字不会同时看得清', (tester) async {
    await tester.pumpWidget(host(motion: true, chapter: '第一章'));
    await tester.pumpWidget(host(motion: true, chapter: '第二章'));

    var sawOld = false;
    var sawNew = false;
    for (var elapsed = 0; elapsed <= 400; elapsed += 10) {
      await tester.pump(const Duration(milliseconds: 10));
      final previous = opacityOf(tester, '第一章');
      final next = opacityOf(tester, '第二章')!;
      if (previous != null && previous > 0) sawOld = true;
      if (next > 0) sawNew = true;
      if (previous != null) {
        expect(
          previous < 0.2 || next < 0.2,
          isTrue,
          reason: '${elapsed}ms 时旧章 $previous、新章 $next',
        );
      }
    }
    expect(sawOld && sawNew, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('第一章'), findsNothing);
    expect(opacityOf(tester, '第二章'), 1);
  });

  testWidgets('往后翻时新章从右边滑进来，往前翻从左边', (tester) async {
    Future<double> slideAtStart(double direction) async {
      await tester.pumpWidget(host(motion: true, chapter: 'a'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        host(motion: true, chapter: 'b$direction', direction: direction),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final slide = tester.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('b$direction'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      final dx = slide.position.value.dx;
      await tester.pumpAndSettle();
      return dx;
    }

    expect(await slideAtStart(1), greaterThan(0));
    expect(await slideAtStart(-1), lessThan(0));
  });

  testWidgets('界面动画关着时直接换章', (tester) async {
    await tester.pumpWidget(host(motion: false, chapter: '第一章'));
    await tester.pumpWidget(host(motion: false, chapter: '第二章'));

    expect(find.text('第一章'), findsNothing);
    expect(opacityOf(tester, '第二章'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
