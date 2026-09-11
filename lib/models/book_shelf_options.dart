enum BookSortMode {
  recentlyRead('最近阅读'),
  importedNewest('最近导入'),
  title('书名'),
  author('作者'),
  series('系列顺序'),
  readingTime('阅读时长');

  final String label;

  const BookSortMode(this.label);

  static BookSortMode fromStorage(String? value) {
    return BookSortMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => BookSortMode.recentlyRead,
    );
  }
}

enum BookShelfViewMode {
  grid,
  list;

  static BookShelfViewMode fromStorage(String? value) {
    return BookShelfViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => BookShelfViewMode.grid,
    );
  }
}
