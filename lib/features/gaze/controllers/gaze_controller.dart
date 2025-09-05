import 'dart:async';
import 'dart:math';
import 'package:eyes_tracker/common/utils/enum.dart';
import 'package:eyes_tracker/features/gaze/models/proctor_score.dart';
import 'package:eyes_tracker/providers/gaze_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/connection/connectivity_controller.dart';
import '../../../providers/conn_providers.dart';
import '../data/gaze_service.dart';
import '../models/calibration_state.dart';
import '../models/gaze_point.dart';
import '../models/proctor_counters.dart';
import '../models/proctor_metric.dart' as prm;
import 'gaze_state.dart';

class GazeController extends AutoDisposeNotifier<GazeState> {
  late final GazeService _ds;
  Size? _screenSize;

  GazeController();

  @override
  GazeState build() {
    _ds = ref.read(gazeServiceProvider);
    final gazeState = const GazeState();
    // schedule the async init after provider is created
    Future.microtask(init);

    // came back online while not ready → try again
    ref.listen<ConnectivityState>(connectivityProvider, (prev, next) {
      //   if(prev != null && prev?.online !=null)
      if ((prev?.online ?? false) == false &&
          next.online == true &&
          !state.ready) {
        /* state = state.copyWith(
          isRetrying: true,
         // status: 'Retrying…',
        ); */
        retry();
      }
    });

    ref.onDispose(() {
      _gazeSub?.cancel();
      _statusSub?.cancel();
      _calibSub?.cancel();
      _metricsSub?.cancel();
      _stopReadyWatchdog();
      _dropSub?.cancel();
      _ds.dispose();
    });

    return gazeState;
  }

  // timeouts for quick check
  final Duration connectivityTimeout = const Duration(seconds: 5);
  // timeouts for overall cap
  final Duration readyTimeout = const Duration(seconds: 20);

  Timer? _readyWatchdog;

  void _startReadyWatchdog() {
    _readyWatchdog?.cancel();
    _readyWatchdog = Timer(readyTimeout, () {
      if (!state.ready && state.phase == InitPhase.initializing) {
        final status = state.status;
        state = state.copyWith(
          status: 'Startup timeout: $status',
          phase: InitPhase.timeout,
          ready: false,
        );
      }
    });
  }

  void _stopReadyWatchdog() {
    _readyWatchdog?.cancel();
    _readyWatchdog = null;
  }

  Future<void> init() async {
    _startReadyWatchdog();
    try {
      final camOk = await _ds.ensureCameraPermission();

      debugPrint('ensureCameraPermission: $camOk');

      if (!camOk) {
        if (!state.isRetrying) {
          state = state.copyWith(
            status: 'Camera Denied',
            phase: InitPhase.cameradenied,
          );
        }
        return;
      }

      final isgazeInitialized =
          state.ready; // await checkStillReady();

      final isOnline =
          await ref
              .read(connectivityProvider.notifier)
              .ensureBaseline();
      if (!isOnline) {
        if (!state.isRetrying) {
          state = state.copyWith(
            status: 'Offline',
            phase: InitPhase.offline,
          );
        }
        if (!isgazeInitialized) {
          return;
        }
      }

      // SDK init, but don't let it hang forever
      if (!state.isRetrying) {
        state = state.copyWith(
          status: 'Initializing SDK…',
          phase: InitPhase.initializing,
        );
      }

      final String version;
      if (!isgazeInitialized) {
        version = await _ds.initialize().timeout(
          // leave a small margin inside the watchdog
          readyTimeout - const Duration(seconds: 2),
        );
      } else {
        version = await _ds.version;
      }

      _stopReadyWatchdog();
      _wire();
      state = state.copyWith(
        version: version,
        ready: true,
        status: 'Ready',
        phase: InitPhase.ready,
      );
    } on TimeoutException {
      _stopReadyWatchdog();
      state = state.copyWith(
        status: 'Initialization Failed',
        phase: InitPhase.timeout,
        ready: false,
      );
    } catch (e) {
      _stopReadyWatchdog();
      if (e is PlatformException) {
        debugPrint(
          'PlatformException: ${e.code}, ${e.message}, ${e.details}',
        );
        state = state.copyWith(
          status: 'Initialization Failed',
          phase: InitPhase.error,
          ready: false,
        );
      } else {
        debugPrint('Exception: $e');
        state = state.copyWith(
          status: 'Can\'t sart now',
          phase: InitPhase.error,
        );
      }
    }
  }

  Future<void> retry() async {
    // small debounce/backoff if you like
    state = state.copyWith(isRetrying: true);
    await Future<void>.delayed(const Duration(seconds: 2));
    await init();
    state = state.copyWith(isRetrying: false);
  }

  /// to verify the native side didn’t die.
  /* Future<bool> checkStillReady() async {
    final ok = await _ds.probeReady(
      timeout: const Duration(milliseconds: 400),
    );
    if (!ok) {
      state = state.copyWith(
        ready: false,
        status: 'Session lost — reinitialize',
      );
      // retry();
    }
    return ok;
  } */

  StreamSubscription<GazePoint>? _gazeSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<CalibrationState>? _calibSub;
  StreamSubscription<prm.ProctorTick>? _metricsSub;
  StreamSubscription<String>? _dropSub;

  final _counters = ProctorCounters();

