import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/painting.dart' show Color;

import '../models/reading_background.dart';
import '../models/reading_defaults.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class ReadingPreferences {
  final double fontSize;
  final double lineHeight;
  final String theme;
  final bool keepScreenOn;
  final String preferredOrientation;
  final double readingBrightness;
  final bool brightnessGestureEnabled;
  final bool lineFocusEnabled;
  final int lineFocusLineCount;
  final double lineFocusDimAmount;
  final double pdfCropAmount;
  final double pdfContrast;
  final String pdfPageLayout;
  final double margin;
  final String? fontFamily;
  final double paragraphSpacing;
  final double letterSpacing;
  final double wordSpacing;
  final bool boldText;
  final String textAlignment;
  final int paragraphIndent;
  final String pageTurnEffect;
  final double topContentPadding;
  final String appBackgroundStyle;
  final String? customBackgroundPath;
  final double backgroundIntensity;
  final String readerPaperId;
  final int? readerPaperColor;

  const ReadingPreferences({
    this.fontSize = ReadingDefaults.fontSize,
    this.lineHeight = ReadingDefaults.lineHeight,
    this.theme = ReadingDefaults.theme,
    this.keepScreenOn = ReadingDefaults.keepScreenOn,
    this.preferredOrientation = ReadingDefaults.preferredOrientation,
    this.readingBrightness = ReadingDefaults.readingBrightness,
    this.brightnessGestureEnabled = ReadingDefaults.brightnessGestureEnabled,
    this.lineFocusEnabled = ReadingDefaults.lineFocusEnabled,
    this.lineFocusLineCount = ReadingDefaults.lineFocusLineCount,
    this.lineFocusDimAmount = ReadingDefaults.lineFocusDimAmount,
    this.pdfCropAmount = ReadingDefaults.pdfCropAmount,
    this.pdfContrast = ReadingDefaults.pdfContrast,
    this.pdfPageLayout = ReadingDefaults.pdfPageLayout,
    this.margin = ReadingDefaults.margin,
    this.fontFamily = ReadingDefaults.fontFamily,
    this.paragraphSpacing = ReadingDefaults.paragraphSpacing,
    this.letterSpacing = ReadingDefaults.letterSpacing,
    this.wordSpacing = ReadingDefaults.wordSpacing,
    this.boldText = ReadingDefaults.boldText,
    this.textAlignment = ReadingDefaults.textAlignment,
    this.paragraphIndent = ReadingDefaults.paragraphIndent,
    this.pageTurnEffect = ReadingDefaults.pageTurnEffect,
    this.topContentPadding = ReadingDefaults.topContentPadding,
    this.appBackgroundStyle = ReadingDefaults.appBackgroundStyle,
    this.customBackgroundPath = ReadingDefaults.customBackgroundPath,
    this.backgroundIntensity = ReadingDefaults.backgroundIntensity,
    this.readerPaperId = ReadingDefaults.readerPaperId,
    this.readerPaperColor = ReadingDefaults.readerPaperColor,
  });

  ReadingPreferences copyWith({
    double? fontSize,
    double? lineHeight,
    String? theme,
    bool? keepScreenOn,
    String? preferredOrientation,
    double? readingBrightness,
    bool? brightnessGestureEnabled,
    bool? lineFocusEnabled,
    int? lineFocusLineCount,
    double? lineFocusDimAmount,
    double? pdfCropAmount,
    double? pdfContrast,
    String? pdfPageLayout,
    double? margin,
    String? fontFamily,
    bool clearFontFamily = false,
    double? paragraphSpacing,
    double? letterSpacing,
    double? wordSpacing,
    bool? boldText,
    String? textAlignment,
    int? paragraphIndent,
    String? pageTurnEffect,
    double? topContentPadding,
    String? appBackgroundStyle,
    String? customBackgroundPath,
    bool clearCustomBackgroundPath = false,
    double? backgroundIntensity,
    String? readerPaperId,
    int? readerPaperColor,
  }) {
    return ReadingPreferences(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      theme: theme ?? this.theme,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      preferredOrientation: preferredOrientation ?? this.preferredOrientation,
      readingBrightness: readingBrightness ?? this.readingBrightness,
      brightnessGestureEnabled:
          brightnessGestureEnabled ?? this.brightnessGestureEnabled,
      lineFocusEnabled: lineFocusEnabled ?? this.lineFocusEnabled,
      lineFocusLineCount: lineFocusLineCount ?? this.lineFocusLineCount,
      lineFocusDimAmount: lineFocusDimAmount ?? this.lineFocusDimAmount,
      pdfCropAmount: pdfCropAmount ?? this.pdfCropAmount,
      pdfContrast: pdfContrast ?? this.pdfContrast,
      pdfPageLayout: pdfPageLayout ?? this.pdfPageLayout,
      margin: margin ?? this.margin,
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      boldText: boldText ?? this.boldText,
      textAlignment: textAlignment ?? this.textAlignment,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      pageTurnEffect: pageTurnEffect ?? this.pageTurnEffect,
      topContentPadding: topContentPadding ?? this.topContentPadding,
      appBackgroundStyle: appBackgroundStyle ?? this.appBackgroundStyle,
      customBackgroundPath: clearCustomBackgroundPath
          ? null
          : (customBackgroundPath ?? this.customBackgroundPath),
      backgroundIntensity: backgroundIntensity ?? this.backgroundIntensity,
      readerPaperId: readerPaperId ?? this.readerPaperId,
      // 没有「清掉自定义色」这一路：切到预设时故意把色值留着，
      // 用户切回自定义还能拿回原来那个颜色（见 updateReaderPaper）。
      readerPaperColor: readerPaperColor ?? this.readerPaperColor,
    );
  }

  /// 当前生效的正文纸张。
  ///
  /// 存的是 id 而不是颜色本身：预设的色值将来调了，用户不用重新选一次。
  /// 只有 [ReaderPaper.customId] 才回落到存下来的 ARGB。
  ReaderPaper get readerPaper {
    if (readerPaperId == ReaderPaper.customId) {
      final argb = readerPaperColor;
      if (argb == null) return ReaderPaper.followTheme;
      return ReaderPaper.custom(Color(argb));
    }
    return ReaderPaper.presetById(readerPaperId) ?? ReaderPaper.followTheme;
  }

  AppBackgroundStyle get backgroundStyle =>
      AppBackgroundStyle.fromStorage(appBackgroundStyle);
}

