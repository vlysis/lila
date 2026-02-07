import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/lila_theme.dart';

class ArmedSwipeToDelete extends StatefulWidget {
  final Key dismissKey;
  final Widget child;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onEdit;
  final String? semanticsLabel;

  const ArmedSwipeToDelete({
    required this.dismissKey,
    required this.child,
    required this.onDelete,
    this.onEdit,
    this.semanticsLabel,
    super.key,
  });

  @override
  State<ArmedSwipeToDelete> createState() => _ArmedSwipeToDeleteState();
}

enum _RevealSide { none, delete, edit }

class _ArmedSwipeToDeleteState extends State<ArmedSwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const double _revealWidth = 96;
  static const double _revealThreshold = 16;

  late final AnimationController _controller;
  late Animation<double> _offsetAnimation;
  double _currentOffset = 0;
  _RevealSide _revealSide = _RevealSide.none;
  final GlobalKey _deletePillKey = GlobalKey();
  final GlobalKey _editPillKey = GlobalKey();

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

  bool get _hasEdit => widget.onEdit != null;

  double get _minOffset => -_revealWidth;
  double get _maxOffset => _hasEdit ? _revealWidth : 0.0;

  void _animateTo(double target) {
    _offsetAnimation = Tween<double>(begin: _currentOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller
      ..reset()
      ..forward();
  }

  void _handleDragStart(DragStartDetails details) {
    if (_revealSide != _RevealSide.none) return;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_revealSide != _RevealSide.none) return;
    final next =
        (_currentOffset + details.delta.dx).clamp(_minOffset, _maxOffset);
    setState(() => _currentOffset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_revealSide != _RevealSide.none) return;
    if (_currentOffset <= -_revealThreshold) {
      HapticFeedback.selectionClick();
      _revealSide = _RevealSide.delete;
      _animateTo(-_revealWidth);
    } else if (_hasEdit && _currentOffset >= _revealThreshold) {
      HapticFeedback.selectionClick();
      _revealSide = _RevealSide.edit;
      _animateTo(_revealWidth);
    } else {
      _animateTo(0);
    }
  }

  Future<void> _handleDelete() async {
    _revealSide = _RevealSide.none;
    _animateTo(0);
    await widget.onDelete();
  }

  Future<void> _handleEdit() async {
    _revealSide = _RevealSide.none;
    _animateTo(0);
    await widget.onEdit!();
  }

  void _dismissReveal() {
    if (_revealSide != _RevealSide.none) {
      _revealSide = _RevealSide.none;
      _animateTo(0);
    }
  }

  bool _isPointerOnPill(Offset position, GlobalKey key) {
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
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _revealSide != _RevealSide.none
            ? context.lilaSurface.overlay.withValues(alpha: 0.03)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(radii.medium),
        border: Border.all(
          color: _revealSide == _RevealSide.delete
              ? const Color(0xFFA87B6B).withValues(alpha: 0.35)
              : _revealSide == _RevealSide.edit
                  ? const Color(0xFF718096).withValues(alpha: 0.35)
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
        final showDeleteBg = _currentOffset < 0;
        final showEditBg = _currentOffset > 0;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (_revealSide != _RevealSide.none &&
                !_isPointerOnPill(event.position, _deletePillKey) &&
                !_isPointerOnPill(event.position, _editPillKey)) {
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
              borderRadius: BorderRadius.circular(radii.medium),
              child: Stack(
                children: [
                  // Delete background (right side)
                  if (showDeleteBg)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 120),
                        child: SizedBox(
                          width: width,
                          child: _buildDeleteBackground(context),
                        ),
                      ),
                    ),
                  // Edit background (left side)
                  if (showEditBg)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 120),
                        child: SizedBox(
                          width: width,
                          child: _buildEditBackground(context),
                        ),
                      ),
                    ),
                  // Main content
                  SizedBox(
                    width: width,
                    child: Transform.translate(
                      offset: Offset(_currentOffset, 0),
                      child: child,
                    ),
                  ),
                  // Delete pill (right side)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      key: const ValueKey('armed_delete_opacity'),
                      opacity: _revealSide == _RevealSide.delete ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Center(
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
                                borderRadius: BorderRadius.circular(radii.small),
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
                                    color: context.lilaSurface.textSecondary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: context.lilaSurface.textSecondary,
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
                  ),
                  // Edit pill (left side)
                  if (_hasEdit)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: AnimatedOpacity(
                        key: const ValueKey('armed_edit_opacity'),
                        opacity: _revealSide == _RevealSide.edit ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Center(
                          child: GestureDetector(
                            onTap: _handleEdit,
                            child: SizedBox(
                              key: _editPillKey,
                              child: Container(
                                key: const ValueKey('armed_edit_pill'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF718096)
                                      .withValues(alpha: 0.18),
                                  borderRadius:
                                      BorderRadius.circular(radii.small),
                                  border: Border.all(
                                    color: const Color(0xFF718096)
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      color: context.lilaSurface.textSecondary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: context.lilaSurface.textSecondary,
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
    final radii = context.lilaRadii;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFA87B6B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radii.medium),
      ),
    );
  }

  Widget _buildEditBackground(BuildContext context) {
    final radii = context.lilaRadii;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF718096).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radii.medium),
      ),
    );
  }
}
