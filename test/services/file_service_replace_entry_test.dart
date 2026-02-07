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

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_replace_entry_test_');
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

  test('replaceEntry swaps entry in-place', () async {
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

    final replacement = LogEntry(
      label: 'Studying',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );

    final replaced = await fs.replaceEntry(entry1, replacement);
    expect(replaced, isTrue);

    final content = await fs.readDailyRaw(date);
    expect(content, isNot(contains('Reading')));
    expect(content, contains('Studying'));
    expect(content, contains('Walk'));
  });

  test('replaceEntry preserves order', () async {
    final fs = await FileService.getInstance();
    final date = DateTime(2026, 2, 3);

    final entry1 = LogEntry(
      label: 'First',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 9)),
    );
    final entry2 = LogEntry(
      label: 'Second',
      mode: Mode.nourishment,
      orientation: LogOrientation.other,
      timestamp: date.add(const Duration(hours: 11)),
    );
    final entry3 = LogEntry(
      label: 'Third',
      mode: Mode.maintenance,
      orientation: LogOrientation.mutual,
      timestamp: date.add(const Duration(hours: 14)),
    );

    await fs.appendEntry(entry1);
    await fs.appendEntry(entry2);
    await fs.appendEntry(entry3);

    final replacement = LogEntry(
      label: 'Updated Second',
      mode: Mode.drift,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 11)),
    );

    await fs.replaceEntry(entry2, replacement);

    final content = await fs.readDailyRaw(date);
    final firstIdx = content.indexOf('First');
    final secondIdx = content.indexOf('Updated Second');
    final thirdIdx = content.indexOf('Third');

    expect(firstIdx, lessThan(secondIdx));
    expect(secondIdx, lessThan(thirdIdx));
  });

  test('replaceEntry preserves reflection section', () async {
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

    final replacement = LogEntry(
      label: 'Studying',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );

    await fs.replaceEntry(entry, replacement);

    final content = await fs.readDailyRaw(date);
    expect(content, contains('## Reflection'));
    expect(content, contains('Felt calm.'));
    expect(content, contains('Studying'));
    expect(content, isNot(contains('Reading')));
  });

  test('replaceEntry returns false when no match', () async {
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

    final replacement = LogEntry(
      label: 'New',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );

    final replaced = await fs.replaceEntry(missing, replacement);
    expect(replaced, isFalse);

    final content = await fs.readDailyRaw(date);
    expect(content, contains('Reading'));
  });

  test('replaceEntry replaces only first matching duplicate', () async {
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

    final replacement = LogEntry(
      label: 'Studying',
      mode: Mode.growth,
      orientation: LogOrientation.self_,
      timestamp: date.add(const Duration(hours: 10)),
    );

    await fs.replaceEntry(entry, replacement);

    final content = await fs.readDailyRaw(date);
    final studyingCount = RegExp(r'- \*\*Studying\*\*').allMatches(content).length;
    final readingCount = RegExp(r'- \*\*Reading\*\*').allMatches(content).length;
    expect(studyingCount, equals(1));
    expect(readingCount, equals(1));
  });
}
