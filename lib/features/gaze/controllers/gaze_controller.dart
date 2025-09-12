import 'dart:async';
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

  String? _lastStatusClass;
  Timer? _retryDebounce;

  @override
  GazeState build() {
    _ds = ref.read(gazeServiceProvider);
    final gazeState = const GazeState();
    // schedule the async init after provider is created
    Future.microtask(init);

    // came back online while not ready → try again
    ref.listen<ConnectivityState>(connectivityProvider, (prev, next) {
      final cameOnline =
          (prev?.online ?? false) == false && next.online == true;
      final badPhase = {
        InitPhase.offline,
        InitPhase.timeout,
        InitPhase.error,
      }.contains(state.phase);
      if (cameOnline && badPhase && !state.ready) {
        // debounce: only retry once after a short quiet period
        _retryDebounce?.cancel();
        _retryDebounce = Timer(const Duration(milliseconds: 800), () {
          if (!state.ready) retry();
        });
      }

      /* // Auto prewarm when back online & SDK is ready but not warm yet
    if (cameOnline && state.ready && !state.startReady) {
      unawaited(_ds.prewarm(silent: true).catchError((_) {}));
      state = state.copyWith(isWarming: true, status: 'Warming Up');
    } */
    });

    ref.onDispose(() {
      _retryDebounce?.cancel();
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
  final Duration readyTimeout = const Duration(seconds: 60);

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

  //init flags
  bool _initInFlight = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || _initInFlight) return;
    _initInFlight = true;
    _startReadyWatchdog();
    StreamSubscription<String>? earlyStatus;
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

      final isOnline =
          await ref
              .read(connectivityProvider.notifier)
              .ensureBaseline();
      if (!isOnline && !state.ready) {
        if (!state.isRetrying) {
          state = state.copyWith(
            status: 'Offline',
            phase: InitPhase.offline,
          );
        }
        return;
      }

      // listen early so "warming" cancels watchdog
      earlyStatus = _ds.status$().listen((s) {
        if (s.contains('warming') ||
            s.contains('ready') ||
            s.contains('tracking')) {
          _stopReadyWatchdog();
        }
      });

      // SDK init, but don't let it hang forever
      if (!state.isRetrying) {
        state = state.copyWith(
          status: 'Initializing SDK…',
          phase: InitPhase.initializing,
        );
      }

      final String version =
          state.ready ? await _ds.version : await _ds.initialize();

      await earlyStatus.cancel();
      earlyStatus = null;
      _stopReadyWatchdog();

      _wire();

      // Fire a silent prewarm so quiz can start ASAP once frames are good.
      // Services implement their own single-flight, so this is race-safe:
      // unawaited(_ds.prewarm(silent: true).catchError((_) {}));

      state = state.copyWith(
        version: version,
        ready: true,
        status: 'Ready',
        phase: InitPhase.ready,
      );

      _initialized = true;
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
    } finally {
      await earlyStatus?.cancel();
      _initInFlight = false;
    }
  }

  startWarming() {
    try {
      _ds.prewarm();
    } catch (_) {}
  }

  Future<void> retry() async {
    if (state.ready) return;
    state = state.copyWith(isRetrying: true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
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
  StreamSubscription<bool>? _startReadySub;
  bool? _lastWarmVal;

  final _counters = ProctorCounters();

  void _wire() {
    _gazeSub?.cancel();
    _startReadySub?.cancel();
    _statusSub?.cancel();
    _calibSub?.cancel();
    _metricsSub?.cancel();
    _dropSub?.cancel();
    _startReadySub?.cancel();

    var live = false;

    // Watch the warm gate once (works for both web & mobile services)
    _lastWarmVal = _ds.startReady;
    if (_lastWarmVal!) {
      state = state.copyWith(
        startReady: _lastWarmVal,
        isWarming: false,
        status: 'Ready',
      );
    }

    debugPrint('start ready $_lastWarmVal');
    _startReadySub = _ds.startReady$().listen((ok) {
      if (_lastWarmVal == ok) return; // de-dupe
      _lastWarmVal = ok;
      state = state.copyWith(startReady: ok, isWarming: false);
      debugPrint('stream start ready $ok');
    });

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
      if (!live) {
        return;
      }
      debugPrint(
        'metrics details: x: ${m.x} , y: ${m.y}, screen: ${m.screen}, tracking: ${m.tracking}, tMS: ${m.tsMs}',
      );
      _accumulateFromMetrics(m);
    });

    _dropSub = _ds.drop$().listen((dts) {
      state = state.copyWith(trackingOk: false);
    });

    /*  uninitialized,
  initializing,
  ready,
  tracking,
  calibrating,
  paused,
  error, */
    _lastStatusClass = null; // reset when (re)wiring

    _statusSub = _ds.status$().listen((s) {
      final cls = _classifyStatus(s);
      if (cls == _lastStatusClass) {
        return; // ignore identical consecutive class
      }
      _lastStatusClass = cls;

      switch (cls) {
        case 'tracking':
          live = true;
          state = state.copyWith(status: 'Tracking', showGaze: true);
          break;
        case 'calibrating':
          live = false;
          state = state.copyWith(
            status: 'Calibrating',
            showGaze: true,
          );
          break;
        case 'ready':
          live = false;
          _stopReadyWatchdog();
          state = state.copyWith(
            status: 'Ready',
            ready: true,
            isWarming: false,
            showGaze: false,
          );
          break;
        case 'warming':
          live = false;
          state = state.copyWith(
            status: 'Warming Up',
            ready: true, //might change
            isWarming: true,
            showGaze: false,
          );
          break;
        default:
          live = false;
          state = state.copyWith(
            status: 'Idle',
            isWarming: false,
            showGaze: false,
          );
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
    /* // Require warm gate
    if (!state.startReady) {
      state = state.copyWith(isWarming: true, status: 'Warming');
      try {
        await _ds.prewarm(
          silent: false,
        ); // active warm (platform may resume/pause)
      } catch (_) {}
    }
    if (!state.startReady) {
      // Still not warm → don’t start tracking; UI can show a toast
      state = state.copyWith(isWarming: false, status: 'Ready');
      return;
    } */
    _resetCounters();
    await _ds.startTracking();
  }

  Future<ProctorScore> stopTracking() async {
    await _ds.stopTracking();
    final degree = _computeProctorDegree();
    state = state.copyWith(
      proctorDegree: degree,
      cheating: degree < 75.0, //needs confirmation
    );
    return ProctorScore(degree, degree < 75);
  }

  /*   startCalibration() {
    try {
      _ds.startCalibration(usePrevious: true);
    } on StateError {
      debugPrint('Bad state: startCalibration failed');
      //state = state.copyWith()
    } catch (e) {
      debugPrint('error');
    }
  } */

  Future<void> startCalibration() async {
    try {
      await _ds.startCalibration(usePrevious: true);
    } on StateError catch (e, st) {
      debugPrint('Bad state: startCalibration failed: $e');
      debugPrint('error trace: ${st.toString()}');
    } on PlatformException catch (e) {
      debugPrint(
        'Platform error during calibration: ${e.code} ${e.message}',
      );
      // state = state.copyWith(status: 'Calibration error', ...);
    } catch (e) {
      debugPrint('Unexpected calibration error: $e');
    } finally {
      // optional cleanup or UI unblocking
      // state = state.copyWith(status: 'Ready');
    }
  }

  stopCalibration() async {
    final isCalib = await _ds.isCalibrating();
    // print('isCalib $isCalib   isTracking $isTracking');
    if (isCalib) {
      await _ds.stopCalibration();
    }
    state = state.copyWith(
      phase: InitPhase.ready,
      ready: true,
      status: 'Ready',
    );
  }

  Future<void> startCalib() =>
      _ds.startCalibration(usePrevious: true);

  String _classifyStatus(String s) {
    if (s.startsWith('start') || s.contains('tracking')) {
      return 'tracking';
    }
    if (s.contains('calibrating')) return 'calibrating';
    if (s.contains('ready') || s.contains('stop')) return 'ready';
    if (s.contains('warming')) return 'warming';
    return 'other';
  }

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
    if (screen == prm.ScreenState.changetab ||
        tracking == prm.TrackingState.gazeNotFound) {
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
