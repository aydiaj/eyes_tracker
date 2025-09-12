import 'package:flutter/material.dart';

class GazeDot extends StatelessWidget {
  final Offset offset;
  final bool ok;
  const GazeDot({super.key, required this.offset, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx - 5,
      top: offset.dy - 5,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: ok ? Colors.green : Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class ComGazeDot extends StatelessWidget {
  /// Gaze point from the SDK in **global logical** pixels.
  /// (If your SDK returns physical pixels, set [sdkUsesPhysicalPixels] to true.)
  final Offset global;

  /// Whether tracking is currently “good”.
  final bool ok;

  /// Put this key on the *Stack* (or container) you want to position inside.
  final GlobalKey viewportKey;

  /// If the SDK gives physical pixels (some Android stacks), set true.
  final bool sdkUsesPhysicalPixels;

  /// Optional override for devicePixelRatio when converting physical→logical.
  final double? devicePixelRatioOverride;

  /// Mirror horizontally across the viewport’s vertical midline (front camera).
  final bool mirrorX;

  /// Dot radius in logical pixels.
  final double radius;

  const ComGazeDot({
    super.key,
    required this.global,
    required this.ok,
    required this.viewportKey,
    this.sdkUsesPhysicalPixels = false,
    this.devicePixelRatioOverride,
    this.mirrorX = false,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final render =
        viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (render == null || !render.hasSize) {
      // Viewport not laid out yet.
      return const SizedBox.shrink();
    }

    // Viewport geometry in global space.
    final Offset viewportGlobalTopLeft = render.localToGlobal(
      Offset.zero,
    );
    final Size viewportSize = render.size;

    // 1) Convert SDK coords to global *logical* pixels if needed.
    double globalLogicalX = global.dx;
    double globalLogicalY = global.dy;
    if (sdkUsesPhysicalPixels) {
      final dpr =
          devicePixelRatioOverride ??
          MediaQuery.of(context).devicePixelRatio;
      globalLogicalX /= dpr;
      globalLogicalY /= dpr;
    }

    // 2) Optional mirror across the viewport’s vertical midline.
    if (mirrorX) {
      final double left = viewportGlobalTopLeft.dx;
      final double right = left + viewportSize.width;
      globalLogicalX =
          (left + right) - globalLogicalX; // mirror around midline
    }

    // 3) Global → local (center of the dot inside the viewport).
    double localCenterX = globalLogicalX - viewportGlobalTopLeft.dx;
    double localCenterY = globalLogicalY - viewportGlobalTopLeft.dy;

    // 4) Clamp *top-left* so the entire dot stays visible.
    final double diameter = radius * 2;
    final double left = (localCenterX - radius).clamp(
      0.0,
      viewportSize.width - diameter,
    );
    final double top = (localCenterY - radius).clamp(
      0.0,
      viewportSize.height - diameter,
    );

    return Positioned(
      left: left,
      top: top + radius,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: ok ? Colors.green : Colors.red,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(blurRadius: 0.5, spreadRadius: 0.5),
          ],
        ),
      ),
    );
  }
}
