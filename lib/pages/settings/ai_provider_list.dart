import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/ai/ai_http.dart';
import '../../providers/database_provider.dart';
import '../../theme/glass_page_route.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/empty_state.dart';
import 'ai_assets_page.dart';
import 'ai_provider_form.dart';

class AiProviderListPage extends ConsumerStatefulWidget {
  const AiProviderListPage({super.key});

  @override
  ConsumerState<AiProviderListPage> createState() => _AiProviderListPageState();
}

class _AiProviderListPageState extends ConsumerState<AiProviderListPage> {
  final Set<int> _deletingProviderIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(allAiProvidersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Provider'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton.filled(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            tooltip: 'AI 扩展',
            onPressed: () => Navigator.push(
              context,
              GlassPageRoute(builder: (_) => const AiAssetsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              GlassPageRoute(builder: (_) => const AiProviderFormPage()),
            ),
          ),
        ],
      ),
      body: providersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: GlassContainer.stable(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.error_outline,
                title: '加载失败',
                subtitle: describeAIError(error),
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
          if (providers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: GlassContainer.stable(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: EmptyState(
                    icon: Icons.smart_toy_outlined,
                    title: '还没有配置 AI Provider',
                    subtitle: '点击右上角 + 添加你的第一个 AI 服务',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        GlassPageRoute(
                            builder: (_) => const AiProviderFormPage()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('添加 Provider'),
                    ),
                  ),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final p = providers[index];
              final deleting = _deletingProviderIds.contains(p.id);
              return GlassContainer.stable(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: Icon(_iconForType(p.type)),
                    title: Text(p.name),
                    subtitle: Text('${p.type} · ${p.modelName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '默认',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: deleting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          tooltip: '删除 ${p.name}',
                          onPressed: deleting ? null : () => _delete(p),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        GlassPageRoute(
                          builder: (_) => AiProviderFormPage(provider: p),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'openai':
        return Icons.smart_toy;
      case 'ollama':
        return Icons.computer;
      case 'dify':
        return Icons.cloud;
      default:
        return Icons.api;
    }
  }

  Future<void> _delete(AiProvider provider) async {
    if (_deletingProviderIds.contains(provider.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Provider'),
        content: Text('确定要删除 ${provider.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingProviderIds.add(provider.id));
    try {
      await ref.read(aiServiceProvider).deleteProvider(provider.id);
      ref.invalidate(allAiProvidersProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：${describeAIError(error)}')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingProviderIds.remove(provider.id));
      }
    }
  }
}

final allAiProvidersProvider = FutureProvider<List<AiProvider>>((ref) {
  return ref.watch(aiServiceProvider).getProviders();
});
