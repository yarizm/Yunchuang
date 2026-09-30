import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/widgets/ai_chat/spoiler_choice_tile.dart';

void main() {
  testWidgets('选中的档位带勾和加粗标题，点击回调生效', (tester) async {
    var tapped = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SpoilerChoiceTile(
                selected: true,
                icon: Icons.check,
                title: '严格防剧透',
                subtitle: '只读已读内容',
                onTap: () => tapped = 'strict',
              ),
              SpoilerChoiceTile(
                selected: false,
                icon: Icons.warning_amber,
                title: '允许全书',
                onTap: () => tapped = 'full',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('严格防剧透')).style?.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('允许全书')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(find.text('只读已读内容'), findsOneWidget);

    await tester.tap(find.text('允许全书'));
    expect(tapped, 'full');
  });
}
