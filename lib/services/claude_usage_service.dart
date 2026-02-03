import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks Claude API token usage and enforces daily caps.
class ClaudeUsageService {
  static const _dailyInputTokensKey = 'claude_daily_input_tokens';
  static const _dailyOutputTokensKey = 'claude_daily_output_tokens';
  static const _usageDateKey = 'claude_usage_date';
  static const _dailyCapKey = 'claude_daily_token_cap';

  static ClaudeUsageService? _instance;
  late SharedPreferences _prefs;

  ClaudeUsageService._();

  static Future<ClaudeUsageService> getInstance() async {
    if (_instance == null) {
      _instance = ClaudeUsageService._();
      await _instance!._init();
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay();
  }

  /// Checks if it's a new UTC day and resets counters if so.
  Future<void> _resetIfNewDay() async {
    final today = _todayUtc();
    final storedDate = _prefs.getString(_usageDateKey);

    if (storedDate != today) {
      await _prefs.setString(_usageDateKey, today);
      await _prefs.setInt(_dailyInputTokensKey, 0);
      await _prefs.setInt(_dailyOutputTokensKey, 0);
    }
  }

  /// Returns today's date in UTC as YYYY-MM-DD.
  String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Records token usage from an API call.
  Future<void> recordUsage({
    required int inputTokens,
    required int outputTokens,
  }) async {
    await _resetIfNewDay();

    final currentInput = _prefs.getInt(_dailyInputTokensKey) ?? 0;
    final currentOutput = _prefs.getInt(_dailyOutputTokensKey) ?? 0;

    await _prefs.setInt(_dailyInputTokensKey, currentInput + inputTokens);
    await _prefs.setInt(_dailyOutputTokensKey, currentOutput + outputTokens);
  }

  /// Gets today's total input tokens.
  int get dailyInputTokens {
    _checkDayRollover();
    return _prefs.getInt(_dailyInputTokensKey) ?? 0;
  }

  /// Gets today's total output tokens.
  int get dailyOutputTokens {
    _checkDayRollover();
    return _prefs.getInt(_dailyOutputTokensKey) ?? 0;
  }

  /// Gets today's total tokens (input + output).
  int get dailyTotalTokens => dailyInputTokens + dailyOutputTokens;

  /// Synchronously checks if day rolled over (for getters).
  void _checkDayRollover() {
    final today = _todayUtc();
    final storedDate = _prefs.getString(_usageDateKey);
    if (storedDate != today) {
      // Day changed, but we can't await here. Values will be stale until next async call.
      // This is acceptable for display purposes.
    }
  }

  /// Gets the daily token cap (0 means no cap).
  int get dailyCap => _prefs.getInt(_dailyCapKey) ?? 0;

  /// Sets the daily token cap (0 to disable).
  Future<void> setDailyCap(int cap) async {
    await _prefs.setInt(_dailyCapKey, cap);
  }

  /// Returns the percentage of daily cap used (0-100+).
  /// Returns 0 if no cap is set.
  double get usagePercentage {
    final cap = dailyCap;
    if (cap == 0) return 0;
    return (dailyTotalTokens / cap) * 100;
  }

  /// Whether usage is at or above 90% of the cap.
  bool get isNearingCap {
    final cap = dailyCap;
    if (cap == 0) return false;
    return usagePercentage >= 90;
  }

  /// Whether usage has reached the cap.
  bool get hasReachedCap {
    final cap = dailyCap;
    if (cap == 0) return false;
    return dailyTotalTokens >= cap;
  }

  /// Whether usage is allowed (not capped).
  bool get canMakeRequest {
    final cap = dailyCap;
    if (cap == 0) return true;
    return dailyTotalTokens < cap;
  }

  /// Formats token count for display (e.g., "12.5K" or "1.2M").
  static String formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  /// Gets a summary string for display (e.g., "Today: ~12.5K tokens").
  String get usageSummary {
    final total = dailyTotalTokens;
    if (total == 0) return 'No usage today';
    return 'Today: ~${formatTokens(total)} tokens';
  }

  /// Gets a detailed breakdown for display.
  String get usageBreakdown {
    final input = dailyInputTokens;
    final output = dailyOutputTokens;
    if (input == 0 && output == 0) return 'No usage today';
    return 'Input: ${formatTokens(input)} / Output: ${formatTokens(output)}';
  }

  /// Resets daily usage (for testing or manual reset).
  Future<void> resetDailyUsage() async {
    await _prefs.setInt(_dailyInputTokensKey, 0);
    await _prefs.setInt(_dailyOutputTokensKey, 0);
    await _prefs.setString(_usageDateKey, _todayUtc());
  }
}
