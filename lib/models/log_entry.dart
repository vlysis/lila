import 'focus_state.dart';

enum Mode {
  nourishment,
  growth,
  maintenance,
  drift;

  String get label {
    return name[0].toUpperCase() + name.substring(1);
  }

  List<DurationPreset> get durationPresets {
    switch (this) {
      case Mode.nourishment:
        return [DurationPreset.moment, DurationPreset.stretch, DurationPreset.immersive];
      case Mode.growth:
        return [DurationPreset.focused, DurationPreset.deep, DurationPreset.extended];
      case Mode.maintenance:
        return [DurationPreset.quick, DurationPreset.routine, DurationPreset.heavy];
      case Mode.drift:
        return [DurationPreset.brief, DurationPreset.lost, DurationPreset.spiral];
    }
  }
}

enum DurationPreset {
  // Nourishment
  moment,
  stretch,
  immersive,
  // Growth
  focused,
  deep,
  extended,
  // Maintenance
  quick,
  routine,
  heavy,
  // Drift
  brief,
  lost,
  spiral;

  String get label {
    return name[0].toUpperCase() + name.substring(1);
  }
}

enum LogOrientation {
  self_,
  mutual,
  other;

  String get label {
    switch (this) {
      case LogOrientation.self_:
        return 'Self';
      case LogOrientation.mutual:
        return 'Mutual';
      case LogOrientation.other:
        return 'Other';
    }
  }

  String get markdownValue {
    switch (this) {
      case LogOrientation.self_:
        return 'self';
      case LogOrientation.mutual:
        return 'mutual';
      case LogOrientation.other:
        return 'other';
    }
  }
}

class LogEntry {
  final String? label;
  final Mode mode;
  final LogOrientation orientation;
  final DurationPreset? duration;
  final FocusSeason? season;
  final DateTime timestamp;

  LogEntry({
    this.label,
    required this.mode,
    required this.orientation,
    this.duration,
    this.season,
    required this.timestamp,
  });

  String toMarkdown() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final activityLabel = label?.isNotEmpty == true ? label! : mode.label;
    final buffer = StringBuffer();
    buffer.writeln('- **$activityLabel**  ');
    buffer.writeln('  mode:: ${mode.name}  ');
    buffer.writeln('  orientation:: ${orientation.markdownValue}  ');
    if (season != null) {
      buffer.writeln('  season:: ${season!.storageValue}  ');
    }
    if (duration != null) {
      buffer.writeln('  duration:: ${duration!.name}  ');
    }
    buffer.writeln('  at:: $time');
    return buffer.toString();
  }

  static LogEntry? fromMarkdown(String block) {
    final labelMatch = RegExp(r'- \*\*(.+?)\*\*').firstMatch(block);
    final modeMatch = RegExp(r'mode:: (\w+)').firstMatch(block);
    final orientationMatch =
        RegExp(r'orientation:: (\w+)').firstMatch(block);
    final seasonMatch = RegExp(r'season:: (\w+)').firstMatch(block);
    final durationMatch = RegExp(r'duration:: (\w+)').firstMatch(block);
    final timeMatch = RegExp(r'at:: (\d{2}:\d{2})').firstMatch(block);

    if (modeMatch == null || orientationMatch == null) return null;

    final modeName = modeMatch.group(1)!;
    final orientationName = orientationMatch.group(1)!;

    final mode = Mode.values.where((m) => m.name == modeName).firstOrNull;
    final orientation = LogOrientation.values
        .where((o) => o.markdownValue == orientationName)
        .firstOrNull;

    if (mode == null || orientation == null) return null;

    DurationPreset? duration;
    if (durationMatch != null) {
      final durationName = durationMatch.group(1)!;
      duration = DurationPreset.values
          .where((d) => d.name == durationName)
          .firstOrNull;
    }

    FocusSeason? season;
    if (seasonMatch != null) {
      season = FocusSeason.fromStorage(seasonMatch.group(1)!);
    }

    DateTime timestamp = DateTime.now();
    if (timeMatch != null) {
      final parts = timeMatch.group(1)!.split(':');
      timestamp = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return LogEntry(
      label: labelMatch?.group(1),
      mode: mode,
      orientation: orientation,
      duration: duration,
      season: season,
      timestamp: timestamp,
    );
  }
}
