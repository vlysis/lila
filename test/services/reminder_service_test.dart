import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lila/models/reminder.dart';
import 'package:lila/services/file_service.dart';
import 'package:lila/services/reminder_alarm_scheduler.dart';
import 'package:lila/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAlarmScheduler implements ReminderAlarmScheduler {
  final List<Reminder> scheduled = [];
  final List<String> canceledIds = [];
  Future<void> Function(String reminderId)? _onTap;
  bool permissionGranted = true;
  bool exactAlarmAllowed = true;
  bool scheduleSuccess = true;

  @override
  Future<void> initialize({
    required Future<void> Function(String reminderId) onReminderTapped,
  }) async {
    _onTap = onReminderTapped;
  }

  @override
  Future<bool> requestNotificationPermission() async => permissionGranted;

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmAllowed;

  @override
  Future<bool> scheduleReminder(Reminder reminder) async {
    scheduled.add(reminder);
    return scheduleSuccess;
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    canceledIds.add(reminderId);
  }

  Future<void> simulateTap(String reminderId) async {
    final callback = _onTap;
    if (callback == null) return;
    await callback(reminderId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String fakeDocs;
  late _FakeAlarmScheduler scheduler;
  late ReminderService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'lila_reminder_service_test_',
    );
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
    scheduler = _FakeAlarmScheduler();
    service = ReminderService(alarmScheduler: scheduler);
  });

  tearDown(() {
    FileService.resetInstance();
    ReminderService.resetInstance();
    tempDir.deleteSync(recursive: true);
  });

  test('createReminder writes markdown and schedules alarm', () async {
    final now = DateTime.now();
    final remindAt = now.add(const Duration(hours: 3));
    final result = await service.createReminder(
      text: 'Get eggs',
      remindAt: remindAt,
      alertOffsetMinutes: 30,
    );

    expect(result.notificationPermissionGranted, isTrue);
    expect(result.exactAlarmAllowed, isTrue);
    expect(result.alarmScheduled, isTrue);
    expect(scheduler.scheduled, hasLength(1));

    final reminders = await service.readRemindersForDate(remindAt);
    expect(reminders, hasLength(1));
    expect(reminders.first.text, 'Get eggs');
    expect(reminders.first.alertOffsetMinutes, 30);
    expect(reminders.first.done, isFalse);
  });

  test('markReminderDoneById updates markdown and cancels alarm', () async {
    final remindAt = DateTime.now().add(const Duration(hours: 2));
    final created = await service.createReminder(
      text: 'Call mom',
      remindAt: remindAt,
      alertOffsetMinutes: 0,
    );

    final changed = await service.markReminderDoneById(created.reminder.id);
    expect(changed, isTrue);
    expect(scheduler.canceledIds, contains(created.reminder.id));

    final reminders = await service.readRemindersForDate(remindAt);
    expect(reminders, hasLength(1));
    expect(reminders.first.done, isTrue);
    expect(reminders.first.doneAt, isNotNull);
  });

  test('getAvailableDates includes sorted reminder file dates', () async {
    final now = DateTime.now();
    await service.createReminder(
      text: 'One',
      remindAt: now.add(const Duration(days: 3)),
      alertOffsetMinutes: 10,
    );
    await service.createReminder(
      text: 'Two',
      remindAt: now.add(const Duration(days: 1)),
      alertOffsetMinutes: 10,
    );

    final dates = await service.getAvailableDates();
    expect(dates.length, 2);
    expect(dates.first.isBefore(dates.last), isTrue);
  });

  test('notification tap marks reminder done and emits stream event', () async {
    final remindAt = DateTime.now().add(const Duration(hours: 4));
    final created = await service.createReminder(
      text: 'Buy tea',
      remindAt: remindAt,
      alertOffsetMinutes: 0,
    );

    await service.initialize();

    String? tappedId;
    final sub = service.notificationDoneStream.listen((id) => tappedId = id);
    await scheduler.simulateTap(created.reminder.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();

    expect(tappedId, created.reminder.id);
    final reminders = await service.readRemindersForDate(remindAt);
    expect(reminders.first.done, isTrue);
  });
}
