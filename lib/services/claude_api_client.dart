import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'claude_service.dart';
import 'claude_usage_service.dart';

/// Error states for Claude API operations.
enum ClaudeApiError {
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
extension ClaudeApiErrorMessage on ClaudeApiError {
  String get userMessage {
    switch (this) {
      case ClaudeApiError.keyInvalid:
        return 'Your API key is invalid or has been revoked. Please check and re-enter.';
      case ClaudeApiError.rateLimited:
        return "You've reached the API usage limit. Please wait a moment and try again.";
      case ClaudeApiError.serverError:
        return "Something went wrong on Anthropic's side. We'll retry automatically.";
      case ClaudeApiError.networkOffline:
        return "No internet connection. Claude features are paused until you're back online.";
      case ClaudeApiError.timeout:
        return 'The request took too long. Please try again.';
      case ClaudeApiError.storageFailed:
        return 'Unable to save your key securely. Please check device settings and retry.';
      case ClaudeApiError.dailyCapReached:
        return "You've reached your daily token limit. Usage resets at midnight UTC.";
      case ClaudeApiError.integrationPaused:
        return 'Claude integration is paused. Enable it in Settings to continue.';
      case ClaudeApiError.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

/// Result of a Claude API call.
class ClaudeApiResult<T> {
  final T? data;
  final ClaudeApiError? error;
  final int? statusCode;
  final int? inputTokens;
  final int? outputTokens;

  ClaudeApiResult({
    this.data,
    this.error,
    this.statusCode,
    this.inputTokens,
    this.outputTokens,
  });

  bool get isSuccess => error == null && data != null;
  bool get isError => error != null;
}

/// Client for communicating with the Claude API.
class ClaudeApiClient {
  static const _baseUrl = 'https://api.anthropic.com';
  static const _apiVersion = '2023-06-01';
  static const _defaultModel = 'claude-haiku-4-5-20251001';

  // Timeouts
  static const _connectTimeout = Duration(seconds: 10);
  static const _receiveTimeout = Duration(seconds: 60);

  // Retry configuration
  static const _maxRetries = 3;
  static const _retryableStatusCodes = {429, 500, 502, 503, 504};
  // Non-retryable: 400, 401, 403, 422 - handled by _mapDioError

  static ClaudeApiClient? _instance;
  late final Dio _dio;
  final ClaudeService _claudeService;

  ClaudeApiClient._(this._claudeService) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(_LogRedactionInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(_DebugLogInterceptor());
    }
  }

  static Future<ClaudeApiClient> getInstance() async {
    if (_instance == null) {
      final claudeService = await ClaudeService.getInstance();
      _instance = ClaudeApiClient._(claudeService);
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

  /// Validates an API key by making a minimal request.
  /// Returns null if valid, or an error if invalid.
  Future<ClaudeApiError?> validateApiKey(String apiKey) async {
    final result = await _makeRequest<Map<String, dynamic>>(
      '/v1/messages',
      {
        'model': _defaultModel,
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': 'ping'}
        ],
      },
      apiKeyOverride: apiKey,
      skipRetry: true, // Don't retry validation requests
    );

    return result.error;
  }

  /// Sends a message to Claude and returns the response.
  ///
  /// If [messageHistory] is provided, it should be a list of message maps
  /// with 'role' ('user' or 'assistant') and 'content' keys. The [message]
  /// parameter will be appended as the final user message.
  Future<ClaudeApiResult<String>> sendMessage({
    required String message,
    String? model,
    int maxTokens = 1024,
    String? systemPrompt,
    List<Map<String, String>>? messageHistory,
  }) async {
    // Check if integration is enabled
    if (!_claudeService.isEnabled) {
      return ClaudeApiResult(error: ClaudeApiError.integrationPaused);
    }

    // Check daily cap
    final usageService = await ClaudeUsageService.getInstance();
    if (!usageService.canMakeRequest) {
      return ClaudeApiResult(error: ClaudeApiError.dailyCapReached);
    }

    final apiKey = await _claudeService.getApiKey();
    if (apiKey == null) {
      return ClaudeApiResult(error: ClaudeApiError.keyInvalid);
    }

    final selectedModel = model ?? _claudeService.selectedModel;

    // Build messages array from history plus new message
    final messages = <Map<String, String>>[];
    if (messageHistory != null) {
      messages.addAll(messageHistory);
    }
    messages.add({'role': 'user', 'content': message});

    final body = <String, dynamic>{
      'model': selectedModel,
      'max_tokens': maxTokens,
      'messages': messages,
    };

    if (systemPrompt != null) {
      body['system'] = systemPrompt;
    }

    final result = await _makeRequest<Map<String, dynamic>>(
      '/v1/messages',
      body,
      apiKeyOverride: apiKey,
    );

    if (result.isError) {
      // Auto-pause on 401 during normal usage
      if (result.error == ClaudeApiError.keyInvalid) {
        await _claudeService.setEnabled(false);
      }
      return ClaudeApiResult(
        error: result.error,
        statusCode: result.statusCode,
      );
    }

    // Record token usage
    if (result.inputTokens != null && result.outputTokens != null) {
      await usageService.recordUsage(
        inputTokens: result.inputTokens!,
        outputTokens: result.outputTokens!,
      );
    }

    // Extract text from response
    final content = result.data?['content'] as List<dynamic>?;
    final textBlock = content?.firstWhere(
      (block) => block['type'] == 'text',
      orElse: () => null,
    );
    final text = textBlock?['text'] as String? ?? '';

    return ClaudeApiResult(
      data: text,
      statusCode: result.statusCode,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
    );
  }

  /// Makes an HTTP request with retry logic.
  Future<ClaudeApiResult<T>> _makeRequest<T>(
    String path,
    Map<String, dynamic> body, {
    String? apiKeyOverride,
    bool skipRetry = false,
  }) async {
    final apiKey = apiKeyOverride ?? await _claudeService.getApiKey();
    if (apiKey == null) {
      return ClaudeApiResult(error: ClaudeApiError.keyInvalid);
    }

    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _dio.post<T>(
          path,
          data: body,
          options: Options(
            headers: {
              'x-api-key': apiKey,
              'User-Agent': 'Lila/1.0.0 (Flutter)',
            },
          ),
        );

        // Extract token usage from response
        int? inputTokens;
        int? outputTokens;
        if (response.data is Map<String, dynamic>) {
          final usage = (response.data as Map<String, dynamic>)['usage'];
          if (usage is Map<String, dynamic>) {
            inputTokens = usage['input_tokens'] as int?;
            outputTokens = usage['output_tokens'] as int?;
          }
        }

        return ClaudeApiResult(
          data: response.data,
          statusCode: response.statusCode,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        );
      } on DioException catch (e) {
        final error = _mapDioError(e);
        final statusCode = e.response?.statusCode;

        // Check if we should retry
        if (!skipRetry &&
            attempt < _maxRetries &&
            statusCode != null &&
            _retryableStatusCodes.contains(statusCode)) {
          await _delayWithJitter(attempt);
          continue;
        }

        return ClaudeApiResult(
          error: error,
          statusCode: statusCode,
        );
      }
    }
  }

  /// Maps DioException to ClaudeApiError.
  ClaudeApiError _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;

    if (statusCode != null) {
      switch (statusCode) {
        case 401:
          return ClaudeApiError.keyInvalid;
        case 429:
          return ClaudeApiError.rateLimited;
        case 500:
        case 502:
        case 503:
        case 504:
          return ClaudeApiError.serverError;
        default:
          return ClaudeApiError.unknown;
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ClaudeApiError.timeout;
      case DioExceptionType.connectionError:
        return ClaudeApiError.networkOffline;
      default:
        return ClaudeApiError.unknown;
    }
  }

  /// Calculates exponential back-off delay with jitter.
  Future<void> _delayWithJitter(int attempt) async {
    final baseDelay = Duration(milliseconds: 1000 * pow(2, attempt - 1).toInt());
    final jitter = Duration(
      milliseconds: Random().nextInt(500),
    );
    await Future.delayed(baseDelay + jitter);
  }
}

/// Interceptor that redacts API keys from logs.
class _LogRedactionInterceptor extends Interceptor {
  static final _keyPattern = RegExp(r'sk-ant-api03-[A-Za-z0-9_-]+');

