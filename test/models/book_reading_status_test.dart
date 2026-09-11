import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/book_reading_status.dart';

void main() {
  test('manual reading status overrides automatic progress inference', () {
    expect(
      resolveBookReadingStatus(
        overrideValue: 'paused',
        percentage: 0.8,
        totalReadingSeconds: 3600,
      ),
      BookReadingStatus.paused,
    );
  });

  test('infers unread reading and finished without storing an override', () {
    expect(
      resolveBookReadingStatus(),
      BookReadingStatus.unread,
    );
    expect(
      resolveBookReadingStatus(totalReadingSeconds: 1),
      BookReadingStatus.reading,
    );
    expect(
      resolveBookReadingStatus(percentage: 0.5),
      BookReadingStatus.reading,
    );
    expect(
      resolveBookReadingStatus(percentage: 0.995),
      BookReadingStatus.finished,
    );
  });

  test('ignores unknown persisted values and clamps progress', () {
    expect(
      resolveBookReadingStatus(
        overrideValue: 'legacy-value',
        percentage: -1,
      ),
      BookReadingStatus.unread,
    );
    expect(
      resolveBookReadingStatus(percentage: 2),
      BookReadingStatus.finished,
    );
  });
}
