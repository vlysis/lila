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
    tempDir = Directory.systemTemp.createTempSync('lila_dates_test_');
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

    SharedPreferences.setMockInitialValues({});
    FileService.resetInstance();
  });

  tearDown(() {
    FileService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  test('returns empty list when Daily directory is empty', () async {
    final fs = await FileService.getInstance();
    final dates = await fs.getAvailableDates();
    expect(dates, isEmpty);
  });

  test('returns sorted dates from Daily directory', () async {
    final fs = await FileService.getInstance();

    // Create files in non-sorted order
    await File('$defaultVault/Daily/2026-01-15.md')
        .writeAsString('---\ndate: 2026-01-15\n---\n');
    await File('$defaultVault/Daily/2026-01-10.md')
        .writeAsString('---\ndate: 2026-01-10\n---\n');
    await File('$defaultVault/Daily/2026-01-20.md')
        .writeAsString('---\ndate: 2026-01-20\n---\n');

    final dates = await fs.getAvailableDates();
    expect(dates.length, 3);
    expect(dates[0], DateTime(2026, 1, 10));
    expect(dates[1], DateTime(2026, 1, 15));
    expect(dates[2], DateTime(2026, 1, 20));
  });

  test('ignores malformed filenames', () async {
    final fs = await FileService.getInstance();

    await File('$defaultVault/Daily/2026-01-15.md')
        .writeAsString('---\ndate: 2026-01-15\n---\n');
    await File('$defaultVault/Daily/notes.md')
        .writeAsString('some notes');
    await File('$defaultVault/Daily/2026-13-01.md')
        .writeAsString('invalid month');

    final dates = await fs.getAvailableDates();
    expect(dates.length, 1);
    expect(dates[0], DateTime(2026, 1, 15));
  });

  test('ignores non-md files', () async {
    final fs = await FileService.getInstance();

    await File('$defaultVault/Daily/2026-01-15.md')
        .writeAsString('---\ndate: 2026-01-15\n---\n');
    await File('$defaultVault/Daily/2026-01-16.txt')
        .writeAsString('not markdown');

    final dates = await fs.getAvailableDates();
    expect(dates.length, 1);
    expect(dates[0], DateTime(2026, 1, 15));
  });
}