  String _redact(String input) {
    return input.replaceAllMapped(_keyPattern, (match) {
      final key = match.group(0)!;
      if (key.length > 15) {
        return 'sk-ant-...${key.substring(key.length - 4)}';
      }
      return 'sk-ant-...[REDACTED]';
    });
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Redact API key from headers before any logging
    final headers = Map<String, dynamic>.from(options.headers);
    if (headers.containsKey('x-api-key')) {
      final key = headers['x-api-key'] as String?;
      if (key != null && key.length > 15) {
        headers['x-api-key'] = 'sk-ant-...${key.substring(key.length - 4)}';
      } else {
        headers['x-api-key'] = '[REDACTED]';
      }
    }
    // Note: We don't modify the actual request, just ensure redaction happens in logs
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Redact any keys that might appear in error messages
    if (err.message != null) {
      final redactedMessage = _redact(err.message!);
      if (redactedMessage != err.message) {
        // Create new error with redacted message if needed
        handler.next(DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: err.error,
          message: redactedMessage,
        ));
        return;
      }
    }
    handler.next(err);
  }
}

/// Debug logging interceptor (only in debug mode).
class _DebugLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Log request without sensitive data
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('x-api-key')) {
      final key = maskedHeaders['x-api-key'] as String?;
      if (key != null && key.length > 15) {
        maskedHeaders['x-api-key'] = 'sk-ant-...${key.substring(key.length - 4)}';
      } else {
        maskedHeaders['x-api-key'] = '[REDACTED]';
      }
    }
    debugPrint('Claude API Request: ${options.method} ${options.path}');
    debugPrint('Headers: $maskedHeaders');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('Claude API Response: ${response.statusCode}');
    // Extract usage info for logging
    if (response.data is Map<String, dynamic>) {
      final usage = (response.data as Map<String, dynamic>)['usage'];
      if (usage != null) {
        debugPrint('Token usage: $usage');
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('Claude API Error: ${err.type} - ${err.message}');
    if (err.response != null) {
      debugPrint('Status: ${err.response?.statusCode}');
    }
    handler.next(err);
  }
}
