import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/ai_api_types.dart';
import '../services/ai_integration_service.dart';
import '../services/ai_provider.dart';
import '../services/ai_usage_service.dart';
import '../services/claude_api_client.dart';
import '../services/gemini_api_client.dart';
import '../services/file_service.dart';
import '../services/synthetic_data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _vaultPath = '';

  // AI integration state
  AiIntegrationService? _integrationService;
  AiUsageService? _usageService;
  AiProvider _activeProvider = AiProvider.claude;
  bool _aiEnabled = false;
  bool _hasApiKey = false;
  String? _maskedKey;
  String _selectedModel = AiProvider.claude.defaultModel;
  String _usageSummary = '';
  int _dailyCap = 0;
  final _apiKeyController = TextEditingController();
  bool _isEnteringKey = false;
  String? _keyError;
  bool _isSavingKey = false;

  // Models are provided by the active provider.

  @override
  void initState() {
    super.initState();
    _loadPath();
    _loadAiState();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadPath() async {
    final fs = await FileService.getInstance();
    if (mounted) setState(() => _vaultPath = fs.rootDir);
  }

  Future<void> _loadAiState() async {
    final integration = await AiIntegrationService.getInstance();
    final provider = integration.activeProvider;
    final usage = await AiUsageService.getInstance(provider);
    final selectedModel = _normalizeModel(
      provider,
      integration.selectedModel(provider),
    );
    if (mounted) {
      setState(() {
        _integrationService = integration;
        _usageService = usage;
        _activeProvider = provider;
        _aiEnabled = integration.isEnabled;
        _hasApiKey = integration.hasApiKey(provider);
        _maskedKey = integration.maskedKey(provider);
        _selectedModel = selectedModel;
        _usageSummary = usage.usageSummary;
        _dailyCap = usage.dailyCap;
      });
    }
  }

  Future<void> _setActiveProvider(AiProvider provider) async {
    if (_integrationService == null) return;
    await _integrationService!.setActiveProvider(provider);
    final usage = await AiUsageService.getInstance(provider);
    final selectedModel = _normalizeModel(
      provider,
      _integrationService!.selectedModel(provider),
    );
    if (!mounted) return;
    setState(() {
      _activeProvider = provider;
      _usageService = usage;
      _aiEnabled = _integrationService!.isEnabled;
      _hasApiKey = _integrationService!.hasApiKey(provider);
      _maskedKey = _integrationService!.maskedKey(provider);
      _selectedModel = selectedModel;
      _usageSummary = usage.usageSummary;
      _dailyCap = usage.dailyCap;
      _keyError = null;
      _isEnteringKey = false;
      _apiKeyController.clear();
    });
  }

  String _normalizeModel(AiProvider provider, String model) {
    final available = provider.availableModels.map((entry) => entry.$1);
    return available.contains(model) ? model : provider.defaultModel;
  }

  void _changeVaultPath() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.folder_open,
                    color: Colors.white.withValues(alpha: 0.6)),
                title: Text('Choose existing folder',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8))),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickExistingFolder();
                },
              ),
              ListTile(
                leading: Icon(Icons.create_new_folder,
                    color: Colors.white.withValues(alpha: 0.6)),
                title: Text('Create new folder',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8))),
                onTap: () {
                  Navigator.pop(ctx);
                  _createNewFolder();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickExistingFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose vault location',
      initialDirectory: _vaultPath,
    );
    if (result == null) return;
    await _applyVaultPath(result);
  }

  Future<void> _createNewFolder() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('New folder name',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          decoration: InputDecoration(
            hintText: 'e.g. Lila',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, nameController.text.trim()),
            child: Text('Next',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    if (!mounted) return;
    final parent = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to create "$name"',
      initialDirectory: _vaultPath,
    );
    if (parent == null) return;

    final newDir = Directory('$parent/$name');
    await newDir.create(recursive: true);
    await _applyVaultPath(newDir.path);
  }

  Future<void> _applyVaultPath(String path) async {
    final fs = await FileService.getInstance();
    await fs.setVaultPath(path);
    if (mounted) {
      setState(() => _vaultPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vault location updated.'),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
        ),
      );
    }
  }

  void _startKeyEntry() {
    setState(() {
      _isEnteringKey = true;
      _keyError = null;
      _apiKeyController.clear();
    });
  }

  void _cancelKeyEntry() {
    setState(() {
      _isEnteringKey = false;
      _keyError = null;
      _apiKeyController.clear();
    });
  }

  Future<AiApiError?> _validateApiKey(String key) async {
    switch (_activeProvider) {
      case AiProvider.claude:
        final client = await ClaudeApiClient.getInstance();
        return client.validateApiKey(key);
      case AiProvider.gemini:
        final client = await GeminiApiClient.getInstance();
        return client.validateApiKey(key);
    }
  }

  Future<void> _saveApiKey() async {
    if (_integrationService == null) return;

    final key = _apiKeyController.text.trim();
    final formatError =
        AiIntegrationService.validateKeyFormat(_activeProvider, key);
    if (formatError != null) {
      setState(() => _keyError = formatError);
      return;
    }

    setState(() {
      _isSavingKey = true;
      _keyError = null;
    });

    // Validate key with API before saving
    final validationError = await _validateApiKey(key);

    if (!mounted) return;

    if (validationError != null) {
      setState(() {
        _keyError = validationError.userMessage;
        _isSavingKey = false;
      });
      return;
    }

    // Key is valid, save it
    final saveError =
        await _integrationService!.saveApiKey(_activeProvider, key);

    if (!mounted) return;

    if (saveError != null) {
      setState(() {
        _keyError = saveError;
        _isSavingKey = false;
      });
    } else {
      setState(() {
        _hasApiKey = true;
        _maskedKey = _integrationService!.maskedKey(_activeProvider);
        _isEnteringKey = false;
        _isSavingKey = false;
        _apiKeyController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('API key validated and saved.'),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
        ),
      );
    }
  }

  Future<void> _toggleAiEnabled(bool enabled) async {
    if (_integrationService == null) return;
    await _integrationService!.setEnabled(enabled);
    if (mounted) {
      setState(() => _aiEnabled = enabled);
    }
  }

  void _confirmDeleteKey() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Remove API key?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
        content: Text(
          'This will disable ${_activeProvider.displayName} integration and remove your saved key.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _integrationService?.deleteApiKey(_activeProvider);
              if (mounted) {
                setState(() {
                  _hasApiKey = false;
                  _maskedKey = null;
                  _aiEnabled = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('API key removed.'),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                );
              }
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFCF6679)),
            ),
          ),
        ],
      ),
    );
  }

  void _onKeyFieldPaste() {
    // Clear clipboard after paste for security
    Future.delayed(const Duration(milliseconds: 100), () {
      AiIntegrationService.clearClipboard();
    });
  }

  Future<void> _changeModel(String model) async {
    await _integrationService?.setModel(_activeProvider, model);
    if (mounted) {
      setState(() => _selectedModel = model);
    }
  }

  void _showDailyCapDialog() {
    final controller = TextEditingController(
      text: _dailyCap > 0 ? (_dailyCap ~/ 1000).toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Daily token limit',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a daily limit (in thousands of tokens) to control costs. Leave empty for no limit.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              decoration: InputDecoration(
                hintText: 'e.g., 100 for 100K tokens',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                suffixText: 'K tokens',
                suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final text = controller.text.trim();
              final cap = text.isEmpty ? 0 : (int.tryParse(text) ?? 0) * 1000;
              await _usageService?.setDailyCap(cap);
              if (mounted) {
                setState(() => _dailyCap = cap);
              }
            },
            child: Text(
              'Save',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTestData() async {
    final fs = await FileService.getInstance();
    await SyntheticDataService.generateWeek(fs);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Test week generated.'),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
        ),
      );
    }
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Reset vault?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
        content: Text(
          'This will delete all logged entries. This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final fs = await FileService.getInstance();
              await fs.resetVault();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Vault reset.'),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                );
              }
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Color(0xFFCF6679)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface.withValues(alpha: 0.7)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.7),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection(
            'Vault location',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _vaultPath,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _changeVaultPath,
                  child: Text(
                    'Change',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSection(
            'Obsidian compatibility',
            Text(
              'All entries are stored as Markdown files. '
              'Copy the Lila folder into your Obsidian vault to view them.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSection(
            'AI & Integrations',
            _buildAiSection(),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            _buildSection(
              'Debug',
              TextButton(
                onPressed: _generateTestData,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Generate test week',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 48),
          TextButton(
            onPressed: _confirmReset,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Reset vault',
              style: TextStyle(
                color: Color(0xFFCF6679),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection() {
    final availableModels = _activeProvider.availableModels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Provider',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            DropdownButton<AiProvider>(
              value: _activeProvider,
              dropdownColor: const Color(0xFF2A2A2A),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              items: AiProvider.values.map((provider) {
                return DropdownMenuItem(
                  value: provider,
                  child: Text(provider.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _setActiveProvider(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Toggle row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI integration',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            Switch(
              value: _aiEnabled,
              onChanged: _hasApiKey ? _toggleAiEnabled : null,
              activeThumbColor: const Color(0xFF6B8AFF),
              activeTrackColor: const Color(0xFF6B8AFF).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.white.withValues(alpha: 0.3),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            ),
          ],
        ),

        // Status text
        if (!_hasApiKey && !_isEnteringKey)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Enter an API key below to enable.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Key display or input
        if (_hasApiKey && !_isEnteringKey) ...[
          // Masked key display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.key,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _maskedKey ?? '***',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Change and Remove buttons
          Row(
            children: [
              GestureDetector(
                onTap: _startKeyEntry,
                child: Text(
                  'Change key',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _confirmDeleteKey,
                child: const Text(
                  'Remove key',
                  style: TextStyle(
                    color: Color(0xFFCF6679),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Key input field
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus && _apiKeyController.text.isNotEmpty) {
                // Clear clipboard when focus is lost after pasting
                AiIntegrationService.clearClipboard();
              }
            },
            child: TextField(
              controller: _apiKeyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: _activeProvider.keyHint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontFamily: 'monospace',
                ),
                errorText: _keyError,
                errorStyle: const TextStyle(color: Color(0xFFCF6679)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                // Trim whitespace and newlines on paste
                final trimmed = value.trim().replaceAll('\n', '');
                if (trimmed != value) {
                  _apiKeyController.text = trimmed;
                  _apiKeyController.selection = TextSelection.fromPosition(
                    TextPosition(offset: trimmed.length),
                  );
                  _onKeyFieldPaste();
                }
                // Clear error when typing
                if (_keyError != null) {
                  setState(() => _keyError = null);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          // Save and Cancel buttons
          Row(
            children: [
              ElevatedButton(
                onPressed: _isSavingKey ? null : _saveApiKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSavingKey
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save key'),
              ),
              if (_hasApiKey || _isEnteringKey) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _cancelKeyEntry,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],

        // Model selector and usage (only show when key is saved)
        if (_hasApiKey && !_isEnteringKey) ...[
          const SizedBox(height: 24),
          // Model selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Model',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              DropdownButton<String>(
                value: _selectedModel,
                dropdownColor: const Color(0xFF2A2A2A),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                items: availableModels.map((model) {
                  return DropdownMenuItem(
                    value: model.$1,
                    child: Text(model.$2),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) _changeModel(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Usage display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Usage',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              Text(
                _usageSummary,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Daily cap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily limit',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: _showDailyCapDialog,
                child: Row(
                  children: [
                    Text(
                      _dailyCap > 0
                          ? AiUsageService.formatTokens(_dailyCap)
                          : 'No limit',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        Text(
          'Your API key is stored securely on this device and never sent anywhere except to your selected provider.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'API keys are sensitive. Client-side use can expose them, so consider restricting keys in your provider settings.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
