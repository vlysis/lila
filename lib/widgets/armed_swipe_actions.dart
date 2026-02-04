import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/lila_theme.dart';

enum _RevealSide {
  none,
  left,
  right,
}

class ArmedSwipeActions extends StatefulWidget {
  final Key dismissKey;
  final Widget child;
  final Future<void> Function() onRestore;
  final Future<void> Function() onDelete;

  const ArmedSwipeActions({
    required this.dismissKey,
    required this.child,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  @override
  State<ArmedSwipeActions> createState() => _ArmedSwipeActionsState();
}

class _ArmedSwipeActionsState extends State<ArmedSwipeActions>
    with SingleTickerProviderStateMixin {
  static const double _revealWidth = 96;
  static const double _revealThreshold = 16;

  static const _restoreColor = Color(0xFF6B8F71);
  static const _deleteColor = Color(0xFFA87B6B);

  late final AnimationController _controller;
  late Animation<double> _offsetAnimation;
  double _currentOffset = 0;
  _RevealSide _revealed = _RevealSide.none;
  final GlobalKey _deletePillKey = GlobalKey();
  final GlobalKey _restorePillKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _offsetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() {
        setState(() => _currentOffset = _offsetAnimation.value);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _offsetAnimation = Tween<double>(begin: _currentOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller
      ..reset()
      ..forward();
  }

  void _handleDragStart(DragStartDetails details) {
    if (_revealed != _RevealSide.none) return;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_revealed != _RevealSide.none) return;
    final next = (_currentOffset + details.delta.dx)
        .clamp(-_revealWidth, _revealWidth);
    setState(() => _currentOffset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_revealed != _RevealSide.none) return;
    if (_currentOffset >= _revealThreshold) {
      HapticFeedback.selectionClick();
      _revealed = _RevealSide.left;
      _animateTo(_revealWidth);
    } else if (_currentOffset <= -_revealThreshold) {
      HapticFeedback.selectionClick();
      _revealed = _RevealSide.right;
      _animateTo(-_revealWidth);
    } else {
      _animateTo(0);
    }
  }

  Future<void> _handleRestore() async {
    _revealed = _RevealSide.none;
    _animateTo(0);
    await widget.onRestore();
  }

  Future<void> _handleDelete() async {
    _revealed = _RevealSide.none;
    _animateTo(0);
    await widget.onDelete();
  }

  void _dismissReveal() {
    if (_revealed != _RevealSide.none) {
      _revealed = _RevealSide.none;
      _animateTo(0);
    }
  }

  bool _isPointerOnAction(Offset position) {
    final key = _revealed == _RevealSide.left ? _restorePillKey : _deletePillKey;
    final context = key.currentContext;
    if (context == null) return false;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    final local = box.globalToLocal(position);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
  }

  @override
  Widget build(BuildContext context) {
    final radii = context.lilaRadii;
    final backgroundColor = _currentOffset > 0
        ? _restoreColor.withValues(alpha: 0.15)
        : _currentOffset < 0
            ? _deleteColor.withValues(alpha: 0.15)
            : Colors.transparent;
    final borderColor = _revealed == _RevealSide.left
        ? _restoreColor.withValues(alpha: 0.4)
        : _revealed == _RevealSide.right
            ? _deleteColor.withValues(alpha: 0.4)
            : Colors.transparent;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _revealed == _RevealSide.none
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(radii.medium),
        border: Border.all(color: borderColor),
      ),
      child: widget.child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        final showBackground = _currentOffset.abs() > 0;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (_revealed != _RevealSide.none &&
                !_isPointerOnAction(event.position)) {
              _dismissReveal();
            }
          },
          child: GestureDetector(
            key: const ValueKey('armed_swipe_actions_container'),
            onTap: _dismissReveal,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            behavior: HitTestBehavior.translucent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radii.medium),
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: showBackground ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: SizedBox(
                      width: width,
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(radii.medium),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: Transform.translate(
                      offset: Offset(_currentOffset, 0),
                      child: child,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedOpacity(
                      key: const ValueKey('armed_restore_opacity'),
                      opacity: _revealed == _RevealSide.left ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: _handleRestore,
                          child: SizedBox(
                            key: _restorePillKey,
                            child: _buildActionPill(
                              label: 'Restore',
                              icon: Icons.undo_rounded,
                              color: _restoreColor,
                              key: const ValueKey('armed_restore_pill'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      key: const ValueKey('armed_delete_opacity'),
                      opacity: _revealed == _RevealSide.right ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: _handleDelete,
                          child: SizedBox(
                            key: _deletePillKey,
                            child: _buildActionPill(
                              label: 'Delete',
                              icon: Icons.delete_outline,
                              color: _deleteColor,
                              key: const ValueKey('armed_delete_pill'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionPill({
    required String label,
    required IconData icon,
    required Color color,
    required Key key,
  }) {
    final radii = context.lilaRadii;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(radii.small),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
