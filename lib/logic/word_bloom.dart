import 'sentiment.dart';

class WordBloomEntry {
  final String word;
  final int count;
  final bool rising;
  final bool shared;

  const WordBloomEntry({
    required this.word,
    required this.count,
    required this.rising,
    required this.shared,
  });
}

class WordBloomData {
  final List<WordBloomEntry> reflectionWords;
  final List<WordBloomEntry> tagWords;

  const WordBloomData({
    required this.reflectionWords,
    required this.tagWords,
  });
}

class WordBloomBuilder {
  static WordBloomData build({
    required List<String> reflectionTextsLast7,
    required List<String> reflectionTextsPrev7,
    required List<String> tagTextsLast7,
    required List<String> tagTextsPrev7,
    int maxWords = 20,
  }) {
    final reflectionCurrent = _countWords(reflectionTextsLast7);
    final reflectionPrev = _countWords(reflectionTextsPrev7);
    final tagCurrent = _countWords(tagTextsLast7);
    final tagPrev = _countWords(tagTextsPrev7);

    final sharedWords = reflectionCurrent.keys
        .toSet()
        .intersection(tagCurrent.keys.toSet());

    final reflectionEntries = _buildEntries(
      current: reflectionCurrent,
      previous: reflectionPrev,
      sharedWords: sharedWords,
      maxWords: maxWords,
    );

    final tagEntries = _buildEntries(
      current: tagCurrent,
      previous: tagPrev,
      sharedWords: sharedWords,
      maxWords: maxWords,
    );

    return WordBloomData(
      reflectionWords: reflectionEntries,
      tagWords: tagEntries,
    );
  }

  static Map<String, int> _countWords(List<String> texts) {
    final counts = <String, int>{};
    for (final text in texts) {
      for (final word in _tokenize(text)) {
        counts[word] = (counts[word] ?? 0) + 1;
      }
    }
    return counts;
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .map((word) => word.trim())
        .where((word) =>
            word.isNotEmpty &&
            word.length > 2 &&
            !SentimentAnalyzer.stopwords.contains(word))
        .map(_singularize)
        .toList();
  }

  static String _singularize(String word) {
    if (word.endsWith('s') && word.length > 3) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  static List<WordBloomEntry> _buildEntries({
    required Map<String, int> current,
    required Map<String, int> previous,
    required Set<String> sharedWords,
    required int maxWords,
  }) {
    final entries = current.entries
        .map((entry) {
          final prevCount = previous[entry.key] ?? 0;
          final rising = entry.value >= 2 && entry.value > prevCount;
          return WordBloomEntry(
            word: entry.key,
            count: entry.value,
            rising: rising,
            shared: sharedWords.contains(entry.key),
          );
        })
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    if (entries.length > maxWords) {
      return entries.take(maxWords).toList();
    }
    return entries;
  }
}
