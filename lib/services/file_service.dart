import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/log_entry.dart';
import '../models/trashed_entry.dart';

class _SectionRemoval {
  final String updatedContent;
  final String removedBlock;

  const _SectionRemoval({
    required this.updatedContent,
    required this.removedBlock,
  });
}

class FileService {
  static const _vaultPathKey = 'custom_vault_path';
  static FileService? _instance;
  static Future<void>? _initFuture;
  late String _rootDir;

  FileService._();

  static Future<FileService> getInstance() async {
    if (_instance == null) {
      _instance = FileService._();
      _initFuture = _instance!._init();
    }
    if (_initFuture != null) {
      await _initFuture;
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
  static void resetInstance() {
    _instance = null;
    _initFuture = null;
  }

  String get rootDir => _rootDir;

  Future<String> backupVaultTo(String destinationRootPath) async {
    final rootDir = Directory(_rootDir);
    final destinationRoot = Directory(destinationRootPath);
    if (!await destinationRoot.exists()) {
      throw FileSystemException(
        'Destination folder does not exist',
        destinationRootPath,
      );
    }

    final rootCanonical = await rootDir.resolveSymbolicLinks();
    final destinationCanonical = await destinationRoot.resolveSymbolicLinks();
    if (_isSubpath(rootCanonical, destinationCanonical)) {
      throw StateError('Backup destination cannot be inside the vault.');
    }

    final backupDir = await _createBackupDirectory(destinationRoot);
    await _copyDirectory(rootDir, backupDir);
    return backupDir.path;
  }

  Future<void> restoreVaultFrom(String backupRootPath) async {
    final rootDir = Directory(_rootDir);
    final backupDir = Directory(backupRootPath);
    if (!await backupDir.exists()) {
      throw FileSystemException(
        'Backup folder does not exist',
        backupRootPath,
      );
    }

    final rootCanonical = await rootDir.resolveSymbolicLinks();
    final backupCanonical = await backupDir.resolveSymbolicLinks();
    if (_isSubpath(rootCanonical, backupCanonical)) {
      throw StateError('Backup folder cannot be inside the vault.');
    }

    if (!await _looksLikeVault(backupDir)) {
      throw StateError('Selected folder does not look like a Lila backup.');
    }

    await _clearDirectory(rootDir);
    await _copyDirectory(backupDir, rootDir);
    await _ensureDirectories();
  }

  bool _isSubpath(String basePath, String candidatePath) {
    if (basePath == candidatePath) return true;
    final normalizedBase = basePath.endsWith(Platform.pathSeparator)
        ? basePath
        : '$basePath${Platform.pathSeparator}';
    return candidatePath.startsWith(normalizedBase);
  }

  Future<bool> _looksLikeVault(Directory root) async {
    final dailyDir = Directory('${root.path}/Daily');
    final weeklyDir = Directory('${root.path}/Weekly');
    final metaFile = File('${root.path}/Meta/modes.md');
    return await dailyDir.exists() ||
        await weeklyDir.exists() ||
        await metaFile.exists();
  }

  Future<void> _clearDirectory(Directory root) async {
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      await entity.delete(recursive: true);
    }
  }

  Future<Directory> _createBackupDirectory(Directory destinationRoot) async {
    final timestamp = DateFormat('yyyy-MM-dd HHmm').format(DateTime.now());
    final baseName = 'Lila Backup $timestamp';
    var name = baseName;
    var index = 1;
    var dir = Directory('${destinationRoot.path}/$name');

    while (await dir.exists()) {
      index += 1;
      name = '$baseName ($index)';
      dir = Directory('${destinationRoot.path}/$name');
    }

    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = entity.path
          .split(Platform.pathSeparator)
          .where((segment) => segment.isNotEmpty)
          .last;
      final targetPath = '${destination.path}/$name';
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }

  Future<void> _ensureDirectories() async {
    final dirs = ['Daily', 'Activities', 'Weekly', 'Meta', 'Trash'];
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

  String _trashFilePath(DateTime date) {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    return '$_rootDir/Trash/$formatted.md';
  }

  Future<void> _ensureTrashFile(String path, DateTime date) async {
    final file = File(path);
    if (!await file.exists()) {
      final formatted = DateFormat('yyyy-MM-dd').format(date);
      await file.writeAsString(
        '---\ndate: $formatted\ntype: trash\n---\n\n## Deleted\n',
      );
    }
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

  LogEntry _applyDate(LogEntry entry, DateTime date) {
    return LogEntry(
      label: entry.label,
      mode: entry.mode,
      orientation: entry.orientation,
      duration: entry.duration,
      season: entry.season,
      timestamp: DateTime(
        date.year,
        date.month,
        date.day,
        entry.timestamp.hour,
        entry.timestamp.minute,
        entry.timestamp.second,
        entry.timestamp.millisecond,
        entry.timestamp.microsecond,
      ),
    );
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
        entries.add(_applyDate(entry, date));
      }
    }
    return entries;
  }

  Future<bool> deleteEntry(LogEntry entry) async {
    final path = _dailyFilePath(entry.timestamp);
    final file = File(path);
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    final removal = _removeEntryFromSection(
      content: content,
      sectionHeader: '## Entries',
      shouldRemove: (parsed, _) => _matchesEntry(entry, parsed),
    );
    if (removal == null) return false;
    await file.writeAsString(removal.updatedContent);
    return true;
  }

  _SectionRemoval? _removeEntryFromSection({
    required String content,
    required String sectionHeader,
    required bool Function(LogEntry parsed, String block) shouldRemove,
  }) {
    final headerIndex = content.indexOf(sectionHeader);
    if (headerIndex == -1) return null;

    final headerLineEnd = content.indexOf('\n', headerIndex);
    if (headerLineEnd == -1) return null;

    final sectionStart = headerLineEnd + 1;
    final afterSection = content.substring(sectionStart);
    final nextSectionMatch = RegExp(r'\n## ').firstMatch(afterSection);
    final sectionEnd = nextSectionMatch != null
        ? sectionStart + nextSectionMatch.start
        : content.length;

    final section = content.substring(sectionStart, sectionEnd);
    final blocks = section.split(RegExp(r'\n(?=- \*\*)'));
    var removedBlock = '';
    var removed = false;
    final keptBlocks = <String>[];

    for (final block in blocks) {
      final parsed = LogEntry.fromMarkdown(block);
      if (!removed && parsed != null && shouldRemove(parsed, block)) {
        removed = true;
        removedBlock = block;
        continue;
      }
      keptBlocks.add(block);
    }

    if (!removed) return null;
    final updated =
        content.substring(0, sectionStart) +
        keptBlocks.join('\n') +
        content.substring(sectionEnd);
    return _SectionRemoval(updatedContent: updated, removedBlock: removedBlock);
  }

  String _withTrashMetadata({
    required String block,
    required DateTime deletedAt,
    required DateTime sourceDate,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(block.trimRight());
    buffer.writeln('  deleted_at:: ${deletedAt.toIso8601String()}');
    buffer.writeln(
      '  source_date:: ${DateFormat('yyyy-MM-dd').format(sourceDate)}',
    );
    return buffer.toString().trimRight();
  }

  DateTime? _parseDeletedAt(String block) {
    final match = RegExp(r'deleted_at:: ([^\n]+)').firstMatch(block);
    if (match == null) return null;
    return DateTime.tryParse(match.group(1)!.trim());
  }

  DateTime? _parseSourceDate(String block) {
    final match = RegExp(r'source_date:: ([^\n]+)').firstMatch(block);
    if (match == null) return null;
    final value = match.group(1)!.trim();
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  bool _matchesTrashEntry(
    LogEntry target,
    LogEntry parsed,
    DateTime? targetDeletedAt,
    DateTime? blockDeletedAt,
  ) {
    if (targetDeletedAt != null && blockDeletedAt != null) {
      if (!blockDeletedAt.isAtSameMomentAs(targetDeletedAt)) {
        return false;
      }
    }
    return _matchesEntry(target, parsed);
  }

  Future<bool> moveEntryToTrash(LogEntry entry) async {
    final path = _dailyFilePath(entry.timestamp);
    final file = File(path);
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    final removal = _removeEntryFromSection(
      content: content,
      sectionHeader: '## Entries',
      shouldRemove: (parsed, _) => _matchesEntry(entry, parsed),
    );
    if (removal == null) return false;

    await file.writeAsString(removal.updatedContent);

    final deletedAt = DateTime.now();
    final trashBlock = _withTrashMetadata(
      block: removal.removedBlock,
      deletedAt: deletedAt,
      sourceDate: entry.timestamp,
    );
    final trashPath = _trashFilePath(entry.timestamp);
    await _ensureTrashFile(trashPath, entry.timestamp);
    await File(trashPath).writeAsString(
      '\n$trashBlock',
      mode: FileMode.append,
    );
    return true;
  }

  Future<List<TrashedEntry>> readTrashEntriesForDate(DateTime date) async {
    final path = _trashFilePath(date);
    final file = File(path);
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final headerIndex = content.indexOf('## Deleted');
    if (headerIndex == -1) return [];

    final headerLineEnd = content.indexOf('\n', headerIndex);
    if (headerLineEnd == -1) return [];

    final sectionStart = headerLineEnd + 1;
    final afterSection = content.substring(sectionStart);
    final nextSectionMatch = RegExp(r'\n## ').firstMatch(afterSection);
    final sectionEnd = nextSectionMatch != null
        ? sectionStart + nextSectionMatch.start
        : content.length;

    final section = content.substring(sectionStart, sectionEnd);
    final blocks = section.split(RegExp(r'\n(?=- \*\*)'));
    final entries = <TrashedEntry>[];

    for (final block in blocks) {
      final parsed = LogEntry.fromMarkdown(block);
      if (parsed == null) continue;
      final sourceDate = _parseSourceDate(block) ?? date;
      final entryWithDate = _applyDate(parsed, sourceDate);
      final deletedAt = _parseDeletedAt(block);
      entries.add(
        TrashedEntry(
          entry: entryWithDate,
          sourceDate: sourceDate,
          deletedAt: deletedAt,
        ),
      );
    }
    return entries;
  }

  Future<Map<DateTime, List<TrashedEntry>>> readAllTrashEntries() async {
    final dir = Directory('$_rootDir/Trash');
    if (!await dir.exists()) return {};

    final results = <DateTime, List<TrashedEntry>>{};
    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.md'))
        .cast<File>()
        .toList();

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.md')) continue;
      final dateString = name.replaceAll('.md', '');
      DateTime? parsedDate;
      try {
        parsedDate = DateFormat('yyyy-MM-dd').parseStrict(dateString);
      } catch (_) {
        parsedDate = null;
      }
      if (parsedDate == null) continue;
      final entries = await readTrashEntriesForDate(parsedDate);
      if (entries.isNotEmpty) {
        results[parsedDate] = entries;
      }
    }
    return results;
  }

  Future<bool> restoreEntry(TrashedEntry trashed) async {
    final trashPath = _trashFilePath(trashed.sourceDate);
    final file = File(trashPath);
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    final removal = _removeEntryFromSection(
      content: content,
      sectionHeader: '## Deleted',
      shouldRemove: (parsed, block) => _matchesTrashEntry(
        trashed.entry,
        parsed,
        trashed.deletedAt,
        _parseDeletedAt(block),
      ),
    );
    if (removal == null) return false;

    await appendEntry(trashed.entry);
    await file.writeAsString(removal.updatedContent);
    return true;
  }

  Future<bool> deleteTrashedEntry(TrashedEntry trashed) async {
    final trashPath = _trashFilePath(trashed.sourceDate);
    final file = File(trashPath);
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    final removal = _removeEntryFromSection(
      content: content,
      sectionHeader: '## Deleted',
      shouldRemove: (parsed, block) => _matchesTrashEntry(
        trashed.entry,
        parsed,
        trashed.deletedAt,
        _parseDeletedAt(block),
      ),
    );
    if (removal == null) return false;
    await file.writeAsString(removal.updatedContent);
    return true;
  }

  bool _matchesEntry(LogEntry target, LogEntry parsed) {
    final targetLabel =
        target.label?.trim().isNotEmpty == true ? target.label! : target.mode.label;
    final parsedLabel =
        parsed.label?.trim().isNotEmpty == true ? parsed.label! : parsed.mode.label;

    if (targetLabel != parsedLabel) return false;
    if (target.mode != parsed.mode) return false;
    if (target.orientation != parsed.orientation) return false;
    if (target.season != null && target.season != parsed.season) return false;
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
