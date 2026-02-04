import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../theme/lila_theme.dart';

class WeekTextureWidget extends StatelessWidget {
  final Map<int, List<LogEntry>> entriesByDay;

  const WeekTextureWidget({super.key, required this.entriesByDay});

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WEEK TEXTURE',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(7, (i) => _buildDayRow(context, i)),
      ],
    );
  }

  Widget _buildDayRow(BuildContext context, int dayIndex) {
    final entries = entriesByDay[dayIndex] ?? [];
    final palette = context.lilaPalette;
    final radii = context.lilaRadii;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Sort by time
    final sorted = List<LogEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _dayLabels[dayIndex],
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: sorted.isEmpty
                ? Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(radii.small),
                    ),
                  )
                : Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: sorted.map((entry) {
                      final color = palette.modeColor(entry.mode);
                      return Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(radii.small),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
