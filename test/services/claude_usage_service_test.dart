import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/services/claude_usage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ClaudeUsageService.resetInstance();
  });

  tearDown(() {
    ClaudeUsageService.resetInstance();
  });

  group('initialization', () {
    test('getInstance returns same instance', () async {
      final service1 = await ClaudeUsageService.getInstance();
      final service2 = await ClaudeUsageService.getInstance();
      expect(identical(service1, service2), isTrue);
    });

    test('resetInstance clears singleton', () async {
      final service1 = await ClaudeUsageService.getInstance();
      ClaudeUsageService.resetInstance();
      final service2 = await ClaudeUsageService.getInstance();
      expect(identical(service1, service2), isFalse);
    });

    test('initial usage is zero', () async {
      final service = await ClaudeUsageService.getInstance();
      expect(service.dailyInputTokens, equals(0));
      expect(service.dailyOutputTokens, equals(0));
      expect(service.dailyTotalTokens, equals(0));
    });
  });

  group('token tracking', () {
    test('recordUsage adds to daily totals', () async {
      final service = await ClaudeUsageService.getInstance();

      await service.recordUsage(inputTokens: 100, outputTokens: 50);

      expect(service.dailyInputTokens, equals(100));
      expect(service.dailyOutputTokens, equals(50));
      expect(service.dailyTotalTokens, equals(150));
    });

    test('recordUsage accumulates multiple calls', () async {
      final service = await ClaudeUsageService.getInstance();

      await service.recordUsage(inputTokens: 100, outputTokens: 50);
      await service.recordUsage(inputTokens: 200, outputTokens: 100);

      expect(service.dailyInputTokens, equals(300));
      expect(service.dailyOutputTokens, equals(150));
      expect(service.dailyTotalTokens, equals(450));
    });

    test('resetDailyUsage clears counters', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.recordUsage(inputTokens: 100, outputTokens: 50);

      await service.resetDailyUsage();

      expect(service.dailyInputTokens, equals(0));
      expect(service.dailyOutputTokens, equals(0));
    });
  });

  group('daily cap', () {
    test('default cap is zero (no limit)', () async {
      final service = await ClaudeUsageService.getInstance();
      expect(service.dailyCap, equals(0));
    });

    test('setDailyCap persists value', () async {
      final service = await ClaudeUsageService.getInstance();

      await service.setDailyCap(100000);

      expect(service.dailyCap, equals(100000));
    });

    test('canMakeRequest is true when no cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.recordUsage(inputTokens: 1000000, outputTokens: 1000000);

      expect(service.canMakeRequest, isTrue);
    });

    test('canMakeRequest is true when under cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.setDailyCap(1000);
      await service.recordUsage(inputTokens: 400, outputTokens: 100);

      expect(service.canMakeRequest, isTrue);
    });

    test('canMakeRequest is false when at cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.setDailyCap(1000);
      await service.recordUsage(inputTokens: 600, outputTokens: 400);

      expect(service.canMakeRequest, isFalse);
    });

    test('canMakeRequest is false when over cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.setDailyCap(1000);
      await service.recordUsage(inputTokens: 800, outputTokens: 500);

      expect(service.canMakeRequest, isFalse);
    });

    test('isNearingCap is false when no cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.recordUsage(inputTokens: 1000000, outputTokens: 1000000);

      expect(service.isNearingCap, isFalse);
    });

    test('isNearingCap is false when under 90%', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.setDailyCap(1000);
      await service.recordUsage(inputTokens: 400, outputTokens: 400);

      expect(service.isNearingCap, isFalse);
    });

    test('isNearingCap is true when at 90%', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.setDailyCap(1000);
      await service.recordUsage(inputTokens: 500, outputTokens: 400);

      expect(service.isNearingCap, isTrue);
    });

    test('hasReachedCap is false when no cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.recordUsage(inputTokens: 1000000, outputTokens: 1000000);

      expect(service.hasReachedCap, isFalse);
    });

    test('hasReachedCap is true when at cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.setDailyCap(1000);
      await service.recordUsage(inputTokens: 600, outputTokens: 400);

      expect(service.hasReachedCap, isTrue);
    });

    test('usagePercentage is zero when no cap', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.recordUsage(inputTokens: 1000, outputTokens: 1000);

      expect(service.usagePercentage, equals(0));
    });

    test('usagePercentage calculates correctly', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.setDailyCap(1000);
      await service.recordUsage(inputTokens: 300, outputTokens: 200);

      expect(service.usagePercentage, equals(50));
    });
  });

  group('formatTokens', () {
    test('formats small numbers directly', () {
      expect(ClaudeUsageService.formatTokens(0), equals('0'));
      expect(ClaudeUsageService.formatTokens(500), equals('500'));
      expect(ClaudeUsageService.formatTokens(999), equals('999'));
    });

    test('formats thousands with K suffix', () {
      expect(ClaudeUsageService.formatTokens(1000), equals('1.0K'));
      expect(ClaudeUsageService.formatTokens(1500), equals('1.5K'));
      expect(ClaudeUsageService.formatTokens(12500), equals('12.5K'));
      expect(ClaudeUsageService.formatTokens(999999), equals('1000.0K'));
    });

    test('formats millions with M suffix', () {
      expect(ClaudeUsageService.formatTokens(1000000), equals('1.0M'));
      expect(ClaudeUsageService.formatTokens(2500000), equals('2.5M'));
    });
  });

  group('display strings', () {
    test('usageSummary shows no usage when zero', () async {
      final service = await ClaudeUsageService.getInstance();
      expect(service.usageSummary, equals('No usage today'));
    });

    test('usageSummary shows formatted total', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.recordUsage(inputTokens: 5000, outputTokens: 3000);

      expect(service.usageSummary, contains('8.0K'));
    });

    test('usageBreakdown shows no usage when zero', () async {
      final service = await ClaudeUsageService.getInstance();
      expect(service.usageBreakdown, equals('No usage today'));
    });

    test('usageBreakdown shows input and output', () async {
      final service = await ClaudeUsageService.getInstance();
      await service.recordUsage(inputTokens: 5000, outputTokens: 3000);

      expect(service.usageBreakdown, contains('Input:'));
      expect(service.usageBreakdown, contains('Output:'));
    });
  });
}
