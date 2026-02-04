import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../models/trashed_entry.dart';
import '../services/file_service.dart';
import '../widgets/armed_swipe_actions.dart';
import '../theme/lila_theme.dart';

class TrashScreen extends StatefulWidget {
  final Future<Map<DateTime, List<TrashedEntry>>> Function()? loadEntries;

  const TrashScreen({super.key, this.loadEntries});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _dateFormat = DateFormat('EEEE, MMMM d');
  Map<DateTime, List<TrashedEntry>> _entriesByDate = {};
  bool _loading = true;

  static const _modeAssets = {
    Mode.nourishment: 'assets/icons/nourishment.png',
    Mode.growth: 'assets/icons/growth.png',
    Mode.maintenance: 'assets/icons/maintenence.png',
    Mode.drift: 'assets/icons/drift.png',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = widget.loadEntries != null
        ? await widget.loadEntries!()
        : await (await FileService.getInstance()).readAllTrashEntries();
    if (!mounted) return;

    final sorted = <DateTime, List<TrashedEntry>>{};
    final dates = entries.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final date in dates) {
      final list = entries[date] ?? [];
      list.sort(
        (a, b) => b.entry.timestamp.compareTo(a.entry.timestamp),
      );
      sorted[date] = list;
    }

    setState(() {
      _entriesByDate = sorted;
      _loading = false;
    });
  }

  Future<void> _restoreEntry(TrashedEntry entry) async {
    final fs = await FileService.getInstance();
    final restored = await fs.restoreEntry(entry);
    if (!mounted) return;
    if (restored) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Moment restored'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    }
  }

  Future<void> _deleteEntry(TrashedEntry entry) async {
    final fs = await FileService.getInstance();
    final removed = await fs.deleteTrashedEntry(entry);
    if (!mounted) return;
    if (removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Deleted permanently'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          icon: Icon(
            Icons.arrow_back,
            color: onSurface.withValues(alpha: 0.7),
          ),
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
          : _entriesByDate.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(radii.medium),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: onSurface.withValues(alpha: 0.4),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No deleted moments.',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Swipe to delete and restore later.',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                  children: _entriesByDate.entries
                      .map((entry) => _buildDateSection(entry.key, entry.value))
                      .toList(),
                ),
    );
  }

  Widget _buildDateSection(DateTime date, List<TrashedEntry> entries) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dateFormat.format(date),
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map(_buildEntryCard),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEntryCard(TrashedEntry trashed) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = context.lilaRadii;
    final onSurface = colorScheme.onSurface;
    final palette = context.lilaPalette;
    final entry = trashed.entry;
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';

    final isReflection = entry.label == 'Daily reflection';
    if (isReflection) {
      return ArmedSwipeActions(
        dismissKey: ValueKey(
          '${entry.timestamp.toIso8601String()}-${entry.label ?? ''}-${entry.mode.name}-${entry.orientation.name}',
        ),
        onRestore: () => _restoreEntry(trashed),
        onDelete: () => _deleteEntry(trashed),
        child: _buildReflectionCard(time),
      );
    }

    final modeColor = palette.modeColor(entry.mode);
    final modeAsset = _modeAssets[entry.mode]!;
    final orientationColor = palette.orientationColor(entry.orientation);

    return ArmedSwipeActions(
      dismissKey: ValueKey(
        '${entry.timestamp.toIso8601String()}-${entry.label ?? ''}-${entry.mode.name}-${entry.orientation.name}',
      ),
      onRestore: () => _restoreEntry(trashed),
      onDelete: () => _deleteEntry(trashed),
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
              child: _buildPill(
                'Daily reflection',
                onSurface.withValues(alpha: 0.4),
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
}
