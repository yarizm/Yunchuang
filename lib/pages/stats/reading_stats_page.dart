import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/progress_dao.dart';
import '../../providers/reading_stats_provider.dart';
import '../../utils/duration_format.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/reading_heatmap_grid.dart';

class ReadingStatsPage extends ConsumerStatefulWidget {
  const ReadingStatsPage({super.key});

  @override
  ConsumerState<ReadingStatsPage> createState() => _ReadingStatsPageState();
}

class _ReadingStatsPageState extends ConsumerState<ReadingStatsPage> {
  @override
  void initState() {
    super.initState();
    // 进入页面时刷新，确保今日时长/最新时长反映
    Future.microtask(() {
      ref.invalidate(readingStatsProvider);
      ref.invalidate(readingHeatmapProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(readingStatsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(title: const Text('统计')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                title: '今日时长',
                value: formatReadingDuration(stats.todaySeconds),
                icon: Icons.today,
                color: theme.colorScheme.primary,
              ),
              _StatCard(
                title: '累计时长',
                value: formatReadingDuration(stats.totalSeconds),
                icon: Icons.access_time,
                color: theme.colorScheme.tertiary,
              ),
              const _HeatmapCard(),
              const SizedBox(height: 16),
              GlassContainer.stable(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('时长排行', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    if (stats.topBooks.isEmpty)
                      const Text('暂无阅读记录')
                    else
                      ...stats.topBooks.map((b) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _BookRankRow(row: b),
                          )),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 热力图单独 watch 自己的 provider：一年的按天数据比上面几个数字慢，
/// 不该让「今日时长」等它。
class _HeatmapCard extends ConsumerWidget {
  const _HeatmapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(readingHeatmapProvider);

    return GlassContainer.stable(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('阅读日历', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          async.when(
            loading: () => const SizedBox(
              height: 132,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 132,
              child: Center(child: Text('加载失败：$e')),
            ),
            data: (heatmap) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeatmapSummary(heatmap: heatmap),
                const SizedBox(height: 16),
                ReadingHeatmapGrid(heatmap: heatmap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 热力图上方的四个汇总数字。
///
/// 热力图看得出模式，看不出数量；这一行补的是「本周读了多少」「连了几天」
/// 这类具体问题，数据来自同一份按天记录，不额外查库。
class _HeatmapSummary extends StatelessWidget {
  final ReadingHeatmap heatmap;

  const _HeatmapSummary({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final streak = heatmap.currentStreak();
    final longest = heatmap.longestStreak();

    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _SummaryItem(
          label: '本周',
          value: formatReadingDuration(heatmap.secondsThisWeek()),
        ),
        _SummaryItem(
          label: '本月',
          value: formatReadingDuration(heatmap.secondsThisMonth()),
        ),
        _SummaryItem(label: '连续', value: '$streak 天'),
        _SummaryItem(label: '最长连续', value: '$longest 天'),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer.stable(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookRankRow extends StatelessWidget {
  final BookSecondsRow row;
  const _BookRankRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(row.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            formatReadingDuration(row.totalSeconds),
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
