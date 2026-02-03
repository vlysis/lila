import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  late String defaultVault;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_test_');
    fakeDocs = '${tempDir.path}/Documents';
    defaultVault = '$fakeDocs/Lila';
    Directory(fakeDocs).createSync();

    // Mock path_provider to return our temp directory
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

    // Mock path_provider_macos channel too
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

    FileService.resetInstance();
  });

  tearDown(() {
    FileService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  group('vault path', () {
    test('uses default path when no custom path is set', () async {
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();
      expect(fs.rootDir, equals(defaultVault));
    });

    test('creates vault directories at default path', () async {
      SharedPreferences.setMockInitialValues({});
      await FileService.getInstance();
      expect(Directory('$defaultVault/Daily').existsSync(), isTrue);
      expect(Directory('$defaultVault/Activities').existsSync(), isTrue);
      expect(Directory('$defaultVault/Weekly').existsSync(), isTrue);
      expect(Directory('$defaultVault/Meta').existsSync(), isTrue);
    });

    test('creates modes.md at default path', () async {
      SharedPreferences.setMockInitialValues({});
      await FileService.getInstance();
      final modesFile = File('$defaultVault/Meta/modes.md');
      expect(modesFile.existsSync(), isTrue);
      final content = modesFile.readAsStringSync();
      expect(content, contains('nourishment'));
      expect(content, contains('growth'));
    });

    test('uses custom path from SharedPreferences', () async {
      final customPath = '${tempDir.path}/CustomVault';
      Directory(customPath).createSync(); // Must exist for write access check
      SharedPreferences.setMockInitialValues({'custom_vault_path': customPath});
      final fs = await FileService.getInstance();
      expect(fs.rootDir, equals(customPath));
    });

    test('creates vault directories at custom path', () async {
      final customPath = '${tempDir.path}/CustomVault';
      Directory(customPath).createSync(); // Must exist for write access check
      SharedPreferences.setMockInitialValues({'custom_vault_path': customPath});
      await FileService.getInstance();
      expect(Directory('$customPath/Daily').existsSync(), isTrue);
      expect(Directory('$customPath/Weekly').existsSync(), isTrue);
      expect(Directory('$customPath/Meta').existsSync(), isTrue);
    });

    test('falls back to default when custom path has no write access', () async {
      final customPath = '${tempDir.path}/NoAccess';
      // Don't create the directory - simulates permission denied
      SharedPreferences.setMockInitialValues({'custom_vault_path': customPath});
      final fs = await FileService.getInstance();
      expect(fs.rootDir, equals(defaultVault));
      // Pref should be cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_vault_path'), isNull);
    });

    test('ignores empty custom path string', () async {
      SharedPreferences.setMockInitialValues({'custom_vault_path': ''});
      final fs = await FileService.getInstance();
      expect(fs.rootDir, equals(defaultVault));
    });

    test('setVaultPath updates rootDir', () async {
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();
      final newPath = '${tempDir.path}/NewVault';
      await fs.setVaultPath(newPath);
      expect(fs.rootDir, equals(newPath));
    });

    test('setVaultPath creates directories at new location', () async {
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();
      final newPath = '${tempDir.path}/NewVault';
      await fs.setVaultPath(newPath);
      expect(Directory('$newPath/Daily').existsSync(), isTrue);
      expect(Directory('$newPath/Activities').existsSync(), isTrue);
      expect(Directory('$newPath/Weekly').existsSync(), isTrue);
      expect(Directory('$newPath/Meta').existsSync(), isTrue);
    });

    test('setVaultPath persists custom path', () async {
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();
      final newPath = '${tempDir.path}/NewVault';
      await fs.setVaultPath(newPath);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_vault_path'), equals(newPath));
    });

    test('setVaultPath removes pref when set back to default', () async {
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();
      final newPath = '${tempDir.path}/NewVault';
      await fs.setVaultPath(newPath);
      await fs.setVaultPath(defaultVault);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_vault_path'), isNull);
      expect(fs.rootDir, equals(defaultVault));
    });

    test('custom path persists across getInstance after reset', () async {
      final customPath = '${tempDir.path}/Persistent';
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();
      await fs.setVaultPath(customPath);

      // Simulate app restart
      FileService.resetInstance();
      SharedPreferences.setMockInitialValues(
        {'custom_vault_path': customPath},
      );
      final fs2 = await FileService.getInstance();
      expect(fs2.rootDir, equals(customPath));
    });

    test('old vault files are not moved to new path', () async {
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();

      // Create a file in the old vault
      File('$defaultVault/Daily/2026-01-01.md')
          .writeAsStringSync('old content');

      final newPath = '${tempDir.path}/NewVault';
      await fs.setVaultPath(newPath);

      // Old file still at old location
      expect(
        File('$defaultVault/Daily/2026-01-01.md').existsSync(),
        isTrue,
      );
      // New location does not have the old file
      expect(
        File('$newPath/Daily/2026-01-01.md').existsSync(),
        isFalse,
      );
    });

    test('file operations use new path after setVaultPath', () async {
      SharedPreferences.setMockInitialValues({});
      final fs = await FileService.getInstance();
      final newPath = '${tempDir.path}/NewVault';
      await fs.setVaultPath(newPath);

      final date = DateTime(2026, 3, 15);
      final raw = await fs.readDailyRaw(date);
      expect(raw, isEmpty);

      // weeklyFilePath should reflect new root
      final weeklyPath = fs.weeklyFilePath(DateTime(2026, 1, 27));
      expect(weeklyPath, startsWith(newPath));
    });
  });
}
