import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider.dart';

/// Service for managing AI integrations across providers.
/// Handles secure key storage, validation, provider selection, and enablement.
class AiIntegrationService {
  static const _enabledPrefKey = 'ai_integration_enabled';
  static const _activeProviderKey = 'ai_active_provider';
  static const _modelPrefPrefix = 'ai_model_';

  // Legacy Claude keys for migration.
  static const _legacyClaudeKey = 'lila_claude_api_key';
  static const _legacyClaudeEnabledKey = 'claude_integration_enabled';
  static const _legacyClaudeModelKey = 'claude_model';

  static AiIntegrationService? _instance;
  late final FlutterSecureStorage _secureStorage;
  late SharedPreferences _prefs;

  final Map<AiProvider, bool> _hasKey = {};
  final Map<AiProvider, String?> _maskedKeys = {};

  AiIntegrationService._();

  static Future<AiIntegrationService> getInstance() async {
    if (_instance == null) {
      _instance = AiIntegrationService._();
      await _instance!._init();
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

  Future<void> _init() async {
    const androidOptions = AndroidOptions(
      encryptedSharedPreferences: true,
    );
    const iosOptions = IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    );
    const macOsOptions = MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    );

    _secureStorage = const FlutterSecureStorage(
      aOptions: androidOptions,
      iOptions: iosOptions,
      mOptions: macOsOptions,
    );

    _prefs = await SharedPreferences.getInstance();

    await _migrateLegacyClaudePrefs();
    await _loadKeyState();

    // Ensure a default active provider is set.
    if (!_prefs.containsKey(_activeProviderKey)) {
      await _prefs.setString(_activeProviderKey, AiProvider.claude.id);
    }
  }

  Future<void> _migrateLegacyClaudePrefs() async {
    final legacyKey = await _secureStorage.read(key: _legacyClaudeKey);
    final newKey = await _secureStorage.read(
      key: _storageKeyForProvider(AiProvider.claude),
    );

    if ((newKey == null || newKey.isEmpty) &&
        legacyKey != null &&
        legacyKey.isNotEmpty) {
      await _secureStorage.write(
        key: _storageKeyForProvider(AiProvider.claude),
        value: legacyKey,
      );
    }

    if (!_prefs.containsKey(_enabledPrefKey) &&
        _prefs.containsKey(_legacyClaudeEnabledKey)) {
      final enabled = _prefs.getBool(_legacyClaudeEnabledKey) ?? false;
      await _prefs.setBool(_enabledPrefKey, enabled);
    }

    final legacyModel = _prefs.getString(_legacyClaudeModelKey);
    final modelKey = _modelPrefKey(AiProvider.claude);
    if (legacyModel != null && !_prefs.containsKey(modelKey)) {
      await _prefs.setString(modelKey, legacyModel);
    }
  }

  Future<void> _loadKeyState() async {
    for (final provider in AiProvider.values) {
      final key = await _secureStorage.read(
        key: _storageKeyForProvider(provider),
      );
      final hasKey = key != null && key.isNotEmpty;
      _hasKey[provider] = hasKey;
      _maskedKeys[provider] = hasKey ? _maskKey(provider, key!) : null;
    }
  }

  /// Returns the currently active provider.
  AiProvider get activeProvider {
    final raw = _prefs.getString(_activeProviderKey);
    return AiProvider.values.firstWhere(
      (p) => p.id == raw,
      orElse: () => AiProvider.claude,
    );
  }

  /// Sets the active provider.
  Future<void> setActiveProvider(AiProvider provider) async {
    await _prefs.setString(_activeProviderKey, provider.id);
    final enabled = _prefs.getBool(_enabledPrefKey) ?? false;
    if (enabled && !hasApiKey(provider)) {
      await _prefs.setBool(_enabledPrefKey, false);
    }
  }

  /// Whether an API key is stored for a provider.
  bool hasApiKey(AiProvider provider) => _hasKey[provider] ?? false;

  /// Whether the active provider integration is enabled.
  bool get isEnabled {
    final enabled = _prefs.getBool(_enabledPrefKey) ?? false;
    return enabled && hasApiKey(activeProvider);
  }

  /// Whether a specific provider is active and enabled.
  bool isEnabledFor(AiProvider provider) {
    if (provider != activeProvider) return false;
    return isEnabled;
  }

  /// The masked API key for display.
  String? maskedKey(AiProvider provider) => _maskedKeys[provider];

  /// Returns the selected model for a provider.
  String selectedModel(AiProvider provider) {
    return _prefs.getString(_modelPrefKey(provider)) ?? provider.defaultModel;
  }

  /// Sets the model for a provider.
  Future<void> setModel(AiProvider provider, String model) async {
    await _prefs.setString(_modelPrefKey(provider), model);
  }

  /// Validates API key format (provider-specific).
  /// Returns null if valid, or an error message if invalid.
  static String? validateKeyFormat(AiProvider provider, String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return 'API key cannot be empty';
    }
    if (trimmed.contains(RegExp(r'\s'))) {
      return 'API key cannot contain spaces';
    }

    switch (provider) {
      case AiProvider.claude:
        final pattern = RegExp(r'^sk-ant-api03-[A-Za-z0-9_-]{40,}$');
        if (!pattern.hasMatch(trimmed)) {
          return 'Invalid API key format. Keys start with sk-ant-api03-';
        }
        return null;
      case AiProvider.gemini:
        // Gemini uses Google API keys, which can vary in format.
        return null;
    }
  }

  /// Saves the API key to secure storage.
  /// Clears clipboard after saving for security.
  /// Returns null on success, or an error message on failure.
  Future<String?> saveApiKey(AiProvider provider, String key) async {
    final trimmed = key.trim();

    final formatError = validateKeyFormat(provider, trimmed);
    if (formatError != null) return formatError;

    try {
      await _secureStorage.write(
        key: _storageKeyForProvider(provider),
        value: trimmed,
      );
      _hasKey[provider] = true;
      _maskedKeys[provider] = _maskKey(provider, trimmed);

      await Clipboard.setData(const ClipboardData(text: ''));

      return null;
    } catch (e) {
      return 'Unable to save your key securely. Please check device settings and retry.';
    }
  }

  /// Retrieves the API key from secure storage.
  Future<String?> getApiKey(AiProvider provider) async {
    if (!hasApiKey(provider)) return null;
    try {
      return await _secureStorage.read(
        key: _storageKeyForProvider(provider),
      );
    } catch (e) {
      return null;
    }
  }

  /// Deletes the API key from secure storage.
  /// Also disables the integration if this provider is active.
  Future<void> deleteApiKey(AiProvider provider) async {
    try {
      await _secureStorage.delete(
        key: _storageKeyForProvider(provider),
      );
    } catch (e) {
      // Ignore deletion errors.
    }

    _hasKey[provider] = false;
    _maskedKeys[provider] = null;

    if (activeProvider == provider) {
      await _prefs.setBool(_enabledPrefKey, false);
    }
  }

  /// Enables or disables integration for the active provider.
  Future<void> setEnabled(bool enabled) async {
    if (enabled && !hasApiKey(activeProvider)) return;
    await _prefs.setBool(_enabledPrefKey, enabled);
  }

  static Future<void> clearClipboard() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  String _storageKeyForProvider(AiProvider provider) {
    return 'lila_ai_api_key_${provider.id}';
  }

  String _modelPrefKey(AiProvider provider) {
    return '$_modelPrefPrefix${provider.id}';
  }

  String _maskKey(AiProvider provider, String key) {
    if (key.length < 8) return '***';
    final last4 = key.substring(key.length - 4);
    return '${provider.maskPrefix}...$last4';
  }
}
