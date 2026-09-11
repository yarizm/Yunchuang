import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/reading_background.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/widgets/reader_paper_picker.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ReaderPaper selected,
    Color? lastCustomColor,
    required ValueChanged<ReaderPaper> onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReaderPaperPicker(
              selected: selected,
              lastCustomColor: lastCustomColor,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  /// 「自定义」那张色卡当前显示的颜色。
  Color customSwatchColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('自'),
            matching: find.byType(Container),
          )
          .first,
    );
    return ((container.decoration as BoxDecoration).color)!;
  }

  testWidgets('点预设色卡会把那张纸报上去', (tester) async {
    ReaderPaper? picked;
    await pump(
      tester,
      selected: ReaderPaper.followTheme,
      onChanged: (paper) => picked = paper,
    );

    await tester.tap(find.text('豆绿'));
    await tester.pumpAndSettle();

    expect(picked?.id, 'eyecare');
  });

  // 偏好里那个 ARGB 是故意留着的（见 PreferencesNotifier.updateReaderPaper），
  // 让用户切去预设再切回来还能拿到原来的颜色。选择器只看 selected 的话就取
  // 不到它——selected 是预设时不带自定义色。
  testWidgets('选中预设时，自定义色卡仍显示上次用过的颜色', (tester) async {
    const remembered = Color(0xFF3A5F4B);
    await pump(
      tester,
      selected: ReaderPaper.presetById('rice')!,
      lastCustomColor: remembered,
      onChanged: (_) {},
    );

    expect(customSwatchColor(tester), remembered);
  });

  testWidgets('自定义取色盘从上次用过的颜色开始', (tester) async {
    const remembered = Color(0xFF3A5F4B);
    await pump(
      tester,
      selected: ReaderPaper.presetById('rice')!,
      lastCustomColor: remembered,
      onChanged: (_) {},
    );

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();

    // 弹层里的预览块用的就是初始色。
    final preview = tester.widget<Container>(
      find
          .ancestor(
            of: find.textContaining('芸香草'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((preview.decoration as BoxDecoration).color, remembered);
  });

  testWidgets('从来没设过自定义色时退回主题底色', (tester) async {
    await pump(
      tester,
      selected: ReaderPaper.followTheme,
      onChanged: (_) {},
    );

    expect(
      customSwatchColor(tester),
      AppTheme.lightTheme.colorScheme.surface,
    );
  });

  testWidgets('当前就是自定义时，以当前色为准而不是上次那个', (tester) async {
    const current = Color(0xFF8B2F3A);
    const stale = Color(0xFF3A5F4B);
    await pump(
      tester,
      selected: ReaderPaper.custom(current),
      lastCustomColor: stale,
      onChanged: (_) {},
    );

    expect(customSwatchColor(tester), current);
  });
}
