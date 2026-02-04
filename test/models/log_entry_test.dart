import 'package:flutter_test/flutter_test.dart';
import 'package:lila/models/log_entry.dart';
import 'package:lila/models/focus_state.dart';

void main() {
  group('Mode', () {
    test('label capitalizes first letter', () {
      expect(Mode.nourishment.label, 'Nourishment');
      expect(Mode.growth.label, 'Growth');
      expect(Mode.maintenance.label, 'Maintenance');
      expect(Mode.drift.label, 'Drift');
    });

    test('durationPresets returns correct presets for each mode', () {
      expect(Mode.nourishment.durationPresets, [
        DurationPreset.moment,
        DurationPreset.stretch,
        DurationPreset.immersive,
      ]);
      expect(Mode.growth.durationPresets, [
        DurationPreset.focused,
        DurationPreset.deep,
        DurationPreset.extended,
      ]);
      expect(Mode.maintenance.durationPresets, [
        DurationPreset.quick,
        DurationPreset.routine,
        DurationPreset.heavy,
      ]);
      expect(Mode.drift.durationPresets, [
        DurationPreset.brief,
        DurationPreset.lost,
        DurationPreset.spiral,
      ]);
    });
  });

  group('DurationPreset', () {
    test('label capitalizes first letter', () {
      expect(DurationPreset.moment.label, 'Moment');
      expect(DurationPreset.deep.label, 'Deep');
      expect(DurationPreset.spiral.label, 'Spiral');
    });
  });

  group('LogOrientation', () {
    test('label returns display name', () {
      expect(LogOrientation.self_.label, 'Self');
      expect(LogOrientation.mutual.label, 'Mutual');
      expect(LogOrientation.other.label, 'Other');
    });

    test('markdownValue returns lowercase string', () {
      expect(LogOrientation.self_.markdownValue, 'self');
      expect(LogOrientation.mutual.markdownValue, 'mutual');
      expect(LogOrientation.other.markdownValue, 'other');
    });
  });

  group('LogEntry.toMarkdown', () {
    test('formats entry with label', () {
      final entry = LogEntry(
        label: 'Reading',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        timestamp: DateTime(2026, 2, 2, 10, 32),
      );
      final md = entry.toMarkdown();
      expect(md, contains('- **Reading**'));
      expect(md, contains('mode:: growth'));
      expect(md, contains('orientation:: self'));
      expect(md, contains('at:: 10:32'));
    });

    test('uses mode label when no label provided', () {
      final entry = LogEntry(
        mode: Mode.drift,
        orientation: LogOrientation.other,
        timestamp: DateTime(2026, 2, 2, 9, 5),
      );
      final md = entry.toMarkdown();
      expect(md, contains('- **Drift**'));
      expect(md, contains('at:: 09:05'));
    });

    test('uses mode label when label is empty string', () {
      final entry = LogEntry(
        label: '',
        mode: Mode.nourishment,
        orientation: LogOrientation.mutual,
        timestamp: DateTime(2026, 2, 2, 0, 0),
      );
      final md = entry.toMarkdown();
      expect(md, contains('- **Nourishment**'));
      expect(md, contains('at:: 00:00'));
    });

    test('pads single-digit hours and minutes', () {
      final entry = LogEntry(
        label: 'Walk',
        mode: Mode.maintenance,
        orientation: LogOrientation.self_,
        timestamp: DateTime(2026, 1, 1, 7, 3),
      );
      final md = entry.toMarkdown();
      expect(md, contains('at:: 07:03'));
    });

    test('includes duration when provided', () {
      final entry = LogEntry(
        label: 'Reading',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        duration: DurationPreset.deep,
        timestamp: DateTime(2026, 2, 2, 10, 32),
      );
      final md = entry.toMarkdown();
      expect(md, contains('duration:: deep'));
    });

    test('omits duration when null', () {
      final entry = LogEntry(
        label: 'Reading',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        timestamp: DateTime(2026, 2, 2, 10, 32),
      );
      final md = entry.toMarkdown();
      expect(md, isNot(contains('duration::')));
    });

    test('includes season when provided', () {
      final entry = LogEntry(
        label: 'Build',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        season: FocusSeason.builder,
        timestamp: DateTime(2026, 2, 2, 10, 32),
      );
      final md = entry.toMarkdown();
      expect(md, contains('season:: builder'));
    });
  });

  group('LogEntry.fromMarkdown', () {
    test('parses a complete entry', () {
      const block = '''- **Reading**
  mode:: growth
  orientation:: self
  at:: 10:32''';

      final entry = LogEntry.fromMarkdown(block);
      expect(entry, isNotNull);
      expect(entry!.label, 'Reading');
      expect(entry.mode, Mode.growth);
      expect(entry.orientation, LogOrientation.self_);
      expect(entry.timestamp.hour, 10);
      expect(entry.timestamp.minute, 32);
    });

    test('parses entry with duration', () {
      const block = '''- **Reading**
  mode:: growth
  orientation:: self
  duration:: deep
  at:: 10:32''';

      final entry = LogEntry.fromMarkdown(block);
      expect(entry, isNotNull);
      expect(entry!.duration, DurationPreset.deep);
    });

    test('parses entry without duration', () {
      const block = '''- **Reading**
  mode:: growth
  orientation:: self
  at:: 10:32''';

      final entry = LogEntry.fromMarkdown(block);
      expect(entry, isNotNull);
      expect(entry!.duration, isNull);
    });

    test('parses entry with season', () {
      const block = '''- **Reset**
  mode:: nourishment
  orientation:: mutual
  season:: sanctuary
  at:: 09:15''';

      final entry = LogEntry.fromMarkdown(block);
      expect(entry, isNotNull);
      expect(entry!.season, FocusSeason.sanctuary);
    });

    test('parses all duration preset types', () {
      for (final d in DurationPreset.values) {
        final block = '- **Test**  \n  mode:: growth  \n  orientation:: self  \n  duration:: ${d.name}  \n  at:: 12:00';
        final entry = LogEntry.fromMarkdown(block);
        expect(entry, isNotNull, reason: 'Failed to parse duration ${d.name}');
        expect(entry!.duration, d);
      }
    });

    test('ignores invalid duration name', () {
      const block = '''- **Reading**
  mode:: growth
  orientation:: self
  duration:: invalid
  at:: 10:32''';

      final entry = LogEntry.fromMarkdown(block);
      expect(entry, isNotNull);
      expect(entry!.duration, isNull);
    });

    test('parses all mode types', () {
      for (final mode in Mode.values) {
        final block = '- **Test**  \n  mode:: ${mode.name}  \n  orientation:: self  \n  at:: 12:00';
        final entry = LogEntry.fromMarkdown(block);
        expect(entry, isNotNull, reason: 'Failed to parse mode ${mode.name}');
        expect(entry!.mode, mode);
      }
    });

    test('parses all orientation types', () {
      for (final o in LogOrientation.values) {
        final block = '- **Test**  \n  mode:: growth  \n  orientation:: ${o.markdownValue}  \n  at:: 12:00';
        final entry = LogEntry.fromMarkdown(block);
        expect(entry, isNotNull, reason: 'Failed to parse orientation ${o.markdownValue}');
        expect(entry!.orientation, o);
      }
    });

    test('returns null for missing mode', () {
      const block = '- **Reading**  \n  orientation:: self  \n  at:: 10:32';
      expect(LogEntry.fromMarkdown(block), isNull);
    });

    test('returns null for missing orientation', () {
      const block = '- **Reading**  \n  mode:: growth  \n  at:: 10:32';
      expect(LogEntry.fromMarkdown(block), isNull);
    });

    test('returns null for invalid mode name', () {
      const block = '- **Reading**  \n  mode:: invalid  \n  orientation:: self  \n  at:: 10:32';
      expect(LogEntry.fromMarkdown(block), isNull);
    });

    test('returns null for invalid orientation name', () {
      const block = '- **Reading**  \n  mode:: growth  \n  orientation:: invalid  \n  at:: 10:32';
      expect(LogEntry.fromMarkdown(block), isNull);
    });

    test('handles missing label gracefully', () {
      const block = 'mode:: growth  \n  orientation:: self  \n  at:: 10:32';
      final entry = LogEntry.fromMarkdown(block);
      expect(entry, isNotNull);
      expect(entry!.label, isNull);
    });

    test('handles missing time gracefully', () {
      const block = '- **Reading**  \n  mode:: growth  \n  orientation:: self';
      final entry = LogEntry.fromMarkdown(block);
      expect(entry, isNotNull);
      expect(entry!.mode, Mode.growth);
    });

    test('returns null for empty string', () {
      expect(LogEntry.fromMarkdown(''), isNull);
    });

    test('returns null for random text', () {
      expect(LogEntry.fromMarkdown('hello world'), isNull);
    });
  });

  group('LogEntry roundtrip', () {
    test('toMarkdown then fromMarkdown preserves data', () {
      final original = LogEntry(
        label: 'Yoga',
        mode: Mode.nourishment,
        orientation: LogOrientation.mutual,
        timestamp: DateTime(2026, 2, 2, 14, 30),
      );

      final md = original.toMarkdown();
      final parsed = LogEntry.fromMarkdown(md);

      expect(parsed, isNotNull);
      expect(parsed!.label, 'Yoga');
      expect(parsed.mode, Mode.nourishment);
      expect(parsed.orientation, LogOrientation.mutual);
      expect(parsed.timestamp.hour, 14);
      expect(parsed.timestamp.minute, 30);
    });

    test('toMarkdown then fromMarkdown preserves duration', () {
      final original = LogEntry(
        label: 'Deep work',
        mode: Mode.growth,
        orientation: LogOrientation.self_,
        duration: DurationPreset.extended,
        timestamp: DateTime(2026, 2, 2, 9, 0),
      );

      final md = original.toMarkdown();
      final parsed = LogEntry.fromMarkdown(md);

      expect(parsed, isNotNull);
      expect(parsed!.duration, DurationPreset.extended);
    });

    test('toMarkdown then fromMarkdown preserves season', () {
      final original = LogEntry(
        label: 'Boundary',
        mode: Mode.nourishment,
        orientation: LogOrientation.other,
        season: FocusSeason.sanctuary,
        timestamp: DateTime(2026, 2, 2, 12, 0),
      );

      final md = original.toMarkdown();
      final parsed = LogEntry.fromMarkdown(md);

      expect(parsed, isNotNull);
      expect(parsed!.season, FocusSeason.sanctuary);
    });

    test('roundtrip works for all mode+orientation combos', () {
      for (final mode in Mode.values) {
        for (final o in LogOrientation.values) {
          final original = LogEntry(
            label: 'Test',
            mode: mode,
            orientation: o,
            timestamp: DateTime(2026, 1, 1, 12, 0),
          );
          final parsed = LogEntry.fromMarkdown(original.toMarkdown());
          expect(parsed, isNotNull,
              reason: 'Roundtrip failed for ${mode.name}/${o.markdownValue}');
          expect(parsed!.mode, mode);
          expect(parsed.orientation, o);
        }
      }
    });

    test('roundtrip without label uses mode label', () {
      final original = LogEntry(
        mode: Mode.drift,
        orientation: LogOrientation.self_,
        timestamp: DateTime(2026, 1, 1, 23, 59),
      );
      final parsed = LogEntry.fromMarkdown(original.toMarkdown());
      expect(parsed, isNotNull);
      expect(parsed!.label, 'Drift');
      expect(parsed.timestamp.hour, 23);
      expect(parsed.timestamp.minute, 59);
    });
  });
}
