/// Utility functions for handling fonts across different platforms
class FontUtils {
  static String? resolveFontFamily(String? fontFamily) {
    if (fontFamily == null) return null;
    switch (fontFamily) {
      case 'serif':
        return 'serif';
      case 'sans-serif':
        return 'sans-serif';
      case 'monospace':
        return 'monospace';
      default:
        return fontFamily;
    }
  }

  /// Resolves CSS generic font family names to platform-specific fallback lists
  static List<String>? resolveFontFamilyFallback(String? fontFamily) {
    if (fontFamily == null) return null;
    switch (fontFamily) {
      case 'serif':
        return ['Noto Serif CJK SC', 'Noto Serif', 'STSong', 'SimSun'];
      case 'sans-serif':
        return ['Noto Sans CJK SC', 'Microsoft YaHei', 'Roboto'];
      case 'monospace':
        return ['Noto Sans Mono CJK SC', 'Consolas', 'Courier New'];
      default:
        return null;
    }
  }
}
