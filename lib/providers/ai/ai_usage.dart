import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一次 AI 请求的 token 用量。
///
/// API 返回了 `usage` 就是准确值；没返回（老的兼容服务、流式没开
/// `stream_options`）就按字数估一个，[estimated] 标出来。估值只求量级——
/// 各家分词器不一样，同一段中文在不同模型上能差三成。
@immutable
class AIUsage {
  final int promptTokens;
  final int completionTokens;
  final bool estimated;

  const AIUsage({
    required this.promptTokens,
    required this.completionTokens,
    this.estimated = false,
  });

  int get totalTokens => promptTokens + completionTokens;

  /// 从 OpenAI 风格的 `usage` 对象取值。字段缺失或不是数字返回 null，
  /// 调用方再退到估算。
  static AIUsage? fromOpenAi(Object? usage) {
    if (usage is! Map) return null;
    final prompt = _readInt(usage['prompt_tokens']);
    final completion = _readInt(usage['completion_tokens']);
    if (prompt == null && completion == null) return null;
    return AIUsage(
      promptTokens: prompt ?? 0,
      completionTokens: completion ?? 0,
    );
  }

  /// 按文本估：[promptTexts] 是发出去的每条消息，[completion] 是收到的回复。
  factory AIUsage.estimate({
    required Iterable<String> promptTexts,
    required String completion,
  }) {
    return AIUsage(
      promptTokens: estimatePromptTokens(promptTexts),
      completionTokens: estimateTokenCount(completion),
      estimated: true,
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AIUsage &&
      other.promptTokens == promptTokens &&
      other.completionTokens == completionTokens &&
      other.estimated == estimated;

  @override
  int get hashCode => Object.hash(promptTokens, completionTokens, estimated);

  @override
  String toString() =>
      'AIUsage(prompt: $promptTokens, completion: $completionTokens'
      '${estimated ? ', estimated' : ''})';
}

typedef AIUsageListener = void Function(AIUsage usage);

/// 收用量的地方。[AiUsageTracker] 实现它；AIService 只认这个接口，测试里
/// 可以塞个假的。
abstract interface class AIUsageSink {
  void record(int providerId, AIUsage usage);

  /// Provider 删掉了，它的记录也不用留。
  void forget(int providerId);
}

/// 估算一段文本的 token 数。
///
/// 汉字、假名、谚文按每字 0.7 个 token（现在主流分词器上中文大致是
/// 1.3–1.5 个字一个 token），其他文字按 4 个字符一个 token，空白不算。
int estimateTokenCount(String text) {
  var cjk = 0;
  var other = 0;
  for (final unit in text.codeUnits) {
    if (_isCjk(unit)) {
      cjk++;
    } else if (!_isWhitespace(unit)) {
      other++;
    }
  }
  if (cjk == 0 && other == 0) return 0;
  return (cjk * 0.7 + other / 4).ceil();
}

/// 每条消息再加 4 个 token 的格式开销（角色、分隔），和 OpenAI 的算法一致。
int estimatePromptTokens(Iterable<String> messages) {
  var total = 0;
  for (final message in messages) {
    total += estimateTokenCount(message) + 4;
  }
  return total;
}

bool _isCjk(int unit) =>
    (unit >= 0x2E80 && unit <= 0x9FFF) ||
    (unit >= 0xAC00 && unit <= 0xD7AF) ||
    (unit >= 0xF900 && unit <= 0xFAFF) ||
    (unit >= 0xFF00 && unit <= 0xFFEF);

bool _isWhitespace(int unit) =>
    unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;

/// 某一天的用量。
@immutable
class AiDayUsage {
  final int promptTokens;
  final int completionTokens;
  final int requests;

  const AiDayUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.requests = 0,
  });

  static const empty = AiDayUsage();

  int get totalTokens => promptTokens + completionTokens;

  AiDayUsage add(AIUsage usage) => AiDayUsage(
        promptTokens: promptTokens + usage.promptTokens,
        completionTokens: completionTokens + usage.completionTokens,
        requests: requests + 1,
      );

  AiDayUsage plus(AiDayUsage other) => AiDayUsage(
        promptTokens: promptTokens + other.promptTokens,
        completionTokens: completionTokens + other.completionTokens,
        requests: requests + other.requests,
      );

  List<int> toJson() => [promptTokens, completionTokens, requests];

