import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';

class DailyReflectionScreen extends StatefulWidget {
  final DateTime date;

  const DailyReflectionScreen({super.key, required this.date});

  @override
  State<DailyReflectionScreen> createState() => _DailyReflectionScreenState();
}

class _DailyReflectionScreenState extends State<DailyReflectionScreen> {
  List<LogEntry> _entries = [];
  String _savedReflectionText = '';
  bool _loading = true;

  final _reflectionController = TextEditingController();
  Timer? _saveTimer;

  static const _modeColors = {
    Mode.nourishment: Color(0xFF6B8F71),
    Mode.growth: Color(0xFF7B9EA8),
    Mode.maintenance: Color(0xFFA8976B),
    Mode.drift: Color(0xFF8B7B8B),
  };

  static const _modeAssets = {
    Mode.nourishment: 'assets/icons/nourishment.png',
    Mode.growth: 'assets/icons/growth.png',
    Mode.maintenance: 'assets/icons/maintenence.png',
    Mode.drift: 'assets/icons/drift.png',
  };

  static const _orientationColors = {
    LogOrientation.self_: Color(0xFF9B8EC4),
    LogOrientation.mutual: Color(0xFF6BA8A0),
    LogOrientation.other: Color(0xFFA87B6B),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveReflectionNow();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final fs = await FileService.getInstance();
    final entries = await fs.readDailyEntries(widget.date);
    final reflection = await fs.readDailyReflection(widget.date);

    if (mounted) {
      setState(() {
        _entries = entries;
        _savedReflectionText = reflection;
        if (_loading) {
          _reflectionController.text = reflection;
        }
        _loading = false;
      });
    }
  }

  void _onReflectionChanged(String text) {
    _savedReflectionText = text;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _saveReflectionNow);
  }

  Future<void> _saveReflectionNow() async {
    final text = _reflectionController.text;
    final fs = await FileService.getInstance();
    await fs.saveDailyReflection(widget.date, text);
  }

  Future<void> _logReflection() async {
    setState(() {
      _savedReflectionText = _reflectionController.text;
    });
    await _saveReflectionNow();

    final entry = LogEntry(
      label: 'Daily reflection',
      mode: Mode.nourishment,
      orientation: LogOrientation.self_,
      timestamp: DateTime.now(),
    );

    final fs = await FileService.getInstance();
    await fs.appendEntry(entry);

    if (mounted) {
      await _load();
    }
  }

  String _buildSummaryText() {
    if (_entries.isEmpty) return 'No moments logged.';

    final modeCounts = <Mode, int>{};
    for (final e in _entries) {
      modeCounts[e.mode] = (modeCounts[e.mode] ?? 0) + 1;
    }

    final modeNames =
        modeCounts.keys.map((m) => m.label.toLowerCase()).join(', ');
    final count = _entries.length;
    return '$count moment${count == 1 ? '' : 's'} \u2014 $modeNames';
  }

  String? _generateWhisper() {
    if (_entries.isEmpty) return null;

    final modeCounts = <Mode, int>{};
    final orientationCounts = <LogOrientation, int>{};
    for (final e in _entries) {
      modeCounts[e.mode] = (modeCounts[e.mode] ?? 0) + 1;
      orientationCounts[e.orientation] =
          (orientationCounts[e.orientation] ?? 0) + 1;
    }

    if (modeCounts[Mode.nourishment] == 1 && _entries.length > 1) {
      return 'First Nourishment logged today.';
    }

    final otherCount = orientationCounts[LogOrientation.other] ?? 0;
    if (otherCount > _entries.length / 2 && _entries.length >= 3) {
      return 'Mostly Other-directed so far.';
    }

    final selfCount = orientationCounts[LogOrientation.self_] ?? 0;
    if (selfCount > _entries.length / 2 && _entries.length >= 3) {
      return 'Mostly Self-directed today.';
    }

    if (modeCounts[Mode.drift] != null && modeCounts[Mode.drift]! >= 1) {
      final lastEntry = _entries.last;
      if (lastEntry.mode == Mode.drift) {
        return 'Drift noticed.';
      }
    }

    if (_entries.length == 1) {
      return 'Day started.';
    }

    return '${_entries.length} moments logged today.';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(widget.date);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Colors.white.withValues(alpha: 0.7)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7B9EA8),
                strokeWidth: 2,
              ),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _buildSummaryText(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 14,
                      ),
                    ),
                    if (_generateWhisper() != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _generateWhisper()!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (_entries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'TODAY\u2019S MOMENTS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._entries.map(_buildEntryCard),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      'REFLECTION',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reflectionController,
                      onChanged: _onReflectionChanged,
                      maxLines: null,
                      minLines: 6,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: 'How did today feel?',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontStyle: FontStyle.italic,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: _logReflection,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A2A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Log',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEntryCard(LogEntry entry) {
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    final isReflection = entry.label == 'Daily reflection';

    if (isReflection) {
      return _buildReflectionCard(time);
    }

    final modeColor = _modeColors[entry.mode] ?? Colors.grey;
    final modeAsset = _modeAssets[entry.mode]!;
    final orientationColor =
        _orientationColors[entry.orientation] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Image.asset(
                  modeAsset,
                  width: 20,
                  height: 20,
                  color: modeColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label ?? entry.mode.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _buildPill(entry.mode.label, modeColor),
                      const SizedBox(width: 6),
                      _buildPill(entry.orientation.label, orientationColor),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReflectionCard(String time) {
    final reflectionText = _savedReflectionText.trim();
    final preview = reflectionText.isNotEmpty
        ? (reflectionText.length > 80
            ? '${reflectionText.substring(0, 80)}...'
            : reflectionText)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.isNotEmpty) ...[
                    Text(
                      preview,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _buildPill('Daily reflection',
                      Colors.white.withValues(alpha: 0.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
