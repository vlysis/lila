import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/log_entry.dart';

class FileService {
  static const _vaultPathKey = 'custom_vault_path';
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

  static Future<String> get defaultPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/Lila';
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_vaultPathKey);
    if (custom != null && custom.isNotEmpty) {
      // Test if we still have write access to the custom path
      if (await _hasWriteAccess(custom)) {
        _rootDir = custom;
      } else {
        // Permission lost (e.g., macOS sandbox after restart), fall back to default
        await prefs.remove(_vaultPathKey);
        _rootDir = await defaultPath;
      }
    } else {
      _rootDir = await defaultPath;
    }
    await _ensureDirectories();
  }

  Future<bool> _hasWriteAccess(String path) async {
    try {
      final testFile = File('$path/.lila_access_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> setVaultPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == await defaultPath) {
      await prefs.remove(_vaultPathKey);
    } else {
      await prefs.setString(_vaultPathKey, path);
    }
    _rootDir = path;
    await _ensureDirectories();
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

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

  Future<bool> deleteEntry(LogEntry entry) async {
    final path = _dailyFilePath(entry.timestamp);
    final file = File(path);
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    final entriesHeaderIndex = content.indexOf('## Entries');
    if (entriesHeaderIndex == -1) return false;

    final headerLineEnd = content.indexOf('\n', entriesHeaderIndex);
    if (headerLineEnd == -1) return false;

    final entriesStart = headerLineEnd + 1;
    final afterEntries = content.substring(entriesStart);
    final nextSectionMatch = RegExp(r'\n## ').firstMatch(afterEntries);
    final entriesEnd = nextSectionMatch != null
        ? entriesStart + nextSectionMatch.start
        : content.length;

    final entriesSection = content.substring(entriesStart, entriesEnd);
    final blocks = entriesSection.split(RegExp(r'\n(?=- \*\*)'));
    var removed = false;
    final keptBlocks = <String>[];

    for (final block in blocks) {
      final parsed = LogEntry.fromMarkdown(block);
      if (!removed && parsed != null && _matchesEntry(entry, parsed)) {
        removed = true;
        continue;
      }
      keptBlocks.add(block);
    }

    if (removed) {
      final updated =
          content.substring(0, entriesStart) +
          keptBlocks.join('\n') +
          content.substring(entriesEnd);
      await file.writeAsString(updated);
    }
    return removed;
  }

  bool _matchesEntry(LogEntry target, LogEntry parsed) {
    final targetLabel =
        target.label?.trim().isNotEmpty == true ? target.label! : target.mode.label;
    final parsedLabel =
        parsed.label?.trim().isNotEmpty == true ? parsed.label! : parsed.mode.label;

    if (targetLabel != parsedLabel) return false;
    if (target.mode != parsed.mode) return false;
    if (target.orientation != parsed.orientation) return false;
    if (target.timestamp.hour != parsed.timestamp.hour ||
        target.timestamp.minute != parsed.timestamp.minute) {
      return false;
    }
    if (target.duration != null && target.duration != parsed.duration) {
      return false;
    }
    return true;
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

  /// Reads the Discussion section from a daily file.
  /// Returns null if no discussion exists.
  Future<String?> readDiscussion(DateTime date) async {
    final path = _dailyFilePath(date);
    final file = File(path);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final match = RegExp(
      r'## Discussion\n\n([\s\S]*?)(?=\n## |$)',
    ).firstMatch(content);
    if (match == null) return null;
    final text = match.group(1)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// Saves the Discussion section to a daily file.
  /// Discussion is placed after Reflection (last in file).
  Future<void> saveDiscussion(DateTime date, String markdown) async {
    final path = _dailyFilePath(date);
    await _ensureDailyFile(path, date);

    var content = await File(path).readAsString();
    final discussionSection = '\n\n## Discussion\n\n$markdown';

    if (content.contains('## Discussion')) {
      content = content.replaceFirst(
        RegExp(r'\n*## Discussion\n\n[\s\S]*?(?=\n## |$)'),
        discussionSection,
      );
    } else {
      content += discussionSection;
    }
    await File(path).writeAsString(content);
  }
}
