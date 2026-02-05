import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/models/focus_state.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/services/intention_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  late String defaultVault;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_intention_test_');
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
    IntentionService.resetInstance();
  });

  tearDown(() {
    FileService.resetInstance();
    IntentionService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  test('readCurrent returns default when file missing', () async {
    final service = await IntentionService.getInstance();
    final current = await service.readCurrent();

    expect(current.season, FocusSeason.explorer);
    expect(current.intention, isEmpty);
    expect(current.setAt, isNull);
  });

  test('setCurrent writes file and readCurrent returns values', () async {
    final service = await IntentionService.getInstance();
    final setAt = DateTime(2026, 2, 3, 8, 0);

    await service.setCurrent(
      FocusState(
        season: FocusSeason.sanctuary,
        intention: 'Pause and recover',
        setAt: setAt,
      ),
    );

    final current = await service.readCurrent();
    expect(current.season, FocusSeason.sanctuary);
    expect(current.intention, 'Pause and recover');
    expect(current.setAt?.toIso8601String(), setAt.toIso8601String());

    final file = File('$defaultVault/Meta/intentions.md');
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('season:: sanctuary'));
    expect(content, contains('intention:: Pause and recover'));
    expect(content, contains('set_at:: ${setAt.toIso8601String()}'));
  });
}
