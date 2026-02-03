/// Error states for AI API operations.
enum AiApiError {
  keyInvalid,
  rateLimited,
  serverError,
  networkOffline,
  timeout,
  storageFailed,
  dailyCapReached,
  integrationPaused,
  unknown,
}

/// Extension to get user-facing messages for errors.
extension AiApiErrorMessage on AiApiError {
  String get userMessage {
    switch (this) {
      case AiApiError.keyInvalid:
        return 'Your API key is invalid or has been revoked. Please check and re-enter.';
      case AiApiError.rateLimited:
        return "You've reached the API usage limit. Please wait a moment and try again.";
      case AiApiError.serverError:
        return "Something went wrong on the provider's side. We'll retry automatically.";
      case AiApiError.networkOffline:
        return "No internet connection. AI features are paused until you're back online.";
      case AiApiError.timeout:
        return 'The request took too long. Please try again.';
      case AiApiError.storageFailed:
        return 'Unable to save your key securely. Please check device settings and retry.';
      case AiApiError.dailyCapReached:
        return "You've reached your daily token limit. Usage resets at midnight UTC.";
      case AiApiError.integrationPaused:
        return 'AI integration is paused. Enable it in Settings to continue.';
      case AiApiError.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

extension AiApiErrorRetryable on AiApiError {
  bool get isRetryable {
    switch (this) {
      case AiApiError.networkOffline:
      case AiApiError.timeout:
      case AiApiError.serverError:
        return true;
      default:
        return false;
    }
  }
}

/// Result of an AI API call.
class AiApiResult<T> {
  final T? data;
  final AiApiError? error;
  final int? statusCode;
  final int? inputTokens;
  final int? outputTokens;

  AiApiResult({
    this.data,
    this.error,
    this.statusCode,
    this.inputTokens,
    this.outputTokens,
  });

  bool get isSuccess => error == null && data != null;
  bool get isError => error != null;
}
