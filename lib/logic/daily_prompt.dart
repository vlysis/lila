String dailyPromptText({
  required int hour,
}) {
  if (hour < 12) {
    return 'What do you want from today?';
  }
  if (hour < 18) {
    return 'How is today unfolding?';
  }
  return 'How did today feel?';
}