class PreferencesNotifier extends Notifier<ReadingPreferences> {
  static const _kFontSize = 'fontSize';
  static const _kLineHeight = 'lineHeight';
  static const _kTheme = 'theme';
  static const _kKeepScreenOn = 'keepScreenOn';
  static const _kPreferredOrientation = 'preferredOrientation';
  static const _kReadingBrightness = 'readingBrightness';
  static const _kBrightnessGestureEnabled = 'brightnessGestureEnabled';
  static const _kLineFocusEnabled = 'lineFocusEnabled';
  static const _kLineFocusLineCount = 'lineFocusLineCount';
  static const _kLineFocusDimAmount = 'lineFocusDimAmount';
  static const _kPdfCropAmount = 'pdfCropAmount';
  static const _kPdfContrast = 'pdfContrast';
  static const _kPdfPageLayout = 'pdfPageLayout';
  static const _kMargin = 'margin';
  static const _kFontFamily = 'fontFamily';
  static const _kParagraphSpacing = 'paragraphSpacing';
  static const _kLetterSpacing = 'letterSpacing';
  static const _kWordSpacing = 'wordSpacing';
  static const _kBoldText = 'boldText';
  static const _kTextAlignment = 'textAlignment';
  static const _kParagraphIndent = 'paragraphIndent';
  static const _kPageTurnEffect = 'pageTurnEffect';
  static const _kTopContentPadding = 'topContentPadding';
  static const _kAppBackgroundStyle = 'appBackgroundStyle';
  static const _kCustomBackgroundPath = 'customBackgroundPath';
  static const _kBackgroundIntensity = 'backgroundIntensity';
  static const _kReaderPaperId = 'readerPaperId';
  static const _kReaderPaperColor = 'readerPaperColor';

