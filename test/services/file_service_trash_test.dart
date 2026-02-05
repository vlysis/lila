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
  late String defaultVault;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_trash_test_');
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

  test('moveEntryToTrash removes from daily and appends to trash', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3, 10, 30);

    final entry = LogEntry(
      label: 'Reading',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      duration: DurationPreset.deep,
      timestamp: date,
    );

    await fs.appendEntry(entry);
    final moved = await fs.moveEntryToTrash(entry);
    expect(moved, isTrue);

    final daily = await fs.readDailyRaw(DateTime(2026, 2, 3));
    expect(daily, isNot(contains('Reading')));

    final trashFile = File('$defaultVault/Trash/2026-02-03.md');
    expect(trashFile.existsSync(), isTrue);
    final trashContent = trashFile.readAsStringSync();
    expect(trashContent, contains('Reading'));
    expect(trashContent, contains('deleted_at::'));
    expect(trashContent, contains('source_date:: 2026-02-03'));
  });

  test('restoreEntry moves from trash back to daily', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3, 9, 15);

    final entry = LogEntry(
      label: 'Walk',
      mode: Mode.nourishment,
      orientation: LogOrientation.other,
      timestamp: date,
    );

    await fs.appendEntry(entry);
    await fs.moveEntryToTrash(entry);

    final trashEntries = await fs.readTrashEntriesForDate(date);
    expect(trashEntries, isNotEmpty);

    final restored = await fs.restoreEntry(trashEntries.first);
    expect(restored, isTrue);

    final daily = await fs.readDailyRaw(DateTime(2026, 2, 3));
    expect(daily, contains('Walk'));

    final trashFile = File('$defaultVault/Trash/2026-02-03.md');
    final trashContent = trashFile.readAsStringSync();
    expect(trashContent, isNot(contains('Walk')));
  });

  test('deleteTrashedEntry removes from trash file', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3, 14, 0);

    final entry = LogEntry(
      label: 'Stretch',
      mode: Mode.nourishment,
      orientation: LogOrientation.self_,
      timestamp: date,
    );

    await fs.appendEntry(entry);
    await fs.moveEntryToTrash(entry);

    final trashEntries = await fs.readTrashEntriesForDate(date);
    expect(trashEntries, isNotEmpty);

    final removed = await fs.deleteTrashedEntry(trashEntries.first);
    expect(removed, isTrue);

    final trashFile = File('$defaultVault/Trash/2026-02-03.md');
    final trashContent = trashFile.readAsStringSync();
    expect(trashContent, isNot(contains('Stretch')));
  });
}
