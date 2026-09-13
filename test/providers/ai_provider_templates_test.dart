import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/ai/ai_provider_templates.dart';

void main() {
  test('模板 id 唯一，端点是合法的 HTTP(S) 地址', () {
    final ids = AiProviderTemplate.all.map((t) => t.id).toSet();
    expect(ids.length, AiProviderTemplate.all.length);
    for (final template in AiProviderTemplate.all) {
      final uri = Uri.parse(template.baseUrl);
      expect(uri.scheme, anyOf('http', 'https'), reason: template.id);
      expect(uri.host, isNotEmpty, reason: template.id);
      expect(template.baseUrl.endsWith('/'), isFalse, reason: template.id);
      expect(
        const {'openai', 'ollama', 'dify'}.contains(template.type),
        isTrue,
        reason: template.id,
      );
    }
  });

  test('OpenAI 兼容的模板都带模型建议和拿 Key 的地址；Ollama / Dify 不带', () {
    for (final template in AiProviderTemplate.all) {
      if (template.type == 'openai') {
        expect(template.models, isNotEmpty, reason: template.id);
        expect(template.defaultModel, template.models.first);
        expect(template.consoleUrl, isNotNull, reason: template.id);
      } else {
        expect(template.models, isEmpty, reason: template.id);
        expect(template.defaultModel, '');
      }
    }
    expect(AiProviderTemplate.byId('ollama')!.needsApiKey, isFalse);
    expect(AiProviderTemplate.byId('deepseek')!.needsApiKey, isTrue);
  });

  test('按端点反查模板，末尾斜杠和大小写不算差异', () {
    expect(
      AiProviderTemplate.matching(
        type: 'openai',
        baseUrl: 'https://api.deepseek.com/',
      )?.id,
      'deepseek',
    );
    expect(
      AiProviderTemplate.matching(
        type: 'openai',
        baseUrl: 'HTTPS://API.OPENAI.COM/v1',
      )?.id,
      'openai',
    );
    // 类型对不上就不算：同一个地址填成 Ollama 类型没意义。
    expect(
      AiProviderTemplate.matching(
        type: 'ollama',
        baseUrl: 'https://api.openai.com/v1',
      ),
      isNull,
    );
    expect(
      AiProviderTemplate.matching(
        type: 'openai',
        baseUrl: 'https://my-proxy.example/v1',
      ),
      isNull,
    );
    expect(AiProviderTemplate.byId('nope'), isNull);
  });
}
