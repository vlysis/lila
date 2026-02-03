import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/services/ai_integration_service.dart';
import 'package:lila/services/ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStorage = {};

  setUp(() {
    mockSecureStorage.clear();

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

  group('Gemini key format validation', () {
    test('accepts non-empty keys without whitespace', () {
      const key = 'AIzaSyTestKeyValue1234567890';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.gemini, key),
        isNull,
      );
    });

    test('rejects empty keys', () {
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.gemini, ''),
        isNotNull,
      );
    });

    test('rejects keys with spaces', () {
      const keyWithSpace = 'AIza Sy Test';
      expect(
        AiIntegrationService.validateKeyFormat(AiProvider.gemini, keyWithSpace),
        isNotNull,
      );
    });
  });

  group('provider switching', () {
    test('disables integration when switching to provider without key', () async {
      final service = await AiIntegrationService.getInstance();
      const key = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';

      await service.saveApiKey(AiProvider.claude, key);
      await service.setEnabled(true);
      expect(service.isEnabled, isTrue);

      await service.setActiveProvider(AiProvider.gemini);
      expect(service.isEnabled, isFalse);
    });
  });
}
