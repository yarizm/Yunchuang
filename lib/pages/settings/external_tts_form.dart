import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/external_tts.dart';
import '../../services/tts_service.dart';

/// 朗读引擎的选择，以及外部语音服务的配置。
///
/// 外部服务走 OpenAI 兼容的 `/audio/speech` 接口；地址、模型、声音都填了
/// 才生效，没填全时朗读继续用系统引擎。
class ExternalTtsForm extends ConsumerStatefulWidget {
  const ExternalTtsForm({super.key});

  @override
  ConsumerState<ExternalTtsForm> createState() => _ExternalTtsFormState();
}

class _ExternalTtsFormState extends ConsumerState<ExternalTtsForm> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _voice;
  bool _showApiKey = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(externalTtsSettingsProvider);
    _baseUrl = TextEditingController(text: saved.baseUrl);
    _apiKey = TextEditingController(text: saved.apiKey);
    _model = TextEditingController(text: saved.model);
    _voice = TextEditingController(text: saved.voice);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _voice.dispose();
    super.dispose();
  }

  ExternalTtsSettings _formSettings({required bool enabled}) {
    return ExternalTtsSettings(
      enabled: enabled,
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim(),
      voice: _voice.text.trim(),
    );
  }

  /// 存下来并立刻交给朗读服务，不等 provider 的监听转一圈：接下来马上
  /// 试听的话，要保证用的已经是新设置。
  ///
  /// 用到的 provider 都在第一个 await 之前取好：保存途中用户退出设置页的话，
  /// 之后再碰 ref 会抛异常，朗读服务就漏掉了这次设置。
  Future<void> _apply(ExternalTtsSettings settings) async {
    final notifier = ref.read(externalTtsSettingsProvider.notifier);
    final tts = ref.read(ttsServiceProvider);
    final saved = await notifier.save(settings);
    await tts.configureExternal(saved);
  }

  Future<void> _setEnabled(bool enabled) async {
    final saved = ref.read(externalTtsSettingsProvider);
    await _apply(saved.copyWith(enabled: enabled));
  }

  Future<bool> _save() async {
    final settings = _formSettings(enabled: true);
    if (!settings.isComplete) {
      _showMessage('服务地址、模型、声音都要填，地址以 http:// 或 https:// 开头。');
      return false;
    }
    await _apply(settings);
    return true;
  }

  Future<void> _saveAndPreview() async {
    final tts = ref.read(ttsServiceProvider);
    setState(() => _busy = true);
    try {
      if (!await _save()) return;
      final started = await tts.play('这是外部语音服务的试听。');
      if (!started && mounted) {
        _showMessage(tts.lastError ?? '外部语音服务试听失败。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(externalTtsSettingsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('朗读引擎', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.record_voice_over_outlined),
              label: Text('系统语音'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.cloud_outlined),
              label: Text('外部语音服务'),
            ),
          ],
          selected: {settings.enabled},
          onSelectionChanged: (selection) =>
              unawaited(_setEnabled(selection.single)),
        ),
        if (settings.enabled) ...[
          const SizedBox(height: 12),
          Text(
            '填 OpenAI 兼容的语音接口（/audio/speech），如 OpenAI、硅基流动，'
            '或自己搭的 openai-edge-tts、Kokoro。朗读的正文会发给这个服务。',
            style: theme.textTheme.bodySmall,
          ),
          if (!settings.isComplete) ...[
            const SizedBox(height: 8),
            Text(
              '还没填全，朗读暂时仍用系统语音。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('external-tts-base-url'),
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '服务地址',
              hintText: '例如 https://api.openai.com/v1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('external-tts-api-key'),
            controller: _apiKey,
            obscureText: !_showApiKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: '自建服务不需要可以留空',
              suffixIcon: IconButton(
                tooltip: _showApiKey ? '隐藏' : '显示',
                icon: Icon(
                  _showApiKey ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('external-tts-model'),
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型',
              hintText: '例如 tts-1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('external-tts-voice'),
            controller: _voice,
            decoration: const InputDecoration(
              labelText: '声音',
              hintText: '例如 alloy',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _save()) _showMessage('已保存。');
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _saveAndPreview,
                icon: const Icon(Icons.play_arrow),
                label: const Text('保存并试听'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
