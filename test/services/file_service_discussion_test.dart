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
    tempDir = Directory.systemTemp.createTempSync('lila_discussion_test_');
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

  group('readDiscussion', () {
    test('returns null when file does not exist', () async {
      final fs = await FileService.getInstance();
      final result = await fs.readDiscussion(DateTime(2026, 2, 3));
      expect(result, isNull);
    });

    test('returns null when no discussion section exists', () async {
      final fs = await FileService.getInstance();
      final date = DateTime(2026, 2, 3);

      // Create a daily file without discussion
      final entry = LogEntry(
        label: 'Test',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        timestamp: date.add(const Duration(hours: 10)),
      );
      await fs.appendEntry(entry);

      final result = await fs.readDiscussion(date);
      expect(result, isNull);
    });

    test('returns null when discussion section is empty', () async {
      final fs = await FileService.getInstance();
      final date = DateTime(2026, 2, 3);
      final filePath = '$defaultVault/Daily/2026-02-03.md';

      // Create file with empty discussion section
      await File(filePath).writeAsString('''---
date: 2026-02-03
type: daily
---

## Entries

## Discussion

''');

      final result = await fs.readDiscussion(date);
      expect(result, isNull);
    });

    test('parses existing discussion correctly', () async {
      final fs = await FileService.getInstance();
      final date = DateTime(2026, 2, 3);
      final filePath = '$defaultVault/Daily/2026-02-03.md';

      // Ensure directories exist
      await Directory('$defaultVault/Daily').create(recursive: true);

      await File(filePath).writeAsString('''---
date: 2026-02-03
type: daily
---

## Entries

## Reflection

Felt good today.

## Discussion

**User:** How was my day?

**Claude:** You had a productive morning.
''');

      final result = await fs.readDiscussion(date);
      expect(result, isNotNull);
      expect(result, contains('**User:** How was my day?'));
      expect(result, contains('**Claude:** You had a productive morning.'));
    });
  });

  group('saveDiscussion', () {
    test('creates discussion section if not exists', () async {
      final fs = await FileService.getInstance();
      final date = DateTime(2026, 2, 3);

      // Create entry first
      final entry = LogEntry(
        label: 'Test',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        timestamp: date.add(const Duration(hours: 10)),
      );
      await fs.appendEntry(entry);

      // Save discussion
      await fs.saveDiscussion(date, '**User:** Hello\n\n**Claude:** Hi there!');

      // Verify
      final content = await fs.readDailyRaw(date);
      expect(content, contains('## Discussion'));
      expect(content, contains('**User:** Hello'));
      expect(content, contains('**Claude:** Hi there!'));
    });

    test('updates existing discussion section', () async {
      final fs = await FileService.getInstance();
      final date = DateTime(2026, 2, 3);
      final filePath = '$defaultVault/Daily/2026-02-03.md';

      await Directory('$defaultVault/Daily').create(recursive: true);

      // Create file with existing discussion
      await File(filePath).writeAsString('''---
date: 2026-02-03
type: daily
---

## Entries

## Discussion

**User:** Old message

**Claude:** Old reply
''');

      // Update discussion
      await fs.saveDiscussion(date, '**User:** New message\n\n**Claude:** New reply');

      final content = await fs.readDailyRaw(date);
      expect(content, contains('**User:** New message'));
      expect(content, contains('**Claude:** New reply'));
      expect(content, isNot(contains('Old message')));
    });

    test('discussion section placed after reflection', () async {
      final fs = await FileService.getInstance();
      final date = DateTime(2026, 2, 3);

      // Create entry first
      final entry = LogEntry(
        label: 'Test',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        timestamp: date.add(const Duration(hours: 10)),
      );
      await fs.appendEntry(entry);

      // Add reflection
      await fs.saveDailyReflection(date, 'My reflection text');

      // Add discussion
      await fs.saveDiscussion(date, '**User:** Hello');

      final content = await fs.readDailyRaw(date);

      // Reflection should come before Discussion
      final reflectionIndex = content.indexOf('## Reflection');
      final discussionIndex = content.indexOf('## Discussion');

      expect(reflectionIndex, isNonNegative);
      expect(discussionIndex, isNonNegative);
      expect(discussionIndex, greaterThan(reflectionIndex));
    });

    test('creates daily file if not exists', () async {
      final fs = await FileService.getInstance();
      final date = DateTime(2026, 2, 3);
      final filePath = '$defaultVault/Daily/2026-02-03.md';

      // File should not exist
      expect(File(filePath).existsSync(), isFalse);

      // Save discussion
      await fs.saveDiscussion(date, '**User:** First message');

      // File should now exist
      expect(File(filePath).existsSync(), isTrue);

      final content = await fs.readDailyRaw(date);
      expect(content, contains('## Discussion'));
      expect(content, contains('**User:** First message'));
    });
  });
}
