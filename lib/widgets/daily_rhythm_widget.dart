import 'package:flutter/material.dart';
import '../models/log_entry.dart';

class DailyRhythmWidget extends StatelessWidget {
  final Map<int, List<LogEntry>> entriesByDay;

  const DailyRhythmWidget({super.key, required this.entriesByDay});

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _timeLabels = ['morn', 'aftn', 'eve', 'night'];

  static const _modeColors = {
    Mode.nourishment: Color(0xFF6B8F71),
    Mode.growth: Color(0xFF7B9EA8),
    Mode.maintenance: Color(0xFFA8976B),
    Mode.drift: Color(0xFF8B7B8B),
  };

  int _timeBucket(int hour) {
    if (hour < 12) return 0;
    if (hour < 17) return 1;
    if (hour < 21) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    // Build grid data: [day][bucket] = list of entries
    final grid = List.generate(
        7, (_) => List.generate(4, (_) => <LogEntry>[]));

    for (int day = 0; day < 7; day++) {
      final entries = entriesByDay[day] ?? [];
      for (final e in entries) {
        final bucket = _timeBucket(e.timestamp.hour);
        grid[day][bucket].add(e);
      }
    }

    int maxCount = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell.length > maxCount) maxCount = cell.length;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY RHYTHM',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 44),
            ..._timeLabels.map(
              (label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(7, (day) => _buildRow(day, grid[day], maxCount)),
      ],
    );
  }

  Widget _buildRow(int dayIndex, List<List<LogEntry>> buckets, int maxCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _dayLabels[dayIndex],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...buckets.map((entries) => _buildCell(entries, maxCount)),
        ],
      ),
    );
  }

  Widget _buildCell(List<LogEntry> entries, int maxCount) {
    Color cellColor;
    if (entries.isEmpty) {
      cellColor = Colors.white.withValues(alpha: 0.03);
    } else {
      // Blend mode colors of all entries in this cell
      final intensity = maxCount > 0
          ? 0.12 + (entries.length / maxCount) * 0.45
          : 0.12;
      final dominantMode = _dominantMode(entries);
      final baseColor = _modeColors[dominantMode]!;
      cellColor = baseColor.withValues(alpha: intensity);
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Mode _dominantMode(List<LogEntry> entries) {
    final counts = <Mode, int>{};
    for (final e in entries) {
      counts[e.mode] = (counts[e.mode] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
