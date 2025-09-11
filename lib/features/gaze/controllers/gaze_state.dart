import '../../../common/utils/enum.dart';
import '../models/calibration_state.dart';

class GazeState {
  final String version;
  final bool ready; // initialized
  final bool startReady; // warm gate passed (new)
  final bool isWarming; // warm in progress (new)
  final bool showGaze;
  final double x, y;
  final String status; // start/stop/err
  final InitPhase phase;
  final CalibrationState calib;
  final double proctorDegree;
  final bool cheating;
  final bool? trackingOk;
  final bool isRetrying;

  const GazeState({
    this.version = 'unknown',
    this.ready = false,
    this.startReady = false,
    this.isWarming = false,
    this.showGaze = false,
    this.trackingOk = false,
    this.x = 0,
    this.y = 0,
    this.phase = InitPhase.idle,
    this.status = 'IDLE',
    this.calib = const CalibrationState(inProgress: false),
    this.proctorDegree = 100,
    this.cheating = false,
    this.isRetrying = false,
  });

  bool get isCaliMode => calib.inProgress;

  GazeState copyWith({
    String? version,
    bool? ready,
    bool? startReady,
    bool? isWarming,
    bool? showGaze,
    bool? trackingOk,
    double? x,
    double? y,
    InitPhase? phase,
    String? status,
    CalibrationState? calib,
    double? proctorDegree,
    bool? cheating,
    bool? isRetrying,
  }) => GazeState(
    version: version ?? this.version,
    ready: ready ?? this.ready,
    startReady: startReady ?? this.startReady,
    isWarming: isWarming ?? this.isWarming,
    showGaze: showGaze ?? this.showGaze,
    x: x ?? this.x,
    y: y ?? this.y,
    phase: phase ?? this.phase,
    status: status ?? this.status,
    calib: calib ?? this.calib,
    trackingOk: trackingOk ?? this.trackingOk,
    proctorDegree: proctorDegree ?? this.proctorDegree,
    cheating: cheating ?? this.cheating,
    isRetrying: isRetrying ?? this.isRetrying,
  );
}
