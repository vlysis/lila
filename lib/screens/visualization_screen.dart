import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../logic/sentiment.dart';
import '../logic/word_bloom.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../theme/lila_theme.dart';
import '../widgets/orientation_threads_widget.dart';

class VisualizationScreen extends StatefulWidget {
  const VisualizationScreen({super.key});

  @override
  State<VisualizationScreen> createState() => _VisualizationScreenState();
}

class _VisualizationScreenState extends State<VisualizationScreen> {
  List<_DayGardenData> _days = [];
  SentimentResult _weekSentiment = const SentimentResult(
    score: 0,
    energy: 0,
    matches: 0,
    tone: SentimentTone.even,
  );
  WordBloomData _wordBloom = const WordBloomData(
    reflectionWords: [],
    tagWords: [],
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fs = await FileService.getInstance();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final prevStart =
        DateTime(today.year, today.month, today.day)
            .subtract(const Duration(days: 13));

    final days = <_DayGardenData>[];
    final allLabels = <String>[];
    final allReflections = StringBuffer();
    final reflectionLast7 = <String>[];
    final reflectionPrev7 = <String>[];
    final tagLast7 = <String>[];
    final tagPrev7 = <String>[];

    for (var i = 0; i < 7; i += 1) {
      final date = start.add(Duration(days: i));
      final entries = await fs.readDailyEntries(date);
      final reflection = await fs.readDailyReflection(date);
      final labels = entries
          .map((entry) => entry.label ?? '')
          .where((label) =>
              label.trim().isNotEmpty && label != 'Daily reflection')
          .toList();

      allLabels.addAll(labels);
      if (reflection.trim().isNotEmpty) {
        allReflections.writeln(reflection);
        reflectionLast7.add(reflection);
      }
      if (labels.isNotEmpty) {
        tagLast7.addAll(labels);
      }

      final sentiment =
          SentimentAnalyzer.analyzeFromTextAndTags(reflection, labels);
      final reflectionCount = entries
          .where((entry) => entry.label == 'Daily reflection')
          .length;
      final dayLabel = DateFormat('EEE').format(date);

      days.add(
        _DayGardenData(
          date: date,
          dayLabel: dayLabel,
          entries: entries,
          reflectionText: reflection,
          sentiment: sentiment,
          reflectionCount: reflectionCount,
        ),
      );
    }

    for (var i = 0; i < 7; i += 1) {
      final date = prevStart.add(Duration(days: i));
      final entries = await fs.readDailyEntries(date);
      final reflection = await fs.readDailyReflection(date);
      final labels = entries
          .map((entry) => entry.label ?? '')
          .where((label) =>
              label.trim().isNotEmpty && label != 'Daily reflection')
          .toList();

      if (reflection.trim().isNotEmpty) {
        reflectionPrev7.add(reflection);
      }
      if (labels.isNotEmpty) {
        tagPrev7.addAll(labels);
      }
    }

    final weekSentiment = SentimentAnalyzer.analyzeFromTextAndTags(
      allReflections.toString(),
      allLabels,
    );
    final wordBloom = WordBloomBuilder.build(
      reflectionTextsLast7: reflectionLast7,
      reflectionTextsPrev7: reflectionPrev7,
      tagTextsLast7: tagLast7,
      tagTextsPrev7: tagPrev7,
      maxWords: 20,
    );

    if (mounted) {
      setState(() {
        _days = days;
        _weekSentiment = weekSentiment;
        _wordBloom = wordBloom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Balance Garden'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMoodCanopy()),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final allEntries = _days.expand((day) => day.entries).toList();
    final hasData = allEntries.isNotEmpty ||
        _days.any((day) => day.reflectionText.trim().isNotEmpty);

    if (!hasData) {
      return Padding(
        padding: const EdgeInsets.only(top: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.local_florist_outlined,
              size: 48,
              color: onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No moments yet.',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your garden grows from moments and reflections.',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildToneSummary(),
        const SizedBox(height: 28),
        _buildModePebbles(_modeCounts(allEntries)),
        const SizedBox(height: 32),
        if (allEntries.isNotEmpty)
          OrientationThreadsWidget(weekEntries: allEntries),
        const SizedBox(height: 32),
        _buildWordBloom(),
        const SizedBox(height: 32),
        _buildToneTrend(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildToneSummary() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final todayTone = _days.isNotEmpty
        ? _days.last.sentiment.tone
        : SentimentTone.even;
    final recentTone = _weekSentiment.tone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TONE',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Today: ${todayTone.label}',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.75),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Recent: ${recentTone.label}',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildModePebbles(Map<Mode, int> counts) {
    final palette = context.lilaPalette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final maxCount =
        counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MODE BALANCE',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: Mode.values.map((mode) {
            final count = counts[mode] ?? 0;
            final size = maxCount > 0
                ? 28 + (count / maxCount) * 36
                : 28.0;
            final color = palette.modeColor(mode);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mode.label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToneTrend() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TONE TREND',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: _days.map((day) {
            final color = _toneColor(day.sentiment.tone);
            return Expanded(
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWordBloom() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (_wordBloom.reflectionWords.isEmpty &&
        _wordBloom.tagWords.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WORD BLOOMS',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.25),
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No words yet.',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORD BLOOMS',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.25),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_wordBloom.reflectionWords.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Reflections',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.4),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          _buildWordSection(
            words: _wordBloom.reflectionWords,
            tint: onSurface.withValues(alpha: 0.7),
            hintColor: onSurface.withValues(alpha: 0.05),
            isReflection: true,
          ),
        ],
        if (_wordBloom.tagWords.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Tags',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _buildWordSection(
            words: _wordBloom.tagWords,
            tint: onSurface.withValues(alpha: 0.85),
            hintColor: onSurface.withValues(alpha: 0.08),
            isReflection: false,
          ),
        ],
      ],
    );
  }

  Widget _buildWordSection({
    required List<WordBloomEntry> words,
    required Color tint,
    required Color hintColor,
    required bool isReflection,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 200.0;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BloomCirclePainter(color: hintColor),
                ),
              ),
              ..._buildBloomWords(
                words: words,
                tint: tint,
                isReflection: isReflection,
                containerWidth: width,
                containerHeight: height,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildBloomWords({
    required List<WordBloomEntry> words,
    required Color tint,
    required bool isReflection,
    required double containerWidth,
    required double containerHeight,
  }) {
    if (words.isEmpty) return [];
    final capped = words.take(15).toList();
    final maxCount =
        capped.map((e) => e.count).fold<int>(0, (a, b) => a > b ? a : b);
    final random = Random(capped.length);
    final placed = <Rect>[];
    const padding = 4.0;

    return List.generate(capped.length, (index) {
      final entry = capped[index];
      final fontSize =
          maxCount == 0 ? 13.0 : 13 + (entry.count / maxCount) * 9;
      final weight = isReflection ? FontWeight.w400 : FontWeight.w600;
      final color = entry.shared
          ? tint.withValues(alpha: 0.9)
          : tint.withValues(alpha: isReflection ? 0.6 : 0.8);

      final wordW = entry.word.length * fontSize * 0.6 + 12;
      final wordH = fontSize * 1.4 + 4;

      // Initial position: polar from center
      final angle = random.nextDouble() * pi * 2;
      final radius = 20 + (index % 5) * 24.0;
      var x = containerWidth * 0.5 + cos(angle) * radius - wordW / 2;
      var y = containerHeight * 0.5 + sin(angle) * radius - wordH / 2;

      // Clamp to container bounds
      x = x.clamp(0, (containerWidth - wordW).clamp(0, double.infinity));
      y = y.clamp(0, (containerHeight - wordH).clamp(0, double.infinity));

      // Collision avoidance: spiral outward if overlapping
      var candidate = Rect.fromLTWH(
          x - padding, y - padding, wordW + padding * 2, wordH + padding * 2);
      var attempts = 0;
      while (_overlapsAny(candidate, placed) && attempts < 36) {
        attempts++;
        final spiralAngle = angle + attempts * 0.55;
        final spiralRadius = radius + attempts * 12.0;
        x = containerWidth * 0.5 +
            cos(spiralAngle) * spiralRadius -
            wordW / 2;
        y = containerHeight * 0.5 +
            sin(spiralAngle) * spiralRadius -
            wordH / 2;
        x = x.clamp(0, (containerWidth - wordW).clamp(0, double.infinity));
        y = y.clamp(0, (containerHeight - wordH).clamp(0, double.infinity));
        candidate = Rect.fromLTWH(x - padding, y - padding,
            wordW + padding * 2, wordH + padding * 2);
      }
      placed.add(candidate);

      return Positioned(
        left: x,
        top: y,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: entry.rising
              ? BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: _toneColor(_weekSentiment.tone)
                          .withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : null,
          child: Text(
            entry.word,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: weight,
              fontStyle:
                  isReflection ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      );
    });
  }

  bool _overlapsAny(Rect candidate, List<Rect> placed) {
    for (final r in placed) {
      if (candidate.overlaps(r)) return true;
    }
    return false;
  }

  Widget _buildMoodCanopy() {
    final toneColor = _toneColor(_weekSentiment.tone);
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              toneColor.withValues(alpha: 0.18),
              toneColor.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Color _toneColor(SentimentTone tone) {
    switch (tone) {
      case SentimentTone.quiet:
        return const Color(0xFF6A7D9A);
      case SentimentTone.even:
        return const Color(0xFF78808A);
      case SentimentTone.warm:
        return const Color(0xFFB07A63);
      case SentimentTone.charged:
        return const Color(0xFFC4A46A);
    }
  }

  Map<Mode, int> _modeCounts(List<LogEntry> entries) {
    final counts = <Mode, int>{};
    for (final entry in entries) {
      counts[entry.mode] = (counts[entry.mode] ?? 0) + 1;
    }
    return counts;
  }
}

class _DayGardenData {
  final DateTime date;
  final String dayLabel;
  final List<LogEntry> entries;
  final String reflectionText;
  final SentimentResult sentiment;
  final int reflectionCount;

  const _DayGardenData({
    required this.date,
    required this.dayLabel,
    required this.entries,
    required this.reflectionText,
    required this.sentiment,
    required this.reflectionCount,
  });
}

class _BloomCirclePainter extends CustomPainter {
  final Color color;

  const _BloomCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.shortestSide * 0.45,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BloomCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
