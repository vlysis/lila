import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';

class FileService {
  static FileService? _instance;
  late String _rootDir;

  FileService._();

  static Future<FileService> getInstance() async {
    if (_instance == null) {
      _instance = FileService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _rootDir = '${appDir.path}/Lila';
    await _ensureDirectories();
  }

  String get rootDir => _rootDir;

  Future<void> _ensureDirectories() async {
    final dirs = ['Daily', 'Activities', 'Weekly', 'Meta'];
    for (final dir in dirs) {
      await Directory('$_rootDir/$dir').create(recursive: true);
    }
    final modesFile = File('$_rootDir/Meta/modes.md');
    if (!await modesFile.exists()) {
      await modesFile.writeAsString(
        '---\ntype: modes\n---\n\n'
        '- nourishment\n- growth\n- maintenance\n- drift\n',
      );
    }
  }

  String _dailyFilePath(DateTime date) {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    return '$_rootDir/Daily/$formatted.md';
  }

  Future<void> _ensureDailyFile(String path, DateTime date) async {
    final file = File(path);
    if (!await file.exists()) {
      final formatted = DateFormat('yyyy-MM-dd').format(date);
      await file.writeAsString(
        '---\ndate: $formatted\ntype: daily\n---\n\n## Entries\n',
      );
    }
  }

  Future<void> appendEntry(LogEntry entry) async {
    final path = _dailyFilePath(entry.timestamp);
    await _ensureDailyFile(path, entry.timestamp);
    final file = File(path);
    final markdown = entry.toMarkdown();
    final content = await file.readAsString();

    // Insert before ## Reflection if it exists, otherwise append
    if (content.contains('## Reflection')) {
      final updated = content.replaceFirst(
        RegExp(r'\n*## Reflection'),
        '\n$markdown\n## Reflection',
      );
      await file.writeAsString(updated);
    } else {
      await file.writeAsString('\n$markdown', mode: FileMode.append);
    }
  }

  Future<List<LogEntry>> readDailyEntries(DateTime date) async {
    final path = _dailyFilePath(date);
    final file = File(path);
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final entries = <LogEntry>[];

    // Split on entry bullets
    final blocks = content.split(RegExp(r'\n(?=- \*\*)'));
    for (final block in blocks) {
      final entry = LogEntry.fromMarkdown(block);
      if (entry != null) {
        // Reconstruct with correct date
        entries.add(LogEntry(
          label: entry.label,
          mode: entry.mode,
          orientation: entry.orientation,
          timestamp: DateTime(
            date.year,
            date.month,
            date.day,
            entry.timestamp.hour,
            entry.timestamp.minute,
          ),
        ));
      }
    }
    return entries;
  }

  Future<String> readDailyRaw(DateTime date) async {
    final path = _dailyFilePath(date);
    final file = File(path);
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<List<String>> getRecentLabels() async {
    final labels = <String>{};
    final now = DateTime.now();

    // Scan last 7 days
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final entries = await readDailyEntries(date);
      for (final entry in entries) {
        if (entry.label != null &&
            entry.label!.isNotEmpty &&
            entry.label != entry.mode.label) {
          labels.add(entry.label!);
        }
      }
    }
    return labels.take(8).toList();
  }

  String weeklyFilePath(DateTime weekStart) {
    // ISO week number
    final jan1 = DateTime(weekStart.year, 1, 1);
    final dayOfYear = weekStart.difference(jan1).inDays + 1;
    final weekNumber = ((dayOfYear - weekStart.weekday + 10) / 7).floor();
    return '$_rootDir/Weekly/${weekStart.year}-W${weekNumber.toString().padLeft(2, '0')}.md';
  }

  Future<void> writeWeeklySummary(DateTime weekStart, String content) async {
    final path = weeklyFilePath(weekStart);
    await File(path).writeAsString(content);
  }

  Future<Map<int, List<LogEntry>>> readWeekEntries(DateTime weekStart) async {
    final result = <int, List<LogEntry>>{};
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      result[i] = await readDailyEntries(date);
    }
    return result;
  }

  Future<String> readWeeklyReflection(DateTime weekStart) async {
    final path = weeklyFilePath(weekStart);
    final file = File(path);
    if (!await file.exists()) return '';

    final content = await file.readAsString();
    final match = RegExp(
      r'## Reflection\n\n([\s\S]*?)(?=\n## |$)',
    ).firstMatch(content);
    if (match == null) return '';
    return match.group(1)?.trim() ?? '';
  }

  Future<void> saveWeeklyReflection(
      DateTime weekStart, String reflection) async {
    final path = weeklyFilePath(weekStart);
    final file = File(path);
    if (!await file.exists()) return;

    var content = await file.readAsString();
    final reflectionSection = '\n\n## Reflection\n\n$reflection';

    if (content.contains('## Reflection')) {
      content = content.replaceFirst(
        RegExp(r'\n*## Reflection\n\n[\s\S]*?(?=\n## |$)'),
        reflectionSection,
      );
    } else {
      content += reflectionSection;
    }
    await file.writeAsString(content);
  }

  Future<String> readDailyReflection(DateTime date) async {
    final path = _dailyFilePath(date);
    final file = File(path);
    if (!await file.exists()) return '';

    final content = await file.readAsString();
    final match = RegExp(
      r'## Reflection\n\n([\s\S]*?)(?=\n## |$)',
    ).firstMatch(content);
    if (match == null) return '';
    return match.group(1)?.trim() ?? '';
  }

  Future<void> saveDailyReflection(DateTime date, String reflection) async {
    final path = _dailyFilePath(date);
    await _ensureDailyFile(path, date);

    var content = await File(path).readAsString();
    final reflectionSection = '\n\n## Reflection\n\n$reflection';

    if (content.contains('## Reflection')) {
      content = content.replaceFirst(
        RegExp(r'\n*## Reflection\n\n[\s\S]*?(?=\n## |$)'),
        reflectionSection,
      );
    } else {
      content += reflectionSection;
    }
    await File(path).writeAsString(content);
  }

  Future<void> resetVault() async {
    final dir = Directory(_rootDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _ensureDirectories();
  }
}
