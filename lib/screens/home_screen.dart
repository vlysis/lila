import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../widgets/armed_swipe_to_delete.dart';
import '../widgets/log_bottom_sheet.dart';
import 'daily_detail_screen.dart';
import 'daily_reflection_screen.dart';
import 'settings_screen.dart';
import 'weekly_review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LogEntry> _todayEntries = [];
  String _dailyReflection = '';

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
    _loadEntries();
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

  void _openLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogBottomSheet(onLogged: _loadEntries),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(today);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Icon(
                  Icons.edit_note_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
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
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Icon(
                  Icons.calendar_view_week_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
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
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _todayEntries.isNotEmpty
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyDetailScreen(date: today),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'Today',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              if (_todayEntries.isNotEmpty) ...[
                _buildTodaySummary(),
              ],
              if (_todayEntries.isNotEmpty &&
                  DateTime.now().hour >= 18) ...[
                const SizedBox(height: 20),
                _buildEveningWhisper(),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 96,
        height: 96,
        child: FloatingActionButton(
          onPressed: _openLogSheet,
          backgroundColor: const Color(0xFF2A2A2A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            Icons.add,
            color: Colors.white.withValues(alpha: 0.8),
            size: 42,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEveningWhisper() {
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
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_todayEntries.length} moment${_todayEntries.length == 1 ? '' : 's'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryEntry(LogEntry entry) {
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    final modeColor = _modeColors[entry.mode] ?? Colors.grey;
    final modeAsset = _modeAssets[entry.mode]!;
    final orientationColor =
        _orientationColors[entry.orientation] ?? Colors.grey;

    return ArmedSwipeToDelete(
      dismissKey: ValueKey(
          '${entry.timestamp.toIso8601String()}-${entry.label ?? ''}-${entry.mode.name}-${entry.orientation.name}'),
      onDelete: () async {
        final fs = await FileService.getInstance();
        final removed = await fs.deleteEntry(entry);
        if (removed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Moment deleted'),
              backgroundColor: const Color(0xFF2A2A2A),
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
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
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
                        color: Colors.white.withValues(alpha: 0.8),
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
                  color: Colors.white.withValues(alpha: 0.25),
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
