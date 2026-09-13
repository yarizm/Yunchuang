import 'package:flutter/foundation.dart';

/// 常见服务商的接入模板：选一个，填 Key 就能用。
///
/// 端点和模型名核对于 2026-09（各家官方文档 / OpenRouter 模型列表）。模型
/// 名会过期，所以表单上还有「拉取模型列表」，从服务端 `/models` 拿现成的；
/// 这里的列表只是离线时的起点。
@immutable
class AiProviderTemplate {
  final String id;
  final String name;

  /// `ai_providers.type`：openai / ollama / dify。
  final String type;
  final String baseUrl;

  /// 建议的模型，第一个是默认值。Ollama / Dify 为空。
  final List<String> models;

  /// 去哪里拿 Key。
  final String? consoleUrl;

  /// 一两句提示，显示在表单里。
  final String note;

  const AiProviderTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.models = const [],
    this.consoleUrl,
    this.note = '',
  });

  String get defaultModel => models.isEmpty ? '' : models.first;

  bool get needsApiKey => type != 'ollama';

  static const List<AiProviderTemplate> all = [
    AiProviderTemplate(
      id: 'openai',
      name: 'OpenAI',
      type: 'openai',
      baseUrl: 'https://api.openai.com/v1',
      models: ['gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.6-sol', 'gpt-6-astra'],
      consoleUrl: 'https://platform.openai.com/api-keys',
      note: 'Terra 性价比均衡，Luna 便宜量大，Sol / GPT-6 Astra 最强也最贵。',
    ),
    AiProviderTemplate(
      id: 'anthropic',
      name: 'Anthropic Claude',
      type: 'openai',
      baseUrl: 'https://api.anthropic.com/v1',
      models: [
        'claude-sonnet-5',
        'claude-opus-5',
        'claude-haiku-4-5',
        'claude-fable-5-1',
      ],
      consoleUrl: 'https://platform.claude.com/settings/keys',
      note: '走 Anthropic 的 OpenAI 兼容层。Sonnet 5 快且够用，Opus 5 更强。',
    ),
    AiProviderTemplate(
      id: 'gemini',
      name: 'Google Gemini',
      type: 'openai',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      models: [
        'gemini-3.8-flash',
        'gemini-3.1-pro-preview',
        'gemini-3.5-flash-lite',
      ],
      consoleUrl: 'https://aistudio.google.com/apikey',
      note: 'AI Studio 的 Key 有免费额度。3.8 Flash 是当前的稳定版。',
    ),
    AiProviderTemplate(
      id: 'deepseek',
      name: 'DeepSeek',
      type: 'openai',
      baseUrl: 'https://api.deepseek.com',
      models: ['deepseek-flash', 'deepseek-v4-pro'],
      consoleUrl: 'https://platform.deepseek.com/api_keys',
      note: 'Flash 便宜快，V4 Pro 是旗舰。',
    ),
    AiProviderTemplate(
      id: 'qwen',
      name: '通义千问（阿里云百炼）',
      type: 'openai',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      models: ['qwen-plus', 'qwen3.8-max', 'qwen-max'],
      consoleUrl: 'https://bailian.console.aliyun.com/?apiKey=1#/api-key',
      note: 'qwen-plus 是通用档，qwen3.8-max 最强。',
    ),
    AiProviderTemplate(
      id: 'kimi',
      name: 'Kimi（月之暗面）',
      type: 'openai',
      baseUrl: 'https://api.moonshot.cn/v1',
      models: ['kimi-k3', 'kimi-k2.6'],
      consoleUrl: 'https://platform.kimi.com/console/api-keys',
      note: 'K3 是当前旗舰。',
    ),
    AiProviderTemplate(
      id: 'zhipu',
      name: '智谱 GLM',
      type: 'openai',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      models: ['glm-5.3-flash', 'glm-5.3', 'glm-4.7-flash'],
      consoleUrl: 'https://bigmodel.cn/usercenter/proj-mgmt/apikeys',
      note: 'GLM-4.7-Flash 免费；5.3 系列是旗舰。',
    ),
    AiProviderTemplate(
      id: 'siliconflow',
      name: '硅基流动 SiliconFlow',
      type: 'openai',
      baseUrl: 'https://api.siliconflow.cn/v1',
      models: [
        'deepseek-ai/DeepSeek-V4-Flash',
        'deepseek-ai/DeepSeek-V4-Pro',
        'Qwen/Qwen3.6-35B-A3B',
        'zai-org/GLM-5.3',
        'moonshotai/Kimi-K2.6',
      ],
      consoleUrl: 'https://cloud.siliconflow.cn/account/ak',
      note: '一个 Key 用多家开源模型，模型名带厂商前缀。',
    ),
    AiProviderTemplate(
      id: 'openrouter',
      name: 'OpenRouter',
      type: 'openai',
      baseUrl: 'https://openrouter.ai/api/v1',
      models: [
        'anthropic/claude-sonnet-5',
        'openai/gpt-5.6-luna',
        'google/gemini-3.8-flash',
        'deepseek/deepseek-v4.1-flash',
        'moonshotai/kimi-k3',
      ],
      consoleUrl: 'https://openrouter.ai/settings/keys',
      note: '一个 Key 转接各家闭源 / 开源模型，模型名带厂商前缀。',
    ),
    AiProviderTemplate(
      id: 'ollama',
      name: 'Ollama（本机）',
      type: 'ollama',
      baseUrl: 'http://localhost:11434',
      note: '先在电脑上 ollama pull 模型。手机上不能填 localhost，'
          '要填电脑的局域网 IP，例如 http://192.168.1.10:11434。',
    ),
    AiProviderTemplate(
      id: 'dify',
      name: 'Dify',
      type: 'dify',
      baseUrl: 'http://localhost/v1',
      note: '填 Dify 应用的 API Base URL 和 App API Key，只适合聊天类应用。',
    ),
  ];

  static AiProviderTemplate? byId(String id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }

  /// 已保存的配置最像哪个模板（按端点匹配），用来给编辑页找回模型建议。
  static AiProviderTemplate? matching({
    required String type,
    required String baseUrl,
  }) {
    final normalized = _normalizeUrl(baseUrl);
    for (final template in all) {
      if (template.type == type &&
          _normalizeUrl(template.baseUrl) == normalized) {
        return template;
      }
    }
    return null;
  }

  static String _normalizeUrl(String url) {
    var value = url.trim().toLowerCase();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
