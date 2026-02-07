import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import 'file_service.dart';
import 'reminder_alarm_scheduler.dart';

class ReminderCreateResult {
  final Reminder reminder;
  final bool notificationPermissionGranted;
  final bool exactAlarmAllowed;
  final bool alarmScheduled;

  const ReminderCreateResult({
    required this.reminder,
    required this.notificationPermissionGranted,
    required this.exactAlarmAllowed,
    required this.alarmScheduled,
  });
}

class ReminderService {
  static ReminderService? _instance;

  final ReminderAlarmScheduler _alarmScheduler;
  final StreamController<String> _notificationDoneController =
      StreamController<String>.broadcast();
  bool _initialized = false;

  ReminderService({ReminderAlarmScheduler? alarmScheduler})
    : _alarmScheduler = alarmScheduler ?? MethodChannelReminderAlarmScheduler();

  static ReminderService get instance => _instance ??= ReminderService();

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  Stream<String> get notificationDoneStream =>
      _notificationDoneController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _alarmScheduler.initialize(
      onReminderTapped: (reminderId) async {
        final changed = await markReminderDoneById(reminderId);
        if (changed) {
          _notificationDoneController.add(reminderId);
        }
      },
    );
  }

  Future<ReminderCreateResult> createReminder({
    required String text,
    required DateTime remindAt,
    required int alertOffsetMinutes,
  }) async {
    final reminder = Reminder(
      id: _createId(text, remindAt),
      text: text.trim(),
      remindAt: remindAt,
      alertOffsetMinutes: alertOffsetMinutes,
      createdAt: DateTime.now(),
      done: false,
      doneAt: null,
    );

    await _upsertReminder(reminder);

    final permissionGranted = await _alarmScheduler
        .requestNotificationPermission();
    final exactAlarmAllowed = await _alarmScheduler.canScheduleExactAlarms();
    final alarmScheduled = await _alarmScheduler.scheduleReminder(reminder);

    return ReminderCreateResult(
      reminder: reminder,
      notificationPermissionGranted: permissionGranted,
      exactAlarmAllowed: exactAlarmAllowed,
      alarmScheduled: alarmScheduled,
    );
  }

  Future<List<Reminder>> readRemindersForDate(DateTime date) async {
    final fs = await FileService.getInstance();
    final file = File(_dailyReminderFilePath(fs.rootDir, date));
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final reminders = _parseReminders(content);
    reminders.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return reminders;
  }

  Future<List<DateTime>> getAvailableDates() async {
    final fs = await FileService.getInstance();
    final dir = Directory('${fs.rootDir}/Reminders');
    if (!await dir.exists()) return [];

    final dates = <DateTime>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final name = entity.uri.pathSegments.last.replaceAll('.md', '');
      try {
        dates.add(DateFormat('yyyy-MM-dd').parseStrict(name));
      } catch (_) {}
    }
    dates.sort();
    return dates;
  }

  Future<bool> markReminderDone(Reminder reminder, {DateTime? doneAt}) async {
    return markReminderDoneById(reminder.id, doneAt: doneAt);
  }

  Future<bool> markReminderDoneById(
    String reminderId, {
    DateTime? doneAt,
  }) async {
    final fs = await FileService.getInstance();
    final dir = Directory('${fs.rootDir}/Reminders');
    if (!await dir.exists()) return false;

    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.md'))
        .cast<File>()
        .toList();

    for (final file in files) {
      final content = await file.readAsString();
      final reminders = _parseReminders(content);
      final idx = reminders.indexWhere((r) => r.id == reminderId);
      if (idx == -1) continue;
      if (reminders[idx].done) return false;

      reminders[idx] = reminders[idx].copyWith(
        done: true,
        doneAt: doneAt ?? DateTime.now(),
      );
      await _writeReminderFile(
        file: file,
        date: reminders[idx].remindAt,
        reminders: reminders,
      );
      await _alarmScheduler.cancelReminder(reminderId);
      return true;
    }
    return false;
  }

  Future<void> _upsertReminder(Reminder reminder) async {
    final fs = await FileService.getInstance();
    final filePath = _dailyReminderFilePath(fs.rootDir, reminder.remindAt);
    final file = File(filePath);
    await _ensureReminderFile(file, reminder.remindAt);

    final existing = await readRemindersForDate(reminder.remindAt);
    final idx = existing.indexWhere((r) => r.id == reminder.id);
    if (idx == -1) {
      existing.add(reminder);
    } else {
      existing[idx] = reminder;
    }
    existing.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    await _writeReminderFile(
      file: file,
      date: reminder.remindAt,
      reminders: existing,
    );
  }

  Future<void> _ensureReminderFile(File file, DateTime date) async {
    if (await file.exists()) return;
    await file.parent.create(recursive: true);
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    await file.writeAsString(
      '---\ndate: $formatted\ntype: reminders\n---\n\n## Reminders\n',
    );
  }

  Future<void> _writeReminderFile({
    required File file,
    required DateTime date,
    required List<Reminder> reminders,
  }) async {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    final buffer = StringBuffer();
    buffer.write('---\n');
    buffer.write('date: $formatted\n');
    buffer.write('type: reminders\n');
    buffer.write('---\n\n');
    buffer.write('## Reminders\n');
    if (reminders.isNotEmpty) {
      for (final reminder in reminders) {
        buffer.write('\n');
        buffer.write(reminder.toMarkdown());
      }
    }
    await file.writeAsString(buffer.toString());
  }

  List<Reminder> _parseReminders(String content) {
    final headerIndex = content.indexOf('## Reminders');
    if (headerIndex == -1) return [];

    final headerLineEnd = content.indexOf('\n', headerIndex);
    if (headerLineEnd == -1) return [];

    final sectionStart = headerLineEnd + 1;
    final afterSection = content.substring(sectionStart);
    final nextSectionMatch = RegExp(r'\n## ').firstMatch(afterSection);
    final sectionEnd = nextSectionMatch != null
        ? sectionStart + nextSectionMatch.start
        : content.length;

    final section = content.substring(sectionStart, sectionEnd);
    if (section.trim().isEmpty) return [];

    final blocks = section.split(RegExp(r'\n(?=- \*\*)'));
    final reminders = <Reminder>[];
    for (final block in blocks) {
      final reminder = Reminder.fromMarkdown(block);
      if (reminder != null) {
        reminders.add(reminder);
      }
    }
    return reminders;
  }

  String _dailyReminderFilePath(String rootDir, DateTime date) {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    return '$rootDir/Reminders/$formatted.md';
  }

  String _createId(String text, DateTime remindAt) {
    final now = DateTime.now();
    final textHash = text.hashCode.abs();
    final remindHash = remindAt.millisecondsSinceEpoch;
    return 'rem_${now.microsecondsSinceEpoch}_${textHash}_$remindHash';
  }
}
