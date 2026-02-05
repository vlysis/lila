import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../theme/lila_theme.dart';

class DailyDetailScreen extends StatefulWidget {
  final DateTime date;

  const DailyDetailScreen({super.key, required this.date});

  @override
  State<DailyDetailScreen> createState() => _DailyDetailScreenState();
}

class _DailyDetailScreenState extends State<DailyDetailScreen> {
  List<LogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fs = await FileService.getInstance();
    final entries = await fs.readDailyEntries(widget.date);
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(widget.date);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface.withValues(alpha: 0.7)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          dateStr,
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.7),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: _entries.isEmpty
          ? Center(
              child: Text(
                'No entries yet.',
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.3),
                  fontSize: 15,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _buildEntryCard(entry);
              },
            ),
    );
  }

  Widget _buildEntryCard(LogEntry entry) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final palette = context.lilaPalette;
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    final modeColor = palette.modeColor(entry.mode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 50,
              child: Text(
                time,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.25),
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          const SizedBox(width: 12),
          // Entry content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label ?? entry.mode.label,
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildBadge(entry.mode.label, modeColor),
                    const SizedBox(width: 8),
                    _buildBadge(
                      entry.orientation.label,
                      context.lilaSurface.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
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
