import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../database/daos/book_reading_settings_dao.dart';
import '../../providers/book_reading_settings_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../utils/app_orientation.dart';
import '../../theme/reader_theme.dart';
import '../../utils/font_utils.dart';
import 'format_reader.dart';

Future<void> showQuickSettingsPanel(
  BuildContext context,
  WidgetRef ref, {
  int? bookId,
  bool isPdf = false,
  ReadingMode currentMode = ReadingMode.scroll,
  ValueChanged<ReadingMode>? onModeChanged,
}) async {
  final globalPreferences = ref.read(preferencesProvider);
  final notifier = ref.read(preferencesProvider.notifier);
  BookReadingSettingsDao? bookSettingsDao;
  BookReadingSetting? bookSettings;
  if (bookId != null) {
    final dao = ref.read(bookReadingSettingsDaoProvider);
    bookSettingsDao = dao;
    bookSettings = await dao.getForBook(bookId);
  }
  if (!context.mounted) return;
  final effectivePreferences = applyBookReadingSettings(
    globalPreferences,
    bookSettings,
  );

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.86,
      alignment: Alignment.bottomCenter,
      child: _QuickSettingsContent(
        prefs: effectivePreferences,
        globalPreferences: globalPreferences,
        notifier: notifier,
        bookId: bookId,
        bookSettingsDao: bookSettingsDao,
        usesBookSettings: bookSettings != null,
        isPdf: isPdf,
        currentMode: currentMode,
        onModeChanged: onModeChanged,
      ),
    ),
  );
}

class _QuickSettingsContent extends StatefulWidget {
  final ReadingPreferences prefs;
  final ReadingPreferences globalPreferences;
  final PreferencesNotifier notifier;
  final int? bookId;
  final BookReadingSettingsDao? bookSettingsDao;
  final bool usesBookSettings;
  final bool isPdf;
  final ReadingMode currentMode;
  final ValueChanged<ReadingMode>? onModeChanged;

  const _QuickSettingsContent({
    required this.prefs,
    required this.globalPreferences,
    required this.notifier,
    required this.bookId,
    required this.bookSettingsDao,
    required this.usesBookSettings,
    required this.isPdf,
    required this.currentMode,
    this.onModeChanged,
  });

  @override
  State<_QuickSettingsContent> createState() => _QuickSettingsContentState();
}

