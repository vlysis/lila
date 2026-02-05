import 'log_entry.dart';

class TrashedEntry {
  final LogEntry entry;
  final DateTime sourceDate;
  final DateTime? deletedAt;

  const TrashedEntry({
    required this.entry,
    required this.sourceDate,
    this.deletedAt,
  });
}
