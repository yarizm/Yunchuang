import 'package:flutter/material.dart';

/// 阅读器主题 - 借鉴原项目木质暖色调设计
class AppTheme {
  // 木质暖色调
  static const Color primaryColor = Color(0xFFA36B46); // Amber Wood
  static const Color primaryDark = Color(0xFF8F5D3D);
  static const Color primaryLight = Color(0xFFC29B7A);

  // 背景色
  static const Color bgLight = Color(0xFFF8FAF5);
  static const Color bgSepia = Color(0xFFF5F0E1);
  static const Color bgDark = Color(0xFF1E1E1E);

  // 文字色
  static const Color textPrimary = Color(0xFF2E2520); // Deep Brown
  static const Color textSecondary = Color(0xFF6B5E53); // Warm Grey
  static const Color textLight = Color(0xFF9B8E83);

  // 表面色
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSepia = Color(0xFFFFFBF0);
  static const Color surfaceDark = Color(0xFF2D2D2D);

  // 边框色
  static const Color borderLight = Color(0x33A36B46);
  static const Color borderDark = Color(0x33FFFFFF);

  // 三套主题各自唯一的配色方案。ThemeData.colorScheme 与依赖配色的组件主题
  // （如 chipTheme）必须共用同一份，避免两处手写色值漂移。
  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: primaryDark,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFECD7C5),
    onPrimaryContainer: Color(0xFF3D2618),
    secondary: Color(0xFF8B6F52),
    surface: surfaceLight,
    onSurface: textPrimary,
    onSurfaceVariant: Color(0xFF594C43),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF8F5),
    surfaceContainer: Color(0xFFF4F0EB),
    surfaceContainerHigh: Color(0xFFEEE8E1),
    surfaceContainerHighest: Color(0xFFE6DED5),
    outlineVariant: Color(0xFFBDAFA4),
  );

  static const ColorScheme _sepiaScheme = ColorScheme.light(
    primary: primaryDark,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE9D3B9),
    onPrimaryContainer: Color(0xFF3D2819),
    secondary: Color(0xFF8B6F52),
    surface: surfaceSepia,
    onSurface: textPrimary,
    onSurfaceVariant: Color(0xFF5B5046),
    surfaceContainerLowest: Color(0xFFFFFBF0),
    surfaceContainerLow: Color(0xFFFAF4E5),
    surfaceContainer: Color(0xFFF3EBD9),
    surfaceContainerHigh: Color(0xFFECE2CE),
    surfaceContainerHighest: Color(0xFFE4D8C2),
    outlineVariant: Color(0xFFB9AA94),
  );

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: primaryLight,
    onPrimary: Colors.black,
    primaryContainer: primaryDark,
    onPrimaryContainer: Color(0xFFFFF7F0),
    secondary: Color(0xFFC29B7A),
    surface: surfaceDark,
    onSurface: Color(0xFFFFF8F2),
    onSurfaceVariant: Color(0xFFD8CEC6),
    surfaceContainerLowest: Color(0xFF1F1B19),
    surfaceContainerLow: Color(0xFF292522),
    surfaceContainer: Color(0xFF342F2C),
    surfaceContainerHigh: Color(0xFF3C3632),
    surfaceContainerHighest: Color(0xFF463F3A),
    outlineVariant: Color(0xFF6B6059),
  );

  static InputDecorationTheme _buildInputDecorationTheme(
      Color fillColor, Color borderColor, Color focusedColor) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor.withValues(alpha: 0.9),
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: focusedColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusedColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  static TextTheme _buildTextTheme(Color color) {
    return ThemeData().textTheme.apply(
      bodyColor: color,
      displayColor: color,
      fontFamilyFallback: const [
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
    );
  }

  static SegmentedButtonThemeData get _segmentedButtonTheme {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  static SliderThemeData get _sliderTheme {
    return SliderThemeData(
      activeTrackColor: primaryColor,
      inactiveTrackColor: primaryLight.withValues(alpha: 0.3),
      thumbColor: primaryColor,
      overlayColor: primaryLight.withValues(alpha: 0.2),
    );
  }

  static FloatingActionButtonThemeData get _fabTheme {
    return const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    );
  }

  static ChipThemeData _buildChipTheme(ColorScheme scheme) {
    return ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(fontSize: 12, color: scheme.onSurface),
      secondaryLabelStyle:
          TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  /// 三套配色方案本体。
  ///
  /// 下面的 `lightTheme` / `sepiaTheme` / `darkTheme` 都是 **getter**——每次
  /// 访问都新建一份 `ThemeData`，而 `_buildTextTheme` 内部还会再 `ThemeData()`
  /// 一次。只为读一个 `colorScheme` 就走那条路是纯浪费，尤其在每帧重建的
  /// 预览里。要配色就取这三个 const，不要 `AppTheme.lightTheme.colorScheme`。
  static const ColorScheme lightScheme = _lightScheme;
  static const ColorScheme sepiaScheme = _sepiaScheme;
  static const ColorScheme darkScheme = _darkScheme;

  /// [resolve] 的配色版：同样的主题名映射，但不构造 ThemeData。
  ///
  /// 与 [resolve] 的一致性由 `test/theme/app_theme_contrast_test.dart` 钉住。
  static ColorScheme resolveScheme(String name, Brightness platformBrightness) {
    switch (name) {
      case 'sepia':
        return sepiaScheme;
      case 'dark':
        return darkScheme;
      case 'system':
        return platformBrightness == Brightness.dark
            ? darkScheme
            : lightScheme;
      default:
        return lightScheme;
    }
  }

  /// 按偏好里的主题名与系统亮度解析出主题。
  ///
  /// `system` 跟随 [platformBrightness] 在日间 / 夜间之间切；sepia 是显式
  /// 选择，不参与跟随。构造 ThemeData 不便宜，只在真的要整套主题时用它
  /// （`MaterialApp.theme`）；只要配色就走 [resolveScheme]。
  static ThemeData resolve(String name, Brightness platformBrightness) {
    switch (name) {
      case 'sepia':
        return sepiaTheme;
      case 'dark':
        return darkTheme;
      case 'system':
        return platformBrightness == Brightness.dark ? darkTheme : lightTheme;
      default:
        return lightTheme;
    }
  }

  /// 日间主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _lightScheme,
      textTheme: _buildTextTheme(textPrimary),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLight.withValues(alpha: 0.9),
        elevation: 0,
        height: 65,
        indicatorColor: primaryLight.withValues(alpha: 0.3),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: _fabTheme,
      sliderTheme: _sliderTheme,
      segmentedButtonTheme: _segmentedButtonTheme,
      chipTheme: _buildChipTheme(_lightScheme),
      inputDecorationTheme:
          _buildInputDecorationTheme(surfaceLight, borderLight, primaryColor),
    );
  }

  /// 护眼主题
  static ThemeData get sepiaTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _sepiaScheme,
      textTheme: _buildTextTheme(textPrimary),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceSepia,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceSepia,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceSepia.withValues(alpha: 0.9),
        elevation: 0,
        height: 65,
        indicatorColor: primaryLight.withValues(alpha: 0.3),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: _fabTheme,
      sliderTheme: _sliderTheme,
      segmentedButtonTheme: _segmentedButtonTheme,
      chipTheme: _buildChipTheme(_sepiaScheme),
      inputDecorationTheme:
          _buildInputDecorationTheme(surfaceSepia, borderLight, primaryColor),
    );
  }

  /// 夜间主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkScheme,
      textTheme: _buildTextTheme(Colors.white),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark.withValues(alpha: 0.9),
        elevation: 0,
        height: 65,
        indicatorColor: primaryColor.withValues(alpha: 0.3),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: _fabTheme,
      sliderTheme: _sliderTheme,
      segmentedButtonTheme: _segmentedButtonTheme,
      chipTheme: _buildChipTheme(_darkScheme),
      inputDecorationTheme:
          _buildInputDecorationTheme(surfaceDark, borderDark, primaryLight),
    );
  }
}
