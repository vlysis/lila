class Reminder {
  final String id;
  final String text;
  final DateTime remindAt;
  final int alertOffsetMinutes;
  final DateTime createdAt;
  final bool done;
  final DateTime? doneAt;

  const Reminder({
    required this.id,
    required this.text,
    required this.remindAt,
    required this.alertOffsetMinutes,
    required this.createdAt,
    required this.done,
    required this.doneAt,
  });

  DateTime get alertAt =>
      remindAt.subtract(Duration(minutes: alertOffsetMinutes));

  Reminder copyWith({
    String? id,
    String? text,
    DateTime? remindAt,
    int? alertOffsetMinutes,
    DateTime? createdAt,
    bool? done,
    DateTime? doneAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      text: text ?? this.text,
      remindAt: remindAt ?? this.remindAt,
      alertOffsetMinutes: alertOffsetMinutes ?? this.alertOffsetMinutes,
      createdAt: createdAt ?? this.createdAt,
      done: done ?? this.done,
      doneAt: doneAt ?? this.doneAt,
    );
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('- **$text**  ');
    buffer.writeln('  id:: $id  ');
    buffer.writeln('  remind_at:: ${remindAt.toIso8601String()}  ');
    buffer.writeln('  alert_offset_min:: $alertOffsetMinutes  ');
    buffer.writeln('  created_at:: ${createdAt.toIso8601String()}  ');
    buffer.writeln('  done:: $done  ');
    buffer.writeln(
      '  done_at:: ${doneAt != null ? doneAt!.toIso8601String() : ''}',
    );
    return buffer.toString();
  }

  static Reminder? fromMarkdown(String block) {
    final textMatch = RegExp(r'- \*\*(.+?)\*\*').firstMatch(block);
    final idMatch = RegExp(r'id:: ([^\n]+)').firstMatch(block);
    final remindAtMatch = RegExp(r'remind_at:: ([^\n]+)').firstMatch(block);
    final offsetMatch = RegExp(
      r'alert_offset_min:: ([^\n]+)',
    ).firstMatch(block);
    final createdAtMatch = RegExp(r'created_at:: ([^\n]+)').firstMatch(block);
    final doneMatch = RegExp(r'done:: ([^\n]+)').firstMatch(block);
    final doneAtMatch = RegExp(r'done_at::([^\n]*)').firstMatch(block);

    if (textMatch == null ||
        idMatch == null ||
        remindAtMatch == null ||
        offsetMatch == null ||
        createdAtMatch == null ||
        doneMatch == null) {
      return null;
    }

    final remindAt = DateTime.tryParse(remindAtMatch.group(1)!.trim());
    final createdAt = DateTime.tryParse(createdAtMatch.group(1)!.trim());
    final offset = int.tryParse(offsetMatch.group(1)!.trim());
    final done = doneMatch.group(1)!.trim().toLowerCase() == 'true';

    if (remindAt == null || createdAt == null || offset == null) {
      return null;
    }

    final doneAtRaw = doneAtMatch?.group(1)?.trim() ?? '';
    final doneAt = doneAtRaw.isEmpty ? null : DateTime.tryParse(doneAtRaw);

    return Reminder(
      id: idMatch.group(1)!.trim(),
      text: textMatch.group(1)!.trim(),
      remindAt: remindAt,
      alertOffsetMinutes: offset,
      createdAt: createdAt,
      done: done,
      doneAt: doneAt,
    );
  }
}
