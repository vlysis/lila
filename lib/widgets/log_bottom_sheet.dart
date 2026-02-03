import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';

class LogBottomSheet extends StatefulWidget {
  final VoidCallback onLogged;

  const LogBottomSheet({super.key, required this.onLogged});

  @override
  State<LogBottomSheet> createState() => _LogBottomSheetState();
}

class _LogBottomSheetState extends State<LogBottomSheet> {
  Mode? _selectedMode;
  LogOrientation? _selectedOrientation;
  String? _label;
  List<String> _recentLabels = [];
  bool _showLabel = false;
  bool _saving = false;

  static const _modeColors = {
    Mode.nourishment: Color(0xFF6B8F71),
    Mode.growth: Color(0xFF7B9EA8),
    Mode.maintenance: Color(0xFFA8976B),
    Mode.drift: Color(0xFF8B7B8B),
  };

  static const _orientationAssets = {
    LogOrientation.self_: 'assets/icons/self.png',
    LogOrientation.mutual: 'assets/icons/mutual.png',
    LogOrientation.other: 'assets/icons/other.png',
  };

  static const _modeAssets = {
    Mode.nourishment: 'assets/icons/nourishment.png',
    Mode.growth: 'assets/icons/growth.png',
    Mode.maintenance: 'assets/icons/maintenence.png',
    Mode.drift: 'assets/icons/drift.png',
  };

  @override
  void initState() {
    super.initState();
    _loadRecentLabels();
  }

  Future<void> _loadRecentLabels() async {
    final fs = await FileService.getInstance();
    final labels = await fs.getRecentLabels();
    if (mounted) {
      setState(() => _recentLabels = labels);
    }
  }

  Future<void> _saveEntry() async {
    if (_selectedMode == null || _selectedOrientation == null || _saving) return;

    setState(() => _saving = true);

    final entry = LogEntry(
      label: _label,
      mode: _selectedMode!,
      orientation: _selectedOrientation!,
      timestamp: DateTime.now(),
    );

    final fs = await FileService.getInstance();
    await fs.appendEntry(entry);

    HapticFeedback.mediumImpact();

    if (mounted) {
      widget.onLogged();
      Navigator.of(context).pop();
    }
  }

  void _selectMode(Mode mode) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedMode = mode;
    });
  }

  void _selectOrientation(LogOrientation orientation) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedOrientation = orientation;
      _showLabel = true;
    });
    // Auto-save after a brief moment to allow optional label
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _selectedMode != null && _selectedOrientation != null && !_showLabel) {
        _saveEntry();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Mode selection
            if (_selectedMode == null) ...[
              Text(
                'What kind of moment?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              _buildModeGrid(),
            ],

            // Orientation selection
            if (_selectedMode != null && _selectedOrientation == null) ...[
              _buildSelectedModeBadge(),
              const SizedBox(height: 24),
              Text(
                'Directed toward?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildOrientationSelector(),
            ],

            // Optional label
            if (_selectedMode != null &&
                _selectedOrientation != null &&
                _showLabel) ...[
              _buildSelectedModeBadge(),
              const SizedBox(height: 8),
              _buildSelectedOrientationBadge(),
              const SizedBox(height: 24),
              _buildLabelInput(),
              const SizedBox(height: 16),
              _buildSaveButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: Mode.values.map((mode) {
        final color = _modeColors[mode]!;
        final asset = _modeAssets[mode]!;
        return GestureDetector(
          onTap: () => _selectMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(asset, width: 42, height: 42,
                  color: color, colorBlendMode: BlendMode.srcIn),
                const SizedBox(width: 10),
                Text(
                  mode.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedModeBadge() {
    final mode = _selectedMode!;
    final color = _modeColors[mode]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(_modeAssets[mode]!, width: 33, height: 33,
            color: color, colorBlendMode: BlendMode.srcIn),
          const SizedBox(width: 8),
          Text(
            mode.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOrientationSelector() {
    return Row(
      children: LogOrientation.values.map((o) {
        final isSelected = _selectedOrientation == o;
        final iconColor = isSelected
            ? Colors.white
            : Colors.white.withValues(alpha: 0.5);
        return Expanded(
          child: GestureDetector(
            onTap: () => _selectOrientation(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    _orientationAssets[o]!,
                    width: 28,
                    height: 28,
                    color: iconColor,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    o.label,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedOrientationBadge() {
    final o = _selectedOrientation!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            _orientationAssets[o]!,
            width: 18,
            height: 18,
            color: Colors.white.withValues(alpha: 0.6),
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 6),
          Text(
            o.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          autofocus: false,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'What was it?',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (v) => _label = v,
        ),
        if (_recentLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentLabels.map((label) {
              return GestureDetector(
                onTap: () {
                  setState(() => _label = label);
                  _saveEntry();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _saving ? null : _saveEntry,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _label?.isNotEmpty == true ? 'Log' : 'Log without label',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
