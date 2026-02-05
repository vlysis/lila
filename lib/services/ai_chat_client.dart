import 'ai_api_types.dart';
import 'ai_integration_service.dart';
import 'ai_provider.dart';
import 'claude_api_client.dart';
import 'gemini_api_client.dart';

/// Routes chat requests to the active provider.
class AiChatClient {
  static AiChatClient? _instance;
  final AiIntegrationService _integrationService;

  AiChatClient._(this._integrationService);

  static Future<AiChatClient> getInstance() async {
    if (_instance == null) {
      final integrationService = await AiIntegrationService.getInstance();
      _instance = AiChatClient._(integrationService);
    }
    return _instance!;
  }

  static void resetInstance() => _instance = null;

  Future<AiApiResult<String>> sendMessage({
    required String message,
    String? model,
    int maxTokens = 1024,
    String? systemPrompt,
    List<Map<String, String>>? messageHistory,
  }) async {
    final provider = _integrationService.activeProvider;
    switch (provider) {
      case AiProvider.claude:
        final client = await ClaudeApiClient.getInstance();
        return client.sendMessage(
          message: message,
          model: model,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
          messageHistory: messageHistory,
        );
      case AiProvider.gemini:
        final client = await GeminiApiClient.getInstance();
        return client.sendMessage(
          message: message,
          model: model,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
          messageHistory: messageHistory,
        );
    }
  }
}
