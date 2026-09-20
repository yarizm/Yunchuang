import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ai/agent_models.dart';
import '../../providers/ai/spoiler_protection_provider.dart';
import '../../widgets/glass_container.dart';

class AiReadingSafetyPage extends ConsumerWidget {
  const AiReadingSafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(spoilerProtectionProvider);
    final notifier = ref.read(spoilerProtectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 阅读安全')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer.stable(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              type: MaterialType.transparency,
              child: RadioGroup<SpoilerProtectionLevel>(
                groupValue: settings.defaultLevel,
                onChanged: (level) {
                  if (level != null) notifier.updateDefaultLevel(level);
                },
                child: Column(
                  children: [
                    _ProtectionLevelTile(
                      level: SpoilerProtectionLevel.strict,
                      title: '严格防剧透',
                      subtitle: 'AI 只能检索当前阅读位置之前的内容',
                      selected: settings.defaultLevel ==
                          SpoilerProtectionLevel.strict,
                    ),
                    const SizedBox(height: 4),
                    _ProtectionLevelTile(
                      level: SpoilerProtectionLevel.ask,
                      title: '访问前询问',
                      subtitle: '需要未读内容时先请求本次授权',
                      selected:
                          settings.defaultLevel == SpoilerProtectionLevel.ask,
                    ),
                    const SizedBox(height: 4),
                    _ProtectionLevelTile(
                      level: SpoilerProtectionLevel.fullBook,
                      title: '允许全书',
                      subtitle: 'AI 可以检索后续章节，回答可能包含剧透',
                      selected: settings.defaultLevel ==
                          SpoilerProtectionLevel.fullBook,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionLevelTile extends StatelessWidget {
  final SpoilerProtectionLevel level;
  final String title;
  final String subtitle;
  final bool selected;

  const _ProtectionLevelTile({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.82)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.38)
              : Colors.transparent,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        child: RadioListTile<SpoilerProtectionLevel>(
          value: level,
          selected: selected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}
