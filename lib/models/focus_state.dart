class FocusState {
  final FocusSeason season;
  final String intention;
  final DateTime? setAt;

  const FocusState({
    required this.season,
    required this.intention,
    this.setAt,
  });

  static FocusState defaultState() {
    return const FocusState(
      season: FocusSeason.builder,
      intention: '',
      setAt: null,
    );
  }

  FocusState copyWith({
    FocusSeason? season,
    String? intention,
    DateTime? setAt,
  }) {
    return FocusState(
      season: season ?? this.season,
      intention: intention ?? this.intention,
      setAt: setAt ?? this.setAt,
    );
  }
}

enum FocusSeason {
  builder,
  sanctuary;

  String get storageValue => name;

  String get label {
    switch (this) {
      case FocusSeason.builder:
        return 'Building & Growing';
      case FocusSeason.sanctuary:
        return 'Resting & Nourishing';
    }
  }

  String get prompt {
    switch (this) {
      case FocusSeason.builder:
        return 'What are we moving forward today?';
      case FocusSeason.sanctuary:
        return 'What are we letting go of today?';
    }
  }

  static FocusSeason? fromStorage(String value) {
    for (final season in FocusSeason.values) {
      if (season.storageValue == value) return season;
    }
    return null;
  }
}
