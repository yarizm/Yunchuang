import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../database/app_database.dart';
import '../../providers/ai/ai_http.dart';
import '../../providers/database_provider.dart';
import '../../widgets/glass_container.dart';
import 'ai_provider_list.dart';

class AiProviderFormPage extends ConsumerStatefulWidget {
  final AiProvider? provider; // null = create, non-null = edit
  const AiProviderFormPage({super.key, this.provider});

  @override
  ConsumerState<AiProviderFormPage> createState() => _AiProviderFormPageState();
}

class _AiProviderFormPageState extends ConsumerState<AiProviderFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  final _urlDrafts = <String, String>{};
  final _keyDrafts = <String, String>{};
  final _modelDrafts = <String, String>{};
  bool _isDefault = false;
  bool _saving = false;
  bool _testing = false;
  bool _apiKeyVisible = false;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _type = p?.type ?? 'openai';
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _urlCtrl = TextEditingController(text: p?.baseUrl ?? _defaultUrl(_type));
    _keyCtrl = TextEditingController(text: p?.apiKey ?? '');
    _modelCtrl = TextEditingController(text: p?.modelName ?? '');
    _urlDrafts[_type] = _urlCtrl.text;
    _keyDrafts[_type] = _keyCtrl.text;
    _modelDrafts[_type] = _modelCtrl.text;
    _isDefault = p?.isDefault ?? false;
  }

  String _defaultUrl(String type) {
    switch (type) {
      case 'openai':
        return 'https://api.openai.com/v1';
      case 'ollama':
        return 'http://localhost:11434';
      case 'dify':
        return 'http://localhost/v1';
      default:
        return '';
    }
  }

  Future<void> _save() async {
    if (_saving || _testing || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(aiServiceProvider);
    final apiKey = _keyCtrl.text.trim();
    final companion = AiProvidersCompanion(
      name: drift.Value(_nameCtrl.text.trim()),
      type: drift.Value(_type),
      baseUrl: drift.Value(_urlCtrl.text.trim()),
      apiKey: drift.Value(apiKey.isEmpty ? null : apiKey),
      modelName: drift.Value(_type == 'dify' ? '' : _modelCtrl.text.trim()),
      isDefault: drift.Value(_isDefault),
    );

    try {
      await service.saveProvider(
        companion,
        providerId: widget.provider?.id,
        makeDefault: _isDefault,
      );
      ref.invalidate(allAiProvidersProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：${describeAIError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(
        title: Text(widget.provider != null ? '编辑 Provider' : '添加 Provider'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '配置手册',
            onPressed: _showHelp,
          ),
          TextButton(
            onPressed: _saving || _testing ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassContainer.stable(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'openai', label: Text('OpenAI')),
                      ButtonSegment(value: 'ollama', label: Text('Ollama')),
                      ButtonSegment(value: 'dify', label: Text('Dify')),
                      ButtonSegment(value: 'custom', label: Text('自定义')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) =>
                        _switchProviderType(selection.first),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameCtrl,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: '显示名称',
                      hintText: '例如：我的 OpenAI',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return '请输入名称';
                      if (value.length > 100) return '名称不能超过 100 个字符';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API 端点',
                      hintText: 'https://api.openai.com/v1',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEndpoint,
                  ),
                  const SizedBox(height: 16),
                  if (_type != 'ollama')
                    TextFormField(
                      controller: _keyCtrl,
                      obscureText: !_apiKeyVisible,
                      obscuringCharacter: '•',
                      decoration: InputDecoration(
                        labelText: 'API 密钥',
                        hintText: 'sk-...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _apiKeyVisible ? '隐藏 API 密钥' : '显示 API 密钥',
                          onPressed: () => setState(
                            () => _apiKeyVisible = !_apiKeyVisible,
                          ),
                          icon: Icon(
                            _apiKeyVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (_type == 'dify' &&
                            (value == null || value.trim().isEmpty)) {
                          return '请输入 Dify App API Key';
                        }
                        return null;
                      },
                    ),
                  if (_type != 'ollama') const SizedBox(height: 16),
                  if (_type != 'dify')
                    TextFormField(
                      controller: _modelCtrl,
                      decoration: const InputDecoration(
                        labelText: '模型名称',
                        hintText: 'gpt-4o-mini',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请输入模型名' : null,
                    ),
                  if (_type != 'dify') const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      title: const Text('设为默认 Provider'),
                      subtitle: const Text('阅读页 AI 助手将优先使用此服务',
                          style: TextStyle(fontSize: 12)),
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving || _testing ? null : _testProvider,
                    icon: _testing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: Text(_testing ? '正在测试' : '测试连接'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchProviderType(String nextType) {
    if (nextType == _type) return;
    _urlDrafts[_type] = _urlCtrl.text;
    _keyDrafts[_type] = _keyCtrl.text;
    _modelDrafts[_type] = _modelCtrl.text;

    setState(() {
      _type = nextType;
      _urlCtrl.text = _urlDrafts[nextType] ?? _defaultUrl(nextType);
      _keyCtrl.text = _keyDrafts[nextType] ?? '';
      _modelCtrl.text = _modelDrafts[nextType] ?? '';
      _apiKeyVisible = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _testProvider() async {
    if (_saving || _testing || !_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    final apiKey = _keyCtrl.text.trim();
    final config = AiProvider(
      id: widget.provider?.id ?? -1,
      name: _nameCtrl.text.trim(),
      type: _type,
      baseUrl: _urlCtrl.text.trim(),
      apiKey: apiKey.isEmpty ? null : apiKey,
      modelName: _type == 'dify' ? '' : _modelCtrl.text.trim(),
      isDefault: _isDefault,
      extraConfig: null,
    );
    try {
      final ok = await ref.read(aiServiceProvider).testProvider(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '连接成功' : _providerTroubleshootingText())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${describeAIError(error)}\n${_providerTroubleshootingText()}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String? _validateEndpoint(String? value) {
    final endpoint = value?.trim() ?? '';
    if (endpoint.isEmpty) return '请输入端点 URL';
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return '请输入有效的 HTTP(S) 端点';
    }
    return null;
  }

  String _providerTroubleshootingText() {
    switch (_type) {
      case 'ollama':
        return '连接失败：请确认 Ollama 已启动且模型已经拉取。手机不能使用 localhost，需要填写电脑局域网 IP。';
      case 'dify':
        return '连接失败：请确认 Base URL、App API Key 和 Dify 应用类型。';
      default:
        return '连接失败：请确认 API 端点、API Key、模型名称和网络环境。';
    }
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: const [
              Text(
                'AI Provider 配置手册',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('显示名称：只在本地用于区分不同供应商，可以随意填写。'),
              SizedBox(height: 12),
              Text(
                  'API 端点：OpenAI 兼容服务通常以 /v1 结尾，例如 https://api.openai.com/v1。'),
              SizedBox(height: 12),
              Text('API Key：从供应商控制台获取。不要把 Key 分享给他人。'),
              SizedBox(height: 12),
              Text(
                  '模型名称：填写供应商提供的模型 id，例如 gpt-4o-mini、deepseek-chat、qwen-plus。'),
              SizedBox(height: 12),
              Text(
                  'Ollama：先在运行 Ollama 的设备上执行 ollama pull 模型名。手机不能填写 localhost，需要填写电脑局域网 IP，例如 http://192.168.1.10:11434。'),
              SizedBox(height: 12),
              Text('Dify：填写 Dify 应用的 API Base URL 和 App API Key。当前只适合聊天类应用。'),
              SizedBox(height: 12),
              Text('自定义：需要兼容 OpenAI Chat Completions 风格接口。'),
            ],
          ),
        ),
      ),
    );
  }
}
