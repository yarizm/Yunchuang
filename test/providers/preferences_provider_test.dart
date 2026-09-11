import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reading brightness preferences are normalized and persisted', () async {
    SharedPreferences.setMockInitialValues({
      'readingBrightness': 2.0,
      'brightnessGestureEnabled': false,
      'lineFocusLineCount': 2,
      'lineFocusDimAmount': 0.9,
      'pdfCropAmount': 0.4,
      'pdfContrast': 3.0,
      'pdfPageLayout': 'grid',
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(preferencesProvider).readingBrightness, -1);
    expect(container.read(preferencesProvider).lineFocusLineCount, 3);
    expect(container.read(preferencesProvider).lineFocusDimAmount, 0.65);
    expect(container.read(preferencesProvider).pdfCropAmount, 0.2);
    expect(container.read(preferencesProvider).pdfContrast, 2);
    expect(container.read(preferencesProvider).pdfPageLayout, 'single');

    final notifier = container.read(preferencesProvider.notifier);
    notifier.updateReadingBrightness(0.72);
    notifier.updateBrightnessGestureEnabled(true);
    notifier.updateLineFocusEnabled(true);
    notifier.updateLineFocusLineCount(5);
    notifier.updateLineFocusDimAmount(0.42);
    notifier.updatePdfCropAmount(0.12);
    notifier.updatePdfContrast(1.6);
    notifier.updatePdfPageLayout('double');

    expect(container.read(preferencesProvider).readingBrightness, 0.72);
    expect(
      container.read(preferencesProvider).brightnessGestureEnabled,
      isTrue,
    );
    expect(preferences.getDouble('readingBrightness'), 0.72);
    expect(preferences.getBool('brightnessGestureEnabled'), isTrue);
    expect(container.read(preferencesProvider).lineFocusEnabled, isTrue);
    expect(container.read(preferencesProvider).lineFocusLineCount, 5);
    expect(container.read(preferencesProvider).lineFocusDimAmount, 0.42);
    expect(preferences.getBool('lineFocusEnabled'), isTrue);
    expect(preferences.getInt('lineFocusLineCount'), 5);
    expect(preferences.getDouble('lineFocusDimAmount'), 0.42);
    expect(container.read(preferencesProvider).pdfCropAmount, 0.12);
    expect(container.read(preferencesProvider).pdfContrast, 1.6);
    expect(container.read(preferencesProvider).pdfPageLayout, 'double');
    expect(preferences.getDouble('pdfCropAmount'), 0.12);
    expect(preferences.getDouble('pdfContrast'), 1.6);
    expect(preferences.getString('pdfPageLayout'), 'double');

    notifier.updatePdfPageLayout('grid');
    expect(container.read(preferencesProvider).pdfPageLayout, 'double');

    notifier.updateReadingBrightness(null);
    expect(container.read(preferencesProvider).readingBrightness, -1);
    expect(preferences.getDouble('readingBrightness'), -1);
  });
}