  static AiDayUsage fromJson(Object? json) {
    if (json is! List || json.length < 3) return empty;
    int at(int i) {
      final v = json[i];
      return v is num ? v.toInt() : 0;
    }

    return AiDayUsage(
      promptTokens: at(0),
      completionTokens: at(1),
      requests: at(2),
    );
  }
}

/// 一个 Provider 的累计用量。
///
/// 累计数单独存，不从 [days] 加总：按天的记录只保留最近 [keptDays] 天，
/// 累计数要一直往上加。
@immutable
class AiProviderUsage {
  /// 按天记录保留多少天。图表最多看 30 天，多留一倍余量。
  static const keptDays = 60;

  final int promptTokens;
  final int completionTokens;
  final int requests;

  /// 其中按字数估算（API 没返回 usage）的请求数。
  final int estimatedRequests;

  /// 按天的用量，键是 yyyy-MM-dd。
  final Map<String, AiDayUsage> days;

  /// 「今日」是哪一天。由 [forDay] 设定，读今日数字前要先经过它。
  final String? todayKey;

  /// 开始统计的时间（第一次记录或上次清零）。
  final DateTime? since;

  const AiProviderUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.requests = 0,
    this.estimatedRequests = 0,
    this.days = const {},
    this.todayKey,
    this.since,
  });

  static const empty = AiProviderUsage();

  int get totalTokens => promptTokens + completionTokens;
  bool get isEmpty => requests == 0;

  AiDayUsage get today => days[todayKey] ?? AiDayUsage.empty;
  int get todayPromptTokens => today.promptTokens;
  int get todayCompletionTokens => today.completionTokens;
  int get todayRequests => today.requests;
  int get todayTotalTokens => today.totalTokens;

  /// 把「今日」对到 [dayKey]。
  AiProviderUsage forDay(String dayKey) {
    if (todayKey == dayKey) return this;
    return _copyWith(todayKey: dayKey);
  }

  AiProviderUsage add(AIUsage usage, {required String dayKey, DateTime? now}) {
    final nextDays = Map<String, AiDayUsage>.of(days);
    nextDays[dayKey] = (nextDays[dayKey] ?? AiDayUsage.empty).add(usage);
    return _copyWith(
      promptTokens: promptTokens + usage.promptTokens,
      completionTokens: completionTokens + usage.completionTokens,
      requests: requests + 1,
      estimatedRequests: estimatedRequests + (usage.estimated ? 1 : 0),
      days: _prune(nextDays),
      todayKey: dayKey,
      since: since ?? now,
    );
  }

  /// 只留最近 [keptDays] 天。键是 yyyy-MM-dd，字符串顺序就是日期顺序。
  static Map<String, AiDayUsage> _prune(Map<String, AiDayUsage> days) {
    if (days.length <= keptDays) return days;
    final keys = days.keys.toList()..sort();
    final kept = keys.sublist(keys.length - keptDays);
    return {for (final key in kept) key: days[key]!};
  }

  AiProviderUsage _copyWith({
    int? promptTokens,
    int? completionTokens,
    int? requests,
    int? estimatedRequests,
    Map<String, AiDayUsage>? days,
    String? todayKey,
    DateTime? since,
  }) =>
      AiProviderUsage(
        promptTokens: promptTokens ?? this.promptTokens,
        completionTokens: completionTokens ?? this.completionTokens,
        requests: requests ?? this.requests,
        estimatedRequests: estimatedRequests ?? this.estimatedRequests,
        days: days ?? this.days,
        todayKey: todayKey ?? this.todayKey,
        since: since ?? this.since,
      );

  Map<String, Object?> toJson() => {
        'prompt': promptTokens,
        'completion': completionTokens,
        'requests': requests,
        'estimatedRequests': estimatedRequests,
        'days': {for (final e in days.entries) e.key: e.value.toJson()},
        'since': since?.toIso8601String(),
      };

  static AiProviderUsage fromJson(Map<String, Object?> json) {
    int readInt(String key) {
      final value = json[key];
      return value is num ? value.toInt() : 0;
    }

    final days = <String, AiDayUsage>{};
    final rawDays = json['days'];
    if (rawDays is Map) {
      for (final entry in rawDays.entries) {
        days[entry.key.toString()] = AiDayUsage.fromJson(entry.value);
      }
    } else {
      // 老格式（v1.0.0 之后短暂用过）：今日数字平铺在顶层。
      final todayKey = json['todayKey'];
      if (todayKey is String && readInt('todayRequests') > 0) {
        days[todayKey] = AiDayUsage(
          promptTokens: readInt('todayPrompt'),
          completionTokens: readInt('todayCompletion'),
          requests: readInt('todayRequests'),
        );
      }
    }
    final since = json['since'];
    return AiProviderUsage(
      promptTokens: readInt('prompt'),
      completionTokens: readInt('completion'),
      requests: readInt('requests'),
      estimatedRequests: readInt('estimatedRequests'),
      days: days,
      since: since is String ? DateTime.tryParse(since) : null,
    );
  }
}

