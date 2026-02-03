import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/services/claude_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mock storage for secure storage operations
  final Map<String, String> mockSecureStorage = {};

  setUp(() {
    mockSecureStorage.clear();

    // Mock flutter_secure_storage channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'read':
            final key = call.arguments['key'] as String;
            return mockSecureStorage[key];
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String;
            mockSecureStorage[key] = value;
            return null;
          case 'delete':
            final key = call.arguments['key'] as String;
            mockSecureStorage.remove(key);
            return null;
          case 'containsKey':
            final key = call.arguments['key'] as String;
            return mockSecureStorage.containsKey(key);
          default:
            return null;
        }
      },
    );

    SharedPreferences.setMockInitialValues({});
    ClaudeService.resetInstance();
  });

  tearDown(() {
    ClaudeService.resetInstance();
  });

  group('key format validation', () {
    test('accepts valid API key format', () {
      const validKey = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      expect(ClaudeService.validateKeyFormat(validKey), isNull);
    });

    test('accepts key with underscores and hyphens', () {
      const validKey = 'sk-ant-api03-abc_def-ghi_jkl-mno_pqr-stu_vwx-yz0123456789';
      expect(ClaudeService.validateKeyFormat(validKey), isNull);
    });

    test('rejects empty key', () {
      expect(ClaudeService.validateKeyFormat(''), isNotNull);
      expect(ClaudeService.validateKeyFormat('   '), isNotNull);
    });

    test('rejects key without sk-ant-api03 prefix', () {
      const invalidKey = 'api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      expect(ClaudeService.validateKeyFormat(invalidKey), isNotNull);
    });

    test('rejects key with wrong prefix', () {
      const invalidKey = 'sk-ant-api02-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      expect(ClaudeService.validateKeyFormat(invalidKey), isNotNull);
    });

    test('rejects key that is too short', () {
      const shortKey = 'sk-ant-api03-abc';
      expect(ClaudeService.validateKeyFormat(shortKey), isNotNull);
    });

    test('rejects key with invalid characters', () {
      const invalidKey = 'sk-ant-api03-abc!@#\$%^&*()abcdefghijklmnopqrst';
      expect(ClaudeService.validateKeyFormat(invalidKey), isNotNull);
    });

    test('trims whitespace from key', () {
      const keyWithSpaces =
          '  sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD  ';
      expect(ClaudeService.validateKeyFormat(keyWithSpaces), isNull);
    });
  });

  group('initialization', () {
    test('hasApiKey is false when no key stored', () async {
      final service = await ClaudeService.getInstance();
      expect(service.hasApiKey, isFalse);
    });

    test('hasApiKey is true when key is stored', () async {
      mockSecureStorage['lila_claude_api_key'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await ClaudeService.getInstance();
      expect(service.hasApiKey, isTrue);
    });

    test('maskedKey is null when no key stored', () async {
      final service = await ClaudeService.getInstance();
      expect(service.maskedKey, isNull);
    });

    test('maskedKey shows last 4 chars when key stored', () async {
      mockSecureStorage['lila_claude_api_key'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await ClaudeService.getInstance();
      expect(service.maskedKey, equals('sk-ant-...ABCD'));
    });
  });

  group('saveApiKey', () {
    test('saves valid key to secure storage', () async {
      final service = await ClaudeService.getInstance();
      const key = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';

      final error = await service.saveApiKey(key);

      expect(error, isNull);
      expect(mockSecureStorage['lila_claude_api_key'], equals(key));
      expect(service.hasApiKey, isTrue);
      expect(service.maskedKey, equals('sk-ant-...ABCD'));
    });

    test('trims whitespace when saving', () async {
      final service = await ClaudeService.getInstance();
      const key =
          '  sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD  ';
      const trimmedKey =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';

      await service.saveApiKey(key);

      expect(mockSecureStorage['lila_claude_api_key'], equals(trimmedKey));
    });

    test('returns error for invalid key format', () async {
      final service = await ClaudeService.getInstance();

      final error = await service.saveApiKey('invalid-key');

      expect(error, isNotNull);
      expect(service.hasApiKey, isFalse);
    });

    test('returns error for empty key', () async {
      final service = await ClaudeService.getInstance();

      final error = await service.saveApiKey('');

      expect(error, isNotNull);
      expect(service.hasApiKey, isFalse);
    });
  });

  group('getApiKey', () {
    test('returns null when no key stored', () async {
      final service = await ClaudeService.getInstance();
      final key = await service.getApiKey();
      expect(key, isNull);
    });

    test('returns key when stored', () async {
      const storedKey =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      mockSecureStorage['lila_claude_api_key'] = storedKey;

      final service = await ClaudeService.getInstance();
      final key = await service.getApiKey();

      expect(key, equals(storedKey));
    });
  });

  group('deleteApiKey', () {
    test('removes key from secure storage', () async {
      mockSecureStorage['lila_claude_api_key'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await ClaudeService.getInstance();
      expect(service.hasApiKey, isTrue);

      await service.deleteApiKey();

      expect(mockSecureStorage['lila_claude_api_key'], isNull);
      expect(service.hasApiKey, isFalse);
      expect(service.maskedKey, isNull);
    });

    test('disables integration when key deleted', () async {
      mockSecureStorage['lila_claude_api_key'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      SharedPreferences.setMockInitialValues({
        'claude_integration_enabled': true,
      });

      final service = await ClaudeService.getInstance();
      await service.deleteApiKey();

      expect(service.isEnabled, isFalse);
    });
  });

  group('integration toggle', () {
    test('isEnabled is false when no key', () async {
      final service = await ClaudeService.getInstance();
      expect(service.isEnabled, isFalse);
    });

    test('isEnabled is false when key exists but not enabled', () async {
      mockSecureStorage['lila_claude_api_key'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await ClaudeService.getInstance();
      expect(service.isEnabled, isFalse);
    });

    test('isEnabled is true when key exists and enabled', () async {
      mockSecureStorage['lila_claude_api_key'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      SharedPreferences.setMockInitialValues({
        'claude_integration_enabled': true,
      });

      final service = await ClaudeService.getInstance();
      expect(service.isEnabled, isTrue);
    });

    test('setEnabled persists state', () async {
      mockSecureStorage['lila_claude_api_key'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await ClaudeService.getInstance();

      await service.setEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('claude_integration_enabled'), isTrue);
      expect(service.isEnabled, isTrue);
    });

    test('cannot enable without key', () async {
      final service = await ClaudeService.getInstance();

      await service.setEnabled(true);

      expect(service.isEnabled, isFalse);
    });
  });

  group('model selection', () {
    test('default model is haiku', () async {
      final service = await ClaudeService.getInstance();
      expect(service.selectedModel, equals('claude-haiku-4-5-20251001'));
    });

    test('setModel persists selection', () async {
      final service = await ClaudeService.getInstance();

      await service.setModel('claude-sonnet-4-20250514');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('claude_model'),
          equals('claude-sonnet-4-20250514'));
      expect(service.selectedModel, equals('claude-sonnet-4-20250514'));
    });
  });

  group('daily token cap', () {
    test('default cap is 0 (no cap)', () async {
      final service = await ClaudeService.getInstance();
      expect(service.dailyTokenCap, equals(0));
    });

    test('setDailyTokenCap persists value', () async {
      final service = await ClaudeService.getInstance();

      await service.setDailyTokenCap(100000);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('claude_daily_token_cap'), equals(100000));
      expect(service.dailyTokenCap, equals(100000));
    });
  });
}
