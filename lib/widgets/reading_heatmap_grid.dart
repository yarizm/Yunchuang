import 'package:flutter/material.dart';

import '../providers/reading_stats_provider.dart';
import '../utils/duration_format.dart';
import '../utils/local_date.dart';

const _cellSize = 13.0;
const _cellGap = 3.0;
const _columnWidth = _cellSize + _cellGap;
const _weekdayLabelWidth = 20.0;
const _monthLabelHeight = 16.0;

/// 按周分列的阅读热力图，横向可滚动，初始停在最近一周。
///
/// 一年 53 列在手机宽度上放不下。缩小格子会小到点不中，所以选择横向滚动
/// 而不是压缩——统计页其余内容仍是纵向列表，只有这一块横向滚。
class ReadingHeatmapGrid extends StatefulWidget {
  final ReadingHeatmap heatmap;

  const ReadingHeatmapGrid({super.key, required this.heatmap});

  @override
  State<ReadingHeatmapGrid> createState() => _ReadingHeatmapGridState();
}

class _ReadingHeatmapGridState extends State<ReadingHeatmapGrid> {
  final _scrollController = ScrollController();
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    // 默认看最近的日期，而不是一年前。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heatmap = widget.heatmap;
    final todayKey = localDateString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _monthLabelHeight),
              child: _WeekdayLabels(style: theme.textTheme.bodySmall),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MonthLabels(
                      heatmap: heatmap,
                      style: theme.textTheme.bodySmall,
                    ),
                    _Grid(
                      heatmap: heatmap,
                      todayKey: todayKey,
                      selectedIndex: _selectedIndex,
                      onTapCell: (index) => setState(() {
                        _selectedIndex = _selectedIndex == index ? null : index;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Footer(
          heatmap: heatmap,
          selectedIndex: _selectedIndex,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// 星期标签只标一、三、五，七行全标会挤成一团。
class _WeekdayLabels extends StatelessWidget {
  final TextStyle? style;
  const _WeekdayLabels({this.style});

  @override
  Widget build(BuildContext context) {
    const labels = ['一', '', '三', '', '五', '', ''];
    return Column(
      children: [
        for (final label in labels)
          SizedBox(
            height: _columnWidth,
            width: _weekdayLabelWidth,
            child: Text(label, style: style),
          ),
      ],
    );
  }
}

class _MonthLabels extends StatelessWidget {
  final ReadingHeatmap heatmap;
  final TextStyle? style;

  const _MonthLabels({required this.heatmap, this.style});

  @override
  Widget build(BuildContext context) {
    // 每列取该列周一的月份，月份变了就在那一列打标签。
    final labels = <int, String>{};
    var lastMonth = -1;
    for (var week = 0; week < heatmap.weekCount; week++) {
      final month = heatmap.dateAt(week * 7).month;
      if (month != lastMonth) {
        labels[week] = '$month月';
        lastMonth = month;
      }
    }

    return SizedBox(
      height: _monthLabelHeight,
      width: heatmap.weekCount * _columnWidth,
      child: Stack(
        children: [
          for (final entry in labels.entries)
            Positioned(
              left: entry.key * _columnWidth,
              top: 0,
              child: Text(entry.value, style: style),
            ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final ReadingHeatmap heatmap;
  final String todayKey;
  final int? selectedIndex;
  final ValueChanged<int> onTapCell;

  const _Grid({
    required this.heatmap,
    required this.todayKey,
    required this.selectedIndex,
    required this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var week = 0; week < heatmap.weekCount; week++)
          Column(
            children: [
              for (var day = 0; day < 7; day++)
                _buildCell(theme, week * 7 + day),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(ThemeData theme, int index) {
    final key = localDateString(heatmap.dateAt(index));
    // 本周里还没到的那几天留空，不画成「没读书」。
    // 日期是零填充的 yyyy-MM-dd，字典序即时间序。
    final isFuture = key.compareTo(todayKey) > 0;
    final level = heatLevel(heatmap.secondsAt(index), heatmap.maxSeconds);

    return Padding(
      padding: const EdgeInsets.only(right: _cellGap, bottom: _cellGap),
      child: GestureDetector(
        onTap: isFuture ? null : () => onTapCell(index),
        child: Container(
          key: ValueKey('heatmap-cell-$key'),
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: isFuture ? Colors.transparent : levelColor(theme, level),
            borderRadius: BorderRadius.circular(3),
            border: _border(theme, index, key),
          ),
        ),
      ),
    );
  }

  BoxBorder? _border(ThemeData theme, int index, String key) {
    if (selectedIndex == index) {
      return Border.all(color: theme.colorScheme.onSurface, width: 1.2);
    }
    if (key == todayKey) {
      return Border.all(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      );
    }
    return null;
  }
}

/// 色阶配色。0 档是「有这一天但没读」，用极淡的前景色而不是透明，
/// 否则会和未来日期的空白混淆。
Color levelColor(ThemeData theme, int level) {
  final base = theme.colorScheme.primary;
  return switch (level) {
    0 => theme.colorScheme.onSurface.withValues(alpha: 0.06),
    1 => base.withValues(alpha: 0.25),
    2 => base.withValues(alpha: 0.45),
    3 => base.withValues(alpha: 0.7),
    _ => base,
  };
}

class _Footer extends StatelessWidget {
  final ReadingHeatmap heatmap;
  final int? selectedIndex;
  final TextStyle? style;

  const _Footer({
    required this.heatmap,
    required this.selectedIndex,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selectedIndex;

    if (selected != null) {
      final seconds = heatmap.secondsAt(selected);
      final date = localDateString(heatmap.dateAt(selected));
      final detail = seconds > 0 ? formatReadingDuration(seconds) : '没有阅读记录';
      return Text('$date  $detail', style: style);
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            heatmap.isEmpty ? '还没有阅读记录' : '点格子看当天时长',
            style: style,
          ),
        ),
        Text('少', style: style),
        const SizedBox(width: 4),
        for (var level = 0; level <= 4; level++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: levelColor(theme, level),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 1),
        Text('多', style: style),
      ],
    );
  }
}
