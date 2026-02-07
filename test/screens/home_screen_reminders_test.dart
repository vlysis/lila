import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lila/models/focus_state.dart';
import 'package:lila/screens/home_screen.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/services/focus_controller.dart';
import 'package:lila/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lila_home_reminders_test_');
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
    ReminderService.resetInstance();
  });

  tearDown(() {
    FileService.resetInstance();
    ReminderService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpHome(WidgetTester tester, FocusController controller) async {
    await tester.runAsync(() async {
      await FileService.getInstance();
      await ReminderService.instance.initialize();
    });

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(focusController: controller)),
    );

    await tester.runAsync(() async {
      await (tester.state(find.byType(HomeScreen)) as dynamic)
          .loadEntriesForTest();
    });
    await tester.pump();
  }

  testWidgets('renders reminder card with distinct reminder tag', (
    tester,
  ) async {
    final remindAt = DateTime.now().add(const Duration(hours: 2));
    late final ReminderCreateResult created;
    await tester.runAsync(() async {
      created = await ReminderService.instance.createReminder(
        text: 'Remember to get eggs',
        remindAt: remindAt,
        alertOffsetMinutes: 0,
      );
    });

    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    expect(
      find.byKey(ValueKey('reminder_card_${created.reminder.id}')),
      findsOneWidget,
    );
    expect(find.text('Remember to get eggs'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
  });

  testWidgets('remind button opens reminder bottom sheet', (tester) async {
    final controller = FocusController();
    controller.update(FocusState.defaultState());
    await pumpHome(tester, controller);

    await tester.tap(find.byKey(const ValueKey('remind_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Set reminder'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder_text_input')), findsOneWidget);
  });
}
