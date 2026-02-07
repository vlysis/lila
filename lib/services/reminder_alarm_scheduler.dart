import 'dart:io';
import 'package:flutter/services.dart';
import '../models/reminder.dart';

abstract class ReminderAlarmScheduler {
  Future<void> initialize({
    required Future<void> Function(String reminderId) onReminderTapped,
  });

  Future<bool> requestNotificationPermission();

  Future<bool> canScheduleExactAlarms();

  Future<bool> scheduleReminder(Reminder reminder);

  Future<void> cancelReminder(String reminderId);
}

class MethodChannelReminderAlarmScheduler implements ReminderAlarmScheduler {
  static const MethodChannel _channel = MethodChannel('lila/reminder_alarm');
  bool _initialized = false;

  @override
  Future<void> initialize({
    required Future<void> Function(String reminderId) onReminderTapped,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    if (!_initialized) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'onReminderTapped') {
          return;
        }
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final id = args['id'] as String?;
        if (id == null || id.isEmpty) return;
        await onReminderTapped(id);
      });
      _initialized = true;
    }

    try {
      final initialId = await _channel.invokeMethod<String>(
        'getInitialReminderTap',
      );
      if (initialId != null && initialId.isNotEmpty) {
        await onReminderTapped(initialId);
      }
    } on MissingPluginException {
      // Not wired in this platform target.
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final allowed = await _channel.invokeMethod<bool>(
        'canScheduleExactAlarms',
      );
      return allowed ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<bool> scheduleReminder(Reminder reminder) async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final scheduled = await _channel.invokeMethod<bool>('scheduleReminder', {
        'id': reminder.id,
        'title': reminder.text,
        'body': _description(reminder),
        'triggerAtMillis': reminder.alertAt.millisecondsSinceEpoch,
      });
      return scheduled ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cancelReminder', {'id': reminderId});
    } on MissingPluginException {
      // Not wired in this platform target.
    }
  }

  String _description(Reminder reminder) {
    final minutes = reminder.alertOffsetMinutes;
    if (minutes <= 0) {
      return 'Reminder now';
    }
    if (minutes == 60) {
      return 'Reminder 1 hour before';
    }
    return 'Reminder $minutes min before';
  }
}
