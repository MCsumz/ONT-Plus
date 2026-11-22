import 'dart:async';

import 'package:flutter/material.dart';

/// Lets Home move between days by swiping: the page follows the finger, and
/// a swipe far or fast enough slides it out, asks [onChangeDay] for the
/// next (left) or previous (right) day, and slides that day in from the
/// other side once [day] changes.
///
/// A swipe that starts on a logged food goes to that row (swipe to delete)
/// instead, because the innermost horizontal gesture wins.
class HomeDaySwiper extends StatefulWidget {
  /// The day shown; a change slides the new content in.
  final DateTime day;

  /// Moves by [delta] days (+1 next, -1 previous). Returns false when Home
  /// cannot go that way, and the page springs back.
  final bool Function(int delta) onChangeDay;

  final Widget child;

  const HomeDaySwiper({
    super.key,
    required this.day,
    required this.onChangeDay,
    required this.child,
  });

  @override
  State<HomeDaySwiper> createState() => _HomeDaySwiperState();
}

class _HomeDaySwiperState extends State<HomeDaySwiper>
    with SingleTickerProviderStateMixin {
  static const _commitFraction = 0.28;
  static const _flingVelocity = 650.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<double>? _animation;
  double _dx = 0;
  double _width = 1;

  /// Set while the old day slides out and the new one is awaited: the
  /// side (-1 left, +1 right) it left by.
  int? _leftBy;

  /// Brings the page back if the new day never arrives, so Home cannot be
  /// left slid off screen.
  Timer? _arrivalTimeout;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final animation = _animation;
      if (animation != null) setState(() => _dx = animation.value);
    });
  }

  @override
  void didUpdateWidget(covariant HomeDaySwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.day, widget.day)) {
      // The new day enters from the side opposite to where the old one
      // left; a change from the date bar enters by its direction too.
      final from = _leftBy != null
          ? -_leftBy!
          : (widget.day.isAfter(oldWidget.day) ? 1 : -1);
      _leftBy = null;
      _arrivalTimeout?.cancel();
      _dx = from * _width;
      _animateTo(0);
    }
  }

  @override
  void dispose() {
    _arrivalTimeout?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target, {VoidCallback? onDone}) {
    _animation = Tween<double>(begin: _dx, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..reset()
      ..forward().whenComplete(() => onDone?.call());
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_leftBy != null) return;
    _controller.stop();
    setState(() => _dx += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_leftBy != null) return;
    final velocity = details.primaryVelocity ?? 0;
    final far = _dx.abs() > _width * _commitFraction;
    final fast = velocity.abs() > _flingVelocity;
    if (!far && !fast) {
      _animateTo(0);
      return;
    }
    // Left (negative) goes forward in time, like turning a page.
    final side = (fast ? velocity : _dx) < 0 ? -1 : 1;
    final delta = -side;
    _leftBy = side;
    _animateTo(
      side * _width,
      onDone: () {
        if (!mounted) return;
        if (!widget.onChangeDay(delta)) {
          _leftBy = null;
          _animateTo(0);
          return;
        }
        _arrivalTimeout?.cancel();
        _arrivalTimeout = Timer(const Duration(seconds: 2), () {
          if (!mounted || _leftBy == null) return;
          _leftBy = null;
          _animateTo(0);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final progress = (_dx.abs() / _width).clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: () {
            if (_leftBy == null) _animateTo(0);
          },
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(_dx, 0),
              child: Opacity(
                opacity: 1 - progress * 0.35,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
