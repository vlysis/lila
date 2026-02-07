import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../services/ai_integration_service.dart';
import '../widgets/armed_swipe_to_delete.dart';
import '../widgets/day_discussion_sheet.dart';
import '../theme/lila_theme.dart';

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
  bool _aiEnabled = false;

  final _reflectionController = TextEditingController();
  Timer? _saveTimer;

  static const _modeAssets = {
    Mode.nourishment: 'assets/icons/nourishment.png',
    Mode.growth: 'assets/icons/growth.png',
    Mode.maintenance: 'assets/icons/maintenence.png',
    Mode.drift: 'assets/icons/drift.png',
    Mode.decay: 'assets/icons/decay.png',
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
    final integrationService = await AiIntegrationService.getInstance();

    if (mounted) {
      setState(() {
        _entries = entries;
        _savedReflectionText = reflection;
        _aiEnabled = integrationService.isEnabled;
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

  Future<void> _deleteEntry(LogEntry entry) async {
    final fs = await FileService.getInstance();
    final removed = await fs.moveEntryToTrash(entry);
    if (removed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Moved to trash'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    }
  }

  void _openDiscussion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDiscussionSheet(
        date: widget.date,
        entries: _entries,
        reflectionText: _reflectionController.text,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(widget.date);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = context.lilaRadii;
    final onSurface = colorScheme.onSurface;

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
                      dateStr,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.9),
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _buildSummaryText(),
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.35),
                        fontSize: 14,
                      ),
                    ),
                    if (_entries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionCard(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TODAY\u2019S MOMENTS',
                              style: TextStyle(
                                color: onSurface.withValues(alpha: 0.25),
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._entries.map(_buildEntryCard),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    _sectionCard(
                      Column(
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
                            minLines: 6,
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.8),
                              fontSize: 15,
                              height: 1.6,
                            ),
                            decoration: InputDecoration(
                              hintText: 'How did today feel?',
                              hintStyle: TextStyle(
                                color: onSurface.withValues(alpha: 0.3),
                                fontStyle: FontStyle.italic,
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceVariant
                                  .withValues(alpha: 0.6),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(radii.medium),
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
                                backgroundColor:
                                    colorScheme.surfaceVariant,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(radii.medium),
                                ),
                              ),
                              child: Text(
                                'Log',
                                style: TextStyle(
                                  color: onSurface.withValues(alpha: 0.8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          if (_aiEnabled) ...[
                            const SizedBox(height: 24),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: _openDiscussion,
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                  color: onSurface.withValues(alpha: 0.6),
                                ),
                                label: Text(
                                  'Discuss your day',
                                  style: TextStyle(
                                    color: onSurface.withValues(alpha: 0.6),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  side: BorderSide(
                                    color:
                                        onSurface.withValues(alpha: 0.15),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        radii.medium),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEntryCard(LogEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = context.lilaRadii;
    final onSurface = colorScheme.onSurface;
    final palette = context.lilaPalette;
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    final isReflection = entry.label == 'Daily reflection';

    if (isReflection) {
      return ArmedSwipeToDelete(
        dismissKey: ValueKey(
            '${entry.timestamp.toIso8601String()}-${entry.label ?? ''}-${entry.mode.name}-${entry.orientation.name}'),
        onDelete: () => _deleteEntry(entry),
        child: _buildReflectionCard(time),
      );
    }

    final modeColor = palette.modeColor(entry.mode);
    final modeAsset = _modeAssets[entry.mode]!;
    final orientationColor = palette.orientationColor(entry.orientation);

    return ArmedSwipeToDelete(
      dismissKey: ValueKey(
          '${entry.timestamp.toIso8601String()}-${entry.label ?? ''}-${entry.mode.name}-${entry.orientation.name}'),
      onDelete: () => _deleteEntry(entry),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(radii.medium),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(radii.medium),
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
                        color: onSurface.withValues(alpha: 0.8),
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
                  color: onSurface.withValues(alpha: 0.25),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReflectionCard(String time) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = context.lilaRadii;
    final onSurface = colorScheme.onSurface;
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
          color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(radii.medium),
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
                        color: onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _buildPill(
                    'Daily reflection',
                    onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              time,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.25),
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
    final radii = context.lilaRadii;
    final textStyle = Theme.of(context).textTheme.labelSmall ??
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radii.small),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: textStyle.fontSize,
          fontWeight: textStyle.fontWeight,
          letterSpacing: textStyle.letterSpacing,
        ),
      ),
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
