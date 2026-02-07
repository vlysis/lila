import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/widgets/log_bottom_sheet.dart';
import 'package:lila/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_sheet_edit_test_');
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

    FileService.resetInstance();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FileService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  LogEntry _makeEntry({
    String? label,
    Mode mode = Mode.growth,
    LogOrientation orientation = LogOrientation.self_,
    DurationPreset? duration,
  }) {
    return LogEntry(
      label: label ?? 'Reading',
      mode: mode,
      orientation: orientation,
      duration: duration,
      timestamp: DateTime(2026, 2, 3, 10, 30),
    );
  }

  Future<void> pumpEditSheet(
    WidgetTester tester, {
    required LogEntry editEntry,
  }) async {
    await tester.runAsync(() async {
      await FileService.getInstance();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: LogBottomSheet(
            onLogged: () {},
            editEntry: editEntry,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('edit mode pre-population', () {
    testWidgets('shows label input with pre-filled data', (tester) async {
      await pumpEditSheet(tester, editEntry: _makeEntry(label: 'Reading'));

      // Should jump straight to label step (all badges visible)
      expect(find.byKey(const ValueKey('mode_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('orientation_badge')), findsOneWidget);
      // Label input should be visible
      expect(find.text('What was it?'), findsOneWidget);
      // Save button says "Save"
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows duration badge when entry has duration', (tester) async {
      await pumpEditSheet(
        tester,
        editEntry: _makeEntry(duration: DurationPreset.deep),
      );

      expect(find.byKey(const ValueKey('duration_badge')), findsOneWidget);
      expect(find.text('Deep'), findsOneWidget);
    });

    testWidgets('no duration badge when entry has no duration', (tester) async {
      await pumpEditSheet(tester, editEntry: _makeEntry());

      expect(find.byKey(const ValueKey('duration_badge')), findsNothing);
    });
  });

  group('badge tappability in edit mode', () {
    testWidgets('tapping mode badge returns to mode selection', (tester) async {
      await pumpEditSheet(tester, editEntry: _makeEntry());

      await tester.tap(find.byKey(const ValueKey('mode_badge')));
      await tester.pumpAndSettle();

      // Should show mode grid
      expect(find.text('What kind of moment?'), findsOneWidget);
      expect(find.text('Nourishment'), findsOneWidget);
    });

    testWidgets('tapping orientation badge returns to orientation selection',
        (tester) async {
      await pumpEditSheet(tester, editEntry: _makeEntry());

      await tester.tap(find.byKey(const ValueKey('orientation_badge')));
      await tester.pumpAndSettle();

      // Should show orientation selector with mode badge still visible
      expect(find.text('Directed toward?'), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_badge')), findsOneWidget);
    });

    testWidgets('tapping duration badge returns to duration selection',
        (tester) async {
      await pumpEditSheet(
        tester,
        editEntry: _makeEntry(duration: DurationPreset.deep),
      );

      await tester.tap(find.byKey(const ValueKey('duration_badge')));
      await tester.pumpAndSettle();

      // Should show duration selector
      expect(find.text('How long?'), findsOneWidget);
    });
  });

  group('save behavior', () {
    testWidgets('save pops with new LogEntry preserving timestamp',
        (tester) async {
      LogEntry? poppedEntry;
      final editEntry = _makeEntry(label: 'Reading');

      await tester.runAsync(() async {
        await FileService.getInstance();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await showModalBottomSheet<LogEntry>(
                      context: context,
                      builder: (_) => LogBottomSheet(
                        onLogged: () {},
                        editEntry: editEntry,
                      ),
                    );
                    poppedEntry = result;
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.runAsync(() async {
        final button = tester.widget<TextButton>(
          find.byKey(const ValueKey('log_save_button')),
        );
        button.onPressed!();
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(poppedEntry, isNotNull);
      expect(poppedEntry!.timestamp, equals(editEntry.timestamp));
      expect(poppedEntry!.mode, equals(Mode.growth));
      expect(poppedEntry!.orientation, equals(LogOrientation.self_));
    });
  });
}
