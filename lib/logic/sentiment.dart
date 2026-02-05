class SentimentResult {
  final double score;
  final double energy;
  final int matches;
  final SentimentTone tone;

  const SentimentResult({
    required this.score,
    required this.energy,
    required this.matches,
    required this.tone,
  });
}

enum SentimentTone {
  quiet,
  even,
  warm,
  charged;

  String get label {
    switch (this) {
      case SentimentTone.quiet:
        return 'Quiet';
      case SentimentTone.even:
        return 'Even';
      case SentimentTone.warm:
        return 'Warm';
      case SentimentTone.charged:
        return 'Charged';
    }
  }
}

class SentimentAnalyzer {
  static const Map<String, double> _lexicon = {
    'calm': 1.0,
    'steady': 0.8,
    'grateful': 1.2,
    'joy': 1.2,
    'joyful': 1.4,
    'good': 0.6,
    'great': 1.0,
    'energized': 1.1,
    'energizing': 1.0,
    'content': 0.7,
    'relief': 0.6,
    'clear': 0.6,
    'connected': 0.8,
    'supported': 0.9,
    'open': 0.6,
    'hopeful': 0.9,
    'warm': 0.7,
    'peace': 1.2,
    'peaceful': 1.2,
    'light': 0.6,
    'curious': 0.6,
    'playful': 0.7,
    'tired': -0.7,
    'exhausted': -1.2,
    'anxious': -1.1,
    'overwhelmed': -1.4,
    'stressed': -1.0,
    'stress': -0.9,
    'frustrated': -1.0,
    'sad': -1.0,
    'heavy': -1.0,
    'lonely': -1.1,
    'tense': -0.8,
    'angry': -1.2,
    'irritable': -0.9,
    'stuck': -0.7,
    'lost': -0.8,
    'foggy': -0.6,
    'drained': -1.1,
    'flat': -0.6,
    'scattered': -0.7,
  };

  static const Set<String> _negations = {
    'not',
    'no',
    'never',
    'hardly',
    'barely',
    'without',
  };

  static const Set<String> _intensifiers = {
    'very',
    'really',
    'deeply',
    'extremely',
    'so',
    'quite',
    'too',
  };

  static const Set<String> _diminishers = {
    'slightly',
    'somewhat',
    'kind',
    'kinda',
    'sorta',
    'little',
  };

  static const Set<String> stopwords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'but',
    'if',
    'then',
    'so',
    'of',
    'to',
    'in',
    'on',
    'at',
    'for',
    'from',
    'with',
    'without',
    'by',
    'about',
    'as',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'i',
    'me',
    'my',
    'we',
    'our',
    'you',
    'your',
    'they',
    'them',
    'he',
    'she',
    'it',
    'this',
    'that',
    'these',
    'those',
    'today',
    'yesterday',
    'tomorrow',
    'morning',
    'evening',
    'night',
    'day',
    'days',
    'week',
    'weeks',
    'moment',
    'moments',
    'reflection',
    'reflections',
    'log',
    'logged',
    'logging',
    'note',
    'notes',
  };

  static SentimentResult analyze(String text) {
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((token) => token.isNotEmpty);

    var score = 0.0;
    var energy = 0.0;
    var matches = 0;
    var positiveMatches = 0;
    var negativeMatches = 0;
    var multiplier = 1.0;
    var negateWindow = 0;

    for (final token in tokens) {
      if (_negations.contains(token)) {
        negateWindow = 2;
        continue;
      }
      if (_intensifiers.contains(token)) {
        multiplier = 1.4;
        continue;
      }
      if (_diminishers.contains(token)) {
        multiplier = 0.7;
        continue;
      }

      final base = _lexicon[token];
      if (base != null) {
        var adjusted = base * multiplier;
        if (negateWindow > 0) {
          adjusted = -adjusted;
        }
        score += adjusted;
        energy += adjusted.abs();
        matches += 1;
        if (base > 0) {
          positiveMatches += 1;
        } else if (base < 0) {
          negativeMatches += 1;
        }
        multiplier = 1.0;
      }

      if (negateWindow > 0) {
        negateWindow -= 1;
      }
    }

    final tone = _toneFrom(
      score: score,
      energy: energy,
      matches: matches,
      positiveMatches: positiveMatches,
      negativeMatches: negativeMatches,
    );
    return SentimentResult(
      score: score,
      energy: energy,
      matches: matches,
      tone: tone,
    );
  }

  static SentimentResult analyzeFromTextAndTags(
    String reflection,
    List<String> tags,
  ) {
    final combined = [
      reflection,
      ...tags.where((tag) => tag.trim().isNotEmpty),
    ].join(' ');
    if (combined.trim().isEmpty) {
      return const SentimentResult(
        score: 0,
        energy: 0,
        matches: 0,
        tone: SentimentTone.even,
      );
    }
    return analyze(combined);
  }

  static SentimentTone _toneFrom({
    required double score,
    required double energy,
    required int matches,
    required int positiveMatches,
    required int negativeMatches,
  }) {
    if (matches == 0) return SentimentTone.even;

    final mixed = positiveMatches > 0 && negativeMatches > 0;
    if (mixed && energy >= 1.4) {
      return SentimentTone.charged;
    }
    if (energy >= 2.8 && score.abs() < 0.6) {
      return SentimentTone.charged;
    }
    if (score >= 0.8) return SentimentTone.warm;
    if (score <= -0.8) return SentimentTone.quiet;
    if (energy >= 1.6) return SentimentTone.charged;
    return SentimentTone.even;
  }
}
