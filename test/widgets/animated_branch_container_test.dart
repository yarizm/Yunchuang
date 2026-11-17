import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/theme/app_motion.dart';
import 'package:yunchuang/widgets/animated_branch_container.dart';

void main() {
  Widget host({required bool motion, required int index}) {
    return MaterialApp(
      builder: (context, child) => AppMotion(enabled: motion, child: child!),
      home: AnimatedBranchContainer(
        currentIndex: index,
        children: const [_Branch('A'), _Branch('B')],
      ),
    );
  }

  double opacityOf(WidgetTester tester, String label) {
    final fade = find.ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(FadeTransition),
    );
    return tester.widget<FadeTransition>(fade.first).opacity.value;
  }

  setUp(_Branch.created.clear);

  testWidgets('界面动画开着时切 Tab 先淡出旧页再淡入新页，状态都留着', (tester) async {
    await tester.pumpWidget(host(motion: true, index: 0));
    await tester.pumpWidget(host(motion: true, index: 1));

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('A'), findsOneWidget, reason: '旧页淡出时还在画');
    expect(opacityOf(tester, 'A'), inExclusiveRange(0, 1));
    expect(opacityOf(tester, 'B'), 0, reason: '新页等旧页淡出后才开始淡入');

    await tester.pump(const Duration(milliseconds: 120));
    expect(opacityOf(tester, 'A'), 0);
    expect(opacityOf(tester, 'B'), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: '动画结束后旧页不再绘制');
    expect(find.text('A', skipOffstage: false), findsOneWidget);
    expect(opacityOf(tester, 'B'), 1);

    await tester.pumpWidget(host(motion: true, index: 0));
    await tester.pumpAndSettle();
    expect(_Branch.created, {'A': 1, 'B': 1});
  });

  testWidgets('界面动画关着时和 IndexedStack 一样直接切过去', (tester) async {
    await tester.pumpWidget(host(motion: false, index: 0));
    await tester.pumpWidget(host(motion: false, index: 1));

    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(opacityOf(tester, 'B'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

class _Branch extends StatefulWidget {
  final String label;

  const _Branch(this.label);

  static final created = <String, int>{};

  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> {
  @override
  void initState() {
    super.initState();
    _Branch.created.update(widget.label, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => Center(child: Text(widget.label));
}
