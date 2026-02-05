import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/screens/settings_screen.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/services/ai_integration_service.dart';
import 'package:lila/services/ai_usage_service.dart';
import 'package:lila/services/ai_provider.dart';
import 'package:lila/services/claude_api_client.dart';

/// Fake [FilePicker] that returns a predetermined directory path.
class FakeFilePicker extends FilePicker {
  String? nextResult;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    return nextResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  late String defaultVault;
  late FakeFilePicker fakePicker;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_settings_test_');
    fakeDocs = '${tempDir.path}/Documents';
    defaultVault = '$fakeDocs/Lila';
    Directory(fakeDocs).createSync();

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
        // Return null for all secure storage calls (no key stored)
        return null;
      },
    );

    fakePicker = FakeFilePicker();
    FilePicker.platform = fakePicker;

    FileService.resetInstance();
    AiIntegrationService.resetInstance();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FileService.resetInstance();
    AiIntegrationService.resetInstance();
    ClaudeApiClient.resetInstance();
    AiUsageService.resetInstance(AiProvider.claude);
    tempDir.deleteSync(recursive: true);
  });

  Widget buildApp() {
    return MaterialApp(
      home: const SettingsScreen(),
    );
  }

  /// Pump the widget and wait for the async _loadPath and _loadClaudeState to complete.
  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      await FileService.getInstance();
      await AiIntegrationService.getInstance();
      await AiUsageService.getInstance(AiProvider.claude);
    });
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  /// Tap Change, wait for the bottom sheet, then tap an option and settle.
  Future<void> tapChangeOption(WidgetTester tester, String option) async {
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text(option));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('displays current vault path', (tester) async {
    await pumpSettingsScreen(tester);
    expect(find.text(defaultVault), findsOneWidget);
  });

  testWidgets('displays Change button', (tester) async {
    await pumpSettingsScreen(tester);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('displays Backup vault button', (tester) async {
    await pumpSettingsScreen(tester);
    expect(find.text('Backup vault'), findsOneWidget);
  });

  testWidgets('displays Restore vault button', (tester) async {
    await pumpSettingsScreen(tester);
    expect(find.text('Restore vault'), findsOneWidget);
  });

  group('bottom sheet', () {
    testWidgets('tapping Change shows bottom sheet with two options',
        (tester) async {
      await pumpSettingsScreen(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Choose existing folder'), findsOneWidget);
      expect(find.text('Create new folder'), findsOneWidget);
    });
  });

  group('choose existing folder', () {
    testWidgets('updates path on selection', (tester) async {
      final newPath = '${tempDir.path}/PickedVault';
      Directory(newPath).createSync();
      fakePicker.nextResult = newPath;

      await pumpSettingsScreen(tester);
      expect(find.text(defaultVault), findsOneWidget);

      await tapChangeOption(tester, 'Choose existing folder');

      expect(find.text(newPath), findsOneWidget);
      expect(find.text(defaultVault), findsNothing);
      expect(find.text('Vault location updated.'), findsOneWidget);
    });

    testWidgets('picker cancelled does not change path', (tester) async {
      fakePicker.nextResult = null;

      await pumpSettingsScreen(tester);
      expect(find.text(defaultVault), findsOneWidget);

      await tapChangeOption(tester, 'Choose existing folder');

      expect(find.text(defaultVault), findsOneWidget);
      expect(find.text('Vault location updated.'), findsNothing);
    });

    testWidgets('persists selected path to SharedPreferences',
        (tester) async {
      final newPath = '${tempDir.path}/Persisted';
      Directory(newPath).createSync();
      fakePicker.nextResult = newPath;

      await pumpSettingsScreen(tester);
      await tapChangeOption(tester, 'Choose existing folder');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_vault_path'), equals(newPath));
    });

    testWidgets('creates vault directories at selected path', (tester) async {
      final newPath = '${tempDir.path}/NewVault';
      fakePicker.nextResult = newPath;

      await pumpSettingsScreen(tester);
      await tapChangeOption(tester, 'Choose existing folder');

      expect(Directory('$newPath/Daily').existsSync(), isTrue);
      expect(Directory('$newPath/Weekly').existsSync(), isTrue);
      expect(Directory('$newPath/Meta').existsSync(), isTrue);
    });
  });

  group('create new folder', () {
    testWidgets('shows name dialog when tapped', (tester) async {
      await pumpSettingsScreen(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create new folder'));
      await tester.pumpAndSettle();

      expect(find.text('New folder name'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancelling name dialog does not change path', (tester) async {
      await pumpSettingsScreen(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create new folder'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text(defaultVault), findsOneWidget);
      expect(find.text('Vault location updated.'), findsNothing);
    });

    testWidgets('empty name does not proceed', (tester) async {
      await pumpSettingsScreen(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create new folder'));
      await tester.pumpAndSettle();

      // Tap Next without entering a name
      await tester.runAsync(() async {
        await tester.tap(find.text('Next'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text(defaultVault), findsOneWidget);
      expect(find.text('Vault location updated.'), findsNothing);
    });

    testWidgets('creates folder and updates vault path', (tester) async {
      final parentPath = '${tempDir.path}/Parent';
      Directory(parentPath).createSync();
      fakePicker.nextResult = parentPath;

      await pumpSettingsScreen(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      // Tap "Create new folder" inside runAsync so the entire async chain
      // (_createNewFolder → showDialog → getDirectoryPath → mkdir)
      // stays in the real-async zone where file I/O can complete.
      await tester.runAsync(() async {
        await tester.tap(find.text('Create new folder'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Enter folder name and tap Next (find TextField inside AlertDialog)
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'MyVault',
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Next'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      final expectedPath = '$parentPath/MyVault';
      expect(Directory(expectedPath).existsSync(), isTrue);
      expect(find.text(expectedPath), findsOneWidget);
      expect(find.text('Vault location updated.'), findsOneWidget);
    });

    testWidgets('cancelling parent picker does not change path',
        (tester) async {
      fakePicker.nextResult = null;

      await pumpSettingsScreen(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Create new folder'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'MyVault',
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Next'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(find.text(defaultVault), findsOneWidget);
      expect(find.text('Vault location updated.'), findsNothing);
    });
  });
}
