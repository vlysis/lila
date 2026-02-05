import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_restore_test_');
    fakeDocs = '${tempDir.path}/Documents';
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

  test('restoreVaultFrom replaces vault contents with backup', () async {
    final fs = await FileService.getInstance();
    final oldDate = DateTime(2026, 2, 4, 9, 0);
    await fs.appendEntry(
      LogEntry(
        label: 'Old entry',
        mode: Mode.maintenance,
        orientation: LogOrientation.self_,
        timestamp: oldDate,
      ),
    );

    final backupDir = Directory('${tempDir.path}/BackupSource');
    await Directory('${backupDir.path}/Daily').create(recursive: true);
    await Directory('${backupDir.path}/Meta').create(recursive: true);
    await File('${backupDir.path}/Daily/2026-02-05.md')
        .writeAsString('backup-content');
    await File('${backupDir.path}/Meta/modes.md').writeAsString('modes');

    await fs.restoreVaultFrom(backupDir.path);

    expect(
      File('${fs.rootDir}/Daily/2026-02-04.md').existsSync(),
      isFalse,
    );
    final restored = File('${fs.rootDir}/Daily/2026-02-05.md');
    expect(restored.existsSync(), isTrue);
    expect(restored.readAsStringSync(), equals('backup-content'));
    expect(Directory('${fs.rootDir}/Activities').existsSync(), isTrue);
  });
}
