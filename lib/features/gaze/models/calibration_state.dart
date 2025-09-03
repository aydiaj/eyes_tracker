class CalibrationState {
  final bool inProgress;
  final double progress; // 0..1
  final double nextX, nextY;

  const CalibrationState({
    required this.inProgress,
    this.progress = 0,
    this.nextX = 0,
    this.nextY = 0,
  });

  CalibrationState copyWith({
    bool? inProgress,
    double? progress,
    double? nextX,
    double? nextY,
  }) => CalibrationState(
    inProgress: inProgress ?? this.inProgress,
    progress: progress ?? this.progress,
    nextX: nextX ?? this.nextX,
    nextY: nextY ?? this.nextY,
  );
}
