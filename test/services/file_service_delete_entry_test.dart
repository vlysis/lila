import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/models/log_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  late String defaultVault;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_delete_entry_test_');
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

  test('deleteEntry removes matching entry', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3);

    final entry1 = LogEntry(
      label: 'Reading',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );
    final entry2 = LogEntry(
      label: 'Walk',
      mode: Mode.nourishment,
      orientation: LogOrientation.other,
      timestamp: date.add(const Duration(hours: 12, minutes: 30)),
    );

    await fs.appendEntry(entry1);
    await fs.appendEntry(entry2);

    final removed = await fs.deleteEntry(entry1);
    expect(removed, isTrue);

    final content = await fs.readDailyRaw(date);
    expect(content, isNot(contains('Reading')));
    expect(content, contains('Walk'));
  });

  test('deleteEntry returns false when no match', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3);

    final entry = LogEntry(
      label: 'Reading',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );
    await fs.appendEntry(entry);

    final missing = LogEntry(
      label: 'Missing',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );

    final removed = await fs.deleteEntry(missing);
    expect(removed, isFalse);

    final content = await fs.readDailyRaw(date);
    expect(content, contains('Reading'));
  });

  test('deleteEntry preserves reflection and discussion sections', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3);

    final entry = LogEntry(
      label: 'Reading',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );
    await fs.appendEntry(entry);
    await fs.saveDailyReflection(date, 'Felt calm.');
    await fs.saveDiscussion(date, '**User:** hi');

    final removed = await fs.deleteEntry(entry);
    expect(removed, isTrue);

    final content = await fs.readDailyRaw(date);
    expect(content, contains('## Reflection'));
    expect(content, contains('Felt calm.'));
    expect(content, contains('## Discussion'));
    expect(content, contains('**User:** hi'));
  });

  test('deleteEntry removes only one matching duplicate', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3);

    final entry = LogEntry(
      label: 'Reading',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );

    await fs.appendEntry(entry);
    await fs.appendEntry(entry);

    final removed = await fs.deleteEntry(entry);
    expect(removed, isTrue);

    final content = await fs.readDailyRaw(date);
    final occurrences = RegExp(r'- \*\*Reading\*\*').allMatches(content).length;
    expect(occurrences, equals(1));
  });

  test('deleteEntry respects duration when provided', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3);

    final entry = LogEntry(
      label: 'Practice',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      duration: DurationPreset.deep,
      timestamp: date.add(const Duration(hours: 10)),
    );
    await fs.appendEntry(entry);

    final mismatch = LogEntry(
      label: 'Practice',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      duration: DurationPreset.focused,
      timestamp: date.add(const Duration(hours: 10)),
    );

    final removed = await fs.deleteEntry(mismatch);
    expect(removed, isFalse);

    final removedMatch = await fs.deleteEntry(entry);
    expect(removedMatch, isTrue);
  });
}
