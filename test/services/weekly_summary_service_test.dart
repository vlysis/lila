import 'package:flutter_test/flutter_test.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/services/weekly_summary_service.dart';

LogEntry _entry(Mode mode, LogOrientation orientation, {String? label, int day = 0, int hour = 12}) {
  return LogEntry(
    label: label,
    mode: mode,
    orientation: orientation,
    timestamp: DateTime(2026, 1, 27 + day, hour, 0),
  );
}

void main() {
  group('WeeklySummaryService.generate', () {
    test('produces valid frontmatter', () {
      final weekStart = DateTime(2026, 1, 27);
      final result = WeeklySummaryService.generate(weekStart, {}, []);
      expect(result, contains('type: weekly'));
      expect(result, contains('from: 2026-01-27'));
      expect(result, contains('to: 2026-02-02'));
    });

    test('lists mode names per day', () {
      final weekStart = DateTime(2026, 1, 27);
      final entries = {
        0: [_entry(Mode.growth, LogOrientation.self_, day: 0)],
        1: <LogEntry>[],
        2: <LogEntry>[],
        3: <LogEntry>[],
        4: <LogEntry>[],
        5: <LogEntry>[],
        6: <LogEntry>[],
      };
      final all = entries.values.expand((e) => e).toList();
      final result = WeeklySummaryService.generate(weekStart, entries, all);
      expect(result, contains('Monday: growth'));
      expect(result, contains('Tuesday: —'));
    });

    test('includes orientation frequency', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [
        _entry(Mode.growth, LogOrientation.self_),
        _entry(Mode.growth, LogOrientation.self_),
        _entry(Mode.growth, LogOrientation.self_),
        _entry(Mode.growth, LogOrientation.other),
      ];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('Self: noticed often'));
      expect(result, contains('Other: noticed sometimes'));
    });

    test('includes whisper section', () {
      final weekStart = DateTime(2026, 1, 27);
      final result = WeeklySummaryService.generate(weekStart, {}, []);
      expect(result, contains('## Whisper'));
    });

    test('includes reflection when provided', () {
      final weekStart = DateTime(2026, 1, 27);
      final result = WeeklySummaryService.generate(
        weekStart, {}, [],
        reflection: 'A good week overall.',
      );
      expect(result, contains('## Reflection'));
      expect(result, contains('A good week overall.'));
    });

    test('omits reflection section when null', () {
      final weekStart = DateTime(2026, 1, 27);
      final result = WeeklySummaryService.generate(weekStart, {}, []);
      expect(result, isNot(contains('## Reflection')));
    });

    test('omits reflection section when empty', () {
      final weekStart = DateTime(2026, 1, 27);
      final result = WeeklySummaryService.generate(
        weekStart, {}, [],
        reflection: '   ',
      );
      expect(result, isNot(contains('## Reflection')));
    });
  });

  group('whisper text generation', () {
    test('quiet week for fewer than 2 entries', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [_entry(Mode.growth, LogOrientation.self_)];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('A quiet week.'));
    });

    test('quieter week for 2-4 entries', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = List.generate(3, (_) => _entry(Mode.growth, LogOrientation.self_));
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('A quieter week.'));
    });

    test('mode dominance detected for nourishment', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [
        ...List.generate(6, (_) => _entry(Mode.nourishment, LogOrientation.self_)),
        _entry(Mode.growth, LogOrientation.self_),
        _entry(Mode.drift, LogOrientation.self_),
      ];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('A week steeped in nourishment.'));
    });

    test('mode dominance detected for growth', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [
        ...List.generate(6, (_) => _entry(Mode.growth, LogOrientation.self_)),
        _entry(Mode.nourishment, LogOrientation.self_),
      ];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('Growth threaded through the week.'));
    });

    test('mode dominance detected for maintenance', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [
        ...List.generate(6, (_) => _entry(Mode.maintenance, LogOrientation.self_)),
        _entry(Mode.growth, LogOrientation.self_),
      ];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('A week of tending to things.'));
    });

    test('mode dominance detected for drift', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [
        ...List.generate(6, (_) => _entry(Mode.drift, LogOrientation.self_)),
        _entry(Mode.growth, LogOrientation.self_),
      ];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('The week drifted gently.'));
    });

    test('mode dominance detected for decay', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [
        ...List.generate(6, (_) => _entry(Mode.decay, LogOrientation.self_)),
        _entry(Mode.growth, LogOrientation.self_),
      ];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('Decay wove through the week.'));
    });

    test('fallback when no dominance', () {
      final weekStart = DateTime(2026, 1, 27);
      final all = [
        ...List.generate(2, (_) => _entry(Mode.nourishment, LogOrientation.self_)),
        ...List.generate(2, (_) => _entry(Mode.growth, LogOrientation.self_)),
        ...List.generate(2, (_) => _entry(Mode.maintenance, LogOrientation.self_)),
        _entry(Mode.drift, LogOrientation.self_),
      ];
      final result = WeeklySummaryService.generate(weekStart, {0: all}, all);
      expect(result, contains('A week, observed.'));
    });
  });
}
