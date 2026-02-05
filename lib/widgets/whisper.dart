import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../theme/lila_theme.dart';

class WhisperWidget extends StatelessWidget {
  final List<LogEntry> todayEntries;

  const WhisperWidget({super.key, required this.todayEntries});

  String? _generateWhisper() {
    if (todayEntries.isEmpty) return null;

    // Count modes
    final modeCounts = <Mode, int>{};
    final orientationCounts = <LogOrientation, int>{};
    for (final e in todayEntries) {
      modeCounts[e.mode] = (modeCounts[e.mode] ?? 0) + 1;
      orientationCounts[e.orientation] =
          (orientationCounts[e.orientation] ?? 0) + 1;
    }

    // First nourishment
    if (modeCounts[Mode.nourishment] == 1 && todayEntries.length > 1) {
      return 'First Nourishment logged today.';
    }

    // Mostly other-directed
    final otherCount = orientationCounts[LogOrientation.other] ?? 0;
    if (otherCount > todayEntries.length / 2 && todayEntries.length >= 3) {
      return 'Mostly Other-directed so far.';
    }

    // Mostly self
    final selfCount = orientationCounts[LogOrientation.self_] ?? 0;
    if (selfCount > todayEntries.length / 2 && todayEntries.length >= 3) {
      return 'Mostly Self-directed today.';
    }

    // Drift appeared
    if (modeCounts[Mode.drift] != null && modeCounts[Mode.drift]! >= 1) {
      final lastEntry = todayEntries.last;
      if (lastEntry.mode == Mode.drift) {
        return 'Drift noticed.';
      }
    }

    if (todayEntries.length == 1) {
      return 'Day started.';
    }

    return '${todayEntries.length} moments logged today.';
  }

  @override
  Widget build(BuildContext context) {
    final whisper = _generateWhisper();
    if (whisper == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        whisper,
        style: TextStyle(
          color: context.lilaSurface.textMuted,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
