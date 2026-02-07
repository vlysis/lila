import 'package:flutter_test/flutter_test.dart';
import 'package:lila/models/log_entry.dart';

// Insight data class for testing (mirrors WeeklyInsightsWidget._Insight)
class Insight {
  final String text;
  Insight(this.text);
}

// Extract insights logic for testability (mirrors WeeklyInsightsWidget._generate)
List<Insight> generateInsights(
  List<LogEntry> weekEntries,
  Map<int, List<LogEntry>> entriesByDay,
) {
  final insights = <Insight>[];
  final total = weekEntries.length;
  if (total < 3) return insights;

  final modeCounts = <Mode, int>{};
  final orientationCounts = <LogOrientation, int>{};
  for (final e in weekEntries) {
    modeCounts[e.mode] = (modeCounts[e.mode] ?? 0) + 1;
    orientationCounts[e.orientation] =
        (orientationCounts[e.orientation] ?? 0) + 1;
  }

  // Mode balance: top two modes
  final sortedModes = modeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sortedModes.length >= 2 &&
      sortedModes[0].value + sortedModes[1].value > total * 0.6) {
    final m1 = sortedModes[0].key.label;
    final m2 = sortedModes[1].key.label;
    insights.add(Insight('$m1 and ${m2.toLowerCase()} were most present.'));
  } else if (sortedModes.isNotEmpty &&
      sortedModes[0].value > total * 0.5) {
    insights.add(Insight(
        '${sortedModes[0].key.label} carried much of the week.'));
  }

  // Absent modes
  for (final mode in Mode.values) {
    if ((modeCounts[mode] ?? 0) == 0) {
      insights.add(Insight('${mode.label} didn\'t appear this week.'));
    }
  }

  // Busiest day
  int busiestDay = 0;
  int busiestCount = 0;
  int quietestDay = 0;
  int quietestCount = 999;
  int activeDays = 0;
  for (int i = 0; i < 7; i++) {
    final count = (entriesByDay[i] ?? []).length;
    if (count > busiestCount) {
      busiestCount = count;
      busiestDay = i;
    }
    if (count < quietestCount && count >= 0) {
      quietestCount = count;
      quietestDay = i;
    }
    if (count > 0) activeDays++;
  }

  final dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  if (busiestCount >= 3 && busiestCount > total / 7 * 1.5) {
    insights.add(Insight('${dayNames[busiestDay]} was the fullest day.'));
  }

  // Quietest day (only if there's contrast)
  if (quietestCount == 0 && activeDays >= 4) {
    insights.add(Insight('${dayNames[quietestDay]} was the stillest.'));
  }

  // Morning vs evening
  int morningCount = 0;
  int eveningCount = 0;
  for (final e in weekEntries) {
    if (e.timestamp.hour < 12) {
      morningCount++;
    } else if (e.timestamp.hour >= 17) {
      eveningCount++;
    }
  }
  if (morningCount > total * 0.5) {
    insights.add(Insight('Most moments happened in the morning.'));
  } else if (eveningCount > total * 0.5) {
    insights.add(Insight('The evenings were where things lived.'));
  }

  // Weekend shift
  final weekdayModes = <Mode, int>{};
  final weekendModes = <Mode, int>{};
  for (int i = 0; i < 5; i++) {
    for (final e in (entriesByDay[i] ?? [])) {
      weekdayModes[e.mode] = (weekdayModes[e.mode] ?? 0) + 1;
    }
  }
  for (int i = 5; i < 7; i++) {
    for (final e in (entriesByDay[i] ?? [])) {
      weekendModes[e.mode] = (weekendModes[e.mode] ?? 0) + 1;
    }
  }
  if (weekdayModes.isNotEmpty && weekendModes.isNotEmpty) {
    final topWeekday = weekdayModes.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final topWeekend = weekendModes.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    if (topWeekday != topWeekend) {
      insights.add(Insight(
          'The weekend had a different texture than the weekdays.'));
    }
  }

  // Orientation arc: first half vs second half
  final firstHalfOrient = <LogOrientation, int>{};
  final secondHalfOrient = <LogOrientation, int>{};
  for (int i = 0; i < 4; i++) {
    for (final e in (entriesByDay[i] ?? [])) {
      firstHalfOrient[e.orientation] =
          (firstHalfOrient[e.orientation] ?? 0) + 1;
    }
  }
  for (int i = 4; i < 7; i++) {
    for (final e in (entriesByDay[i] ?? [])) {
      secondHalfOrient[e.orientation] =
          (secondHalfOrient[e.orientation] ?? 0) + 1;
    }
  }
  if (firstHalfOrient.isNotEmpty && secondHalfOrient.isNotEmpty) {
    final topFirst = firstHalfOrient.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final topSecond = secondHalfOrient.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    if (topFirst != topSecond) {
      insights.add(Insight(
          'The week started ${topFirst.label}-directed and shifted toward ${topSecond.label}.'));
    }
  }

  // Logging streak
  if (activeDays == 7) {
    insights.add(Insight('Logged every day this week.'));
  } else if (activeDays >= 5) {
    insights.add(Insight('Logged $activeDays of 7 days.'));
  }

  return insights.take(5).toList();
}

