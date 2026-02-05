import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/screens/settings_screen.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/services/ai_integration_service.dart';
import 'package:lila/services/ai_provider.dart';
import 'package:lila/services/ai_usage_service.dart';
import 'package:lila/services/claude_api_client.dart';
import 'package:lila/services/focus_controller.dart';
import 'package:lila/theme/lila_theme.dart';
import 'package:lila/models/focus_state.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  final Map<String, String> mockSecureStorage = {};

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_claude_test_');
    fakeDocs = '${tempDir.path}/Documents';
    Directory(fakeDocs).createSync();
    mockSecureStorage.clear();

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return fakeDocs;
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider_macos'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return fakeDocs;
        }
        return null;
      },
    );

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
          case 'containsKey':
            final key = call.arguments['key'] as String;
            return mockSecureStorage.containsKey(key);
          default:
            return null;
        }
      },
    );

    FileService.resetInstance();
    AiIntegrationService.resetInstance();
    ClaudeApiClient.resetInstance();
    AiUsageService.resetAll();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FileService.resetInstance();
    AiIntegrationService.resetInstance();
    ClaudeApiClient.resetInstance();
    AiUsageService.resetAll();
    tempDir.deleteSync(recursive: true);
  });

  Widget buildApp() {
    return MaterialApp(
      theme: LilaTheme.forSeason(FocusSeason.explorer),
      home: SettingsScreen(focusController: FocusController()),
    );
  }

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      await FileService.getInstance();
      await AiIntegrationService.getInstance();
      await AiUsageService.getInstance(AiProvider.claude);
    });
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
  }

  group('AI & Integrations section', () {
    testWidgets('displays section title', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('AI & Integrations'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI & Integrations'), findsOneWidget);
    });

    testWidgets('shows provider selector defaulting to Claude', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Provider'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Claude'), findsOneWidget);
    });

    testWidgets('shows Claude integration toggle', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('AI integration'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI integration'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('toggle is disabled when no API key', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('AI integration'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      // The AI integration switch is the second one (after dark mode toggle)
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      final aiSwitch = switches.last;
      expect(aiSwitch.onChanged, isNull);
    });

    testWidgets('shows prompt to enter API key when none saved', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Enter an API key below to enable.'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter an API key below to enable.'), findsOneWidget);
    });

    testWidgets('shows API key input field', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Save key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      // Should have a TextField for API key entry
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows Save key button', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Save key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save key'), findsOneWidget);
    });
  });

  group('API key format validation', () {
    testWidgets('shows error for invalid key format', (tester) async {
      await pumpSettingsScreen(tester);

      // Scroll to the Save key area first
      await tester.dragUntilVisible(
        find.text('Save key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Find the API key TextField (it's obscured)
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'invalid-key');
      await tester.pumpAndSettle();

      // Tap Save key
      await tester.tap(find.text('Save key'));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.textContaining('Invalid'), findsOneWidget);
    });

    testWidgets('shows error for empty key', (tester) async {
      await pumpSettingsScreen(tester);

      // Tap Save key without entering anything
      await tester.dragUntilVisible(
        find.text('Save key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save key'));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.textContaining('empty'), findsOneWidget);
    });
  });

  group('with saved API key', () {
    setUp(() {
      // Pre-populate secure storage with a valid key
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
    });

    testWidgets('shows masked key display', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('AI & Integrations'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Should show masked key (last 4 chars)
      expect(find.textContaining('sk-ant-...'), findsOneWidget);
      expect(find.textContaining('ABCD'), findsOneWidget);
    });

    testWidgets('toggle is enabled when API key exists', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('AI integration'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      // The AI integration switch is the second one (after dark mode toggle)
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      final aiSwitch = switches.last;
      expect(aiSwitch.onChanged, isNotNull);
    });

    testWidgets('shows Change key and Remove key buttons', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Remove key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change key'), findsOneWidget);
      expect(find.text('Remove key'), findsOneWidget);
    });

    testWidgets('shows model selector dropdown', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Model'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Model'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('shows usage display', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Usage'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Usage'), findsOneWidget);
      expect(find.text('No usage today'), findsOneWidget);
    });

    testWidgets('shows daily limit option', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Daily limit'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Daily limit'), findsOneWidget);
      expect(find.text('No limit'), findsOneWidget);
    });

    testWidgets('tapping Change key shows input field', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Change key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change key'));
      await tester.pumpAndSettle();

      // Should show input field and Cancel button
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save key'), findsOneWidget);
    });

    testWidgets('tapping Remove key shows confirmation dialog', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Remove key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove key'));
      await tester.pumpAndSettle();

      expect(find.text('Remove API key?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('confirming Remove deletes key', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Remove key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Tap Remove key
      await tester.tap(find.text('Remove key'));
      await tester.pumpAndSettle();

      // Confirm removal
      await tester.runAsync(() async {
        await tester.tap(find.text('Remove'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Key should be removed from storage
      expect(mockSecureStorage['lila_ai_api_key_claude'], isNull);

      // Should show prompt to enter key again
      expect(find.text('Enter an API key below to enable.'), findsOneWidget);
    });

    testWidgets('cancelling Remove keeps key', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('Remove key'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove key'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Key should still exist
      expect(mockSecureStorage['lila_ai_api_key_claude'], isNotNull);
      expect(find.textContaining('sk-ant-...'), findsOneWidget);
    });
  });

  group('model selector', () {
    setUp(() {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
    });

    testWidgets('default model is Haiku', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.byType(DropdownButton<String>),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Haiku (fastest, cheapest)'), findsOneWidget);
    });

    testWidgets('can open model dropdown', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.byType(DropdownButton<String>),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Should show all model options
      expect(find.text('Haiku (fastest, cheapest)'), findsWidgets);
      expect(find.text('Sonnet (balanced)'), findsOneWidget);
      expect(find.text('Opus (most capable)'), findsOneWidget);
    });
  });

  group('daily limit dialog', () {
    setUp(() {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
    });

    testWidgets('tapping daily limit opens dialog', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('No limit'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('No limit'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Daily token limit'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('toggle behavior', () {
    setUp(() {
      mockSecureStorage['lila_ai_api_key_claude'] =
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD';
    });

    testWidgets('toggle starts OFF', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('AI integration'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      // The AI integration switch is the second one (after dark mode toggle)
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      final aiSwitch = switches.last;
      expect(aiSwitch.value, isFalse);
    });

    testWidgets('tapping toggle changes state', (tester) async {
      await pumpSettingsScreen(tester);

      await tester.dragUntilVisible(
        find.text('AI integration'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      // Tap the AI integration switch (the last one)
      final switches = find.byType(Switch);
      await tester.tap(switches.last);
      await tester.pumpAndSettle();

      final updatedSwitches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      final aiSwitch = updatedSwitches.last;
      expect(aiSwitch.value, isTrue);
    });
  });
}
