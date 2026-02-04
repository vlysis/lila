import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/focus_state.dart';
import '../services/focus_controller.dart';
import '../services/intention_service.dart';

class IntentionFlowScreen extends StatefulWidget {
  final FocusState? initialState;
  final Future<void> Function(FocusState state)? onSave;
  final FocusController? focusController;

  const IntentionFlowScreen({
    super.key,
    this.initialState,
    this.onSave,
    this.focusController,
  });

  @override
  State<IntentionFlowScreen> createState() => _IntentionFlowScreenState();
}

class _IntentionFlowScreenState extends State<IntentionFlowScreen>
    with TickerProviderStateMixin {
  FocusSeason? _selectedSeason;
  late final TextEditingController _intentionController;
  late final AnimationController _holdController;
  late final AnimationController _appliedController;
  Timer? _hapticTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.initialState?.season;
    _intentionController = TextEditingController(
      text: widget.initialState?.intention ?? '',
    );
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completeHold();
        }
      });
    _appliedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _holdController.dispose();
    _appliedController.dispose();
    _intentionController.dispose();
    super.dispose();
  }

  bool get _hasIntention => _intentionController.text.trim().isNotEmpty;

  _FlowTheme _themeFor(FocusSeason season) {
    switch (season) {
      case FocusSeason.builder:
        return const _FlowTheme(
          surface: Color(0xFF1B2B2E),
          border: Color(0xFF2E6F77),
          accent: Color(0xFFD6B25E),
          muted: Color(0xFF6E8B8F),
          radius: 12,
        );
      case FocusSeason.sanctuary:
        return const _FlowTheme(
          surface: Color(0xFF2B2723),
          border: Color(0xFF6D8570),
          accent: Color(0xFFB07A63),
          muted: Color(0xFF7A7F72),
          radius: 20,
        );
    }
  }

  Future<void> _save(FocusState state) async {
    if (widget.onSave != null) {
      await widget.onSave!(state);
      return;
    }
    final service = await IntentionService.getInstance();
    await service.setCurrent(state);
  }

  Future<void> _applyState(
    FocusState state, {
    bool popWhenDone = false,
  }) async {
    widget.focusController?.update(state);
    await _save(state);
    if (popWhenDone && mounted) {
      Navigator.pop(context, state);
    }
  }

  void _startHold() {
    if (_saving || _selectedSeason == null) return;
    _holdController.forward(from: 0);
    _startHaptics();
  }

  void _cancelHold() {
    _hapticTimer?.cancel();
    _holdController.animateBack(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _startHaptics() {
    _hapticTimer?.cancel();
    _scheduleHaptic();
  }

  void _showAppliedPulse() {
    _appliedController.forward(from: 0);
  }

  void _scheduleHaptic() {
    if (!_holdController.isAnimating) return;
    final progress = _holdController.value;
    final intervalMs = lerpDouble(420, 200, progress)!.round();
    _hapticTimer = Timer(Duration(milliseconds: intervalMs), () {
      HapticFeedback.selectionClick();
      _scheduleHaptic();
    });
  }

  Future<void> _completeHold() async {
    if (_saving || _selectedSeason == null) return;
    _hapticTimer?.cancel();
    setState(() => _saving = true);

    final state = FocusState(
      season: _selectedSeason!,
      intention: _intentionController.text.trim(),
      setAt: DateTime.now(),
    );

    await _applyState(state, popWhenDone: true);
  }

  @override
  Widget build(BuildContext context) {
    final season = _selectedSeason;
    final theme = season != null
        ? _themeFor(season)
        : const _FlowTheme(
            surface: Color(0xFF1F1F1F),
            border: Color(0xFF3A3A3A),
            accent: Color(0xFF7B9EA8),
            muted: Color(0xFF5A5A5A),
            radius: 16,
          );

    final appTheme = Theme.of(context);
    final onSurface = appTheme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Intention',
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.9),
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildSeasonOption(FocusSeason.builder),
                      const SizedBox(width: 16),
                      _buildSeasonOption(FocusSeason.sanctuary),
                    ],
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: season == null
                        ? const SizedBox.shrink()
                        : _buildCommitment(theme, season),
                  ),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: season != null
                        ? _buildConfirm(theme)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeasonOption(FocusSeason season) {
    final isSelected = _selectedSeason == season;
    final theme = _themeFor(season);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedSeason = season);
          final state = FocusState(
            season: season,
            intention: _intentionController.text.trim(),
            setAt: DateTime.now(),
          );
          _applyState(state);
          _showAppliedPulse();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface.withValues(alpha: isSelected ? 0.9 : 0.5),
            borderRadius: BorderRadius.circular(theme.radius + 8),
            border: Border.all(
              color: theme.border.withValues(alpha: isSelected ? 0.8 : 0.3),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  season == FocusSeason.builder
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined,
                  color: theme.accent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                season == FocusSeason.builder ? 'Builder' : 'Sanctuary',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                season.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommitment(_FlowTheme theme, FocusSeason season) {
    return Column(
      key: ValueKey('commitment_${season.storageValue}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          season == FocusSeason.builder
              ? 'Define your focus'
              : 'Define your boundary',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          season == FocusSeason.builder
              ? 'What one project or skill is your priority for this season?'
              : 'What activity or stressor are you giving yourself permission to ignore?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('intention_input'),
          controller: _intentionController,
          onChanged: (_) => setState(() {}),
          minLines: 2,
          maxLines: 3,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: season.prompt,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontStyle: FontStyle.italic,
            ),
            filled: true,
            fillColor: theme.surface.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.radius),
              borderSide: BorderSide(
                color: theme.border.withValues(alpha: 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.radius),
              borderSide: BorderSide(
                color: theme.border.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.radius),
              borderSide: BorderSide(
                color: theme.accent.withValues(alpha: 0.8),
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirm(_FlowTheme theme) {
    final enabled = !_saving;
    return Column(
      key: const ValueKey('confirm_section'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _appliedController,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_appliedController.value);
            final opacity = (1 - t).clamp(0.0, 1.0);
            final scale = 0.96 + (t * 0.08);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Applied',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          key: const ValueKey('intention_confirm'),
          onLongPressStart: enabled ? (_) => _startHold() : null,
          onLongPressEnd: enabled ? (_) => _cancelHold() : null,
          onLongPressCancel: enabled ? _cancelHold : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: AnimatedBuilder(
                  animation: _holdController,
                  builder: (context, _) {
                    return CircularProgressIndicator(
                      value: _holdController.value,
                      strokeWidth: 4,
                      color: theme.accent.withValues(alpha: 0.9),
                      backgroundColor: theme.accent.withValues(alpha: 0.2),
                    );
                  },
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.surface.withValues(alpha: enabled ? 0.85 : 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.border.withValues(alpha: enabled ? 0.8 : 0.3),
                  ),
                ),
                child: Icon(
                  Icons.touch_app_outlined,
                  color: Colors.white.withValues(alpha: enabled ? 0.75 : 0.35),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _hasIntention ? 'Hold to confirm' : 'Hold to confirm (optional)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: enabled ? 0.5 : 0.35),
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _FlowTheme {
  final Color surface;
  final Color border;
  final Color accent;
  final Color muted;
  final double radius;

  const _FlowTheme({
    required this.surface,
    required this.border,
    required this.accent,
    required this.muted,
    required this.radius,
  });
}
