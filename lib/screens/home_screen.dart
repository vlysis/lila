import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../models/focus_state.dart';
import '../services/file_service.dart';
import '../services/focus_controller.dart';
import '../logic/daily_prompt.dart';
import '../theme/lila_theme.dart';
import '../widgets/armed_swipe_to_delete.dart';
import '../widgets/log_bottom_sheet.dart';
import 'daily_detail_screen.dart';
import 'intention_flow_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import 'visualization_screen.dart';
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
  bool _reflectionLoaded = false;
  bool _isLoggingReflection = false;

  late DateTime _selectedDate;
  List<DateTime> _availableDates = [];
  int _slideDirection = 0;

  static const _modeAssets = {
    Mode.nourishment: 'assets/icons/nourishment.png',
    Mode.growth: 'assets/icons/growth.png',
    Mode.maintenance: 'assets/icons/maintenence.png',
    Mode.drift: 'assets/icons/drift.png',
  };

  final ScrollController _scrollController = ScrollController();
  static const _reflectionSectionKey = ValueKey('reflection_section');
  final TextEditingController _reflectionController = TextEditingController();
  final FocusNode _reflectionFocusNode = FocusNode();
  Timer? _reflectionSaveTimer;

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday {
    final t = _today();
    return _selectedDate.year == t.year &&
        _selectedDate.month == t.month &&
        _selectedDate.day == t.day;
  }

  List<DateTime> _navigableDates() {
    final t = _today();
    final dates = <DateTime>{..._availableDates, t};
    final sorted = dates.toList()..sort();
    return sorted;
  }

  int _currentDateIndex() {
    final dates = _navigableDates();
    for (var i = 0; i < dates.length; i++) {
      if (dates[i].year == _selectedDate.year &&
          dates[i].month == _selectedDate.month &&
          dates[i].day == _selectedDate.day) {
        return i;
      }
    }
    return dates.length - 1;
  }

  bool get _hasPreviousDay => _currentDateIndex() > 0;
  bool get _hasNextDay => _currentDateIndex() < _navigableDates().length - 1;

  @override
  void initState() {
    super.initState();
    _selectedDate = _today();
    _loadEntries();
    _focusState = widget.focusController.state;
    _focusLoading = widget.focusController.isLoading;
    widget.focusController.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusController.removeListener(_handleFocusChange);
    _reflectionSaveTimer?.cancel();
    _saveReflectionNow();
    _reflectionController.dispose();
    _reflectionFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final fs = await FileService.getInstance();
    final date = _selectedDate;
    final entries = await fs.readDailyEntries(date);
    final reflection = await fs.readDailyReflection(date);
    final dates = await fs.getAvailableDates();
    if (mounted) {
      final previousReflection = _dailyReflection;
      setState(() {
        _todayEntries = entries;
        _dailyReflection = reflection;
        _availableDates = dates;
        if (!_reflectionLoaded ||
            _reflectionController.text == previousReflection) {
          _reflectionController.text = reflection;
          _reflectionLoaded = true;
        }
      });
    }
  }

  @visibleForTesting
  Future<void> loadEntriesForTest() => _loadEntries();

  @visibleForTesting
  Future<void> goToPreviousDayForTest() => _goToPreviousDay();

  @visibleForTesting
  Future<void> goToNextDayForTest() => _goToNextDay();

  @visibleForTesting
  Future<void> goToTodayForTest() => _goToToday();

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
      builder: (_) => LogBottomSheet(
        onLogged: _loadEntries,
        date: _isToday ? null : _selectedDate,
      ),
    );
  }

  void _scrollToReflection() {
    final targetContext = _reflectionFocusNode.context;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
  }

  void _onReflectionChanged(String text) {
    setState(() {
      _dailyReflection = text;
    });
    _reflectionSaveTimer?.cancel();
    _reflectionSaveTimer =
        Timer(const Duration(seconds: 1), _saveReflectionNow);
  }

  Future<void> _saveReflectionNow() async {
    final text = _reflectionController.text;
    final fs = await FileService.getInstance();
    await fs.saveDailyReflection(_selectedDate, text);
  }

  Future<void> _logReflection() async {
    if (_isLoggingReflection) return;
    if (_reflectionController.text.trim().isEmpty) return;

    setState(() {
      _isLoggingReflection = true;
      _dailyReflection = _reflectionController.text;
    });
    await _saveReflectionNow();

    final now = DateTime.now();
    final ts = _isToday
        ? now
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
            now.hour, now.minute, now.second);

    final entry = LogEntry(
      label: 'Daily reflection',
      mode: Mode.nourishment,
      orientation: LogOrientation.self_,
      timestamp: ts,
    );

    final fs = await FileService.getInstance();
    await fs.appendEntry(entry);

    if (mounted) {
      await _loadEntries();
      setState(() => _isLoggingReflection = false);
    }
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

  Future<void> _goToPreviousDay() async {
    if (!_hasPreviousDay) return;
    _reflectionSaveTimer?.cancel();
    await _saveReflectionNow();
    final dates = _navigableDates();
    final idx = _currentDateIndex();
    setState(() {
      _reflectionLoaded = false;
      _slideDirection = 1;
      _selectedDate = dates[idx - 1];
    });
    await _loadEntries();
  }

  Future<void> _goToNextDay() async {
    if (!_hasNextDay) return;
    _reflectionSaveTimer?.cancel();
    await _saveReflectionNow();
    final dates = _navigableDates();
    final idx = _currentDateIndex();
    setState(() {
      _reflectionLoaded = false;
      _slideDirection = -1;
      _selectedDate = dates[idx + 1];
    });
    await _loadEntries();
  }

  Future<void> _goToToday() async {
    if (_isToday) return;
    _reflectionSaveTimer?.cancel();
    await _saveReflectionNow();
    setState(() {
      _reflectionLoaded = false;
      _slideDirection = -1;
      _selectedDate = _today();
    });
    await _loadEntries();
  }

  String _titleForDate() {
    if (_isToday) return 'Today';
    final t = _today();
    final yesterday = DateTime(t.year, t.month, t.day - 1);
    if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('EEEE').format(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(_selectedDate);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                    builder: (_) => const VisualizationScreen(),
                  ),
                ).then((_) => _loadEntries());
              },
              child: Container(
                width: 54,
                height: 54,
                child: Icon(
                  Icons.local_florist_outlined,
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
                final ref = _selectedDate;
                final monday = ref.subtract(Duration(days: ref.weekday - 1));
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
                MaterialPageRoute(builder: (_) => SettingsScreen(focusController: widget.focusController)),
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
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300 && _hasPreviousDay) {
            _goToPreviousDay();
          } else if (velocity < -300 && _hasNextDay) {
            _goToNextDay();
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: Offset(
                  _slideDirection == 0 ? 0 : -_slideDirection.toDouble(), 0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(position: offset, child: child);
          },
          child: SingleChildScrollView(
            key: ValueKey(_selectedDate),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_hasPreviousDay)
                      Icon(Icons.chevron_left, size: 20,
                          color: onSurface.withValues(alpha: 0.2)),
                    Expanded(
                      child: Text(
                        _titleForDate(),
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.9),
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    if (_hasNextDay)
                      Icon(Icons.chevron_right, size: 20,
                          color: onSurface.withValues(alpha: 0.2)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: subdued,
                    fontSize: 15,
                  ),
                ),
                if (!_isToday) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _goToToday,
                    child: Text(
                      'Return to today',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_isToday) ...[
                  _buildFocusCard(),
                  const SizedBox(height: 16),
                ],
                _buildModeRibbon(),
                const SizedBox(height: 24),
                _buildLogMomentButton(),
                const SizedBox(height: 16),
                if (_todayEntries.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DailyDetailScreen(date: _selectedDate),
                      ),
                    ),
                    child: _buildTodaySummary(),
                  ),
                  const SizedBox(height: 24),
                ],
                _buildReflectionSection(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogMomentButton() {
    final radii = context.lilaRadii;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final theme = _focusTheme(_focusState.season);
    final surfaceColor = colorScheme.surfaceVariant.withValues(alpha: 0.4);
    final borderColor = theme.accent.withValues(alpha: 0.35);
    final radius =
        _focusState.season == FocusSeason.builder ? 8.0 : radii.medium;

    return Semantics(
      button: true,
      label: 'Log Moment',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('log_moment_button'),
          borderRadius: BorderRadius.circular(radius),
          onTap: _openLogSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: context.lilaSurface.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(radius - 2),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: theme.accent.withValues(alpha: 0.9),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Log Moment',
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyPrompt() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final text = _isToday
        ? dailyPromptText(hour: DateTime.now().hour)
        : 'How did this day feel?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: onSurface.withValues(alpha: 0.5),
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildReflectionSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final radii = context.lilaRadii;
    final theme = _focusTheme(_focusState.season);
    final enabled = _reflectionController.text.trim().isNotEmpty &&
        !_isLoggingReflection;

    return Container(
      key: _reflectionSectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDailyPrompt(),
          TextField(
            key: const ValueKey('daily_reflection_input'),
            controller: _reflectionController,
            onChanged: _onReflectionChanged,
            onTap: _scrollToReflection,
            focusNode: _reflectionFocusNode,
            maxLines: null,
            minLines: 4,
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
              fillColor: colorScheme.surfaceVariant.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radii.medium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('log_reflection_button'),
              onPressed: enabled ? _logReflection : null,
              style: TextButton.styleFrom(
                backgroundColor: enabled
                    ? colorScheme.surfaceVariant
                    : colorScheme.surfaceVariant.withValues(alpha: 0.4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    _focusState.season == FocusSeason.builder
                        ? 8.0
                        : radii.medium,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_outlined,
                    size: 18,
                    color: theme.accent.withValues(alpha: enabled ? 0.9 : 0.4),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLoggingReflection ? 'Logging...' : 'Log Reflection',
                    style: TextStyle(
                      color: onSurface.withValues(alpha: enabled ? 0.8 : 0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                borderRadius: BorderRadius.circular(theme.radius + 4),
              ),
              child: Icon(
                switch (season) {
                  FocusSeason.builder => Icons.wb_sunny_outlined,
                  FocusSeason.sanctuary => Icons.nightlight_outlined,
                  FocusSeason.explorer => Icons.explore_outlined,
                  FocusSeason.anchor => Icons.anchor_outlined,
                },
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
                    'Current Season: ${season.currentLabel}',
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

  Widget _buildModeRibbon() {
    if (_todayEntries.isEmpty) return const SizedBox.shrink();
    final palette = context.lilaPalette;
    final radii = context.lilaRadii;
    final segments = _buildRibbonSegments(_todayEntries);
    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('mode_ribbon'),
      height: 12,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceVariant
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(radii.small),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              flex: segments[i].count,
              child: Container(
                decoration: BoxDecoration(
                  color: palette
                      .modeColor(segments[i].mode)
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.only(
                    topLeft: i == 0
                        ? Radius.circular(radii.small)
                        : Radius.zero,
                    bottomLeft: i == 0
                        ? Radius.circular(radii.small)
                        : Radius.zero,
                    topRight: i == segments.length - 1
                        ? Radius.circular(radii.small)
                        : Radius.zero,
                    bottomRight: i == segments.length - 1
                        ? Radius.circular(radii.small)
                        : Radius.zero,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_RibbonSegment> _buildRibbonSegments(List<LogEntry> entries) {
    final sorted = [...entries]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (sorted.isEmpty) return [];

    final segments = <_RibbonSegment>[];
    var currentMode = sorted.first.mode;
    var count = 0;

    for (final entry in sorted) {
      if (entry.mode == currentMode) {
        count += 1;
      } else {
        segments.add(_RibbonSegment(currentMode, count));
        currentMode = entry.mode;
        count = 1;
      }
    }
    segments.add(_RibbonSegment(currentMode, count));
    return segments;
  }

  _FocusTheme _focusTheme(FocusSeason season) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    switch (season) {
      case FocusSeason.builder:
        return isLight
            ? const _FocusTheme(
                surface: Color(0xFFECEAE6),
                border: Color(0xFFB0CED4),
                accent: Color(0xFFB8962E),
                radius: 12,
              )
            : const _FocusTheme(
                surface: Color(0xFF151C1E),
                border: Color(0xFF2A474D),
                accent: Color(0xFFD6B25E),
                radius: 12,
              );
      case FocusSeason.sanctuary:
        return isLight
            ? const _FocusTheme(
                surface: Color(0xFFF0EBE5),
                border: Color(0xFFA3C2A8),
                accent: Color(0xFF925D46),
                radius: 20,
              )
            : const _FocusTheme(
                surface: Color(0xFF2B2723),
                border: Color(0xFF6D8570),
                accent: Color(0xFFB07A63),
                radius: 20,
              );
      case FocusSeason.explorer:
        return isLight
            ? const _FocusTheme(
                surface: Color(0xFFF2EDE8),
                border: Color(0xFFD4A890),
                accent: Color(0xFFC27840),
                radius: 18,
              )
            : const _FocusTheme(
                surface: Color(0xFF1E1A1A),
                border: Color(0xFF3D2F3A),
                accent: Color(0xFFE38B4F),
                radius: 18,
              );
      case FocusSeason.anchor:
        return isLight
            ? const _FocusTheme(
                surface: Color(0xFFE6EAF0),
                border: Color(0xFFAAB8C8),
                accent: Color(0xFF7A8DA0),
                radius: 10,
              )
            : const _FocusTheme(
                surface: Color(0xFF1A202C),
                border: Color(0xFF4A5568),
                accent: Color(0xFFA0AEC0),
                radius: 10,
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
        ..._todayEntries.reversed.map(_buildSummaryEntry),
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
    final isReflection = entry.label == 'Daily reflection';

    if (isReflection) {
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
        child: _buildSummaryReflectionCard(
          time,
          colorScheme: colorScheme,
          onSurface: onSurface,
          radii: radii,
        ),
      );
    }

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

  Widget _buildSummaryReflectionCard(
    String time, {
    required ColorScheme colorScheme,
    required Color onSurface,
    required LilaRadii radii,
  }) {
    final reflectionText = _dailyReflection.trim();
    final preview = reflectionText.isNotEmpty
        ? (reflectionText.length > 80
            ? '${reflectionText.substring(0, 80)}...'
            : reflectionText)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        fontSize: 13,
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
    );
  }

  Widget _buildPill(String text, Color color) {
    final radii = context.lilaRadii;
    final radius =
        _focusState.season == FocusSeason.builder ? 6.0 : radii.small;
    final textStyle = Theme.of(context).textTheme.labelSmall ??
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
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

class _RibbonSegment {
  final Mode mode;
  final int count;

  const _RibbonSegment(this.mode, this.count);
}
