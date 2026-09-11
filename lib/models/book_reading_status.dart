enum BookReadingStatus {
  unread('unread', '未读'),
  reading('reading', '阅读中'),
  finished('finished', '已读完'),
  paused('paused', '暂停');

  final String storageValue;
  final String label;

  const BookReadingStatus(this.storageValue, this.label);

  static BookReadingStatus? fromStorage(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final status in values) {
      if (status.storageValue == value) return status;
    }
    return null;
  }
}

BookReadingStatus resolveBookReadingStatus({
  String? overrideValue,
  double? percentage,
  int? totalReadingSeconds,
}) {
  final override = BookReadingStatus.fromStorage(overrideValue);
  if (override != null) return override;

  final normalizedPercentage = (percentage ?? 0).clamp(0.0, 1.0);
  if (normalizedPercentage >= 0.995) {
    return BookReadingStatus.finished;
  }
  if (normalizedPercentage > 0 || (totalReadingSeconds ?? 0) > 0) {
    return BookReadingStatus.reading;
  }
  return BookReadingStatus.unread;
}
