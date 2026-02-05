import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/services/ai_integration_service.dart';
import 'package:lila/services/ai_provider.dart';

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
    AiIntegrationService.resetInstance();
  });

  tearDown(() {
    AiIntegrationService.resetInstance();
  });

  group('key format validation', () {
    test('accepts valid API key format', () {
      const validKey = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, validKey),
        isNull,
      );
    });

    test('accepts key with underscores and hyphens', () {
      const validKey = 'sk-ant-api03-abc_def-ghi_jkl-mno_pqr-stu_vwx-yz0123456789';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, validKey),
        isNull,
      );
    });

    test('rejects empty key', () {
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, ''),
        isNotNull,
      );
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, '   '),
        isNotNull,
      );
    });

    test('rejects key without sk-ant-api03 prefix', () {
      const invalidKey = 'api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, invalidKey),
        isNotNull,
      );
    });

    test('rejects key with wrong prefix', () {
      const invalidKey = 'sk-ant-api02-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, invalidKey),
        isNotNull,
      );
    });

    test('rejects key that is too short', () {
      const shortKey = 'sk-ant-api03-abc';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, shortKey),
        isNotNull,
      );
    });

    test('rejects key with invalid characters', () {
      const invalidKey = 'sk-ant-api03-abc!@#\$%^&*()abcdefghijklmnopqrst';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, invalidKey),
        isNotNull,
      );
    });

    test('trims whitespace from key', () {
      const keyWithSpaces =
          '  sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD  ';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.claude, keyWithSpaces),
        isNull,
      );
    });
  });

  group('initialization', () {
    test('hasApiKey is false when no key stored', () async {
      final service = await AiIntegrationService.getInstance();
      expect(service.hasApiKey(AiProvider.claude), isFalse);
    });

    test('hasApiKey is true when key is stored', () async {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await AiIntegrationService.getInstance();
      expect(service.hasApiKey(AiProvider.claude), isTrue);
    });

    test('maskedKey is null when no key stored', () async {
      final service = await AiIntegrationService.getInstance();
      expect(service.maskedKey(AiProvider.claude), isNull);
    });

    test('maskedKey shows last 4 chars when key stored', () async {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await AiIntegrationService.getInstance();
      expect(service.maskedKey(AiProvider.claude), equals('sk-ant-...ABCD'));
    });
  });

  group('saveApiKey', () {
    test('saves valid key to secure storage', () async {
      final service = await AiIntegrationService.getInstance();
      const key = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';

      final error = await service.saveApiKey(AiProvider.claude, key);

      expect(error, isNull);
      expect(mockSecureStorage['lila_ai_api_key_claude'], equals(key));
      expect(service.hasApiKey(AiProvider.claude), isTrue);
      expect(service.maskedKey(AiProvider.claude), equals('sk-ant-...ABCD'));
    });

    test('trims whitespace when saving', () async {
      final service = await AiIntegrationService.getInstance();
      const key =
          '  sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD  ';
      const trimmedKey =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';

      await service.saveApiKey(AiProvider.claude, key);

      expect(mockSecureStorage['lila_ai_api_key_claude'], equals(trimmedKey));
    });

    test('returns error for invalid key format', () async {
      final service = await AiIntegrationService.getInstance();

      final error = await service.saveApiKey(AiProvider.claude, 'invalid-key');

      expect(error, isNotNull);
      expect(service.hasApiKey(AiProvider.claude), isFalse);
    });

    test('returns error for empty key', () async {
      final service = await AiIntegrationService.getInstance();

      final error = await service.saveApiKey(AiProvider.claude, '');

      expect(error, isNotNull);
      expect(service.hasApiKey(AiProvider.claude), isFalse);
    });
  });

  group('getApiKey', () {
    test('returns null when no key stored', () async {
      final service = await AiIntegrationService.getInstance();
      final key = await service.getApiKey(AiProvider.claude);
      expect(key, isNull);
    });

    test('returns key when stored', () async {
      const storedKey =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      mockSecureStorage['lila_ai_api_key_claude'] = storedKey;

      final service = await AiIntegrationService.getInstance();
      final key = await service.getApiKey(AiProvider.claude);

      expect(key, equals(storedKey));
    });
  });

  group('deleteApiKey', () {
    test('removes key from secure storage', () async {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await AiIntegrationService.getInstance();
      expect(service.hasApiKey(AiProvider.claude), isTrue);

      await service.deleteApiKey(AiProvider.claude);

      expect(mockSecureStorage['lila_ai_api_key_claude'], isNull);
      expect(service.hasApiKey(AiProvider.claude), isFalse);
      expect(service.maskedKey(AiProvider.claude), isNull);
    });

    test('disables integration when key deleted', () async {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      SharedPreferences.setMockInitialValues({
        'ai_integration_enabled': true,
      });

      final service = await AiIntegrationService.getInstance();
      await service.deleteApiKey(AiProvider.claude);

      expect(service.isEnabled, isFalse);
    });
  });

  group('integration toggle', () {
    test('isEnabled is false when no key', () async {
      final service = await AiIntegrationService.getInstance();
      expect(service.isEnabled, isFalse);
    });

    test('isEnabled is false when key exists but not enabled', () async {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await AiIntegrationService.getInstance();
      expect(service.isEnabled, isFalse);
    });

    test('isEnabled is true when key exists and enabled', () async {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      SharedPreferences.setMockInitialValues({
        'ai_integration_enabled': true,
      });

      final service = await AiIntegrationService.getInstance();
      expect(service.isEnabled, isTrue);
    });

    test('setEnabled persists state', () async {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
      final service = await AiIntegrationService.getInstance();

      await service.setEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ai_integration_enabled'), isTrue);
      expect(service.isEnabled, isTrue);
    });

    test('cannot enable without key', () async {
      final service = await AiIntegrationService.getInstance();

      await service.setEnabled(true);

      expect(service.isEnabled, isFalse);
    });
  });

  group('model selection', () {
    test('default model is haiku', () async {
      final service = await AiIntegrationService.getInstance();
      expect(
        service.selectedModel(AiProvider.claude),
        equals('claude-haiku-4-5-20251001'),
      );
    });

    test('setModel persists selection', () async {
      final service = await AiIntegrationService.getInstance();

      await service.setModel(AiProvider.claude, 'claude-sonnet-4-20250514');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_model_claude'),
          equals('claude-sonnet-4-20250514'));
      expect(
        service.selectedModel(AiProvider.claude),
        equals('claude-sonnet-4-20250514'),
      );
    });
  });
}
