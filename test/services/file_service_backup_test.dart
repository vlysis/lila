import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  late String defaultVault;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_backup_test_');
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

  test('backupVaultTo copies vault contents to destination', () async {
    final fs = await FileService.getInstance();
    final now = DateTime(2026, 2, 5, 10, 30);
    await fs.appendEntry(
      LogEntry(
        label: 'Morning',
        mode: Mode.nourishment,
        orientation: LogOrientation.self_,
        timestamp: now,
      ),
    );

    final backupRoot = Directory('${tempDir.path}/Backups');
    await backupRoot.create(recursive: true);

    final backupPath = await fs.backupVaultTo(backupRoot.path);
    expect(Directory(backupPath).existsSync(), isTrue);

    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final originalFile = File('${fs.rootDir}/Daily/$dateStr.md');
    expect(originalFile.existsSync(), isTrue);
    final backedUpFile = File('$backupPath/Daily/$dateStr.md');

    expect(backedUpFile.existsSync(), isTrue);
    expect(backedUpFile.readAsStringSync(),
        equals(originalFile.readAsStringSync()));
  });
}
