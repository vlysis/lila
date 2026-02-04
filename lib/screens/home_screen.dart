import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../models/focus_state.dart';
import '../services/file_service.dart';
import '../services/focus_controller.dart';
import '../theme/lila_theme.dart';
import '../widgets/armed_swipe_to_delete.dart';
import '../widgets/log_bottom_sheet.dart';
import 'daily_detail_screen.dart';
import 'daily_reflection_screen.dart';
import 'intention_flow_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import 'weekly_review_screen.dart';

class HomeScreen extends StatefulWidget {
  final FocusController focusController;

  const HomeScreen({super.key, required this.focusController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LogEntry> _todayEntries = [];
  String _dailyReflection = '';
  FocusState _focusState = FocusState.defaultState();
  bool _focusLoading = true;

  static const _modeAssets = {
    Mode.nourishment: 'assets/icons/nourishment.png',
    Mode.growth: 'assets/icons/growth.png',
    Mode.maintenance: 'assets/icons/maintenence.png',
    Mode.drift: 'assets/icons/drift.png',
  };

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _focusState = widget.focusController.state;
    _focusLoading = widget.focusController.isLoading;
    widget.focusController.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusController.removeListener(_handleFocusChange);
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final fs = await FileService.getInstance();
    final now = DateTime.now();
    final entries = await fs.readDailyEntries(now);
    final reflection = await fs.readDailyReflection(now);
    if (mounted) {
      setState(() {
        _todayEntries = entries;
        _dailyReflection = reflection;
      });
    }
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {
      _focusState = widget.focusController.state;
      _focusLoading = widget.focusController.isLoading;
    });
  }

  void _openLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogBottomSheet(onLogged: _loadEntries),
    );
  }

  Future<void> _openFocusFlow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IntentionFlowScreen(
          initialState: _focusState,
          focusController: widget.focusController,
        ),
      ),
    );
    if (result is FocusState && mounted) {
      widget.focusController.update(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(today);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = context.lilaRadii;
    final onSurface = colorScheme.onSurface;
    final subdued = onSurface.withValues(alpha: 0.35);
    final iconForeground = onSurface.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        leadingWidth: 84,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              ).then((_) => _loadEntries());
            },
            child: Container(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    child: Icon(
                      Icons.delete_outline,
                      color: iconForeground,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Trash',
                    style: TextStyle(
                      color: subdued,
                      fontSize: 10,
                      letterSpacing: 0.2,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyReflectionScreen(date: DateTime.now()),
                  ),
                ).then((_) => _loadEntries());
              },
              child: Container(
                width: 54,
                height: 54,
                child: Icon(
                  Icons.edit_note_outlined,
                  color: iconForeground,
                  size: 30,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                final now = DateTime.now();
                final monday = now.subtract(Duration(days: now.weekday - 1));
                final weekStart =
                    DateTime(monday.year, monday.month, monday.day);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WeeklyReviewScreen(weekStart: weekStart),
                  ),
                ).then((_) => _loadEntries());
              },
              child: Container(
                width: 54,
                height: 54,
                child: Icon(
                  Icons.calendar_view_week_outlined,
                  color: iconForeground,
                  size: 30,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => _loadEntries()),
              child: Container(
                width: 54,
                height: 54,
                child: Icon(
                  Icons.settings_outlined,
                  color: iconForeground,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'Today',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.9),
                fontSize: 32,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: TextStyle(
                color: subdued,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            _buildFocusCard(),
            const SizedBox(height: 28),
            if (_todayEntries.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyDetailScreen(date: today),
                  ),
                ),
                child: _buildTodaySummary(),
              ),
            if (_todayEntries.isNotEmpty && DateTime.now().hour >= 18) ...[
              const SizedBox(height: 20),
              _buildEveningWhisper(),
            ],
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 96,
        height: 96,
        child: FloatingActionButton(
          onPressed: _openLogSheet,
          backgroundColor: theme.floatingActionButtonTheme.backgroundColor ??
              colorScheme.surfaceVariant,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.large),
          ),
          child: Icon(
            Icons.add,
            color: onSurface.withValues(alpha: 0.8),
            size: 42,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEveningWhisper() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hasReflection = _dailyReflection.trim().isNotEmpty;
    final text = hasReflection ? 'Reflection written.' : 'How did today feel?';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DailyReflectionScreen(date: DateTime.now()),
          ),
        ).then((_) => _loadEntries());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.5),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildFocusCard() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final season = _focusState.season;
    final theme = _focusTheme(season);
    final intention = _focusState.intention.trim();
    final subtitle =
        intention.isNotEmpty ? '\u201c$intention\u201d' : season.prompt;

    return GestureDetector(
      onTap: _openFocusFlow,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radius),
          border: Border.all(color: theme.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                season == FocusSeason.builder
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_outlined,
                color: theme.accent.withValues(alpha: 0.9),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Season: ${season.label}',
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _focusLoading ? 'Setting your focus...' : subtitle,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontStyle:
                          intention.isNotEmpty ? FontStyle.italic : null,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _FocusTheme _focusTheme(FocusSeason season) {
    switch (season) {
      case FocusSeason.builder:
        return const _FocusTheme(
          surface: Color(0xFF151C1E),
          border: Color(0xFF2A474D),
          accent: Color(0xFFD6B25E),
          radius: 12,
        );
      case FocusSeason.sanctuary:
        return const _FocusTheme(
          surface: Color(0xFF2B2723),
          border: Color(0xFF6D8570),
          accent: Color(0xFFB07A63),
          radius: 20,
        );
    }
  }

  Widget _buildTodaySummary() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_todayEntries.length} moment${_todayEntries.length == 1 ? '' : 's'}',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.3),
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._todayEntries.reversed.take(5).map(_buildSummaryEntry),
        if (_todayEntries.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tap to see all',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.25),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryEntry(LogEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final radii = context.lilaRadii;
    final onSurface = colorScheme.onSurface;
    final palette = context.lilaPalette;
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    final modeColor = palette.modeColor(entry.mode);
    final modeAsset = _modeAssets[entry.mode]!;
    final orientationColor = palette.orientationColor(entry.orientation);

    return ArmedSwipeToDelete(
      dismissKey: ValueKey(
          '${entry.timestamp.toIso8601String()}-${entry.label ?? ''}-${entry.mode.name}-${entry.orientation.name}'),
      onDelete: () async {
        final fs = await FileService.getInstance();
        final removed = await fs.moveEntryToTrash(entry);
        if (removed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Moved to trash'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _loadEntries();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(radii.medium),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(radii.medium),
                ),
                child: Center(
                  child: Image.asset(
                    modeAsset,
                    width: 18,
                    height: 18,
                    color: modeColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label ?? entry.mode.label,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(width: 8),
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
}

class _FocusTheme {
  final Color surface;
  final Color border;
  final Color accent;
  final double radius;

  const _FocusTheme({
    required this.surface,
    required this.border,
    required this.accent,
    required this.radius,
  });
}
