import 'package:flutter/material.dart';
import '../models/log_entry.dart';

class OrientationThreadsWidget extends StatelessWidget {
  final List<LogEntry> weekEntries;

  const OrientationThreadsWidget({super.key, required this.weekEntries});

  static const _orientationColors = {
    LogOrientation.self_: Color(0xFF9B8EC4),  // soft violet
    LogOrientation.mutual: Color(0xFF6BA8A0), // warm teal
    LogOrientation.other: Color(0xFFC4956B),  // terracotta
  };

  @override
  Widget build(BuildContext context) {
    if (weekEntries.isEmpty) return const SizedBox.shrink();

    final counts = <LogOrientation, int>{};
    for (final e in weekEntries) {
      counts[e.orientation] = (counts[e.orientation] ?? 0) + 1;
    }
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);
    if (maxCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORIENTATION',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...LogOrientation.values.map((o) => _buildBar(o, counts, maxCount)),
      ],
    );
  }

  Widget _buildBar(
    LogOrientation orientation,
    Map<LogOrientation, int> counts,
    int maxCount,
  ) {
    final count = counts[orientation] ?? 0;
    final fraction = count / maxCount;
    final color = _orientationColors[orientation]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              orientation.label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      width: constraints.maxWidth * fraction,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.45),
                            color.withValues(alpha: 0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