  void _wire() {
    _gazeSub?.cancel();
    _statusSub?.cancel();
    _calibSub?.cancel();
    _metricsSub?.cancel();
    _dropSub?.cancel();

    _gazeSub = _ds.gaze$().listen((g) {
      //_accumulate(g);
      final oldx = state.x, oldy = state.y;
      state = state.copyWith(
        x: g.trackingOk ? g.x : oldx,
        y: g.trackingOk ? g.y : oldy,
        trackingOk: g.trackingOk,
      );
    });

    _metricsSub = _ds.metrics$().listen((m) {
      /*  debugPrint(
        'metrics details: x: ${m.x} , y: ${m.y}, screen: ${m.screen}, tracking: ${m.tracking}, tMS: ${m.tsMs}',
      ); */
      _accumulateFromMetrics(m);
    });

    _dropSub = _ds.drop$().listen((dts) {
      state = state.copyWith(status: 'dropped', trackingOk: false);
    });

    /*  uninitialized,
  initializing,
  ready,
  tracking,
  calibrating,
  paused,
  error, */
    _statusSub = _ds.status$().listen((s) {
      debugPrint(s);
      if (s.startsWith('start')) {
        state = state.copyWith(status: 'Tracking', showGaze: true);
      } else if (s.contains('tracking')) {
        state = state.copyWith(status: 'Tracking', showGaze: true);
      } else if (s.contains('ready')) {
        state = state.copyWith(status: 'Ready', showGaze: false);
      } else {
        print(s);
        state = state.copyWith(status: 'stopped', showGaze: false);
      }
    });

    _calibSub = _ds.calibration$().listen((c) {
      final keepX = c.nextX != 0 ? c.nextX : state.calib.nextX;
      final keepY = c.nextY != 0 ? c.nextY : state.calib.nextY;
      state = state.copyWith(
        calib: state.calib.copyWith(
          inProgress: c.inProgress,
          progress: c.progress,
          nextX: keepX,
          nextY: keepY,
        ),
      );
    });
  }

  Future<void> startTracking() async {
    _resetCounters();
    await _ds.startTracking();
  }

  Future<ProctorScore> stopTracking() async {
    await _ds.stopTracking();
    final degree = _computeProctorDegree();
    state = state.copyWith(
      proctorDegree: degree,
      cheating: degree < 90.0,
    );
    return ProctorScore(degree, degree < 90);
  }

  startCalibration() async {
    final isTracking = await _ds.isTracking();
    if (!isTracking) {
      await _ds.startTracking();
    }
    await _ds.startCalibration(usePrevious: true);
  }

  stopCalibration() async {
    final isCalib = await _ds.isCalibrating();
    final isTracking = await _ds.isTracking();

    if (isCalib) {
      await _ds.stopCalibration();
    }
    if (isTracking) {
      await _ds.stopTracking();
    }
    state = state.copyWith(
      phase: InitPhase.ready,
      ready: true,
      status: 'Ready',
    );
  }

  Future<void> startCalib() =>
      _ds.startCalibration(usePrevious: true);

  void updateScreenSize(Size size) {
    // Only write if changed.
    // ROI reads it during accumulation
    if (_screenSize == null ||
        _screenSize!.width != size.width ||
        _screenSize!.height != size.height) {
      _screenSize = size;
    }
  }

  void _accumulateFromMetrics(prm.ProctorTick info) {
    final ts = info.tsMs;
    int delta = 0;

    if (_counters.lastTs != 0) {
      delta = ts - _counters.lastTs;
      if (delta < 0) delta = 0;
      if (delta > 200) delta = 33; // cap spikes (~30fps)
    }
    _counters.lastTs = ts;
    _counters.sessionMs += delta;

    final tracking = info.tracking;
    final screen = info.screen;

    if (tracking == prm.TrackingState.copypaste) {
      _counters.copyEvents++;
    }
    if (screen == prm.ScreenState.changetab) {
      _counters.offScreenMs += delta;
    } else if (tracking == prm.TrackingState.faceMissing) {
      _counters.faceMissingMs += delta;
    } else if (screen == prm.ScreenState.outsideOfScreen ||
        screen == prm.ScreenState.unknown) {
      _counters.offScreenMs += delta;
    } else {
      final gx = info.x, gy = info.y;
      if (!_inRoi(gx, gy)) _counters.lookAwayMs += delta;
    }
  }

  bool _inRoi(double x, double y) {
    final s = _screenSize;
    if (s == null) return true; // if unknown, don't penalize
    final left = 0, top = 0;
    final right = s.width;
    final bottom = s.height;
    return x >= left && x <= right && y >= top && y <= bottom;
  }

  double _computeProctorDegree() {
    final total = _counters.sessionMs == 0 ? 1 : _counters.sessionMs;
    final rFace = _counters.faceMissingMs / total;
    final rOff = _counters.offScreenMs / total;
    final rLook = _counters.lookAwayMs / total;
    final rCopies = _counters.copyEvents;
    // Weights: faceMissing 50%, offScreen 30%, lookAway 20% (tune as needed)
    final penalty =
        100.0 * (0.55 * rFace + 0.30 * rOff + 0.15 * rLook) - rCopies;
    return (100.0 - penalty).clamp(0.0, 100.0);
  }

  void _resetCounters() => _counters.reset();
}
