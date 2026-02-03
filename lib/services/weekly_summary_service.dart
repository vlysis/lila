import 'package:intl/intl.dart';
import '../models/log_entry.dart';

class WeeklySummaryService {
  static String generate(
    DateTime weekStart,
    Map<int, List<LogEntry>> entriesByDay,
    List<LogEntry> allEntries, {
    String? reflection,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fromStr = DateFormat('yyyy-MM-dd').format(weekStart);
    final toStr = DateFormat('yyyy-MM-dd').format(weekEnd);

    // ISO week number
    final jan1 = DateTime(weekStart.year, 1, 1);
    final dayOfYear = weekStart.difference(jan1).inDays + 1;
    final weekNumber =
        ((dayOfYear - weekStart.weekday + 10) / 7).floor();
    final weekLabel =
        '${weekStart.year}-W${weekNumber.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();

    // Frontmatter
    buffer.writeln('---');
    buffer.writeln('week: $weekLabel');
    buffer.writeln('type: weekly');
    buffer.writeln('from: $fromStr');
    buffer.writeln('to: $toStr');
    buffer.writeln('---');
    buffer.writeln();

    // Week texture
    buffer.writeln('## Week Texture');
    buffer.writeln();
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    for (int i = 0; i < 7; i++) {
      final entries = entriesByDay[i] ?? [];
      if (entries.isEmpty) {
        buffer.writeln('- ${dayNames[i]}: —');
      } else {
        final modes = entries.map((e) => e.mode.name).join(', ');
        buffer.writeln('- ${dayNames[i]}: $modes');
      }
    }
    buffer.writeln();

    // Orientation
    buffer.writeln('## Orientation');
    buffer.writeln();
    final total = allEntries.length;
    if (total > 0) {
      final counts = <LogOrientation, int>{};
      for (final e in allEntries) {
        counts[e.orientation] = (counts[e.orientation] ?? 0) + 1;
      }
      for (final o in LogOrientation.values) {
        final count = counts[o] ?? 0;
        final ratio = count / total;
        final frequency =
            ratio > 0.4 ? 'noticed often' : (ratio > 0.15 ? 'noticed sometimes' : 'noticed rarely');
        buffer.writeln('- ${o.label}: $frequency');
      }
    }
    buffer.writeln();

    // Whisper
    buffer.writeln('## Whisper');
    buffer.writeln();
    final whisper = _generateWhisperText(allEntries, entriesByDay);
    buffer.writeln('_${whisper}_');

    if (reflection != null && reflection.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Reflection');
      buffer.writeln();
      buffer.writeln(reflection.trim());
    }

    return buffer.toString();
  }

  static String _generateWhisperText(
    List<LogEntry> entries,
    Map<int, List<LogEntry>> byDay,
  ) {
    final total = entries.length;
    if (total < 2) return 'A quiet week.';
    if (total < 5) return 'A quieter week.';

    final modeCounts = <Mode, int>{};
    for (final e in entries) {
      modeCounts[e.mode] = (modeCounts[e.mode] ?? 0) + 1;
    }

    if (total >= 7) {
      for (final mode in Mode.values) {
        if ((modeCounts[mode] ?? 0) > total * 0.6) {
          switch (mode) {
            case Mode.nourishment:
              return 'A week steeped in nourishment.';
            case Mode.growth:
              return 'Growth threaded through the week.';
            case Mode.maintenance:
              return 'A week of tending to things.';
            case Mode.drift:
              return 'The week drifted gently.';
          }
        }
      }
    }

    return 'A week, observed.';
  }
}
