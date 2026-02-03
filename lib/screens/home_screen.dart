import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../widgets/log_bottom_sheet.dart';
import '../widgets/whisper.dart';
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.edit_note_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.calendar_view_week_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
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
              WhisperWidget(todayEntries: _todayEntries),
              if (_todayEntries.isNotEmpty) ...[
                const SizedBox(height: 24),
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
        ..._todayEntries.reversed.take(5).map((entry) {
          final time =
              '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  entry.label ?? entry.mode.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }),
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
}
