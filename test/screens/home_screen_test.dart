import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lila/models/focus_state.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/screens/home_screen.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/services/focus_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_home_test_');
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

  testWidgets('daily reflection summary shows reflection text and tag',
      (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final fs = await FileService.getInstance();

      await fs.appendEntry(
        LogEntry(
          label: 'Daily reflection',
          mode: Mode.nourishment,
          orientation: LogOrientation.self_,
          timestamp: now,
        ),
      );
      await fs.saveDailyReflection(now, 'Wandered and wondered.');
    });

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      final entries = await fs.readDailyEntries(now);
      expect(entries.length, 1);
      expect(entries.first.label, 'Daily reflection');
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(focusController: controller),
      ),
    );
    await tester.runAsync(() async {
      await (tester.state(find.byType(HomeScreen)) as dynamic)
          .loadEntriesForTest();
    });
    await tester.pump();

    expect(find.text('Daily reflection'), findsOneWidget);
    expect(find.textContaining('Wandered and wondered'), findsOneWidget);
    expect(find.text('Nourishment'), findsNothing);
    expect(find.text('Self'), findsNothing);
  });

  testWidgets('mode ribbon appears when entries exist', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      await fs.appendEntry(
        LogEntry(
          label: 'First',
          mode: Mode.growth,
          orientation: LogOrientation.self_,
          timestamp: now.subtract(const Duration(minutes: 30)),
        ),
      );
      await fs.appendEntry(
        LogEntry(
          label: 'Second',
          mode: Mode.nourishment,
          orientation: LogOrientation.mutual,
          timestamp: now,
        ),
      );
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(focusController: controller),
      ),
    );
    await tester.runAsync(() async {
      await (tester.state(find.byType(HomeScreen)) as dynamic)
          .loadEntriesForTest();
    });
    await tester.pump();

    expect(find.byKey(const ValueKey('mode_ribbon')), findsOneWidget);
  });

  testWidgets('log moment button opens log sheet and replaces FAB',
      (tester) async {
    final controller = FocusController();
    controller.update(FocusState.defaultState());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(focusController: controller),
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('log_moment_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('log_moment_button')));
    await tester.pumpAndSettle();

    expect(find.text('Nourishment'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
  });

  testWidgets('shows all entries without tap to see all hint', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      for (var i = 0; i < 6; i += 1) {
        await fs.appendEntry(
          LogEntry(
            label: 'Entry ${i + 1}',
            mode: Mode.nourishment,
            orientation: LogOrientation.self_,
            timestamp: now.subtract(Duration(minutes: i * 5)),
          ),
        );
      }
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(focusController: controller),
      ),
    );
    await tester.runAsync(() async {
      await (tester.state(find.byType(HomeScreen)) as dynamic)
          .loadEntriesForTest();
    });
    await tester.pump();

    for (var i = 0; i < 6; i += 1) {
      expect(find.text('Entry ${i + 1}'), findsOneWidget);
    }
    expect(find.text('Tap to see all'), findsNothing);
  });
}
