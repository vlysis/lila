import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../services/synthetic_data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _vaultPath = '';

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    final fs = await FileService.getInstance();
    if (mounted) setState(() => _vaultPath = fs.rootDir);
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white.withValues(alpha: 0.7)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
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
            Text(
              _vaultPath,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
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