/// 图表用的一天：日期 + 当天用量（可以是多个 Provider 加总）。
@immutable
class AiUsageDay {
  final DateTime date;
  final AiDayUsage usage;

  const AiUsageDay({required this.date, required this.usage});
}

/// 按 Provider 累计 token 用量，存在偏好里（一个 JSON 串）。
///
/// 不进数据库：这只是给用户看个大概的计数器，不值得一张表和一次迁移；
/// 备份也不需要带着它走。
class AiUsageTracker extends ChangeNotifier implements AIUsageSink {
  static const storageKey = 'aiUsage';

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final Map<int, AiProviderUsage> _byProvider = {};

  AiUsageTracker(this._prefs, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _load();
  }

  Map<int, AiProviderUsage> get all => Map.unmodifiable(_byProvider);

  /// 某个 Provider 的用量，「今日」按当天折算。没记录过返回空值。
  AiProviderUsage usageFor(int providerId) =>
      (_byProvider[providerId] ?? AiProviderUsage.empty).forDay(_dayKey());

  /// 最近 [days] 天每天的用量（含今天），没记录的天是 0。[providerId] 为空
  /// 时把所有 Provider 加在一起。
  List<AiUsageDay> dailySeries({int days = 14, int? providerId}) {
    final now = _now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sources = providerId == null
        ? _byProvider.values
        : [if (_byProvider[providerId] != null) _byProvider[providerId]!];
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        () {
          final date = todayStart.subtract(Duration(days: offset));
          final key = _dayKey(date);
          var usage = AiDayUsage.empty;
          for (final source in sources) {
            final day = source.days[key];
            if (day != null) usage = usage.plus(day);
          }
          return AiUsageDay(date: date, usage: usage);
        }(),
    ];
  }

  @override
  void record(int providerId, AIUsage usage) {
    final now = _now();
    _byProvider[providerId] =
        (_byProvider[providerId] ?? AiProviderUsage.empty).add(
      usage,
      dayKey: _dayKey(now),
      now: now,
    );
    _save();
    notifyListeners();
  }

  void reset(int providerId) {
    if (_byProvider.remove(providerId) == null) return;
    _save();
    notifyListeners();
  }

  @override
  void forget(int providerId) => reset(providerId);

  void resetAll() {
    if (_byProvider.isEmpty) return;
    _byProvider.clear();
    _save();
    notifyListeners();
  }

  String _dayKey([DateTime? at]) {
    final t = at ?? _now();
    final month = t.month.toString().padLeft(2, '0');
    final day = t.day.toString().padLeft(2, '0');
    return '${t.year}-$month-$day';
  }

  void _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (id == null || value is! Map) continue;
        _byProvider[id] =
            AiProviderUsage.fromJson(Map<String, Object?>.from(value));
      }
    } catch (_) {
      // 存坏了就从零开始；这只是计数器。
      _byProvider.clear();
    }
  }

  void _save() {
    _prefs.setString(
      storageKey,
      jsonEncode({
        for (final entry in _byProvider.entries)
          entry.key.toString(): entry.value.toJson(),
      }),
    );
  }
}

/// 给界面用：12345 → 12.3k，1234567 → 1.23M。
String formatTokenCount(int tokens) {
  if (tokens < 1000) return tokens.toString();
  if (tokens < 1000000) {
    final k = tokens / 1000;
    return '${k < 10 ? k.toStringAsFixed(2) : k.toStringAsFixed(1)}k';
  }
  return '${(tokens / 1000000).toStringAsFixed(2)}M';
}