class _QuickSettingsContentState extends State<_QuickSettingsContent> {
  late double _fontSize;
  late double _lineHeight;
  late String _theme;
  late double _readingBrightness;
  late bool _brightnessGestureEnabled;
  late bool _lineFocusEnabled;
  late bool _readerLandscape;
  late int _lineFocusLineCount;
  late double _lineFocusDimAmount;
  late double _pdfCropAmount;
  late double _pdfContrast;
  late String _pdfPageLayout;
  late ReadingMode _readingMode;
  late double _margin;
  late double _topContentPadding;
  late double _paragraphSpacing;
  late double _letterSpacing;
  late double _wordSpacing;
  late bool _boldText;
  late String _textAlignment;
  late int _paragraphIndent;
  late String _pageTurnEffect;
  String? _fontFamily;
  late bool _usesBookSettings;
  bool _scopeChanging = false;
  Future<void> _bookSaveQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _fontSize = widget.prefs.fontSize;
    _lineHeight = widget.prefs.lineHeight;
    _theme = widget.prefs.theme;
    _readingBrightness = widget.globalPreferences.readingBrightness;
    _brightnessGestureEnabled =
        widget.globalPreferences.brightnessGestureEnabled;
    _lineFocusEnabled = widget.globalPreferences.lineFocusEnabled;
    _readerLandscape = widget.globalPreferences.readerLandscape;
    _lineFocusLineCount = widget.globalPreferences.lineFocusLineCount;
    _lineFocusDimAmount = widget.globalPreferences.lineFocusDimAmount;
    _pdfCropAmount = widget.prefs.pdfCropAmount;
    _pdfContrast = widget.prefs.pdfContrast;
    _pdfPageLayout = widget.prefs.pdfPageLayout;
    _readingMode = widget.currentMode;
    _margin = widget.prefs.margin;
    _topContentPadding = widget.prefs.topContentPadding;
    _paragraphSpacing = widget.prefs.paragraphSpacing;
    _letterSpacing = widget.prefs.letterSpacing;
    _wordSpacing = widget.prefs.wordSpacing;
    _boldText = widget.prefs.boldText;
    _textAlignment = widget.prefs.textAlignment;
    _paragraphIndent = widget.prefs.paragraphIndent;
    _pageTurnEffect = widget.prefs.pageTurnEffect;
    _fontFamily = widget.prefs.fontFamily;
    _usesBookSettings = widget.usesBookSettings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 一次算好给下面三处预览用。这个面板全是滑块，拖动时每帧都会重建。
    // 与「阅读偏好」页共用 readerPreviewColors，两处不会各写一份而慢慢对不上。
    final preview = readerPreviewColors(
      themeName: _theme,
      paper: widget.prefs.readerPaper,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.bookId != null) ...[
            Row(
              children: [
                Text(
                  '设置范围',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('跟随全局'),
                        icon: Icon(Icons.public, size: 18),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('本书独立'),
                        icon: Icon(Icons.menu_book_outlined, size: 18),
                      ),
                    ],
                    selected: {_usesBookSettings},
                    onSelectionChanged: _scopeChanging
                        ? null
                        : (selection) {
                            unawaited(
                              _changeSettingsScope(selection.first),
                            );
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _usesBookSettings
                    ? widget.isPdf
                        ? '下方 PDF 显示只影响当前书；主题仍为全局设置。'
                        : '下方排版只影响当前书；主题仍为全局设置。'
                    : widget.isPdf
                        ? '下方 PDF 显示会修改所有跟随全局的书籍。'
                        : '下方排版会修改所有跟随全局的书籍。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // 预览固定在顶部而不是排进滚动列表：排版控件要滚动才能全部够到，
          // 预览跟着滚走就等于不存在。拖滑块时它必须一直在视野里。
          if (!widget.isPdf) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: preview.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_paragraphIndentPrefix()}预览文字。'
                    '调整滑块会实时改变阅读体验。',
                    textAlign: _resolvedTextAlign,
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: _lineHeight,
                      fontWeight:
                          _boldText ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: FontUtils.resolveFontFamily(_fontFamily),
                      fontFamilyFallback:
                          FontUtils.resolveFontFamilyFallback(_fontFamily),
                      letterSpacing: _letterSpacing,
                      wordSpacing: _wordSpacing,
                      color: preview.foreground,
                    ),
                  ),
                  SizedBox(height: _paragraphSpacing),
                  Text(
                    '${_paragraphIndentPrefix()}段距会影响段落之间的留白。',
                    textAlign: _resolvedTextAlign,
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: _lineHeight,
                      fontWeight:
                          _boldText ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: FontUtils.resolveFontFamily(_fontFamily),
                      fontFamilyFallback:
                          FontUtils.resolveFontFamilyFallback(_fontFamily),
                      letterSpacing: _letterSpacing,
                      wordSpacing: _wordSpacing,
                      color: preview.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 正文排版：一组连续控件。此前被主题、亮度和行聚焦切成两半，
                    // 对齐与段首落到第 15、16 位，实际上没人滚得到。
                    if (!widget.isPdf) ...[
                      // Font size
                      _buildSliderRow(
                          '字号', _fontSize, 12, 28, '${_fontSize.round()}px',
                          (v) {
                        setState(() => _fontSize = v);
                      }, onChangeEnd: (v) {
                        _updateBookOrGlobal(
                          () => widget.notifier.updateFontSize(v),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Line height
                      _buildSliderRow('行距', _lineHeight, 1.2, 2.5,
                          _lineHeight.toStringAsFixed(1), (v) {
                        setState(() => _lineHeight = v);
                      }, onChangeEnd: (v) {
                        _updateBookOrGlobal(
                          () => widget.notifier.updateLineHeight(v),
                        );
                      }),
                      const SizedBox(height: 16),
                      // Font family
                      Row(
                        children: [
                          Text('字体', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          DropdownButton<String?>(
                            value: _fontFamily,
                            hint: const Text('系统默认'),
                            items: const [
                              DropdownMenuItem(
                                  value: null, child: Text('系统默认')),
                              DropdownMenuItem(
                                  value: 'serif', child: Text('衬线')),
                              DropdownMenuItem(
                                  value: 'sans-serif', child: Text('无衬线')),
                              DropdownMenuItem(
                                  value: 'monospace', child: Text('等宽')),
                            ],
                            onChanged: (v) {
                              setState(() => _fontFamily = v);
                              _updateBookOrGlobal(
                                () => widget.notifier.updateFontFamily(v),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Margin
                      const SizedBox(height: 16),
                      _buildSliderRow(
                          '边距', _margin, 8, 48, '${_margin.round()}', (v) {
                        setState(() => _margin = v);
                      }, onChangeEnd: (v) {
                        _updateBookOrGlobal(
                          () => widget.notifier.updateMargin(v),
                        );
                      }),
                      const SizedBox(height: 16),
                      _buildSliderRow('顶部留白', _topContentPadding, 0, 96,
                          '${_topContentPadding.round()}', (v) {
                        setState(() => _topContentPadding = v);
                      }, onChangeEnd: (v) {
                        _updateBookOrGlobal(
                          () => widget.notifier.updateTopContentPadding(v),
                        );
                      }),
                      // Paragraph spacing
                      const SizedBox(height: 16),
                      _buildSliderRow('段距', _paragraphSpacing, 0, 32,
                          '${_paragraphSpacing.round()}', (v) {
                        setState(() => _paragraphSpacing = v);
                      }, onChangeEnd: (v) {
                        _updateBookOrGlobal(
                          () => widget.notifier.updateParagraphSpacing(v),
                        );
                      }),
                      // Letter spacing
                      const SizedBox(height: 16),
                      _buildSliderRow('字距', _letterSpacing, -1, 3,
                          _letterSpacing.toStringAsFixed(1), (v) {
                        setState(() => _letterSpacing = v);
                      }, onChangeEnd: (v) {
                        _updateBookOrGlobal(
                          () => widget.notifier.updateLetterSpacing(v),
                        );
                      }),
                      const SizedBox(height: 16),
                      _buildSliderRow('词间距', _wordSpacing, -1, 8,
                          _wordSpacing.toStringAsFixed(1), (v) {
                        setState(() => _wordSpacing = v);
                      }, onChangeEnd: (v) {
                        _updateBookOrGlobal(
                          () => widget.notifier.updateWordSpacing(v),
                        );
                      }),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('正文粗体', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          Switch(
                            value: _boldText,
                            onChanged: (value) {
                              setState(() => _boldText = value);
                              _updateBookOrGlobal(
                                () => widget.notifier.updateBoldText(value),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('正文对齐', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'start',
                                label: Text('左对齐'),
                                icon: Icon(Icons.format_align_left, size: 18),
                              ),
                              ButtonSegment(
                                value: 'justify',
                                label: Text('两端'),
                                icon:
                                    Icon(Icons.format_align_justify, size: 18),
                              ),
                            ],
                            selected: {_textAlignment},
                            onSelectionChanged: (selection) {
                              final value = selection.first;
                              setState(() => _textAlignment = value);
                              _updateBookOrGlobal(
                                () =>
                                    widget.notifier.updateTextAlignment(value),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSliderRow(
                        '段首',
                        _paragraphIndent.toDouble(),
                        0,
                        4,
                        '$_paragraphIndent字',
                        (value) {
                          setState(() => _paragraphIndent = value.round());
                        },
                        onChangeEnd: (value) {
                          final indent = value.round();
                          _updateBookOrGlobal(
                            () => widget.notifier.updateParagraphIndent(indent),
                          );
                        },
                        divisions: 4,
                      ),
                      const SizedBox(height: 16),
                      // Reading mode
                      Row(
                        children: [
                          Text('阅读模式',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SegmentedButton<ReadingMode>(
                                  segments: const [
                                    ButtonSegment(
                                        value: ReadingMode.scroll,
                                        label: Text('滚动'),
                                        icon: Icon(Icons.view_headline,
                                            size: 18)),
                                    ButtonSegment(
                                        value: ReadingMode.page,
                                        label: Text('翻页'),
                                        icon: Icon(Icons.book, size: 18)),
                                  ],
                                  selected: {_readingMode},
                                  onSelectionChanged: (selection) {
                                    final mode = selection.first;
                                    setState(() => _readingMode = mode);
                                    widget.onModeChanged?.call(mode);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('翻页效果', style: theme.textTheme.titleSmall),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'curl',
                                      label: Text('仿真'),
                                      icon: Icon(Icons.chrome_reader_mode,
                                          size: 18),
                                    ),
                                    ButtonSegment(
                                      value: 'slide',
                                      label: Text('滑动'),
                                      icon: Icon(Icons.swipe, size: 18),
                                    ),
                                    ButtonSegment(
                                      value: 'plain',
                                      label: Text('简洁'),
                                      icon: Icon(Icons.crop_square, size: 18),
                                    ),
                                  ],
                                  selected: {_pageTurnEffect},
                                  onSelectionChanged: (selection) {
                                    final value = selection.first;
                                    setState(() => _pageTurnEffect = value);
                                    _updateBookOrGlobal(
                                      () => widget.notifier
                                          .updatePageTurnEffect(value),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.isPdf) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text('PDF 页面', style: theme.textTheme.titleSmall),
                      ),
                      const SizedBox(height: 12),
                      _buildSliderRow(
                        '裁边',
                        _pdfCropAmount,
                        0,
                        0.2,
                        '${(_pdfCropAmount * 100).round()}%',
                        (value) => setState(() => _pdfCropAmount = value),
                        onChangeEnd: (value) {
                          _updateBookOrGlobal(
                            () => widget.notifier.updatePdfCropAmount(value),
                          );
                        },
                        divisions: 20,
                      ),
                      const SizedBox(height: 12),
                      _buildSliderRow(
                        '对比度',
                        _pdfContrast,
                        1,
                        2,
                        _pdfContrast.toStringAsFixed(1),
                        (value) => setState(() => _pdfContrast = value),
                        onChangeEnd: (value) {
                          _updateBookOrGlobal(
                            () => widget.notifier.updatePdfContrast(value),
                          );
                        },
                        divisions: 10,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('页面布局', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'single',
                                label: Text('单页'),
                                icon: Icon(Icons.crop_portrait, size: 18),
                              ),
                              ButtonSegment(
                                value: 'double',
                                label: Text('横屏双页'),
                                icon: Icon(Icons.view_week_outlined, size: 18),
                              ),
                            ],
                            selected: {_pdfPageLayout},
                            onSelectionChanged: (selection) {
                              final value = selection.first;
                              setState(() => _pdfPageLayout = value);
                              _updateBookOrGlobal(
                                () =>
                                    widget.notifier.updatePdfPageLayout(value),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    // 全局设置：不随书变化，与当前书的排版无关，沉到最后。
                    // 和上面按书的排版隔开一条线：之前「翻页效果」和「主题」
                    // 挨在一起，看着像同一组。
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    // Theme
                    Row(
                      children: [
                        Text('主题（全局）', style: theme.textTheme.titleSmall),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'light',
                                      label: Text('日间'),
                                      icon: Icon(Icons.light_mode, size: 18)),
                                  ButtonSegment(
                                      value: 'sepia',
                                      label: Text('护眼'),
                                      icon: Icon(Icons.brightness_5, size: 18)),
                                  ButtonSegment(
                                      value: 'dark',
                                      label: Text('夜间'),
                                      icon: Icon(Icons.dark_mode, size: 18)),
                                  ButtonSegment(
                                      value: 'system',
                                      label: Text('跟随'),
                                      icon: Icon(Icons.brightness_auto,
                                          size: 18)),
                                ],
                                selected: {_theme},
                                onSelectionChanged: (s) {
                                  setState(() => _theme = s.first);
                                  widget.notifier.updateTheme(s.first);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('阅读亮度（全局）', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Checkbox(
                          value: _readingBrightness < 0,
                          onChanged: (value) {
                            final next = value == true ? -1.0 : 0.5;
                            setState(() => _readingBrightness = next);
                            widget.notifier.updateReadingBrightness(
                              next < 0 ? null : next,
                            );
                          },
                        ),
                        const Text('跟随系统'),
                      ],
                    ),
                    if (_readingBrightness >= 0)
                      Row(
                        children: [
                          const Icon(Icons.brightness_low, size: 20),
                          Expanded(
                            child: Slider(
                              value: _readingBrightness,
                              min: 0.05,
                              max: 1,
                              divisions: 19,
                              onChanged: (value) {
                                setState(() => _readingBrightness = value);
                              },
                              onChangeEnd: (value) {
                                widget.notifier.updateReadingBrightness(value);
                              },
                            ),
                          ),
                          const Icon(Icons.brightness_high, size: 20),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${(_readingBrightness * 100).round()}%',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        Text('左边缘调光', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Switch(
                          value: _brightnessGestureEnabled,
                          onChanged: (value) {
                            setState(() => _brightnessGestureEnabled = value);
                            widget.notifier
                                .updateBrightnessGestureEnabled(value);
                          },
                        ),
                      ],
                    ),
                    if (supportsReaderLandscape) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('横屏阅读（全局）', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          Switch(
                            value: _readerLandscape,
                            onChanged: (value) {
                              setState(() => _readerLandscape = value);
                              widget.notifier.updateReaderLandscape(value);
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('行聚焦（全局）', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Switch(
                          value: _lineFocusEnabled,
                          onChanged: (value) {
                            setState(() => _lineFocusEnabled = value);
                            widget.notifier.updateLineFocusEnabled(value);
                          },
                        ),
                      ],
                    ),
                    if (_lineFocusEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('清晰范围', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1 行')),
                              ButtonSegment(value: 3, label: Text('3 行')),
                              ButtonSegment(value: 5, label: Text('5 行')),
                            ],
                            selected: {_lineFocusLineCount},
                            onSelectionChanged: (selection) {
                              final value = selection.first;
                              setState(() => _lineFocusLineCount = value);
                              widget.notifier.updateLineFocusLineCount(value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSliderRow(
                        '弱化',
                        _lineFocusDimAmount,
                        0.1,
                        0.65,
                        '${(_lineFocusDimAmount * 100).round()}%',
                        (value) {
                          setState(() => _lineFocusDimAmount = value);
                        },
                        onChangeEnd: (value) {
                          widget.notifier.updateLineFocusDimAmount(value);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateBookOrGlobal(VoidCallback updateGlobal) {
    if (_usesBookSettings) {
      _queueBookSettingsSave();
    } else {
      updateGlobal();
    }
  }

  void _queueBookSettingsSave() {
    final dao = widget.bookSettingsDao;
    final bookId = widget.bookId;
    if (dao == null || bookId == null) return;
    final snapshot = (
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      margin: _margin,
      fontFamily: _fontFamily,
      paragraphSpacing: _paragraphSpacing,
      letterSpacing: _letterSpacing,
      wordSpacing: _wordSpacing,
      boldText: _boldText,
      textAlignment: _textAlignment,
      paragraphIndent: _paragraphIndent,
      pdfCropAmount: _pdfCropAmount,
      pdfContrast: _pdfContrast,
      pdfPageLayout: _pdfPageLayout,
      topContentPadding: _topContentPadding,
      pageTurnEffect: _pageTurnEffect,
    );
    _bookSaveQueue = _bookSaveQueue.then((_) {
      return dao.save(
        bookId: bookId,
        fontSize: snapshot.fontSize,
        lineHeight: snapshot.lineHeight,
        margin: snapshot.margin,
        fontFamily: snapshot.fontFamily,
        paragraphSpacing: snapshot.paragraphSpacing,
        letterSpacing: snapshot.letterSpacing,
        wordSpacing: snapshot.wordSpacing,
        boldText: snapshot.boldText,
        textAlignment: snapshot.textAlignment,
        paragraphIndent: snapshot.paragraphIndent,
        pdfCropAmount: snapshot.pdfCropAmount,
        pdfContrast: snapshot.pdfContrast,
        pdfPageLayout: snapshot.pdfPageLayout,
        topContentPadding: snapshot.topContentPadding,
        pageTurnEffect: snapshot.pageTurnEffect,
      );
    }).catchError((Object error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存本书排版失败：$error')),
      );
    });
  }

  Future<void> _changeSettingsScope(bool useBookSettings) async {
    if (_scopeChanging || useBookSettings == _usesBookSettings) return;
    if (useBookSettings) {
      setState(() => _usesBookSettings = true);
      _queueBookSettingsSave();
      return;
    }

    setState(() => _scopeChanging = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复全局排版？'),
        content: const Text('当前书的独立排版将被删除，并立即使用全局默认设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-reset-book-reading-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复全局'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (mounted) setState(() => _scopeChanging = false);
      return;
    }

    try {
      await _bookSaveQueue;
      await widget.bookSettingsDao?.reset(widget.bookId!);
      if (!mounted) return;
      setState(() {
        _usesBookSettings = false;
        _scopeChanging = false;
        _applyPreferences(widget.globalPreferences);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _scopeChanging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复全局排版失败：$error')),
      );
    }
  }

  void _applyPreferences(ReadingPreferences preferences) {
    _fontSize = preferences.fontSize;
    _lineHeight = preferences.lineHeight;
    _readingBrightness = preferences.readingBrightness;
    _brightnessGestureEnabled = preferences.brightnessGestureEnabled;
    _lineFocusEnabled = preferences.lineFocusEnabled;
    _lineFocusLineCount = preferences.lineFocusLineCount;
    _lineFocusDimAmount = preferences.lineFocusDimAmount;
    _margin = preferences.margin;
    _topContentPadding = preferences.topContentPadding;
    _paragraphSpacing = preferences.paragraphSpacing;
    _letterSpacing = preferences.letterSpacing;
    _wordSpacing = preferences.wordSpacing;
    _boldText = preferences.boldText;
    _textAlignment = preferences.textAlignment;
    _paragraphIndent = preferences.paragraphIndent;
    _pdfCropAmount = preferences.pdfCropAmount;
    _pdfContrast = preferences.pdfContrast;
    _pdfPageLayout = preferences.pdfPageLayout;
    _pageTurnEffect = preferences.pageTurnEffect;
    _fontFamily = preferences.fontFamily;
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    String display,
    ValueChanged<double> onChanged, {
    ValueChanged<double>? onChangeEnd,
    int? divisions,
  }) {
    return Row(
      children: [
        SizedBox(
            width: 48,
            child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
        Expanded(
          child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd),
        ),
        SizedBox(
            width: 48,
            child: Text(display,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }

  TextAlign get _resolvedTextAlign =>
      _textAlignment == 'justify' ? TextAlign.justify : TextAlign.start;

  String _paragraphIndentPrefix() =>
      List.filled(_paragraphIndent, '\u3000').join();
}
