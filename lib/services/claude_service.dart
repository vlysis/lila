import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Claude API integration.
/// Handles secure key storage, validation, and integration state.
class ClaudeService {
  static const _keyStorageKey = 'lila_claude_api_key';
  static const _enabledPrefKey = 'claude_integration_enabled';
  static const _modelPrefKey = 'claude_model';
  static const _dailyCapPrefKey = 'claude_daily_token_cap';

  /// Regex for validating Anthropic API key format.
  /// Pattern: sk-ant-api03-[A-Za-z0-9_-]{40,}
  static final apiKeyPattern = RegExp(r'^sk-ant-api03-[A-Za-z0-9_-]{40,}$');

  static ClaudeService? _instance;
  late final FlutterSecureStorage _secureStorage;
  late SharedPreferences _prefs;

  String? _cachedMaskedKey;
  bool _hasKey = false;

  ClaudeService._();

  static Future<ClaudeService> getInstance() async {
    if (_instance == null) {
      _instance = ClaudeService._();
      await _instance!._init();
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() => _instance = null;

  Future<void> _init() async {
    // Configure secure storage with platform-specific options
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

    // Check if we have a stored key
    final key = await _secureStorage.read(key: _keyStorageKey);
    _hasKey = key != null && key.isNotEmpty;
    if (_hasKey) {
      _cachedMaskedKey = _maskKey(key!);
    }
  }

  /// Whether an API key is stored.
  bool get hasApiKey => _hasKey;

  /// Whether Claude integration is enabled.
  bool get isEnabled => _hasKey && (_prefs.getBool(_enabledPrefKey) ?? false);

  /// The masked API key for display (e.g., "sk-ant-...abcd").
  /// Returns null if no key is stored.
  String? get maskedKey => _cachedMaskedKey;

  /// The currently selected model.
  String get selectedModel =>
      _prefs.getString(_modelPrefKey) ?? 'claude-haiku-4-5-20251001';

  /// The daily token cap (0 means no cap).
  int get dailyTokenCap => _prefs.getInt(_dailyCapPrefKey) ?? 0;

  /// Validates the API key format.
  /// Returns null if valid, or an error message if invalid.
  static String? validateKeyFormat(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return 'API key cannot be empty';
    }
    if (!apiKeyPattern.hasMatch(trimmed)) {
      return 'Invalid API key format. Keys start with sk-ant-api03-';
    }
    return null;
  }

  /// Saves the API key to secure storage.
  /// Clears clipboard after saving for security.
  /// Returns null on success, or an error message on failure.
  Future<String?> saveApiKey(String key) async {
    final trimmed = key.trim();

    // Validate format first
    final formatError = validateKeyFormat(trimmed);
    if (formatError != null) {
      return formatError;
    }

    try {
      await _secureStorage.write(key: _keyStorageKey, value: trimmed);
      _hasKey = true;
      _cachedMaskedKey = _maskKey(trimmed);

      // Clear clipboard for security
      await Clipboard.setData(const ClipboardData(text: ''));

      return null;
    } catch (e) {
      return 'Unable to save your key securely. Please check device settings and retry.';
    }
  }

  /// Retrieves the API key from secure storage.
  /// Returns null if no key is stored or on error.
  Future<String?> getApiKey() async {
    if (!_hasKey) return null;
    try {
      return await _secureStorage.read(key: _keyStorageKey);
    } catch (e) {
      return null;
    }
  }

  /// Deletes the API key from secure storage.
  /// Also disables the integration.
  Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: _keyStorageKey);
    } catch (e) {
      // Ignore errors during deletion
    }
    _hasKey = false;
    _cachedMaskedKey = null;
    await _prefs.setBool(_enabledPrefKey, false);
  }

  /// Enables or disables Claude integration.
  /// Only works if an API key is stored.
  Future<void> setEnabled(bool enabled) async {
    if (!_hasKey && enabled) return; // Can't enable without a key
    await _prefs.setBool(_enabledPrefKey, enabled);
  }

  /// Sets the model to use for API requests.
  Future<void> setModel(String model) async {
    await _prefs.setString(_modelPrefKey, model);
  }

  /// Sets the daily token cap (0 to disable).
  Future<void> setDailyTokenCap(int cap) async {
    await _prefs.setInt(_dailyCapPrefKey, cap);
  }

  /// Masks the API key for display.
  /// Shows "sk-ant-...XXXX" where XXXX is the last 4 characters.
  String _maskKey(String key) {
    if (key.length < 15) return '***';
    final last4 = key.substring(key.length - 4);
    return 'sk-ant-...$last4';
  }

  /// Clears the system clipboard.
  /// Call this after the user pastes into the key field.
  static Future<void> clearClipboard() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  }
}
