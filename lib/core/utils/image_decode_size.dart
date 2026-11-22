import 'package:flutter/widgets.dart';

/// The pixel width to decode an image at for a box [logicalSize] wide.
///
/// Without it an image decodes at full size — a 1024 px photo or a large
/// Open Food Facts picture for a 52 px thumbnail — which costs memory and
/// stalls scrolling while each row decodes. The 1.5 headroom lets a
/// landscape photo still cover a square box (BoxFit.cover) without going
/// soft.
int decodeWidthFor(BuildContext context, double logicalSize) =>
    (logicalSize * MediaQuery.devicePixelRatioOf(context) * 1.5).ceil();
