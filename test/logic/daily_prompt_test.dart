import 'package:flutter_test/flutter_test.dart';
import 'package:lila/logic/daily_prompt.dart';

void main() {
  test('daily prompt uses morning text before noon', () {
    final text = dailyPromptText(hour: 9);
    expect(text, 'What do you want from today?');
  });

  test('daily prompt uses neutral text at midday', () {
    expect(dailyPromptText(hour: 12),
        'How is today unfolding?');
    expect(dailyPromptText(hour: 17),
        'How is today unfolding?');
  });

  test('daily prompt uses evening reflection text after 6pm', () {
    final text = dailyPromptText(hour: 18);
    expect(text, 'How did today feel?');
  });
}