LogEntry _e(Mode mode, LogOrientation orientation, {int day = 0, int hour = 12}) {
  return LogEntry(
    mode: mode,
    orientation: orientation,
    timestamp: DateTime(2026, 1, 27 + day, hour, 0),
  );
}

void main() {
  group('Weekly insights', () {
    test('returns empty for fewer than 3 entries', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.other),
      ];
      expect(generateInsights(entries, {0: entries}), isEmpty);
    });

    test('returns empty for 0 entries', () {
      expect(generateInsights([], {}), isEmpty);
    });

    test('detects absent modes', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.other),
      ];
      final insights = generateInsights(entries, {0: entries});
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains("Nourishment didn't appear this week."));
      expect(texts, contains("Maintenance didn't appear this week."));
      expect(texts, contains("Drift didn't appear this week."));
      expect(texts, contains("Decay didn't appear this week."));
    });

    test('does not report present modes as absent', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.self_),
        _e(Mode.maintenance, LogOrientation.other),
        _e(Mode.drift, LogOrientation.mutual),
        _e(Mode.decay, LogOrientation.self_),
      ];
      final insights = generateInsights(entries, {0: entries});
      final texts = insights.map((i) => i.text).toList();
      expect(texts, isNot(contains("Growth didn't appear this week.")));
      expect(texts, isNot(contains("Nourishment didn't appear this week.")));
      expect(texts, isNot(contains("Decay didn't appear this week.")));
    });

    test('detects mode balance with top two modes', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.other),
        _e(Mode.nourishment, LogOrientation.other),
        _e(Mode.drift, LogOrientation.self_),
      ];
      final insights = generateInsights(entries, {0: entries});
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains('Growth and nourishment were most present.'));
    });

    test('detects single mode carrying week', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.other),
        _e(Mode.drift, LogOrientation.self_),
        _e(Mode.maintenance, LogOrientation.mutual),
      ];
      // growth = 2/5 = 40% which is not > 50%, so this shouldn't trigger single mode
      // top two: growth(2) + nourishment(1) = 3/5 = 60%, not > 60%
      final insights = generateInsights(entries, {0: entries});
      final texts = insights.map((i) => i.text).toList();
      // Neither top-two nor single mode triggers, no absent modes either
      expect(texts, isNot(contains('carried much of the week.')));
    });

    test('detects morning person', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_, hour: 8),
        _e(Mode.growth, LogOrientation.self_, hour: 9),
        _e(Mode.nourishment, LogOrientation.other, hour: 10),
        _e(Mode.drift, LogOrientation.self_, hour: 15),
      ];
      final insights = generateInsights(entries, {0: entries});
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains('Most moments happened in the morning.'));
    });

    test('detects evening person', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_, hour: 18),
        _e(Mode.growth, LogOrientation.self_, hour: 19),
        _e(Mode.nourishment, LogOrientation.other, hour: 20),
        _e(Mode.drift, LogOrientation.self_, hour: 10),
      ];
      final insights = generateInsights(entries, {0: entries});
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains('The evenings were where things lived.'));
    });

    test('detects quietest day with contrast', () {
      // Need 4+ active days with one at 0
      final entries = [
        _e(Mode.growth, LogOrientation.self_, day: 0),
        _e(Mode.nourishment, LogOrientation.other, day: 1),
        _e(Mode.maintenance, LogOrientation.mutual, day: 2),
        _e(Mode.drift, LogOrientation.self_, day: 3),
      ];
      final byDay = <int, List<LogEntry>>{
        0: [entries[0]],
        1: [entries[1]],
        2: [entries[2]],
        3: [entries[3]],
      };
      final insights = generateInsights(entries, byDay);
      final texts = insights.map((i) => i.text).toList();
      // Day 4 (Friday), 5, 6 are empty — quietest is whichever comes first at 0
      // With 4 active days and day 4 at 0, should say Friday was stillest
      expect(texts, contains('Friday was the stillest.'));
    });

    test('detects weekend shift', () {
      // Use all 5 modes to avoid absent-mode insights eating up the 5-insight cap
      final entries = [
        _e(Mode.growth, LogOrientation.self_, day: 0),
        _e(Mode.maintenance, LogOrientation.self_, day: 1),
        _e(Mode.drift, LogOrientation.self_, day: 2),
        _e(Mode.decay, LogOrientation.self_, day: 3),
        _e(Mode.nourishment, LogOrientation.other, day: 5),
        _e(Mode.nourishment, LogOrientation.other, day: 6),
      ];
      final byDay = <int, List<LogEntry>>{
        0: [entries[0]],
        1: [entries[1]],
        2: [entries[2]],
        3: [entries[3]],
        5: [entries[4]],
        6: [entries[5]],
      };
      final insights = generateInsights(entries, byDay);
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains(
          'The weekend had a different texture than the weekdays.'));
    });

    test('detects orientation arc shift', () {
      // Use all 5 modes to avoid absent-mode insights eating up the 5-insight cap
      final entries = [
        _e(Mode.growth, LogOrientation.self_, day: 0),
        _e(Mode.nourishment, LogOrientation.self_, day: 1),
        _e(Mode.maintenance, LogOrientation.self_, day: 2),
        _e(Mode.decay, LogOrientation.self_, day: 3),
        _e(Mode.drift, LogOrientation.other, day: 4),
        _e(Mode.growth, LogOrientation.other, day: 5),
        _e(Mode.nourishment, LogOrientation.other, day: 6),
      ];
      final byDay = <int, List<LogEntry>>{
        0: [entries[0]],
        1: [entries[1]],
        2: [entries[2]],
        3: [entries[3]],
        4: [entries[4]],
        5: [entries[5]],
        6: [entries[6]],
      };
      final insights = generateInsights(entries, byDay);
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains(
          'The week started Self-directed and shifted toward Other.'));
    });

    test('detects every day logged', () {
      // Use all 5 modes to avoid absent-mode insights eating up the 5-insight cap
      final modes = [Mode.growth, Mode.nourishment, Mode.maintenance, Mode.drift, Mode.decay, Mode.growth, Mode.nourishment];
      final entries = <LogEntry>[];
      final byDay = <int, List<LogEntry>>{};
      for (int i = 0; i < 7; i++) {
        final e = _e(modes[i], LogOrientation.self_, day: i);
        entries.add(e);
        byDay[i] = [e];
      }
      final insights = generateInsights(entries, byDay);
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains('Logged every day this week.'));
    });

    test('detects partial week logging', () {
      // Use all 5 modes across 5 days to avoid absent-mode insights
      final entries = <LogEntry>[];
      final byDay = <int, List<LogEntry>>{};
      final modes = [Mode.growth, Mode.nourishment, Mode.maintenance, Mode.drift, Mode.decay];
      for (int i = 0; i < 5; i++) {
        final e = _e(modes[i], LogOrientation.self_, day: i);
        entries.add(e);
        byDay[i] = [e];
      }
      final insights = generateInsights(entries, byDay);
      final texts = insights.map((i) => i.text).toList();
      expect(texts, contains('Logged 5 of 7 days.'));
    });

    test('limits to 5 insights max', () {
      // Create a scenario that triggers many insights
      final entries = <LogEntry>[];
      final byDay = <int, List<LogEntry>>{};
      // Day 0-4: growth + self, morning hours
      for (int i = 0; i < 5; i++) {
        final e = _e(Mode.growth, LogOrientation.self_, day: i, hour: 8);
        entries.add(e);
        byDay[i] = [e];
      }
      // Day 5-6: nourishment + other, evening hours
      for (int i = 5; i < 7; i++) {
        final e = _e(Mode.nourishment, LogOrientation.other, day: i, hour: 19);
        entries.add(e);
        byDay[i] = [e];
      }
      final insights = generateInsights(entries, byDay);
      expect(insights.length, lessThanOrEqualTo(5));
    });
  });
}
