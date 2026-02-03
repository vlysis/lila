import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'ai_api_types.dart';
import 'ai_integration_service.dart';
import 'ai_provider.dart';
import 'ai_usage_service.dart';

/// Client for communicating with the Gemini API.
class GeminiApiClient {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const _defaultModel = 'gemini-2.5-flash';

  static const _connectTimeout = Duration(seconds: 10);
  static const _receiveTimeout = Duration(seconds: 60);

  static const _maxRetries = 3;
  static const _retryableStatusCodes = {429, 500, 502, 503, 504};

  static GeminiApiClient? _instance;
  late final Dio _dio;
  final AiIntegrationService _integrationService;

  GeminiApiClient._(this._integrationService) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {
        'content-type': 'application/json',
      },
    ));

    _dio.interceptors.add(_LogRedactionInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(_DebugLogInterceptor());
    }
  }

  static Future<GeminiApiClient> getInstance() async {
    if (_instance == null) {
      final integrationService = await AiIntegrationService.getInstance();
      _instance = GeminiApiClient._(integrationService);
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

  Future<AiApiError?> validateApiKey(String apiKey) async {
    final result = await _makeRequest<Map<String, dynamic>>(
      _modelPath(_defaultModel),
      {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'ping'}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 1,
        },
      },
      apiKeyOverride: apiKey,
      skipRetry: true,
    );

    return result.error;
  }

  Future<AiApiResult<String>> sendMessage({
    required String message,
    String? model,
    int maxTokens = 1024,
    String? systemPrompt,
    List<Map<String, String>>? messageHistory,
  }) async {
    if (!_integrationService.isEnabledFor(AiProvider.gemini)) {
      return AiApiResult(error: AiApiError.integrationPaused);
    }

    final usageService = await AiUsageService.getInstance(AiProvider.gemini);
    if (!usageService.canMakeRequest) {
      return AiApiResult(error: AiApiError.dailyCapReached);
    }

    final apiKey = await _integrationService.getApiKey(AiProvider.gemini);
    if (apiKey == null) {
      return AiApiResult(error: AiApiError.keyInvalid);
    }

    final selectedModel =
        model ?? _integrationService.selectedModel(AiProvider.gemini);

    final contents = <Map<String, dynamic>>[];
    if (messageHistory != null) {
      for (final msg in messageHistory) {
        contents.add(_toGeminiContent(msg['role'] ?? 'user', msg['content'] ?? ''));
      }
    }
    contents.add(_toGeminiContent('user', message));

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': maxTokens,
      },
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ]
      };
    }

    final result = await _makeRequest<Map<String, dynamic>>(
      _modelPath(selectedModel),
      body,
      apiKeyOverride: apiKey,
    );

    if (result.isError) {
      if (result.error == AiApiError.keyInvalid) {
        await _integrationService.setEnabled(false);
      }
      return AiApiResult(
        error: result.error,
        statusCode: result.statusCode,
      );
    }

    if (result.inputTokens != null && result.outputTokens != null) {
      await usageService.recordUsage(
        inputTokens: result.inputTokens!,
        outputTokens: result.outputTokens!,
      );
    }

    final candidates = result.data?['candidates'] as List<dynamic>?;
    final firstCandidate = candidates != null && candidates.isNotEmpty
        ? candidates.first as Map<String, dynamic>
        : null;
    final content = firstCandidate?['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final textPart = parts != null && parts.isNotEmpty
        ? parts.firstWhere(
            (part) => part is Map<String, dynamic> && part['text'] != null,
            orElse: () => null,
          )
        : null;
    final text = textPart is Map<String, dynamic> ? textPart['text'] as String? : null;

    return AiApiResult(
      data: text ?? '',
      statusCode: result.statusCode,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
    );
  }

  Map<String, dynamic> _toGeminiContent(String role, String content) {
    final geminiRole = role == 'assistant' ? 'model' : 'user';
    return {
      'role': geminiRole,
      'parts': [
        {'text': content}
      ],
    };
  }

  String _modelPath(String model) => '/models/$model:generateContent';

  Future<AiApiResult<T>> _makeRequest<T>(
    String path,
    Map<String, dynamic> body, {
    String? apiKeyOverride,
    bool skipRetry = false,
  }) async {
    final apiKey =
        apiKeyOverride ?? await _integrationService.getApiKey(AiProvider.gemini);
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
              'x-goog-api-key': apiKey,
              'User-Agent': 'Lila/1.0.0 (Flutter)',
            },
          ),
        );

        int? inputTokens;
        int? outputTokens;
        if (response.data is Map<String, dynamic>) {
          final usage = (response.data as Map<String, dynamic>)['usageMetadata'];
          if (usage is Map<String, dynamic>) {
            inputTokens = usage['promptTokenCount'] as int?;
            outputTokens = usage['candidatesTokenCount'] as int?;
            final totalTokens = usage['totalTokenCount'] as int?;
            if (inputTokens == null && totalTokens != null) {
              inputTokens = totalTokens;
            }
            if (outputTokens == null &&
                totalTokens != null &&
                inputTokens != null) {
              outputTokens =
                  (totalTokens - inputTokens!).clamp(0, totalTokens).toInt();
            }
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

  AiApiError _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;

    if (statusCode != null) {
      switch (statusCode) {
        case 401:
        case 403:
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

  Future<void> _delayWithJitter(int attempt) async {
    final baseDelay = Duration(milliseconds: 1000 * pow(2, attempt - 1).toInt());
    final jitter = Duration(milliseconds: Random().nextInt(500));
    await Future.delayed(baseDelay + jitter);
  }
}

class _LogRedactionInterceptor extends Interceptor {
  static final _keyPattern =
      RegExp(r'(sk-ant-api03-[A-Za-z0-9_-]+|AIza[0-9A-Za-z\-_]+)');

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
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.message != null) {
      final redactedMessage = _redact(err.message!);
      if (redactedMessage != err.message) {
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

class _DebugLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('x-goog-api-key')) {
      final key = maskedHeaders['x-goog-api-key'] as String?;
      if (key != null && key.length > 15) {
        maskedHeaders['x-goog-api-key'] = 'AIza...${key.substring(key.length - 4)}';
      } else {
        maskedHeaders['x-goog-api-key'] = '[REDACTED]';
      }
    }
    debugPrint('Gemini API Request: ${options.method} ${options.path}');
    debugPrint('Headers: $maskedHeaders');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('Gemini API Response: ${response.statusCode}');
    if (response.data is Map<String, dynamic>) {
      final usage = (response.data as Map<String, dynamic>)['usageMetadata'];
      if (usage != null) {
        debugPrint('Token usage: $usage');
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('Gemini API Error: ${err.type} - ${err.message}');
    if (err.response != null) {
      debugPrint('Status: ${err.response?.statusCode}');
    }
    handler.next(err);
  }
}
