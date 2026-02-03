import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ArmedSwipeToDelete extends StatefulWidget {
  final Key dismissKey;
  final Widget child;
  final Future<void> Function() onDelete;
  final String? semanticsLabel;

  const ArmedSwipeToDelete({
    required this.dismissKey,
    required this.child,
    required this.onDelete,
    this.semanticsLabel,
    super.key,
  });

  @override
  State<ArmedSwipeToDelete> createState() => _ArmedSwipeToDeleteState();
}

class _ArmedSwipeToDeleteState extends State<ArmedSwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const double _revealWidth = 96;
  static const double _revealThreshold = 16;

  late final AnimationController _controller;
  late Animation<double> _offsetAnimation;
  double _currentOffset = 0;
  bool _revealed = false;
  final GlobalKey _deletePillKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  void _animateTo(double target) {
    _offsetAnimation = Tween<double>(begin: _currentOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller
      ..reset()
      ..forward();
  }

  void _handleDragStart(DragStartDetails details) {
    if (_revealed) return;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_revealed) return;
    final next =
        (_currentOffset + details.delta.dx).clamp(-_revealWidth, 0.0);
    setState(() => _currentOffset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_revealed) return;
    if (_currentOffset <= -_revealThreshold) {
      HapticFeedback.selectionClick();
      _revealed = true;
      _animateTo(-_revealWidth);
    } else {
      _animateTo(0);
    }
  }

  Future<void> _handleDelete() async {
    _revealed = false;
    _animateTo(0);
    await widget.onDelete();
  }

  void _dismissReveal() {
    if (_revealed) {
      _revealed = false;
      _animateTo(0);
    }
  }

  bool _isPointerOnDelete(Offset position) {
    final context = _deletePillKey.currentContext;
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
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _revealed
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _revealed
              ? const Color(0xFFA87B6B).withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: widget.child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final showBackground = _currentOffset < 0;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (_revealed && !_isPointerOnDelete(event.position)) {
              _dismissReveal();
            }
          },
          child: GestureDetector(
            key: const ValueKey('armed_swipe_container'),
            onTap: _dismissReveal,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            behavior: HitTestBehavior.translucent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  AnimatedOpacity(
                    opacity: showBackground ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: SizedBox(
                      width: width,
                      child: _buildDeleteBackground(context),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: Transform.translate(
                      offset: Offset(_currentOffset, 0),
                      child: child,
                    ),
                  ),
                  AnimatedOpacity(
                    key: const ValueKey('armed_delete_opacity'),
                    opacity: _revealed ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: _handleDelete,
                        child: SizedBox(
                          key: _deletePillKey,
                          child: Container(
                            key: const ValueKey('armed_delete_pill'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA87B6B)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFA87B6B)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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

  Widget _buildDeleteBackground(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFA87B6B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
