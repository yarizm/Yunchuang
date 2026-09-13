import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/ai/ai_usage.dart';
import '../../providers/database_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';
import 'ai_provider_list.dart';

/// 各 Provider 的 token 用量：今日 / 累计，输入 / 输出。
///
/// 只是个计数器，不是账单：服务端返回了 usage 才是准确值，没返回的按字数
/// 估，估过的请求数单独标出来。价格各家各模型都不一样，这里不折算成钱。
class AiUsagePage extends ConsumerWidget {
  const AiUsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tracker = ref.watch(aiUsageTrackerProvider);
    final providersAsync = ref.watch(allAiProvidersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 用量'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton.filled(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('ai-usage-reset-all'),
            icon: const Icon(Icons.restart_alt),
            tooltip: '全部清零',
            onPressed: tracker.all.isEmpty
                ? null
                : () => _confirmReset(context, () => tracker.resetAll()),
          ),
        ],
      ),
      body: providersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: GlassContainer.stable(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.error_outline,
                title: '加载失败',
                subtitle: '$error',
                action: FilledButton.icon(
                  onPressed: () => ref.invalidate(allAiProvidersProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ),
            ),
          ),
        ),
        data: (providers) {
          final rows = [
            for (final provider in providers)
              (provider: provider, usage: tracker.usageFor(provider.id)),
          ];
          final total = rows.fold(0, (sum, row) => sum + row.usage.totalTokens);
          final today = rows.fold(
            0,
            (sum, row) => sum + row.usage.todayTotalTokens,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassContainer.stable(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: '今日',
                        value: formatTokenCount(today),
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: '累计',
                        value: formatTokenCount(total),
                      ),
                    ),
                  ],
                ),
              ),
              if (rows.isEmpty)
                const GlassContainer.stable(
                  padding: EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  child: EmptyState(
                    icon: Icons.data_usage_outlined,
                    title: '还没有配置 AI Provider',
                    subtitle: '配置并用过之后，这里按 Provider 统计 token',
                  ),
                )
              else
                for (final row in rows)
                  _ProviderUsageCard(
                    provider: row.provider,
                    usage: row.usage,
                    onReset: row.usage.isEmpty
                        ? null
                        : () => _confirmReset(
                              context,
                              () => tracker.reset(row.provider.id),
                            ),
                  ),
              const SizedBox(height: 8),
              Text(
                '数字是 token 数，不是费用。服务端返回了 usage 就记准确值；'
                '没返回的按字数估：中文约 0.7 token / 字，英文约 4 字符 / token。'
                '「测试连接」不计入。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, VoidCallback reset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清零用量'),
        content: const Text('只清本机的计数，不影响服务商那边的账单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清零'),
          ),
        ],
      ),
    );
    if (confirmed == true) reset();
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '≈ $value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text('tokens', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ProviderUsageCard extends StatelessWidget {
  final AiProvider provider;
  final AiProviderUsage usage;
  final VoidCallback? onReset;

  const _ProviderUsageCard({
    required this.provider,
    required this.usage,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer.stable(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.name, style: theme.textTheme.titleSmall),
                    Text(
                      provider.modelName.isEmpty
                          ? provider.type
                          : '${provider.type} · ${provider.modelName}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('ai-usage-reset-${provider.id}'),
                tooltip: '清零',
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (usage.isEmpty)
            Text('还没有用过', style: theme.textTheme.bodySmall)
          else ...[
            _UsageLine(
              label: '今日',
              prompt: usage.todayPromptTokens,
              completion: usage.todayCompletionTokens,
              requests: usage.todayRequests,
            ),
            const SizedBox(height: 6),
            _UsageLine(
              label: '累计',
              prompt: usage.promptTokens,
              completion: usage.completionTokens,
              requests: usage.requests,
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (usage.since != null) '自 ${_formatDate(usage.since!)} 起',
                if (usage.estimatedRequests > 0)
                  '${usage.estimatedRequests} 次按字数估算',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }
}

class _UsageLine extends StatelessWidget {
  final String label;
  final int prompt;
  final int completion;
  final int requests;

  const _UsageLine({
    required this.label,
    required this.prompt,
    required this.completion,
    required this.requests,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '≈ ${formatTokenCount(prompt + completion)} tokens',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '输入 ${formatTokenCount(prompt)} · 输出 ${formatTokenCount(completion)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text('$requests 次', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
