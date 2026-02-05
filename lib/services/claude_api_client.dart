import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'ai_api_types.dart';
import 'ai_integration_service.dart';
import 'ai_provider.dart';
import 'ai_usage_service.dart';

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
  final AiIntegrationService _integrationService;

  ClaudeApiClient._(this._integrationService) {
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
      final integrationService = await AiIntegrationService.getInstance();
      _instance = ClaudeApiClient._(integrationService);
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

  /// Validates an API key by making a minimal request.
  /// Returns null if valid, or an error if invalid.
  Future<AiApiError?> validateApiKey(String apiKey) async {
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
  Future<AiApiResult<String>> sendMessage({
    required String message,
    String? model,
    int maxTokens = 1024,
    String? systemPrompt,
    List<Map<String, String>>? messageHistory,
  }) async {
    // Check if integration is enabled
    if (!_integrationService.isEnabledFor(AiProvider.claude)) {
      return AiApiResult(error: AiApiError.integrationPaused);
    }

    // Check daily cap
    final usageService = await AiUsageService.getInstance(AiProvider.claude);
    if (!usageService.canMakeRequest) {
      return AiApiResult(error: AiApiError.dailyCapReached);
    }

    final apiKey = await _integrationService.getApiKey(AiProvider.claude);
    if (apiKey == null) {
      return AiApiResult(error: AiApiError.keyInvalid);
    }

    final selectedModel =
        model ?? _integrationService.selectedModel(AiProvider.claude);

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
      if (result.error == AiApiError.keyInvalid) {
        await _integrationService.setEnabled(false);
      }
      return AiApiResult(
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

    return AiApiResult(
      data: text,
      statusCode: result.statusCode,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
    );
  }

  /// Makes an HTTP request with retry logic.
  Future<AiApiResult<T>> _makeRequest<T>(
    String path,
    Map<String, dynamic> body, {
    String? apiKeyOverride,
    bool skipRetry = false,
  }) async {
    final apiKey =
        apiKeyOverride ?? await _integrationService.getApiKey(AiProvider.claude);
    if (apiKey == null) {
      return AiApiResult(error: AiApiError.keyInvalid);
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

        return AiApiResult(
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

        return AiApiResult(
          error: error,
          statusCode: statusCode,
        );
      }
    }
  }

  /// Maps DioException to AiApiError.
  AiApiError _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;

    if (statusCode != null) {
      switch (statusCode) {
        case 401:
          return AiApiError.keyInvalid;
        case 429:
          return AiApiError.rateLimited;
        case 500:
        case 502:
        case 503:
        case 504:
          return AiApiError.serverError;
        default:
          return AiApiError.unknown;
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AiApiError.timeout;
      case DioExceptionType.connectionError:
        return AiApiError.networkOffline;
      default:
        return AiApiError.unknown;
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
  static final _keyPattern =
      RegExp(r'(sk-ant-api03-[A-Za-z0-9_-]+|AIza[0-9A-Za-z\\-_]+)');

  String _redact(String input) {
    return input.replaceAllMapped(_keyPattern, (match) {
      final key = match.group(0)!;
      if (key.length > 15) {
        if (key.startsWith('sk-ant')) {
          return 'sk-ant-...${key.substring(key.length - 4)}';
        }
        return 'AIza...${key.substring(key.length - 4)}';
      }
      return '...[REDACTED]';
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
