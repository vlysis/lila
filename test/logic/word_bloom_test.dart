import 'package:flutter_test/flutter_test.dart';
import 'package:lila/logic/word_bloom.dart';

void main() {
  test('builds word blooms from reflections and tags', () {
    final data = WordBloomBuilder.build(
      reflectionTextsLast7: ['Grateful calm walk'],
      reflectionTextsPrev7: const [],
      tagTextsLast7: ['Quiet walk', 'Quiet walk'],
      tagTextsPrev7: const [],
      maxWords: 20,
    );

    final reflectionWords =
        data.reflectionWords.map((entry) => entry.word).toList();
    final tagWords = data.tagWords.map((entry) => entry.word).toList();

    expect(reflectionWords, containsAll(<String>['grateful', 'calm', 'walk']));
    expect(tagWords, containsAll(<String>['quiet', 'walk']));
  });

  test('marks rising words when counts increase', () {
    final data = WordBloomBuilder.build(
      reflectionTextsLast7: ['tender tender'],
      reflectionTextsPrev7: ['tender'],
      tagTextsLast7: const [],
      tagTextsPrev7: const [],
      maxWords: 20,
    );

    final tenderEntry = data.reflectionWords
        .firstWhere((entry) => entry.word == 'tender');
    expect(tenderEntry.rising, true);
  });

  test('filters stopwords and short tokens', () {
    final data = WordBloomBuilder.build(
      reflectionTextsLast7: ['the and of us'],
      reflectionTextsPrev7: const [],
      tagTextsLast7: ['a an to'],
      tagTextsPrev7: const [],
      maxWords: 20,
    );

    expect(data.reflectionWords, isEmpty);
    expect(data.tagWords, isEmpty);
  });
}
