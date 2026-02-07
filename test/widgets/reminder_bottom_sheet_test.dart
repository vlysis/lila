import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lila/models/reminder.dart';
import 'package:lila/services/reminder_alarm_scheduler.dart';
import 'package:lila/services/reminder_service.dart';
import 'package:lila/widgets/reminder_bottom_sheet.dart';

class _NoopScheduler implements ReminderAlarmScheduler {
  @override
  Future<void> initialize({
    required Future<void> Function(String reminderId) onReminderTapped,
  }) async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> scheduleReminder(Reminder reminder) async => true;

  @override
  Future<void> cancelReminder(String reminderId) async {}
}

class _FakeReminderService extends ReminderService {
  String? capturedText;
  DateTime? capturedRemindAt;
  int? capturedOffset;
  int callCount = 0;

  _FakeReminderService() : super(alarmScheduler: _NoopScheduler());

  @override
  Future<ReminderCreateResult> createReminder({
    required String text,
    required DateTime remindAt,
    required int alertOffsetMinutes,
  }) async {
    callCount += 1;
    capturedText = text;
    capturedRemindAt = remindAt;
    capturedOffset = alertOffsetMinutes;
    final reminder = Reminder(
      id: 'test-id',
      text: text,
      remindAt: remindAt,
      alertOffsetMinutes: alertOffsetMinutes,
      createdAt: DateTime.now(),
      done: false,
      doneAt: null,
    );
    return ReminderCreateResult(
      reminder: reminder,
      notificationPermissionGranted: true,
      exactAlarmAllowed: true,
      alarmScheduled: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSheet(
    WidgetTester tester, {
    required ReminderService service,
    required VoidCallback onSaved,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReminderBottomSheet(onSaved: onSaved, reminderService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation when reminder text is empty', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeReminderService();
    await pumpSheet(tester, service: service, onSaved: () {});

    await tester.ensureVisible(
      find.byKey(const ValueKey('save_reminder_button')),
    );
    await tester.tap(find.byKey(const ValueKey('save_reminder_button')));
    await tester.pumpAndSettle();

    expect(find.text('Add a reminder note first.'), findsOneWidget);
    expect(service.callCount, 0);
  });

  testWidgets('saves reminder with selected values', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeReminderService();
    var onSavedCalls = 0;
    await pumpSheet(tester, service: service, onSaved: () => onSavedCalls += 1);

    await tester.enterText(
      find.byKey(const ValueKey('reminder_text_input')),
      'Remember to get eggs',
    );

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowKey = ValueKey(
      'reminder_day_${DateFormat('yyyy-MM-dd').format(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))}',
    );
    await tester.tap(find.byKey(tomorrowKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reminder_offset_30')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('save_reminder_button')),
    );
    await tester.tap(find.byKey(const ValueKey('save_reminder_button')));
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
    expect(service.capturedText, 'Remember to get eggs');
    expect(service.capturedOffset, 30);
    expect(service.capturedRemindAt, isNotNull);
    expect(onSavedCalls, 1);
  });
}
