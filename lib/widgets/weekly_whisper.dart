import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../theme/lila_theme.dart';

class WeeklyWhisperWidget extends StatelessWidget {
  final List<LogEntry> weekEntries;
  final Map<int, List<LogEntry>> entriesByDay;
  final String? whisperOverride;

  const WeeklyWhisperWidget({
    super.key,
    required this.weekEntries,
    required this.entriesByDay,
    this.whisperOverride,
  });

  static String? generateWhisper(
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

    // All four modes present, none >40%
    if (modeCounts.length == 4 &&
        modeCounts.values.every((c) => c <= total * 0.4)) {
      return 'All four modes showed up this week.';
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

  @override
  Widget build(BuildContext context) {
    final whisper =
        whisperOverride ?? generateWhisper(weekEntries, entriesByDay);
    if (whisper == null) return const SizedBox.shrink();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final radii = context.lilaRadii;
    final isSanctuary = radii.large >= 24;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        whisper,
        style: TextStyle(
          color: onSurface.withValues(alpha: isSanctuary ? 0.6 : 0.5),
          fontSize: 14,
          fontStyle: FontStyle.italic,
          fontWeight: isSanctuary ? FontWeight.w300 : FontWeight.w400,
          letterSpacing: isSanctuary ? 0.3 : 0,
        ),
      ),
    );
  }
}
