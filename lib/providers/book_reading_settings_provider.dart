import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'database_provider.dart';
import 'preferences_provider.dart';

final bookReadingSettingsProvider =
    StreamProvider.family<BookReadingSetting?, int>((ref, bookId) {
  return ref.watch(bookReadingSettingsDaoProvider).watchForBook(bookId);
});

final effectiveBookReadingPreferencesProvider =
    Provider.family<ReadingPreferences, int>((ref, bookId) {
  final global = ref.watch(preferencesProvider);
  final bookSettings =
      ref.watch(bookReadingSettingsProvider(bookId)).valueOrNull;
  return applyBookReadingSettings(global, bookSettings);
});

ReadingPreferences applyBookReadingSettings(
  ReadingPreferences global,
  BookReadingSetting? bookSettings,
) {
  if (bookSettings == null) return global;
  return global.copyWith(
    fontSize: bookSettings.fontSize,
    lineHeight: bookSettings.lineHeight,
    margin: bookSettings.margin,
    fontFamily: bookSettings.fontFamily,
    clearFontFamily: bookSettings.fontFamily == null,
    paragraphSpacing: bookSettings.paragraphSpacing,
    letterSpacing: bookSettings.letterSpacing,
    wordSpacing: bookSettings.wordSpacing,
    boldText: bookSettings.boldText,
    textAlignment: bookSettings.textAlignment,
    paragraphIndent: bookSettings.paragraphIndent,
    pdfCropAmount: bookSettings.pdfCropAmount,
    pdfContrast: bookSettings.pdfContrast,
    pdfPageLayout: bookSettings.pdfPageLayout,
    topContentPadding: bookSettings.topContentPadding,
    pageTurnEffect: bookSettings.pageTurnEffect,
  );
}
