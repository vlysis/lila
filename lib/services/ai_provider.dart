enum AiProvider {
  claude,
  gemini,
}

extension AiProviderDetails on AiProvider {
  String get id {
    switch (this) {
      case AiProvider.claude:
        return 'claude';
      case AiProvider.gemini:
        return 'gemini';
    }
  }

  String get displayName {
    switch (this) {
      case AiProvider.claude:
        return 'Claude';
      case AiProvider.gemini:
        return 'Gemini';
    }
  }

  String get keyHint {
    switch (this) {
      case AiProvider.claude:
        return 'sk-ant-api03-...';
      case AiProvider.gemini:
        return 'AIza...';
    }
  }

  String get maskPrefix {
    switch (this) {
      case AiProvider.claude:
        return 'sk-ant-';
      case AiProvider.gemini:
        return 'AIza';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProvider.claude:
        return 'claude-haiku-4-5-20251001';
      case AiProvider.gemini:
        return 'gemini-2.5-flash';
    }
  }

  List<(String, String)> get availableModels {
    switch (this) {
      case AiProvider.claude:
        return const [
          ('claude-haiku-4-5-20251001', 'Haiku (fastest, cheapest)'),
          ('claude-sonnet-4-20250514', 'Sonnet (balanced)'),
          ('claude-opus-4-20250514', 'Opus (most capable)'),
        ];
      case AiProvider.gemini:
        return const [
          ('gemini-2.5-flash', 'Flash (fast, affordable)'),
          ('gemini-2.5-pro', 'Pro (most capable)'),
          ('gemini-2.5-flash-lite', 'Flash Lite (lowest cost)'),
        ];
    }
  }
}
