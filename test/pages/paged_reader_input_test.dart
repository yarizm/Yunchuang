import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/paged_reader.dart';

/// 鼠标和键盘翻页。PageView 默认不接鼠标拖动、也不管纵向滚轮，Windows
/// 上只用鼠标原本翻不了页。
void main() {
  final content = List.filled(1200, '鼠标滚轮和键盘也要能翻页。').join();

  Future<void> pumpReader(
    WidgetTester tester, {
    String? text,
    VoidCallback? onAdvanceBeyondLast,
    VoidCallback? onRetreatBeforeFirst,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedReader(
            content: text ?? content,
            onAdvanceBeyondLast: onAdvanceBeyondLast,
            onRetreatBeforeFirst: onRetreatBeforeFirst,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int currentPage(WidgetTester tester) {
    final indicator = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));
    return int.parse(indicator.split('/').first.trim());
  }

  int pageCount(WidgetTester tester) {
    final indicator = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ / \d+$').hasMatch(text));
    return int.parse(indicator.split('/').last.trim());
  }

  Future<void> wheel(WidgetTester tester, double dy, {double dx = 0}) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final center = tester.getCenter(find.byType(PageView));
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(Offset(dx, dy)));
  }

  testWidgets('one mouse wheel notch turns one page each way', (tester) async {
    await pumpReader(tester);
    expect(currentPage(tester), 1);

    // Windows 默认一格滚轮是 100 像素。
    await wheel(tester, 100);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);

    await wheel(tester, 100);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 3);

    await wheel(tester, -100);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);
  });

  testWidgets('small wheel steps add up before turning a page', (tester) async {
    await pumpReader(tester);

    // 高精度滚轮把一格拆成几段：攒够了才翻，而且只翻一页。
    await wheel(tester, 12);
    await wheel(tester, 12);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);

    await wheel(tester, 12);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);

    // 反向滚一下不该先抵掉之前攒的距离再翻。
    await wheel(tester, 20);
    await wheel(tester, -30);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);
  });

  testWidgets('quick wheel notches keep turning from the page in flight',
      (tester) async {
    await pumpReader(tester);

    await wheel(tester, 100);
    await tester.pump(const Duration(milliseconds: 60));
    await wheel(tester, 100);
    await tester.pump(const Duration(milliseconds: 60));
    await wheel(tester, 100);
    await tester.pumpAndSettle();

    expect(currentPage(tester), 4);
    // 停稳之后没有页还卷着。
    expect(find.byKey(const ValueKey('page_curl_overlay')), findsNothing);
  });

  testWidgets('horizontal scrolling is left to the page view', (tester) async {
    await pumpReader(tester);

    await wheel(tester, 0, dx: 100);
    await tester.pumpAndSettle();
    // 横向一小段由 PageView 按距离处理，吸附回原页；不会被当成一格滚轮翻页。
    expect(currentPage(tester), 1);
  });

  testWidgets('wheel past either end of the chapter asks to change chapter',
      (tester) async {
    var advanced = 0;
    var retreated = 0;
    await pumpReader(
      tester,
      onAdvanceBeyondLast: () => advanced++,
      onRetreatBeforeFirst: () => retreated++,
    );

    // 换章请求和手指拖过头一样，隔一小段时间才发出。
    await wheel(tester, -100);
    await tester.pump(const Duration(milliseconds: 300));
    expect(retreated, 1);

    final lastPage = pageCount(tester) - 1;
    tester
        .widget<PageView>(find.byType(PageView))
        .controller!
        .jumpToPage(lastPage);
    await tester.pumpAndSettle();

    await wheel(tester, 100);
    await tester.pump(const Duration(milliseconds: 300));
    expect(advanced, 1);
    expect(currentPage(tester), lastPage + 1);
  });

  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  testWidgets('page keys and arrows turn pages', variant: windows,
      (tester) async {
    await pumpReader(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 4);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);
  });

  testWidgets('arrow keys still turn pages after clicking into the text',
      variant: windows, (tester) async {
    await pumpReader(tester);

    // 点过正文以后焦点在那一页的 SelectableText 上；方向键要先冒泡到翻页这
    // 一层，不能被文字编辑快捷键拿去挪光标。
    await tester.tap(find.byType(SelectableText).first);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>(),
      isNotNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);
  });

  testWidgets('shift + arrow keeps extending the selection instead',
      variant: windows, (tester) async {
    await pumpReader(tester);

    await tester.tap(find.byType(SelectableText).first);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();

    expect(currentPage(tester), 1);
  });
}
