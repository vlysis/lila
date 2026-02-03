import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider.dart';

/// Tracks AI API token usage and enforces daily caps per provider.
class AiUsageService {
  static const _usageDateKeyPrefix = 'ai_usage_date_';
  static const _dailyInputTokensKeyPrefix = 'ai_daily_input_tokens_';
  static const _dailyOutputTokensKeyPrefix = 'ai_daily_output_tokens_';
  static const _dailyCapKeyPrefix = 'ai_daily_token_cap_';

  // Legacy Claude keys for migration.
  static const _legacyDailyInputTokensKey = 'claude_daily_input_tokens';
  static const _legacyDailyOutputTokensKey = 'claude_daily_output_tokens';
  static const _legacyUsageDateKey = 'claude_usage_date';
  static const _legacyDailyCapKey = 'claude_daily_token_cap';

  static final Map<AiProvider, AiUsageService> _instances = {};

  final AiProvider provider;
  late SharedPreferences _prefs;

  AiUsageService._(this.provider);

  static Future<AiUsageService> getInstance(AiProvider provider) async {
    if (!_instances.containsKey(provider)) {
      final service = AiUsageService._(provider);
      await service._init();
      _instances[provider] = service;
    }
    return _instances[provider]!;
  }

  @visibleForTesting
  static void resetInstance(AiProvider provider) => _instances.remove(provider);

  @visibleForTesting
  static void resetAll() => _instances.clear();

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateLegacyClaudeUsage();
    await _resetIfNewDay();
  }

  Future<void> _migrateLegacyClaudeUsage() async {
    if (provider != AiProvider.claude) return;

    final usageDateKey = _usageDateKey(provider);
    if (_prefs.containsKey(usageDateKey)) return;

    final legacyDate = _prefs.getString(_legacyUsageDateKey);
    if (legacyDate != null) {
      await _prefs.setString(usageDateKey, legacyDate);
    }

    final legacyInput = _prefs.getInt(_legacyDailyInputTokensKey);
    if (legacyInput != null) {
      await _prefs.setInt(_dailyInputTokensKey(provider), legacyInput);
    }

    final legacyOutput = _prefs.getInt(_legacyDailyOutputTokensKey);
    if (legacyOutput != null) {
      await _prefs.setInt(_dailyOutputTokensKey(provider), legacyOutput);
    }

    final legacyCap = _prefs.getInt(_legacyDailyCapKey);
    if (legacyCap != null && !_prefs.containsKey(_dailyCapKey(provider))) {
      await _prefs.setInt(_dailyCapKey(provider), legacyCap);
    }
  }

  Future<void> _resetIfNewDay() async {
    final today = _todayUtc();
    final storedDate = _prefs.getString(_usageDateKey(provider));

    if (storedDate != today) {
      await _prefs.setString(_usageDateKey(provider), today);
      await _prefs.setInt(_dailyInputTokensKey(provider), 0);
      await _prefs.setInt(_dailyOutputTokensKey(provider), 0);
    }
  }

  String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> recordUsage({
    required int inputTokens,
    required int outputTokens,
  }) async {
    await _resetIfNewDay();

    final currentInput = _prefs.getInt(_dailyInputTokensKey(provider)) ?? 0;
    final currentOutput = _prefs.getInt(_dailyOutputTokensKey(provider)) ?? 0;

    await _prefs.setInt(
      _dailyInputTokensKey(provider),
      currentInput + inputTokens,
    );
    await _prefs.setInt(
      _dailyOutputTokensKey(provider),
      currentOutput + outputTokens,
    );
  }

  int get dailyInputTokens {
    _checkDayRollover();
    return _prefs.getInt(_dailyInputTokensKey(provider)) ?? 0;
  }

  int get dailyOutputTokens {
    _checkDayRollover();
    return _prefs.getInt(_dailyOutputTokensKey(provider)) ?? 0;
  }

  int get dailyTotalTokens => dailyInputTokens + dailyOutputTokens;

  void _checkDayRollover() {
    final today = _todayUtc();
    final storedDate = _prefs.getString(_usageDateKey(provider));
    if (storedDate != today) {
      // Stale until next async call.
    }
  }

  int get dailyCap => _prefs.getInt(_dailyCapKey(provider)) ?? 0;

  Future<void> setDailyCap(int cap) async {
    await _prefs.setInt(_dailyCapKey(provider), cap);
  }

  double get usagePercentage {
    final cap = dailyCap;
    if (cap == 0) return 0;
    return (dailyTotalTokens / cap) * 100;
  }

  bool get isNearingCap {
    final cap = dailyCap;
    if (cap == 0) return false;
    return usagePercentage >= 90;
  }

  bool get hasReachedCap {
    final cap = dailyCap;
    if (cap == 0) return false;
    return dailyTotalTokens >= cap;
  }

  bool get canMakeRequest {
    final cap = dailyCap;
    if (cap == 0) return true;
    return dailyTotalTokens < cap;
  }

  static String formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  String get usageSummary {
    final total = dailyTotalTokens;
    if (total == 0) return 'No usage today';
    return 'Today: ~${formatTokens(total)} tokens';
  }

  String get usageBreakdown {
    final input = dailyInputTokens;
    final output = dailyOutputTokens;
    if (input == 0 && output == 0) return 'No usage today';
    return 'Input: ${formatTokens(input)} / Output: ${formatTokens(output)}';
  }

  Future<void> resetDailyUsage() async {
    await _prefs.setInt(_dailyInputTokensKey(provider), 0);
    await _prefs.setInt(_dailyOutputTokensKey(provider), 0);
    await _prefs.setString(_usageDateKey(provider), _todayUtc());
  }

  String _usageDateKey(AiProvider provider) => '$_usageDateKeyPrefix${provider.id}';

  String _dailyInputTokensKey(AiProvider provider) =>
      '$_dailyInputTokensKeyPrefix${provider.id}';

  String _dailyOutputTokensKey(AiProvider provider) =>
      '$_dailyOutputTokensKeyPrefix${provider.id}';

  String _dailyCapKey(AiProvider provider) => '$_dailyCapKeyPrefix${provider.id}';
}
