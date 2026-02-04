import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../services/weekly_summary_service.dart';
import '../widgets/week_texture_widget.dart';
import '../widgets/orientation_threads_widget.dart';
import '../widgets/daily_rhythm_widget.dart';
import '../widgets/weekly_whisper.dart';
import '../widgets/weekly_insights_widget.dart';
import '../theme/lila_theme.dart';

class WeeklyReviewScreen extends StatefulWidget {
  final DateTime weekStart;

  const WeeklyReviewScreen({super.key, required this.weekStart});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  Map<int, List<LogEntry>> _entriesByDay = {};
  List<LogEntry> _allEntries = [];
  bool _loading = true;

  final _reflectionController = TextEditingController();
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Final save on dispose
    _saveReflectionNow();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final fs = await FileService.getInstance();
    final byDay = await fs.readWeekEntries(widget.weekStart);

    final all = <LogEntry>[];
    for (final entries in byDay.values) {
      all.addAll(entries);
    }

    // Auto-save weekly summary markdown
    final summary =
        WeeklySummaryService.generate(widget.weekStart, byDay, all);
    await fs.writeWeeklySummary(widget.weekStart, summary);

    // Load existing reflection
    final reflection = await fs.readWeeklyReflection(widget.weekStart);

    if (mounted) {
      setState(() {
        _entriesByDay = byDay;
        _allEntries = all;
        _reflectionController.text = reflection;
        _loading = false;
      });
    }
  }

  void _onReflectionChanged(String text) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _saveReflectionNow);
  }

  Future<void> _saveReflectionNow() async {
    final text = _reflectionController.text;
    final fs = await FileService.getInstance();
    await fs.saveWeeklyReflection(widget.weekStart, text);
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = widget.weekStart.add(const Duration(days: 6));
    final fromStr = DateFormat('MMM d').format(widget.weekStart);
    final toStr = DateFormat('MMM d').format(weekEnd);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final whisperText =
        WeeklyWhisperWidget.generateWhisper(_allEntries, _entriesByDay);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: onSurface.withValues(alpha: 0.7)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
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
                      'This Week',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.9),
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$fromStr – $toStr',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (whisperText != null) ...[
                      _sectionCard(
                        WeeklyWhisperWidget(
                          weekEntries: _allEntries,
                          entriesByDay: _entriesByDay,
                          whisperOverride: whisperText,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    _sectionCard(
                      WeekTextureWidget(entriesByDay: _entriesByDay),
                    ),
                    const SizedBox(height: 36),
                    if (_allEntries.isNotEmpty) ...[
                      _sectionCard(
                        OrientationThreadsWidget(weekEntries: _allEntries),
                      ),
                      const SizedBox(height: 36),
                      _sectionCard(
                        DailyRhythmWidget(entriesByDay: _entriesByDay),
                      ),
                    ] else ...[
                      _sectionCard(
                        DailyRhythmWidget(entriesByDay: _entriesByDay),
                      ),
                    ],
                    if (_allEntries.isNotEmpty) ...[
                      const SizedBox(height: 36),
                      _sectionCard(
                        WeeklyInsightsWidget(
                          weekEntries: _allEntries,
                          entriesByDay: _entriesByDay,
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    _sectionCard(_buildReflectionSection()),
                    if (_allEntries.isEmpty) ...[
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          'No moments logged this week.',
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.3),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReflectionSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final radii = context.lilaRadii;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REFLECTION',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.25),
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
          minLines: 4,
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.8),
            fontSize: 15,
            height: 1.6,
          ),
          decoration: InputDecoration(
            hintText: 'How did this week feel?',
            hintStyle: TextStyle(
              color: onSurface.withValues(alpha: 0.3),
              fontStyle: FontStyle.italic,
            ),
            filled: true,
            fillColor:
                colorScheme.surfaceVariant.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radii.medium),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final theme = Theme.of(context);
    final radii = context.lilaRadii;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radii.medium),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}
