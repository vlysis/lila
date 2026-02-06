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
    tempDir = Directory.systemTemp.createTempSync('lila_nav_test_');
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

  dynamic homeState(WidgetTester tester) =>
      tester.state(find.byType(HomeScreen)) as dynamic;

  Future<void> pumpHome(WidgetTester tester, FocusController controller) async {
    await tester.runAsync(() async {
      await FileService.getInstance();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(focusController: controller),
      ),
    );

    await tester.runAsync(() async {
      await homeState(tester).loadEntriesForTest();
    });
    await tester.pump();
  }

  testWidgets('shows Today title on initial load', (tester) async {
    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('navigating to previous day shows Yesterday', (tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      await fs.appendEntry(
        LogEntry(
          label: 'Yesterday task',
          mode: Mode.growth,
          orientation: LogOrientation.self_,
          timestamp: DateTime(
              yesterday.year, yesterday.month, yesterday.day, 14, 30),
        ),
      );
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    expect(find.text('Today'), findsOneWidget);

    // Navigate to previous day using test helper
    await tester.runAsync(() async {
      await homeState(tester).goToPreviousDayForTest();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Yesterday task'), findsOneWidget);
    expect(find.text('Return to today'), findsOneWidget);
  });

  testWidgets('return to today restores Today view', (tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      await fs.appendEntry(
        LogEntry(
          label: 'Past entry',
          mode: Mode.maintenance,
          orientation: LogOrientation.other,
          timestamp: DateTime(
              yesterday.year, yesterday.month, yesterday.day, 10, 0),
        ),
      );
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    // Go to yesterday
    await tester.runAsync(() async {
      await homeState(tester).goToPreviousDayForTest();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Yesterday'), findsOneWidget);

    // Return to today
    await tester.runAsync(() async {
      await homeState(tester).goToTodayForTest();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Return to today'), findsNothing);
  });

  testWidgets('focus card hidden on past days', (tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      await fs.appendEntry(
        LogEntry(
          label: 'Past entry',
          mode: Mode.drift,
          orientation: LogOrientation.self_,
          timestamp: DateTime(
              yesterday.year, yesterday.month, yesterday.day, 9, 0),
        ),
      );
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    // Focus card visible on today
    expect(find.textContaining('Current Season'), findsOneWidget);

    // Navigate to yesterday
    await tester.runAsync(() async {
      await homeState(tester).goToPreviousDayForTest();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Focus card should not be visible on past day
    expect(find.textContaining('Current Season'), findsNothing);
  });

  testWidgets('past day shows "How did this day feel?" prompt', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      await fs.appendEntry(
        LogEntry(
          label: 'Past entry',
          mode: Mode.growth,
          orientation: LogOrientation.self_,
          timestamp: DateTime(
              yesterday.year, yesterday.month, yesterday.day, 12, 0),
        ),
      );
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    // Navigate to yesterday
    await tester.runAsync(() async {
      await homeState(tester).goToPreviousDayForTest();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('How did this day feel?'), findsOneWidget);
  });

  testWidgets('reflection text reloads on day change', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    await tester.runAsync(() async {
      final fs = await FileService.getInstance();
      await fs.appendEntry(
        LogEntry(
          label: 'Past entry',
          mode: Mode.growth,
          orientation: LogOrientation.self_,
          timestamp: DateTime(
              yesterday.year, yesterday.month, yesterday.day, 10, 0),
        ),
      );
      await fs.saveDailyReflection(yesterday, 'Yesterday reflection text');
      await fs.saveDailyReflection(now, 'Today reflection text');
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    // Verify today's reflection
    final reflectionField =
        find.byKey(const ValueKey('daily_reflection_input'));
    expect(reflectionField, findsOneWidget);
    final textField = tester.widget<TextField>(reflectionField);
    expect(textField.controller?.text, 'Today reflection text');

    // Navigate to yesterday
    await tester.runAsync(() async {
      await homeState(tester).goToPreviousDayForTest();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify yesterday's reflection loaded
    final reflectionField2 =
        find.byKey(const ValueKey('daily_reflection_input'));
    final textField2 = tester.widget<TextField>(reflectionField2);
    expect(textField2.controller?.text, 'Yesterday reflection text');
  });
}
