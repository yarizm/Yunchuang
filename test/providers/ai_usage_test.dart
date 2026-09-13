import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yunchuang/providers/ai/ai_usage.dart';

void main() {
  group('estimateTokenCount', () {
    test('中文按字算，英文按 4 字符算，空白不算', () {
      expect(estimateTokenCount(''), 0);
      expect(estimateTokenCount('   \n'), 0);
      // 10 个汉字 ≈ 7 个 token
      expect(estimateTokenCount('此开卷第一回也作者自'), 7);
      // 8 个字母 = 2 个 token
      expect(estimateTokenCount('abcd efgh'), 2);
      // 混排相加后向上取整
      expect(estimateTokenCount('Flutter 框架'), (7 / 4 + 2 * 0.7).ceil());
    });

    test('每条消息加 4 个 token 的格式开销', () {
      expect(estimatePromptTokens(['abcd', 'efgh']), 10);
      expect(estimatePromptTokens(const []), 0);
    });
  });

  group('AIUsage.fromOpenAi', () {
    test('取 prompt_tokens / completion_tokens，数字或数字字符串都认', () {
      expect(
        AIUsage.fromOpenAi({'prompt_tokens': 12, 'completion_tokens': 3}),
        const AIUsage(promptTokens: 12, completionTokens: 3),
      );
      expect(
        AIUsage.fromOpenAi({'prompt_tokens': '12', 'completion_tokens': 3.0}),
        const AIUsage(promptTokens: 12, completionTokens: 3),
      );
    });

    test('缺字段或不是对象返回 null，让调用方去估', () {
      expect(AIUsage.fromOpenAi(null), isNull);
      expect(AIUsage.fromOpenAi('usage'), isNull);
      expect(AIUsage.fromOpenAi({'total_tokens': 15}), isNull);
      // 只有一边也算数
      expect(
        AIUsage.fromOpenAi({'completion_tokens': 5}),
        const AIUsage(promptTokens: 0, completionTokens: 5),
      );
    });
  });

  group('AiUsageTracker', () {
    late SharedPreferences prefs;
    var now = DateTime(2026, 9, 12, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 9, 12, 10);
    });

    test('按 Provider 累计，今日与累计分开，估算次数单独计', () {
      final tracker = AiUsageTracker(prefs, now: () => now);

      tracker.record(1, const AIUsage(promptTokens: 100, completionTokens: 20));
      tracker.record(
        1,
        const AIUsage(promptTokens: 50, completionTokens: 5, estimated: true),
      );
      tracker.record(2, const AIUsage(promptTokens: 7, completionTokens: 1));

      final one = tracker.usageFor(1);
      expect(one.promptTokens, 150);
      expect(one.completionTokens, 25);
      expect(one.requests, 2);
      expect(one.estimatedRequests, 1);
      expect(one.todayTotalTokens, 175);
      expect(one.since, DateTime(2026, 9, 12, 10));
      expect(tracker.usageFor(2).totalTokens, 8);
      expect(tracker.usageFor(3).isEmpty, isTrue);
    });

    test('换天之后今日清零，累计不动', () {
      final tracker = AiUsageTracker(prefs, now: () => now);
      tracker.record(1, const AIUsage(promptTokens: 100, completionTokens: 20));

      now = DateTime(2026, 9, 13, 0, 5);
      final nextDay = tracker.usageFor(1);
      expect(nextDay.todayTotalTokens, 0);
      expect(nextDay.todayRequests, 0);
      expect(nextDay.totalTokens, 120);

      tracker.record(1, const AIUsage(promptTokens: 10, completionTokens: 1));
      expect(tracker.usageFor(1).todayTotalTokens, 11);
      expect(tracker.usageFor(1).totalTokens, 131);
    });

    test('按天记录，dailySeries 给最近 N 天（没记录的天是 0）', () {
      final tracker = AiUsageTracker(prefs, now: () => now);
      now = DateTime(2026, 9, 10, 9);
      tracker.record(1, const AIUsage(promptTokens: 100, completionTokens: 10));
      now = DateTime(2026, 9, 12, 9);
      tracker.record(1, const AIUsage(promptTokens: 200, completionTokens: 20));
      tracker.record(2, const AIUsage(promptTokens: 5, completionTokens: 5));

      final series = tracker.dailySeries(days: 4);
      expect(series.map((d) => d.date.day), [9, 10, 11, 12]);
      expect(series.map((d) => d.usage.totalTokens), [0, 110, 0, 230]);
      expect(series.last.usage.promptTokens, 205);
      expect(series.last.usage.requests, 2);

      // 单个 Provider
      final one = tracker.dailySeries(days: 4, providerId: 2);
      expect(one.map((d) => d.usage.totalTokens), [0, 0, 0, 10]);
      // 累计数不受按天记录影响
      expect(tracker.usageFor(1).totalTokens, 330);
    });

    test('按天记录只留最近 60 天，累计数照加', () {
      final tracker = AiUsageTracker(prefs, now: () => now);
      for (var i = 0; i < 70; i++) {
        now = DateTime(2026, 1, 1).add(Duration(days: i));
        tracker.record(1, const AIUsage(promptTokens: 1, completionTokens: 0));
      }
      final usage = tracker.usageFor(1);
      expect(usage.days.length, AiProviderUsage.keptDays);
      expect(usage.days.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
          '2026-01-11');
      expect(usage.promptTokens, 70);
    });

    test('读得懂没有 days 的老格式', () {
      final usage = AiProviderUsage.fromJson({
        'prompt': 48210,
        'completion': 9130,
        'requests': 37,
        'estimatedRequests': 4,
        'todayKey': '2026-09-13',
        'todayPrompt': 3120,
        'todayCompletion': 880,
        'todayRequests': 5,
        'since': '2026-09-01T09:00:00.000',
      });
      expect(usage.totalTokens, 57340);
      expect(usage.forDay('2026-09-13').todayTotalTokens, 4000);
      expect(usage.forDay('2026-09-14').todayTotalTokens, 0);
      expect(usage.days['2026-09-13']?.requests, 5);
    });

    test('存进偏好，重新构造能读回来', () {
      AiUsageTracker(prefs, now: () => now)
          .record(5, const AIUsage(promptTokens: 30, completionTokens: 4));

      final reloaded = AiUsageTracker(prefs, now: () => now);
      expect(reloaded.usageFor(5).totalTokens, 34);
      expect(reloaded.usageFor(5).requests, 1);
    });

    test('存坏了从零开始，不崩', () async {
      await prefs.setString(AiUsageTracker.storageKey, '{not json');
      final tracker = AiUsageTracker(prefs, now: () => now);
      expect(tracker.all, isEmpty);
    });

    test('清零与删除 Provider 时忘掉记录', () {
      final tracker = AiUsageTracker(prefs, now: () => now);
      tracker.record(1, const AIUsage(promptTokens: 1, completionTokens: 1));
      tracker.record(2, const AIUsage(promptTokens: 1, completionTokens: 1));
      var notified = 0;
      tracker.addListener(() => notified++);

      tracker.forget(1);
      expect(tracker.usageFor(1).isEmpty, isTrue);
      expect(tracker.usageFor(2).isEmpty, isFalse);
      expect(notified, 1);

      // 没有的 id 不通知
      tracker.reset(99);
      expect(notified, 1);

      tracker.resetAll();
      expect(tracker.all, isEmpty);
      expect(AiUsageTracker(prefs, now: () => now).all, isEmpty);
    });
  });

  test('formatTokenCount', () {
    expect(formatTokenCount(0), '0');
    expect(formatTokenCount(999), '999');
    expect(formatTokenCount(1234), '1.23k');
    expect(formatTokenCount(12345), '12.3k');
    expect(formatTokenCount(1234567), '1.23M');
  });
}
