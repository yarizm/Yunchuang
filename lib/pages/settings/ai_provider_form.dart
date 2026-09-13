import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../database/app_database.dart';
import '../../providers/ai/ai_http.dart';
import '../../providers/ai/ai_provider_templates.dart';
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
  bool _loadingModels = false;
  bool _apiKeyVisible = false;

  /// 当前套用的模板：给模型建议、Key 的获取地址。按端点反查，所以手改了
  /// 端点它就对不上了，改回来又能对上。
  AiProviderTemplate? get _template =>
      AiProviderTemplate.matching(type: _type, baseUrl: _urlCtrl.text);

  /// 从服务端拉回来的模型列表；拉过之后下拉里优先显示它。
  List<String> _fetchedModels = const [];

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

  /// 只重建依赖端点的那几块（模板标签、Key 地址、模型建议）。不在 onChanged
  /// 里 setState 整个表单：每敲一个字都重建，正在往别的框里输的字会被冲掉。
  Widget _byEndpoint(Widget Function(AiProviderTemplate? template) builder) {
    return ListenableBuilder(
      listenable: _urlCtrl,
      builder: (context, _) => builder(_template),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 模板：选一个就把类型、端点、模型填好，只剩 Key 要填。
                  _byEndpoint(
                    (template) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('ai-provider-template-button'),
                          onPressed: _saving || _testing ? null : _pickTemplate,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(
                            template == null ? '从模板填入' : '模板：${template.name}',
                          ),
                        ),
                        if (template != null && template.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(template.note, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 4),
                  Text(
                    _type == 'ollama'
                        ? '本机或局域网里的 Ollama。'
                        : _type == 'dify'
                            ? 'Dify 应用的聊天接口。'
                            : 'OpenAI 风格的 Chat Completions 接口：OpenAI、Claude、'
                                'Gemini、DeepSeek、通义千问、Kimi、智谱、硅基流动、'
                                'OpenRouter 都是。',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
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
                  if (_type != 'ollama') ...[
                    TextFormField(
                      controller: _keyCtrl,
                      obscureText: !_apiKeyVisible,
                      obscuringCharacter: '•',
                      decoration: InputDecoration(
                        labelText: _type == 'dify' ? 'App API Key' : 'API 密钥',
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
                    _byEndpoint(
                      (template) => template?.consoleUrl == null
                          ? const SizedBox.shrink()
                          : _ConsoleLink(url: template!.consoleUrl!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_type != 'dify') ...[
                    _byEndpoint(
                      (template) => TextFormField(
                        controller: _modelCtrl,
                        decoration: InputDecoration(
                          labelText: '模型名称',
                          hintText: template?.defaultModel.isNotEmpty == true
                              ? template!.defaultModel
                              : (_type == 'ollama'
                                  ? 'qwen3.6:8b'
                                  : 'gpt-5.6-terra'),
                          border: const OutlineInputBorder(),
                          suffixIcon: _ModelMenu(
                            models: _fetchedModels.isNotEmpty
                                ? _fetchedModels
                                : (template?.models ?? const <String>[]),
                            loading: _loadingModels,
                            onPick: (model) => _modelCtrl.text = model,
                            onFetch: _saving || _testing || _loadingModels
                                ? null
                                : _fetchModels,
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '请输入模型名' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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

  Future<void> _pickTemplate() async {
    final picked = await showModalBottomSheet<AiProviderTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '选一个服务商，填好端点和模型；你只需要填 Key。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              for (final template in AiProviderTemplate.all)
                ListTile(
                  key: Key('ai-provider-template-${template.id}'),
                  title: Text(template.name),
                  subtitle: Text(
                    template.models.isEmpty
                        ? template.baseUrl
                        : '${template.models.first} · ${template.baseUrl}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(ctx, template),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _applyTemplate(picked);
  }

  void _applyTemplate(AiProviderTemplate template) {
    // 先把当前类型的草稿存好，模板换了类型时才能切回来。
    _urlDrafts[_type] = _urlCtrl.text;
    _keyDrafts[_type] = _keyCtrl.text;
    _modelDrafts[_type] = _modelCtrl.text;
    _type = template.type;
    _urlCtrl.text = template.baseUrl;
    _keyCtrl.text = _keyDrafts[template.type] ?? '';
    _modelCtrl.text = template.defaultModel;
    if (_nameCtrl.text.trim().isEmpty ||
        AiProviderTemplate.all.any((t) => t.name == _nameCtrl.text.trim())) {
      _nameCtrl.text = template.name;
    }
    setState(() {
      _fetchedModels = const [];
      _apiKeyVisible = false;
    });
  }

  /// 问服务端要模型列表，省得去翻文档抄模型名。
  Future<void> _fetchModels() async {
    if (_validateEndpoint(_urlCtrl.text) != null) {
      _toast('先填一个有效的 API 端点');
      return;
    }
    setState(() => _loadingModels = true);
    final apiKey = _keyCtrl.text.trim();
    final config = AiProvider(
      id: widget.provider?.id ?? -1,
      name: _nameCtrl.text.trim(),
      type: _type,
      baseUrl: _urlCtrl.text.trim(),
      apiKey: apiKey.isEmpty ? null : apiKey,
      modelName: _modelCtrl.text.trim(),
      isDefault: _isDefault,
      extraConfig: null,
    );
    try {
      final models = await ref.read(aiServiceProvider).listModels(config);
      if (!mounted) return;
      if (models.isEmpty) {
        _toast('服务端没有返回模型列表');
        return;
      }
      setState(() => _fetchedModels = models);
      _toast('拉到 ${models.length} 个模型，点模型框右侧选择');
    } catch (error) {
      if (mounted) _toast('拉取失败：${describeAIError(error)}');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _switchProviderType(String nextType) {
    if (nextType == _type) return;
    _urlDrafts[_type] = _urlCtrl.text;
    _keyDrafts[_type] = _keyCtrl.text;
    _modelDrafts[_type] = _modelCtrl.text;

    _type = nextType;
    _urlCtrl.text = _urlDrafts[nextType] ?? _defaultUrl(nextType);
    _keyCtrl.text = _keyDrafts[nextType] ?? '';
    _modelCtrl.text = _modelDrafts[nextType] ?? '';
    setState(() {
      _fetchedModels = const [];
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

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              Text('最省事的路：点「从模板填入」选服务商，填上 Key，'
                  '再点「测试连接」。模板里的模型名会过时，可以在模型框右侧'
                  '「从服务端拉取」拿最新的列表。'),
              SizedBox(height: 12),
              Text('显示名称：只在本地用于区分不同供应商，可以随意填写。'),
              SizedBox(height: 12),
              Text('API 端点：OpenAI 兼容服务通常以 /v1 结尾，'
                  '例如 https://api.openai.com/v1。Claude 用 '
                  'https://api.anthropic.com/v1，Gemini 用 '
                  'https://generativelanguage.googleapis.com/v1beta/openai。'),
              SizedBox(height: 12),
              Text('API Key：从供应商控制台获取。不要把 Key 分享给他人，'
                  '备份也不会带着它。'),
              SizedBox(height: 12),
              Text('模型名称：填供应商的模型 id，例如 gpt-5.6-terra、'
                  'claude-sonnet-5、deepseek-flash、qwen-plus、kimi-k3、'
                  'glm-5.3-flash。硅基流动、OpenRouter 这类转接平台的模型名'
                  '带厂商前缀，如 deepseek-ai/DeepSeek-V4-Flash。'),
              SizedBox(height: 12),
              Text('Ollama：先在运行 Ollama 的设备上执行 ollama pull 模型名。'
                  '手机不能填写 localhost，需要填写电脑局域网 IP，'
                  '例如 http://192.168.1.10:11434。'),
              SizedBox(height: 12),
              Text('Dify：填写 Dify 应用的 API Base URL 和 App API Key。'
                  '当前只适合聊天类应用。'),
              SizedBox(height: 12),
              Text('自定义：任何兼容 OpenAI Chat Completions 风格接口的服务，'
                  '包括自己搭的 vLLM、LM Studio 等。'),
              SizedBox(height: 12),
              Text('用量：每次请求的 token 数记在 Provider 列表的「用量」里，'
                  '服务端返回了 usage 就用准确值，没返回就按字数估。'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Key 的获取地址。没有 url_launcher，长按 / 点复制。
class _ConsoleLink extends StatelessWidget {
  final String url;

  const _ConsoleLink({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '在这里获取 Key：$url',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            key: const Key('ai-provider-copy-console-url'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制地址，去浏览器里打开')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  }
}

/// 模型框右侧的下拉：模板里的建议 / 服务端拉回来的列表，以及「从服务端拉取」。
class _ModelMenu extends StatelessWidget {
  final List<String> models;
  final bool loading;
  final ValueChanged<String> onPick;
  final VoidCallback? onFetch;

  const _ModelMenu({
    required this.models,
    required this.loading,
    required this.onPick,
    required this.onFetch,
  });

  static const _fetchValue = ' fetch';

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      key: const Key('ai-provider-model-menu'),
      tooltip: '选择模型',
      icon: const Icon(Icons.arrow_drop_down),
      onSelected: (value) {
        if (value == _fetchValue) {
          onFetch?.call();
        } else {
          onPick(value);
        }
      },
      itemBuilder: (context) => [
        for (final model in models)
          PopupMenuItem(value: model, child: Text(model)),
        if (models.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem(
          value: _fetchValue,
          enabled: onFetch != null,
          child: const Row(
            children: [
              Icon(Icons.cloud_download_outlined, size: 18),
              SizedBox(width: 8),
              Text('从服务端拉取模型列表'),
            ],
          ),
        ),
      ],
    );
  }
}
