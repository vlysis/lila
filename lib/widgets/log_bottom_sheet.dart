import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/log_entry.dart';
import '../services/file_service.dart';
import '../theme/lila_theme.dart';

class LogBottomSheet extends StatefulWidget {
  final VoidCallback onLogged;
  final DateTime? date;
  final LogEntry? editEntry;

  const LogBottomSheet({
    super.key,
    required this.onLogged,
    this.date,
    this.editEntry,
  });

  @override
  State<LogBottomSheet> createState() => _LogBottomSheetState();
}

class _LogBottomSheetState extends State<LogBottomSheet> {
  Mode? _selectedMode;
  LogOrientation? _selectedOrientation;
  DurationPreset? _selectedDuration;
  String? _label;
  List<String> _recentLabels = [];
  bool _showLabel = false;
  bool _saving = false;

  bool get _isEditMode => widget.editEntry != null;

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
    Mode.decay: 'assets/icons/decay.png',
  };

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final e = widget.editEntry!;
      _selectedMode = e.mode;
      _selectedOrientation = e.orientation;
      _selectedDuration = e.duration;
      _label = e.label;
      _showLabel = true;
    }
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

    if (_isEditMode) {
      final newEntry = LogEntry(
        label: _label,
        mode: _selectedMode!,
        orientation: _selectedOrientation!,
        duration: _selectedDuration,
        season: widget.editEntry!.season,
        timestamp: widget.editEntry!.timestamp,
      );

      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.of(context).pop(newEntry);
      }
      return;
    }

    final now = DateTime.now();
    final ts = widget.date != null
        ? DateTime(widget.date!.year, widget.date!.month, widget.date!.day,
            now.hour, now.minute, now.second)
        : now;

    final entry = LogEntry(
      label: _label,
      mode: _selectedMode!,
      orientation: _selectedOrientation!,
      duration: _selectedDuration,
      timestamp: ts,
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
      // Clear duration if mode changes (spec: previously selected duration is cleared)
      _selectedDuration = null;
    });
  }

  void _selectOrientation(LogOrientation orientation) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedOrientation = orientation;
      // Now proceed to duration selection (duration is optional, shown before label)
    });
  }

  void _selectDuration(DurationPreset? duration) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDuration = duration;
      _showLabel = true;
    });
  }

  void _skipDuration() {
    setState(() {
      _selectedDuration = null;
      _showLabel = true;
    });
  }

  void _editMode() {
    setState(() {
      _selectedMode = null;
      _selectedOrientation = null;
      _selectedDuration = null;
      _showLabel = false;
    });
  }

  void _editOrientation() {
    setState(() {
      _selectedOrientation = null;
      _selectedDuration = null;
      _showLabel = false;
    });
  }

  void _editDuration() {
    setState(() {
      _selectedDuration = null;
      _showLabel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = context.lilaRadii;
    return AnimatedPadding(
      key: const ValueKey('log_sheet_inset_padding'),
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor ??
              colorScheme.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radii.large)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(radii.small),
                ),
              ),
              const SizedBox(height: 24),

            // Mode selection
            if (_selectedMode == null) ...[
              Text(
                'What kind of moment?',
                style: TextStyle(
                  color: context.lilaSurface.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              _buildModeGrid(),
            ],

            // Orientation selection
            if (_selectedMode != null && _selectedOrientation == null) ...[
              _buildSelectedModeBadge(tappable: _isEditMode),
              const SizedBox(height: 24),
              Text(
                'Directed toward?',
                style: TextStyle(
                  color: context.lilaSurface.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildOrientationSelector(),
            ],

            // Duration selection (optional)
            if (_selectedMode != null &&
                _selectedOrientation != null &&
                !_showLabel) ...[
              _buildSelectedModeBadge(tappable: _isEditMode),
              const SizedBox(height: 8),
              _buildSelectedOrientationBadge(tappable: _isEditMode),
              const SizedBox(height: 24),
              Text(
                'How long?',
                style: TextStyle(
                  color: context.lilaSurface.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildDurationSelector(),
              const SizedBox(height: 16),
              _buildSkipDurationButton(),
            ],

            // Optional label
            if (_selectedMode != null &&
                _selectedOrientation != null &&
                _showLabel) ...[
              _buildSelectedModeBadge(tappable: _isEditMode),
              const SizedBox(height: 8),
              _buildSelectedOrientationBadge(tappable: _isEditMode),
              if (_selectedDuration != null) ...[
                const SizedBox(height: 8),
                _buildSelectedDurationBadge(tappable: _isEditMode),
              ],
              const SizedBox(height: 24),
              _buildLabelInput(),
              const SizedBox(height: 16),
              _buildSaveButton(),
            ],
            ],
          ),
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
        final color = context.lilaPalette.modeColor(mode);
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

  Widget _buildSelectedModeBadge({bool tappable = false}) {
    final mode = _selectedMode!;
    final color = context.lilaPalette.modeColor(mode);
    final badge = Container(
      key: const ValueKey('mode_badge'),
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

    if (tappable) {
      return GestureDetector(onTap: _editMode, child: badge);
    }
    return badge;
  }

  Widget _buildOrientationSelector() {
    final s = context.lilaSurface;
    return Row(
      children: LogOrientation.values.map((o) {
        final isSelected = _selectedOrientation == o;
        final iconColor = isSelected
            ? s.foreground
            : s.textMuted;
        return Expanded(
          child: GestureDetector(
            onTap: () => _selectOrientation(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? s.overlay
                    : s.overlay.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? s.borderSubtle
                      : s.borderSubtle.withValues(alpha: 0.08),
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

  Widget _buildSelectedOrientationBadge({bool tappable = false}) {
    final s = context.lilaSurface;
    final o = _selectedOrientation!;
    final badge = Container(
      key: const ValueKey('orientation_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: s.overlay,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            _orientationAssets[o]!,
            width: 18,
            height: 18,
            color: s.textSecondary,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 6),
          Text(
            o.label,
            style: TextStyle(
              color: s.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    if (tappable) {
      return GestureDetector(onTap: _editOrientation, child: badge);
    }
    return badge;
  }

  Widget _buildDurationSelector() {
    final s = context.lilaSurface;
    final presets = _selectedMode!.durationPresets;
    final modeColor = context.lilaPalette.modeColor(_selectedMode!);
    return Row(
      children: presets.map((preset) {
        final isSelected = _selectedDuration == preset;
        return Expanded(
          child: GestureDetector(
            onTap: () => _selectDuration(preset),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? modeColor.withValues(alpha: 0.2)
                    : s.overlay.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? modeColor.withValues(alpha: 0.4)
                      : s.borderSubtle.withValues(alpha: 0.08),
                ),
              ),
              child: Center(
                child: Text(
                  preset.label,
                  style: TextStyle(
                    color: isSelected
                        ? modeColor
                        : s.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkipDurationButton() {
    return GestureDetector(
      onTap: _skipDuration,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Skip',
          style: TextStyle(
            color: context.lilaSurface.textMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDurationBadge({bool tappable = false}) {
    final d = _selectedDuration!;
    final modeColor = context.lilaPalette.modeColor(_selectedMode!);
    final badge = Container(
      key: const ValueKey('duration_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: modeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        d.label,
        style: TextStyle(
          color: modeColor.withValues(alpha: 0.8),
          fontSize: 13,
        ),
      ),
    );

    if (tappable) {
      return GestureDetector(onTap: _editDuration, child: badge);
    }
    return badge;
  }

  Widget _buildLabelInput() {
    final s = context.lilaSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          autofocus: false,
          style: TextStyle(color: s.foreground),
          controller: _isEditMode
              ? (TextEditingController(text: _label ?? '')
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: (_label ?? '').length)))
              : null,
          decoration: InputDecoration(
            hintText: 'What was it?',
            hintStyle: TextStyle(color: s.textFaint),
            filled: true,
            fillColor: s.overlay.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (v) => setState(() => _label = v),
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
                    color: s.overlay,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: s.textSecondary,
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
    final s = context.lilaSurface;
    final buttonText = _isEditMode
        ? 'Save'
        : (_label?.isNotEmpty == true ? 'Log' : 'Log without label');
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        key: const ValueKey('log_save_button'),
        onPressed: _saving ? null : _saveEntry,
        style: TextButton.styleFrom(
          backgroundColor: s.overlay,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            color: s.textSecondary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
