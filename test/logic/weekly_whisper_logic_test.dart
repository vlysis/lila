import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lila/models/log_entry.dart';

// Extract weekly whisper logic for testability (mirrors WeeklyWhisperWidget._generateWhisper)
String? generateWeeklyWhisper(
  List<LogEntry> weekEntries,
  Map<int, List<LogEntry>> entriesByDay,
) {
  final total = weekEntries.length;

  if (total < 2) return null;

  if (total < 5) return 'A quieter week.';

  // Count modes
  final modeCounts = <Mode, int>{};
  final orientationCounts = <LogOrientation, int>{};
  for (final e in weekEntries) {
    modeCounts[e.mode] = (modeCounts[e.mode] ?? 0) + 1;
    orientationCounts[e.orientation] =
        (orientationCounts[e.orientation] ?? 0) + 1;
  }

  // Single-mode dominance (>60%)
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
          case Mode.decay:
            return 'Decay wove through the week.';
        }
      }
    }
  }

  // Orientation skew (>60%)
  if (total >= 5) {
    for (final o in LogOrientation.values) {
      if ((orientationCounts[o] ?? 0) > total * 0.6) {
        switch (o) {
          case LogOrientation.self_:
            return 'Mostly turned inward this week.';
          case LogOrientation.mutual:
            return 'A lot of togetherness this week.';
          case LogOrientation.other:
            return 'Much of the week given outward.';
        }
      }
    }
  }

  // All modes present, none >40%
  if (modeCounts.length == Mode.values.length &&
      modeCounts.values.every((c) => c <= total * 0.4)) {
    return 'All modes showed up this week.';
  }

  // Dense day contrast
  final dayCounts = entriesByDay.entries
      .map((e) => MapEntry(e.key, e.value.length))
      .toList();
  final activeDays = dayCounts.where((e) => e.value > 0).toList();
  if (activeDays.length >= 3) {
    final avg =
        activeDays.map((e) => e.value).reduce((a, b) => a + b) /
            activeDays.length;
    for (final day in dayCounts) {
      if (day.value > avg * 2.5 && day.value >= 4) {
        final dayName = DateFormat('EEEE')
            .format(DateTime(2024, 1, 1).add(Duration(days: day.key)));
        return '$dayName stood out from the rest.';
      }
    }
  }

  // 5+ active days
  if (activeDays.length >= 5) {
    return 'Moments noticed most days.';
  }

  return 'A week, observed.';
}

LogEntry _e(Mode mode, LogOrientation orientation, {int day = 0, int hour = 12}) {
  return LogEntry(
    mode: mode,
    orientation: orientation,
    timestamp: DateTime(2026, 1, 27 + day, hour, 0),
  );
}

