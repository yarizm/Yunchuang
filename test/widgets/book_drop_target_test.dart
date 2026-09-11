import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/widgets/book_drop_target.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool enabled}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookDropTarget(
            enabledOverride: enabled,
            onDrop: (_) async {},
            child: const Text('书架'),
          ),
        ),
      ),
    );
  }

  testWidgets('桌面端包一层 DropTarget', (tester) async {
    await pump(tester, enabled: true);

    expect(find.byType(DropTarget), findsOneWidget);
    expect(find.text('书架'), findsOneWidget);
  });

  // 移动端系统层面就没有拖放到应用的概念，不该白白多一层 widget。
  testWidgets('非桌面端原样返回 child', (tester) async {
    await pump(tester, enabled: false);

    expect(find.byType(DropTarget), findsNothing);
    expect(find.text('书架'), findsOneWidget);
    // child 直接挂在 BookDropTarget 下，中间没有插入容器。
    expect(
      find.descendant(
        of: find.byType(BookDropTarget),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('未拖拽时不显示提示浮层', (tester) async {
    await pump(tester, enabled: true);

    expect(find.text('松开以导入'), findsNothing);
  });
}
