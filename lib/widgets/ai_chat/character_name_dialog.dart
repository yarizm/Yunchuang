import 'package:flutter/material.dart';

import '../../providers/ai/ai_http.dart';
import '../../providers/ai/ai_provider.dart';

/// 生成角色人设前问一句角色名。
///
/// 从 `AiChatPanel` 拆出来：它不依赖面板的任何状态，只回一个字符串。
class CharacterNameDialog extends StatefulWidget {
  final Future<String> Function(AIRequestCancellation cancellation)
      discoverCharacters;

  const CharacterNameDialog({super.key, required this.discoverCharacters});

  @override
  State<CharacterNameDialog> createState() => _CharacterNameDialogState();
}

class _CharacterNameDialogState extends State<CharacterNameDialog> {
  final _controller = TextEditingController();
  String? _suggestions;
  bool _loading = false;
  AIRequestCancellation? _discoveryCancellation;

  Future<void> _discoverCharacters() async {
    _discoveryCancellation?.cancel('已开始新的角色推荐请求。');
    final cancellation = AIRequestCancellation();
    _discoveryCancellation = cancellation;
    setState(() {
      _loading = true;
      _suggestions = null;
    });
    try {
      final value = await widget.discoverCharacters(cancellation);
      if (!mounted) return;
      setState(() => _suggestions = value);
    } on AIRequestCancelledException {
      return;
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _suggestions = '推荐失败：${describeAIError(error)}',
      );
    } finally {
      if (identical(_discoveryCancellation, cancellation)) {
        _discoveryCancellation = null;
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _discoveryCancellation?.cancel('角色名弹窗已关闭。');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入角色名'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '例如：方源'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _discoverCharacters,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('让 AI 总结主要角色'),
            ),
            if (_suggestions?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: SelectableText(_suggestions!),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('开始'),
        ),
      ],
    );
  }
}