void main() {
  group('Weekly whisper', () {
    test('returns null for 0 entries', () {
      expect(generateWeeklyWhisper([], {}), isNull);
    });

    test('returns null for 1 entry', () {
      final entries = [_e(Mode.growth, LogOrientation.self_)];
      expect(generateWeeklyWhisper(entries, {0: entries}), isNull);
    });

    test('returns quieter week for 2-4 entries', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.other),
      ];
      expect(generateWeeklyWhisper(entries, {0: entries}), 'A quieter week.');
    });

    test('returns quieter week for 4 entries', () {
      final entries = List.generate(
        4,
        (_) => _e(Mode.growth, LogOrientation.self_),
      );
      expect(generateWeeklyWhisper(entries, {0: entries}), 'A quieter week.');
    });

    test('detects nourishment dominance', () {
      final entries = [
        ...List.generate(6, (_) => _e(Mode.nourishment, LogOrientation.self_)),
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.drift, LogOrientation.self_),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'A week steeped in nourishment.',
      );
    });

    test('detects growth dominance', () {
      final entries = [
        ...List.generate(6, (_) => _e(Mode.growth, LogOrientation.self_)),
        _e(Mode.nourishment, LogOrientation.self_),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'Growth threaded through the week.',
      );
    });

    test('detects maintenance dominance', () {
      final entries = [
        ...List.generate(6, (_) => _e(Mode.maintenance, LogOrientation.self_)),
        _e(Mode.growth, LogOrientation.self_),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'A week of tending to things.',
      );
    });

    test('detects drift dominance', () {
      final entries = [
        ...List.generate(6, (_) => _e(Mode.drift, LogOrientation.self_)),
        _e(Mode.growth, LogOrientation.self_),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'The week drifted gently.',
      );
    });

    test('detects decay dominance', () {
      final entries = [
        ...List.generate(6, (_) => _e(Mode.decay, LogOrientation.self_)),
        _e(Mode.growth, LogOrientation.self_),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'Decay wove through the week.',
      );
    });

    test('does not trigger dominance with fewer than 7 entries', () {
      final entries = [
        ...List.generate(4, (_) => _e(Mode.growth, LogOrientation.self_)),
        _e(Mode.nourishment, LogOrientation.self_),
      ];
      // 5 entries, 4/5 growth = 80% but total < 7 so dominance skipped
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        isNot(contains('threaded')),
      );
    });

    test('detects self orientation skew', () {
      final entries = [
        ...List.generate(4, (_) => _e(Mode.growth, LogOrientation.self_)),
        _e(Mode.nourishment, LogOrientation.other),
        _e(Mode.maintenance, LogOrientation.self_),
      ];
      // 5/6 self > 60%, total >= 5
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'Mostly turned inward this week.',
      );
    });

    test('detects mutual orientation skew', () {
      final entries = [
        ...List.generate(4, (_) => _e(Mode.growth, LogOrientation.mutual)),
        _e(Mode.nourishment, LogOrientation.mutual),
        _e(Mode.maintenance, LogOrientation.self_),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'A lot of togetherness this week.',
      );
    });

    test('detects other orientation skew', () {
      final entries = [
        ...List.generate(4, (_) => _e(Mode.growth, LogOrientation.other)),
        _e(Mode.nourishment, LogOrientation.other),
        _e(Mode.maintenance, LogOrientation.self_),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'Much of the week given outward.',
      );
    });

    test('detects all modes balanced', () {
      // Need >= 5 entries, all modes present, none > 40%
      final entries = [
        _e(Mode.nourishment, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.other),
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.mutual),
        _e(Mode.maintenance, LogOrientation.self_),
        _e(Mode.maintenance, LogOrientation.other),
        _e(Mode.drift, LogOrientation.self_),
        _e(Mode.drift, LogOrientation.mutual),
        _e(Mode.decay, LogOrientation.self_),
        _e(Mode.decay, LogOrientation.other),
      ];
      expect(
        generateWeeklyWhisper(entries, {0: entries}),
        'All modes showed up this week.',
      );
    });

    test('detects 5+ active days', () {
      // 5 entries across 5 different days, only 3 modes so all-four-modes doesn't trigger
      final entries = [
        _e(Mode.growth, LogOrientation.self_, day: 0),
        _e(Mode.nourishment, LogOrientation.other, day: 1),
        _e(Mode.maintenance, LogOrientation.mutual, day: 2),
        _e(Mode.growth, LogOrientation.self_, day: 3),
        _e(Mode.nourishment, LogOrientation.other, day: 4),
      ];
      final byDay = <int, List<LogEntry>>{
        0: [entries[0]],
        1: [entries[1]],
        2: [entries[2]],
        3: [entries[3]],
        4: [entries[4]],
      };
      expect(
        generateWeeklyWhisper(entries, byDay),
        'Moments noticed most days.',
      );
    });

    test('returns fallback for generic pattern', () {
      // Enough entries to pass quieter, but no dominance, not all modes,
      // fewer than 5 active days
      final entries = [
        _e(Mode.growth, LogOrientation.self_, day: 0),
        _e(Mode.nourishment, LogOrientation.other, day: 0),
        _e(Mode.maintenance, LogOrientation.mutual, day: 1),
        _e(Mode.drift, LogOrientation.self_, day: 1),
        _e(Mode.growth, LogOrientation.other, day: 2),
      ];
      final byDay = <int, List<LogEntry>>{
        0: [entries[0], entries[1]],
        1: [entries[2], entries[3]],
        2: [entries[4]],
      };
      // 4 of 5 modes present (no decay), so all-modes doesn't trigger
      // 3 active days < 5, so "moments noticed most days" doesn't trigger
      expect(
        generateWeeklyWhisper(entries, byDay),
        'A week, observed.',
      );
    });

    test('fallback when 3 modes only and no other pattern', () {
      // 3 modes, no dominance, 3 active days (< 5)
      final entries = [
        _e(Mode.growth, LogOrientation.self_, day: 0),
        _e(Mode.growth, LogOrientation.other, day: 0),
        _e(Mode.nourishment, LogOrientation.mutual, day: 1),
        _e(Mode.nourishment, LogOrientation.self_, day: 1),
        _e(Mode.maintenance, LogOrientation.other, day: 2),
      ];
      final byDay = <int, List<LogEntry>>{
        0: [entries[0], entries[1]],
        1: [entries[2], entries[3]],
        2: [entries[4]],
      };
      expect(
        generateWeeklyWhisper(entries, byDay),
        'A week, observed.',
      );
    });
  });
}
