import 'package:flutter/material.dart';

class CalibTarget extends StatelessWidget {
  /// X/Y from the SDK.
  final double x;
  final double y;

  /// Progress for CircularProgressIndicator.
  /// If your SDK emits 0..100, pass `progress / 100`.
  final double? progress;

  /// The container we’re positioning inside (put this key on your Stack).
  final GlobalKey viewportKey;

  /// If the SDK emits normalized coords (0..1), set true.
  final bool normalized;

  /// If the SDK emits physical pixels, set true (we convert using DPR).
  final bool physical;

  /// Optional override for devicePixelRatio.
  final double? devicePixelRatioOverride;

  /// Visual radius of the target.
  final double radius;

  const CalibTarget({
    super.key,
    required this.x,
    required this.y,
    required this.viewportKey,
    this.progress,
    this.normalized = false,
    this.physical = false,
    this.devicePixelRatioOverride,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final render =
        viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (render == null || !render.hasSize) {
      return const SizedBox.shrink();
    }

    final size = render.size;
    final topLeft = render.localToGlobal(Offset.zero);
    print('topLeft $topLeft'); //topLeft Offset(0.0, 88.8)

    double localCenterX, localCenterY;

    if (normalized) {
      // (0..1) → local pixels
      localCenterX = x * size.width;
      localCenterY = y * size.height;
    } else {
      // global → local (convert physical→logical first if needed)
      final dpr =
          devicePixelRatioOverride ??
          MediaQuery.of(context).devicePixelRatio;

      double globalLogicalX = x, globalLogicalY = y;
      if (physical) {
        globalLogicalX /= dpr;
        globalLogicalY /= dpr;
      }
      localCenterX = globalLogicalX - topLeft.dx;
      localCenterY = globalLogicalY - topLeft.dy;
    }

    // Clamp the *top-left* so the entire circle is visible
    final diameter = radius * 2;

    final double left = (localCenterX - radius).clamp(
      0.0,
      size.width - diameter,
    );
    final double top = (localCenterY - radius).clamp(
      0.0,
      size.height - diameter,
    );

    return Positioned(
      left: left,
      top: top + radius,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CircularProgressIndicator(
          value: progress, // ensure this is 0..1
          backgroundColor: Colors.grey,
          strokeWidth: 3,
        ),
      ),
    );
  }
}
