import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/settings/restore_staged_dialog.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function() exitApp,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showRestoreStagedDialog(context, exitApp: exitApp),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('说清楚重启前的改动会被覆盖，并提供立即退出', (tester) async {
    var exits = 0;
    await _pump(tester, exitApp: () async => exits++);

    expect(find.text('备份已就绪'), findsOneWidget);
    expect(find.textContaining('会被备份覆盖'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restore-staged-exit')));
    await tester.pumpAndSettle();

    expect(exits, 1);
    expect(find.text('备份已就绪'), findsNothing);
  });

  testWidgets('选「稍后」只关掉对话框，不退出', (tester) async {
    var exits = 0;
    await _pump(tester, exitApp: () async => exits++);

    await tester.tap(find.byKey(const Key('restore-staged-later')));
    await tester.pumpAndSettle();

    expect(exits, 0);
    expect(find.text('备份已就绪'), findsNothing);
  });

  testWidgets('点遮罩关不掉：这条提示不能被误触带走', (tester) async {
    await _pump(tester, exitApp: () async {});

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('备份已就绪'), findsOneWidget);
  });
}
