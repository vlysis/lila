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
      season: FocusSeason.explorer,
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
  sanctuary,
  explorer,
  anchor;

  String get storageValue => name;

  String get title {
    switch (this) {
      case FocusSeason.builder:
        return 'Builder';
      case FocusSeason.sanctuary:
        return 'Sanctuary';
      case FocusSeason.explorer:
        return 'Explorer';
      case FocusSeason.anchor:
        return 'Grounded';
    }
  }

  String get label {
    switch (this) {
      case FocusSeason.builder:
        return 'Building & Growing';
      case FocusSeason.sanctuary:
        return 'Resting & Nourishing';
      case FocusSeason.explorer:
        return 'Exploring and Wandering';
      case FocusSeason.anchor:
        return 'Foundation & Consistency';
    }
  }

  String get currentLabel {
    switch (this) {
      case FocusSeason.builder:
        return label;
      case FocusSeason.sanctuary:
        return label;
      case FocusSeason.explorer:
        return 'Exploring & Wandering';
      case FocusSeason.anchor:
        return 'Foundation & Consistency';
    }
  }

  String get prompt {
    switch (this) {
      case FocusSeason.builder:
        return 'What are we moving forward today?';
      case FocusSeason.sanctuary:
        return 'What are we letting go of today?';
      case FocusSeason.explorer:
        return 'What brings you here?';
      case FocusSeason.anchor:
        return 'The foundation is holding.';
    }
  }

  static FocusSeason? fromStorage(String value) {
    for (final season in FocusSeason.values) {
      if (season.storageValue == value) return season;
    }
    return null;
  }
}
