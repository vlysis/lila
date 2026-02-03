import '../models/log_entry.dart';
import 'file_service.dart';

class SyntheticDataService {
  static Future<void> generateWeek(FileService fs) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    // Clear existing data first
    await fs.resetVault();

    // Monday: maintenance-heavy, morning, self-oriented
    await _writeDay(fs, monday, [
      _e(8, 15, 'Emails', Mode.maintenance, LogOrientation.self_),
      _e(9, 0, 'Laundry', Mode.maintenance, LogOrientation.self_),
      _e(10, 20, 'Groceries', Mode.maintenance, LogOrientation.self_),
      _e(11, 45, 'Reading', Mode.nourishment, LogOrientation.self_),
      _e(14, 30, 'Team check-in', Mode.maintenance, LogOrientation.other),
    ]);

    // Tuesday: growth + nourishment mix, spread across day
    await _writeDay(fs, monday.add(const Duration(days: 1)), [
      _e(7, 30, 'Yoga', Mode.nourishment, LogOrientation.self_),
      _e(11, 0, 'Workshop', Mode.growth, LogOrientation.mutual),
      _e(15, 0, 'Call with Alex', Mode.growth, LogOrientation.mutual),
      _e(20, 0, 'Cooking', Mode.nourishment, LogOrientation.self_),
    ]);

    // Wednesday: sparse, drift + maintenance, afternoon
    await _writeDay(fs, monday.add(const Duration(days: 2)), [
      _e(14, 0, 'Scrolling', Mode.drift, LogOrientation.self_),
      _e(16, 30, 'Tidying desk', Mode.maintenance, LogOrientation.self_),
    ]);

    // Thursday: growth-heavy, self + mutual
    await _writeDay(fs, monday.add(const Duration(days: 3)), [
      _e(9, 0, 'Journaling', Mode.growth, LogOrientation.self_),
      _e(10, 30, 'Pair coding', Mode.growth, LogOrientation.mutual),
      _e(13, 0, 'Lunch walk', Mode.nourishment, LogOrientation.self_),
      _e(14, 30, 'Deep work', Mode.growth, LogOrientation.self_),
      _e(16, 0, 'Mentoring', Mode.growth, LogOrientation.other),
    ]);

    // Friday: nourishment-rich, evening-heavy
    await _writeDay(fs, monday.add(const Duration(days: 4)), [
      _e(12, 0, 'Long lunch', Mode.nourishment, LogOrientation.mutual),
      _e(17, 30, 'Walk in the park', Mode.nourishment, LogOrientation.self_),
      _e(19, 0, 'Cooking', Mode.nourishment, LogOrientation.mutual),
      _e(21, 0, 'Music', Mode.nourishment, LogOrientation.self_),
    ]);

    // Saturday: balanced, drift + nourishment
    await _writeDay(fs, monday.add(const Duration(days: 5)), [
      _e(10, 0, 'Scrolling', Mode.drift, LogOrientation.self_),
      _e(14, 0, 'Gardening', Mode.nourishment, LogOrientation.self_),
      _e(18, 0, 'Dinner out', Mode.maintenance, LogOrientation.other),
    ]);

    // Sunday: light, nourishment + growth
    await _writeDay(fs, monday.add(const Duration(days: 6)), [
      _e(9, 30, 'Long breakfast', Mode.nourishment, LogOrientation.mutual),
      _e(15, 0, 'Reading', Mode.growth, LogOrientation.self_),
    ]);
  }

  static LogEntry _e(
    int hour,
    int minute,
    String label,
    Mode mode,
    LogOrientation orientation,
  ) {
    return LogEntry(
      label: label,
      mode: mode,
      orientation: orientation,
      // timestamp is set per-day in _writeDay
      timestamp: DateTime(2000, 1, 1, hour, minute),
    );
  }

  static Future<void> _writeDay(
    FileService fs,
    DateTime date,
    List<LogEntry> templates,
  ) async {
    for (final t in templates) {
      final entry = LogEntry(
        label: t.label,
        mode: t.mode,
        orientation: t.orientation,
        timestamp: DateTime(
          date.year,
          date.month,
          date.day,
          t.timestamp.hour,
          t.timestamp.minute,
        ),
      );
      await fs.appendEntry(entry);
    }
  }
}
