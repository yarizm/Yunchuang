/// 阅读偏好默认值的唯一来源。
///
/// 这些值此前在五处各自定义——`ReadingPreferences` 的 const 构造函数、
/// `PreferencesNotifier.build()` 的 `?? N`，以及 `txt_reader`、`epub_reader`、
/// `paged_reader` 三个部件的参数默认——任何一处漏改都会让实际排版与设置面板
/// 显示的值不一致。新增可配置项时，默认值只写在这里。
///
/// 与 `book_reading_settings` 表的 SQL `DEFAULT` 无关：那套默认只在迁移回填
/// 时生效，语义是「升级前就存在的书保持原样」，不是「新读者该看到什么」，
/// 因此不随本文件变动。
class ReadingDefaults {
  const ReadingDefaults._();

  // 正文排版
  static const double fontSize = 18.0;
  static const double lineHeight = 1.8;
  static const double margin = 20;
  static const double topContentPadding = 16;
  static const String? fontFamily = null;
  static const bool boldText = false;

  /// 中文段落靠首行缩进划分，两字是通行排版约定。
  static const int paragraphIndent = 2;

  /// 有了首行缩进就不需要靠大段间距区分段落，但屏幕阅读保留少量留白便于扫读。
  static const double paragraphSpacing = 6;

  /// 字间距是给西文字母用的；加在方块字上只会把行撑散，因此默认不加。
  static const double letterSpacing = 0;

  static const double wordSpacing = 0;

  /// 保持左对齐。两端对齐要等标点挤压做完才有意义——在此之前，行尾全角标点
  /// 占满一个字宽会让右边缘出现空洞，justify 补偿又会拉松字间距。
  /// 详见 ADR 0003 与 development_roadmap.md §7.3。
  static const String textAlignment = 'start';

  // 阅读环境
  static const String theme = 'light';
  static const bool keepScreenOn = true;
  static const String preferredOrientation = 'auto';

  /// 阅读时锁横屏（只在手机上生效；桌面没有方向）。
  static const bool readerLandscape = false;
  static const String pageTurnEffect = 'curl';

  /// -1 表示跟随系统亮度，不接管窗口亮度。
  static const double readingBrightness = -1;
  static const bool brightnessGestureEnabled = false;

  // 行聚焦
  static const bool lineFocusEnabled = false;
  static const int lineFocusLineCount = 3;
  static const double lineFocusDimAmount = 0.35;

  // 全局背景
  static const String appBackgroundStyle = 'solid';
  static const String? customBackgroundPath = null;

  /// 装饰层默认压得很低。背景是背景，不该跟书封和正文抢注意力——之前那张
  /// 水彩插画常驻在 0.8 不透明度上，书架的封面几乎是贴在一幅画上看的。
  static const double backgroundIntensity = 0.22;

  // 正文纸张
  static const String readerPaperId = 'theme';
  static const int? readerPaperColor = null;

  // PDF 显示
  static const double pdfCropAmount = 0;
  static const double pdfContrast = 1;
  static const String pdfPageLayout = 'single';
}
