import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../theme/lila_theme.dart';

class _Insight {
  final String text;
  final Color color;

  const _Insight(this.text, this.color);
}

class WeeklyInsightsWidget extends StatelessWidget {
  final List<LogEntry> weekEntries;
  final Map<int, List<LogEntry>> entriesByDay;

  const WeeklyInsightsWidget({
    super.key,
    required this.weekEntries,
    required this.entriesByDay,
  });

  static const _neutralColor = Color(0xFF808080);

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  List<_Insight> _generate(BuildContext context) {
    final palette = context.lilaPalette;
    final insights = <_Insight>[];
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
      insights.add(_Insight(
        '$m1 and ${m2.toLowerCase()} were most present.',
        palette.modeColor(sortedModes[0].key),
      ));
    } else if (sortedModes.isNotEmpty &&
        sortedModes[0].value > total * 0.5) {
      insights.add(_Insight(
        '${sortedModes[0].key.label} carried much of the week.',
        palette.modeColor(sortedModes[0].key),
      ));
    }

    // Absent modes
    for (final mode in Mode.values) {
      if ((modeCounts[mode] ?? 0) == 0) {
        insights.add(_Insight(
          '${mode.label} didn\'t appear this week.',
          palette.modeColor(mode),
        ));
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
    if (busiestCount >= 3 && busiestCount > total / 7 * 1.5) {
      insights.add(_Insight(
        '${_dayNames[busiestDay]} was the fullest day.',
        _neutralColor,
      ));
    }

    // Quietest day (only if there's contrast)
    if (quietestCount == 0 && activeDays >= 4) {
      insights.add(_Insight(
        '${_dayNames[quietestDay]} was the stillest.',
        _neutralColor,
      ));
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
      insights.add(_Insight(
        'Most moments happened in the morning.',
        _neutralColor,
      ));
    } else if (eveningCount > total * 0.5) {
      insights.add(_Insight(
        'The evenings were where things lived.',
        _neutralColor,
      ));
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
        insights.add(_Insight(
          'The weekend had a different texture than the weekdays.',
          _neutralColor,
        ));
      }
    }

    // Orientation arc: first half vs second half of week
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
        insights.add(_Insight(
          'The week started ${topFirst.label}-directed and shifted toward ${topSecond.label}.',
          palette.selfOrientation,
        ));
      }
    }

    // Logging streak
    if (activeDays == 7) {
      insights.add(_Insight(
        'Logged every day this week.',
        _neutralColor,
      ));
    } else if (activeDays >= 5) {
      insights.add(_Insight(
        'Logged $activeDays of 7 days.',
        _neutralColor,
      ));
    }

    return insights.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final insights = _generate(context);
    if (insights.isEmpty) return const SizedBox.shrink();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final radii = context.lilaRadii;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSIGHTS',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(radii.small),
                  border: Border(
                    left: BorderSide(
                      color: insight.color.withValues(alpha: 0.5),
                      width: 3,
                    ),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  insight.text,
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
