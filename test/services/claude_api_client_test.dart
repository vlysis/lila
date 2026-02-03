import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/services/claude_api_client.dart';
import 'package:lila/services/claude_service.dart';
import 'package:lila/services/claude_usage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStorage = {};

  setUp(() {
    mockSecureStorage.clear();

    // Mock flutter_secure_storage
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
    ClaudeService.resetInstance();
    ClaudeApiClient.resetInstance();
  });

  tearDown(() {
    ClaudeService.resetInstance();
    ClaudeApiClient.resetInstance();
    ClaudeUsageService.resetInstance();
  });

  group('ClaudeApiError', () {
    test('keyInvalid has correct user message', () {
      expect(
        ClaudeApiError.keyInvalid.userMessage,
        contains('invalid'),
      );
    });

    test('rateLimited has correct user message', () {
      expect(
        ClaudeApiError.rateLimited.userMessage,
        contains('usage limit'),
      );
    });

    test('serverError has correct user message', () {
      expect(
        ClaudeApiError.serverError.userMessage,
        contains("Anthropic's side"),
      );
    });

    test('networkOffline has correct user message', () {
      expect(
        ClaudeApiError.networkOffline.userMessage,
        contains('No internet'),
      );
    });

    test('timeout has correct user message', () {
      expect(
        ClaudeApiError.timeout.userMessage,
        contains('took too long'),
      );
    });

    test('storageFailed has correct user message', () {
      expect(
        ClaudeApiError.storageFailed.userMessage,
        contains('Unable to save'),
      );
    });

    test('unknown has correct user message', () {
      expect(
        ClaudeApiError.unknown.userMessage,
        contains('unexpected error'),
      );
    });

    test('dailyCapReached has correct user message', () {
      expect(
        ClaudeApiError.dailyCapReached.userMessage,
        contains('daily token limit'),
      );
    });

    test('integrationPaused has correct user message', () {
      expect(
        ClaudeApiError.integrationPaused.userMessage,
        contains('paused'),
      );
    });
  });

  group('ClaudeApiResult', () {
    test('isSuccess returns true when data present and no error', () {
      final result = ClaudeApiResult(data: 'test');
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
    });

    test('isError returns true when error present', () {
      final result = ClaudeApiResult<String>(error: ClaudeApiError.keyInvalid);
      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
    });

    test('stores token usage', () {
      final result = ClaudeApiResult(
        data: 'test',
        inputTokens: 10,
        outputTokens: 20,
      );
      expect(result.inputTokens, equals(10));
      expect(result.outputTokens, equals(20));
    });
  });

  group('ClaudeApiClient initialization', () {
    test('getInstance returns same instance', () async {
      final client1 = await ClaudeApiClient.getInstance();
      final client2 = await ClaudeApiClient.getInstance();
      expect(identical(client1, client2), isTrue);
    });

    test('resetInstance clears singleton', () async {
      final client1 = await ClaudeApiClient.getInstance();
      ClaudeApiClient.resetInstance();
      final client2 = await ClaudeApiClient.getInstance();
      expect(identical(client1, client2), isFalse);
    });
  });

  group('sendMessage preconditions', () {
    test('returns integrationPaused when not enabled', () async {
      // No key in storage = integration can't be enabled
      final client = await ClaudeApiClient.getInstance();
      final result = await client.sendMessage(message: 'test');

      expect(result.isError, isTrue);
      expect(result.error, equals(ClaudeApiError.integrationPaused));
    });
  });

  // Note: Full network tests would require mocking dio adapter
  // These tests verify the error handling and structure without making real API calls
}
