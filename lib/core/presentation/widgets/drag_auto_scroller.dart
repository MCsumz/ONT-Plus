import 'dart:async';

import 'package:flutter/widgets.dart';

/// Scrolls the page while a dragged entry is held near its top or bottom
/// edge, so an entry can be carried from Breakfast down to Dinner (or back)
/// on a page taller than the screen.
///
/// One shared instance outlives the dragged row: a list section scrolled far
/// enough off screen is disposed mid-drag, and the scrolling has to carry on
/// until the drop. [stop] is therefore wired to the draggable's
/// `onDragCompleted` / `onDraggableCanceled`, which still fire after the
/// source row is gone, unlike `onDragEnd`.
class DragAutoScroller {
  DragAutoScroller._();

  static final DragAutoScroller instance = DragAutoScroller._();

  /// Distance from an edge, in logical pixels, where scrolling starts.
  static const double _edgeExtent = 88;

  /// Scroll step per frame at the very edge; it eases in from zero.
  static const double _maxStep = 16;

  ScrollPosition? _position;
  Rect? _viewport;
  double? _pointerY;
  Timer? _timer;

  void start(BuildContext context) {
    stop();
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (scrollable == null) return;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _position = scrollable.position;
    _viewport = box.localToGlobal(Offset.zero) & box.size;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void update(Offset globalPosition) => _pointerY = globalPosition.dy;

  void stop() {
    _timer?.cancel();
    _timer = null;
    _position = null;
    _viewport = null;
    _pointerY = null;
  }

  void _tick() {
    final position = _position;
    final viewport = _viewport;
    final y = _pointerY;
    if (position == null || viewport == null || y == null) return;
    if (!position.hasContentDimensions || !position.hasPixels) return;

    double step = 0;
    if (y < viewport.top + _edgeExtent) {
      step = -_maxStep *
          ((viewport.top + _edgeExtent - y) / _edgeExtent).clamp(0.0, 1.0);
    } else if (y > viewport.bottom - _edgeExtent) {
      step = _maxStep *
          ((y - (viewport.bottom - _edgeExtent)) / _edgeExtent).clamp(0.0, 1.0);
    }
    if (step == 0) return;

    final target = (position.pixels + step)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) position.jumpTo(target);
  }
}
