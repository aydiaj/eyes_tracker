enum ScreenState {
  insideOfScreen,
  outsideOfScreen,
  changetab,
  unknown,
}

enum TrackingState { success, gazeNotFound, faceMissing, copypaste }

class ProctorTick {
  final int tsMs;

  final TrackingState tracking;

  final ScreenState screen;

  final double x;
  final double y;

  const ProctorTick({
    required this.tsMs,
    required this.tracking,
    required this.screen,
    required this.x,
    required this.y,
  });
}
