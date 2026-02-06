import 'package:flutter_test/flutter_test.dart';
import 'package:lila/logic/sentiment.dart';

void main() {
  test('positive text yields warm tone', () {
    final result = SentimentAnalyzer.analyze('calm grateful connected');
    expect(result.tone, equals(SentimentTone.warm));
  });

  test('negative text yields quiet tone', () {
    final result = SentimentAnalyzer.analyze('tired overwhelmed anxious');
    expect(result.tone, equals(SentimentTone.quiet));
  });

  test('mixed text yields charged tone', () {
    final result = SentimentAnalyzer.analyze('calm but anxious and heavy');
    expect(result.tone, equals(SentimentTone.charged));
  });

  test('negation flips sentiment', () {
    final result = SentimentAnalyzer.analyze('not calm');
    expect(result.tone, equals(SentimentTone.quiet));
  });

  test('empty text yields even tone', () {
    final result = SentimentAnalyzer.analyze('');
    expect(result.tone, equals(SentimentTone.even));
  });

  test('reflection + tags combine', () {
    final result = SentimentAnalyzer.analyzeFromTextAndTags(
      'grateful and steady',
      ['tired'],
    );
    expect(result.tone, isNotNull);
  });

  test('stopwords are configured', () {
    expect(SentimentAnalyzer.stopwords.contains('the'), isTrue);
    expect(SentimentAnalyzer.stopwords.contains('reflection'), isTrue);
  });
}
