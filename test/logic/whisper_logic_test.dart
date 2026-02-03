import 'package:flutter_test/flutter_test.dart';
import 'package:lila/models/log_entry.dart';

// Extract whisper logic for testability (mirrors WhisperWidget._generateWhisper)
String? generateDailyWhisper(List<LogEntry> entries) {
  if (entries.isEmpty) return null;

  final modeCounts = <Mode, int>{};
  final orientationCounts = <LogOrientation, int>{};
  for (final e in entries) {
    modeCounts[e.mode] = (modeCounts[e.mode] ?? 0) + 1;
    orientationCounts[e.orientation] =
        (orientationCounts[e.orientation] ?? 0) + 1;
  }

  if (modeCounts[Mode.nourishment] == 1 && entries.length > 1) {
    return 'First Nourishment logged today.';
  }

  final otherCount = orientationCounts[LogOrientation.other] ?? 0;
  if (otherCount > entries.length / 2 && entries.length >= 3) {
    return 'Mostly Other-directed so far.';
  }

  final selfCount = orientationCounts[LogOrientation.self_] ?? 0;
  if (selfCount > entries.length / 2 && entries.length >= 3) {
    return 'Mostly Self-directed today.';
  }

  if (modeCounts[Mode.drift] != null && modeCounts[Mode.drift]! >= 1) {
    final lastEntry = entries.last;
    if (lastEntry.mode == Mode.drift) {
      return 'Drift noticed.';
    }
  }

  if (entries.length == 1) {
    return 'Day started.';
  }

  return '${entries.length} moments logged today.';
}

LogEntry _e(Mode mode, LogOrientation orientation) {
  return LogEntry(
    mode: mode,
    orientation: orientation,
    timestamp: DateTime(2026, 2, 2, 12, 0),
  );
}

void main() {
  group('Daily whisper', () {
    test('returns null for empty entries', () {
      expect(generateDailyWhisper([]), isNull);
    });

    test('returns "Day started." for single entry', () {
      expect(
        generateDailyWhisper([_e(Mode.growth, LogOrientation.self_)]),
        'Day started.',
      );
    });

    test('detects first nourishment', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.self_),
      ];
      expect(generateDailyWhisper(entries), 'First Nourishment logged today.');
    });

    test('does not trigger first nourishment when multiple nourishments', () {
      final entries = [
        _e(Mode.nourishment, LogOrientation.self_),
        _e(Mode.nourishment, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.self_),
      ];
      expect(
        generateDailyWhisper(entries),
        isNot('First Nourishment logged today.'),
      );
    });

    test('detects mostly other-directed', () {
      final entries = [
        _e(Mode.growth, LogOrientation.other),
        _e(Mode.growth, LogOrientation.other),
        _e(Mode.growth, LogOrientation.self_),
      ];
      expect(generateDailyWhisper(entries), 'Mostly Other-directed so far.');
    });

    test('does not trigger other-directed with fewer than 3 entries', () {
      final entries = [
        _e(Mode.growth, LogOrientation.other),
        _e(Mode.growth, LogOrientation.other),
      ];
      expect(
        generateDailyWhisper(entries),
        isNot('Mostly Other-directed so far.'),
      );
    });

    test('detects mostly self-directed', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.other),
      ];
      expect(generateDailyWhisper(entries), 'Mostly Self-directed today.');
    });

    test('detects drift noticed when last entry is drift', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.drift, LogOrientation.self_),
      ];
      // First nourishment check runs first: nourishment count is 0, so skips.
      // Other/self checks need >= 3. Falls through to drift check.
      expect(generateDailyWhisper(entries), 'Drift noticed.');
    });

    test('does not trigger drift noticed when drift is not last', () {
      final entries = [
        _e(Mode.drift, LogOrientation.self_),
        _e(Mode.growth, LogOrientation.self_),
      ];
      expect(generateDailyWhisper(entries), isNot('Drift noticed.'));
    });

    test('returns count for multiple entries with no special pattern', () {
      final entries = [
        _e(Mode.growth, LogOrientation.self_),
        _e(Mode.maintenance, LogOrientation.mutual),
      ];
      expect(generateDailyWhisper(entries), '2 moments logged today.');
    });
  });
}
