import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/focus_state.dart';
import 'file_service.dart';

class IntentionService {
  static IntentionService? _instance;
  final FileService _fileService;

  IntentionService._(this._fileService);

  static Future<IntentionService> getInstance() async {
    if (_instance == null) {
      final fs = await FileService.getInstance();
      _instance = IntentionService._(fs);
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

  String get _path => '${_fileService.rootDir}/Meta/intentions.md';

  Future<FocusState> readCurrent() async {
    final file = File(_path);
    if (!await file.exists()) {
      return FocusState.defaultState();
    }

    final content = await file.readAsString();
    final seasonValue = _readValue(content, 'season');
    final intentionValue = _readValue(content, 'intention') ?? '';
    final setAtValue = _readValue(content, 'set_at');

    final season = seasonValue != null
        ? FocusSeason.fromStorage(seasonValue) ?? FocusSeason.builder
        : FocusSeason.builder;
    final setAt = setAtValue != null ? DateTime.tryParse(setAtValue) : null;

    return FocusState(
      season: season,
      intention: intentionValue,
      setAt: setAt,
    );
  }

  Future<void> setCurrent(FocusState state) async {
    final file = File(_path);
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    String? history;
    if (await file.exists()) {
      final existing = await file.readAsString();
      final match = RegExp(r'\n## History[\s\S]*$', multiLine: true)
          .firstMatch(existing);
      history = match?.group(0)?.trimRight();
    }

    final setAt = state.setAt ?? DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('type: intention');
    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('## Current');
    buffer.writeln('season:: ${state.season.storageValue}');
    buffer.writeln('intention:: ${state.intention}');
    buffer.writeln('set_at:: ${setAt.toIso8601String()}');

    if (history != null && history.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(history);
    }

    await file.writeAsString('${buffer.toString().trimRight()}\n');
  }

  String? _readValue(String content, String key) {
    final match = RegExp(
      '^${RegExp.escape(key)}::\\s*(.*)\$',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) return null;
    return match.group(1)?.trim();
  }
}