  @override
  ReadingPreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ReadingPreferences(
      fontSize: prefs.getDouble(_kFontSize) ?? ReadingDefaults.fontSize,
      lineHeight: prefs.getDouble(_kLineHeight) ?? ReadingDefaults.lineHeight,
      theme: prefs.getString(_kTheme) ?? ReadingDefaults.theme,
      keepScreenOn:
          prefs.getBool(_kKeepScreenOn) ?? ReadingDefaults.keepScreenOn,
      preferredOrientation: prefs.getString(_kPreferredOrientation) ??
          ReadingDefaults.preferredOrientation,
      readingBrightness: _readReadingBrightness(prefs),
      brightnessGestureEnabled: prefs.getBool(_kBrightnessGestureEnabled) ??
          ReadingDefaults.brightnessGestureEnabled,
      lineFocusEnabled:
          prefs.getBool(_kLineFocusEnabled) ?? ReadingDefaults.lineFocusEnabled,
      lineFocusLineCount: _readLineFocusLineCount(prefs),
      lineFocusDimAmount: (prefs.getDouble(_kLineFocusDimAmount) ??
              ReadingDefaults.lineFocusDimAmount)
          .clamp(0.1, 0.65),
      pdfCropAmount:
          (prefs.getDouble(_kPdfCropAmount) ?? ReadingDefaults.pdfCropAmount)
              .clamp(0.0, 0.2),
      pdfContrast:
          (prefs.getDouble(_kPdfContrast) ?? ReadingDefaults.pdfContrast)
              .clamp(1.0, 2.0),
      pdfPageLayout: _readPdfPageLayout(prefs),
      margin: prefs.getDouble(_kMargin) ?? ReadingDefaults.margin,
      // 未设置即 null，与 ReadingDefaults.fontFamily 一致，表示跟随系统字体。
      fontFamily: prefs.getString(_kFontFamily),
      paragraphSpacing: prefs.getDouble(_kParagraphSpacing) ??
          ReadingDefaults.paragraphSpacing,
      letterSpacing:
          prefs.getDouble(_kLetterSpacing) ?? ReadingDefaults.letterSpacing,
      wordSpacing:
          prefs.getDouble(_kWordSpacing) ?? ReadingDefaults.wordSpacing,
      boldText: prefs.getBool(_kBoldText) ?? ReadingDefaults.boldText,
      textAlignment:
          prefs.getString(_kTextAlignment) ?? ReadingDefaults.textAlignment,
      paragraphIndent:
          prefs.getInt(_kParagraphIndent) ?? ReadingDefaults.paragraphIndent,
      pageTurnEffect:
          prefs.getString(_kPageTurnEffect) ?? ReadingDefaults.pageTurnEffect,
      topContentPadding: prefs.getDouble(_kTopContentPadding) ??
          ReadingDefaults.topContentPadding,
      appBackgroundStyle: AppBackgroundStyle.fromStorage(
        prefs.getString(_kAppBackgroundStyle),
      ).storageValue,
      customBackgroundPath: prefs.getString(_kCustomBackgroundPath),
      backgroundIntensity: (prefs.getDouble(_kBackgroundIntensity) ??
              ReadingDefaults.backgroundIntensity)
          .clamp(0.0, 1.0),
      readerPaperId:
          prefs.getString(_kReaderPaperId) ?? ReadingDefaults.readerPaperId,
      readerPaperColor: prefs.getInt(_kReaderPaperColor),
    );
  }

  void updateFontSize(double size) {
    state = state.copyWith(fontSize: size);
    ref.read(sharedPreferencesProvider).setDouble(_kFontSize, size);
  }

  void updateLineHeight(double height) {
    state = state.copyWith(lineHeight: height);
    ref.read(sharedPreferencesProvider).setDouble(_kLineHeight, height);
  }

  void updateTheme(String theme) {
    state = state.copyWith(theme: theme);
    ref.read(sharedPreferencesProvider).setString(_kTheme, theme);
  }

  void updateKeepScreenOn(bool value) {
    state = state.copyWith(keepScreenOn: value);
    ref.read(sharedPreferencesProvider).setBool(_kKeepScreenOn, value);
  }

  void updatePreferredOrientation(String orientation) {
    state = state.copyWith(preferredOrientation: orientation);
    ref
        .read(sharedPreferencesProvider)
        .setString(_kPreferredOrientation, orientation);
  }

  void updateReadingBrightness(double? value) {
    final normalized = value == null ? -1.0 : value.clamp(0.05, 1.0);
    state = state.copyWith(readingBrightness: normalized);
    ref
        .read(sharedPreferencesProvider)
        .setDouble(_kReadingBrightness, normalized);
  }

  void updateBrightnessGestureEnabled(bool value) {
    state = state.copyWith(brightnessGestureEnabled: value);
    ref
        .read(sharedPreferencesProvider)
        .setBool(_kBrightnessGestureEnabled, value);
  }

  void updateLineFocusEnabled(bool value) {
    state = state.copyWith(lineFocusEnabled: value);
    ref.read(sharedPreferencesProvider).setBool(_kLineFocusEnabled, value);
  }

  void updateLineFocusLineCount(int value) {
    final normalized = const {1, 3, 5}.contains(value) ? value : 3;
    state = state.copyWith(lineFocusLineCount: normalized);
    ref
        .read(sharedPreferencesProvider)
        .setInt(_kLineFocusLineCount, normalized);
  }

  void updateLineFocusDimAmount(double value) {
    final normalized = value.clamp(0.1, 0.65);
    state = state.copyWith(lineFocusDimAmount: normalized);
    ref
        .read(sharedPreferencesProvider)
        .setDouble(_kLineFocusDimAmount, normalized);
  }

  void updatePdfCropAmount(double value) {
    final normalized = value.clamp(0.0, 0.2);
    state = state.copyWith(pdfCropAmount: normalized);
    ref.read(sharedPreferencesProvider).setDouble(_kPdfCropAmount, normalized);
  }

  void updatePdfContrast(double value) {
    final normalized = value.clamp(1.0, 2.0);
    state = state.copyWith(pdfContrast: normalized);
    ref.read(sharedPreferencesProvider).setDouble(_kPdfContrast, normalized);
  }

  void updatePdfPageLayout(String value) {
    if (!const {'single', 'double'}.contains(value)) return;
    state = state.copyWith(pdfPageLayout: value);
    ref.read(sharedPreferencesProvider).setString(_kPdfPageLayout, value);
  }

  void updateMargin(double value) {
    state = state.copyWith(margin: value);
    ref.read(sharedPreferencesProvider).setDouble(_kMargin, value);
  }

  void updateFontFamily(String? family) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (family == null) {
      prefs.remove(_kFontFamily);
    } else {
      prefs.setString(_kFontFamily, family);
    }
    state = state.copyWith(fontFamily: family, clearFontFamily: family == null);
  }

  void updateParagraphSpacing(double value) {
    state = state.copyWith(paragraphSpacing: value);
    ref.read(sharedPreferencesProvider).setDouble(_kParagraphSpacing, value);
  }

  void updateLetterSpacing(double value) {
    state = state.copyWith(letterSpacing: value);
    ref.read(sharedPreferencesProvider).setDouble(_kLetterSpacing, value);
  }

  void updateWordSpacing(double value) {
    state = state.copyWith(wordSpacing: value);
    ref.read(sharedPreferencesProvider).setDouble(_kWordSpacing, value);
  }

  void updateBoldText(bool value) {
    state = state.copyWith(boldText: value);
    ref.read(sharedPreferencesProvider).setBool(_kBoldText, value);
  }

  void updateTextAlignment(String value) {
    if (!const {'start', 'justify'}.contains(value)) return;
    state = state.copyWith(textAlignment: value);
    ref.read(sharedPreferencesProvider).setString(_kTextAlignment, value);
  }

  void updateParagraphIndent(int value) {
    final normalized = value.clamp(0, 4);
    state = state.copyWith(paragraphIndent: normalized);
    ref.read(sharedPreferencesProvider).setInt(_kParagraphIndent, normalized);
  }

  void updatePageTurnEffect(String value) {
    state = state.copyWith(pageTurnEffect: value);
    ref.read(sharedPreferencesProvider).setString(_kPageTurnEffect, value);
  }

  void updateTopContentPadding(double value) {
    state = state.copyWith(topContentPadding: value);
    ref.read(sharedPreferencesProvider).setDouble(_kTopContentPadding, value);
  }

  void updateAppBackgroundStyle(AppBackgroundStyle style) {
    state = state.copyWith(appBackgroundStyle: style.storageValue);
    ref
        .read(sharedPreferencesProvider)
        .setString(_kAppBackgroundStyle, style.storageValue);
  }

  /// 记下自定义背景图。传 null 表示放弃这张图。
  ///
  /// 放弃时顺手把样式退回纯色：留着 custom 而没有图片，界面上就是一个选中
  /// 了却什么都不显示的选项，用户会以为坏了。
  void updateCustomBackgroundPath(String? path) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (path == null) {
      prefs.remove(_kCustomBackgroundPath);
      final fallback = state.backgroundStyle == AppBackgroundStyle.custom
          ? AppBackgroundStyle.solid.storageValue
          : state.appBackgroundStyle;
      prefs.setString(_kAppBackgroundStyle, fallback);
      state = state.copyWith(
        clearCustomBackgroundPath: true,
        appBackgroundStyle: fallback,
      );
      return;
    }
    prefs.setString(_kCustomBackgroundPath, path);
    state = state.copyWith(customBackgroundPath: path);
  }

  void updateBackgroundIntensity(double value) {
    final normalized = value.clamp(0.0, 1.0);
    state = state.copyWith(backgroundIntensity: normalized);
    ref
        .read(sharedPreferencesProvider)
        .setDouble(_kBackgroundIntensity, normalized);
  }

  void updateReaderPaper(ReaderPaper paper) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kReaderPaperId, paper.id);
    if (paper.id == ReaderPaper.customId && paper.background != null) {
      final argb = paper.background!.toARGB32();
      prefs.setInt(_kReaderPaperColor, argb);
      state = state.copyWith(
        readerPaperId: paper.id,
        readerPaperColor: argb,
      );
      return;
    }
    state = state.copyWith(readerPaperId: paper.id);
  }

  double _readReadingBrightness(SharedPreferences prefs) {
    final value = prefs.getDouble(_kReadingBrightness) ?? -1;
    if (value == -1 || (value >= 0.05 && value <= 1)) {
      return value;
    }
    return -1;
  }

  int _readLineFocusLineCount(SharedPreferences prefs) {
    final value = prefs.getInt(_kLineFocusLineCount) ?? 3;
    return const {1, 3, 5}.contains(value) ? value : 3;
  }

  String _readPdfPageLayout(SharedPreferences prefs) {
    final value = prefs.getString(_kPdfPageLayout) ?? 'single';
    return const {'single', 'double'}.contains(value) ? value : 'single';
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, ReadingPreferences>(
  PreferencesNotifier.new,
);
