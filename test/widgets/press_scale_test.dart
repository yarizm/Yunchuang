import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/theme/app_motion.dart';
import 'package:yunchuang/widgets/press_scale.dart';

void main() {
  var taps = 0;
  var longPresses = 0;

  Widget host({required bool motion}) {
    return MaterialApp(
      builder: (context, child) => AppMotion(enabled: motion, child: child!),
      home: Scaffold(
        body: ListView(
          children: [
            const SizedBox(height: 200),
            PressScale(
              child: Material(
                child: InkWell(
                  onTap: () => taps++,
                  onLongPress: () => longPresses++,
                  child: const SizedBox(
                    height: 120,
                    child: Center(child: Text('card')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
  }

  double scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  setUp(() {
    taps = 0;
    longPresses = 0;
  });

  testWidgets('按下缩小、松手回弹，点击照常触发', (tester) async {
    await tester.pumpWidget(host(motion: true));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump();
    expect(scaleOf(tester), lessThan(1));

    await gesture.up();
    await tester.pump();
    expect(scaleOf(tester), 1);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('长按多选不受影响', (tester) async {
    await tester.pumpWidget(host(motion: true));
    await tester.longPress(find.text('card'));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(scaleOf(tester), 1);
  });

  testWidgets('手指一滑就当作滚动，卡片立刻弹回', (tester) async {
    await tester.pumpWidget(host(motion: true));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump();
    expect(scaleOf(tester), lessThan(1));

    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(scaleOf(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('界面动画关着时按下不缩', (tester) async {
    await tester.pumpWidget(host(motion: false));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump();
    expect(scaleOf(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
