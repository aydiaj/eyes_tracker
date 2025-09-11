import 'dart:async';
import 'package:eyedid_flutter/constants/eyedid_flutter_calibration_option.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:eyedid_flutter/eyedid_flutter.dart';
import 'package:eyedid_flutter/eyedid_flutter_initialized_result.dart';
import 'package:eyedid_flutter/gaze_tracker_options.dart';
import 'package:eyedid_flutter/events/eyedid_flutter_metrics.dart';
import 'package:eyedid_flutter/events/eyedid_flutter_status.dart';
import 'package:eyedid_flutter/events/eyedid_flutter_calibration.dart';
import '../models/gaze_point.dart';
import '../models/calibration_state.dart';
import 'package:eyedid_flutter/events/eyedid_flutter_drop.dart';

import '../../../secrets.dart';
import '../models/proctor_metric.dart' as prm;
import 'gaze_service.dart';

//for mobile
class EyedidService implements GazeService {
  static final _sdk = EyedidFlutter();

  EyedidService._();

  Future<bool> isgazeInitialized() async {
    try {
      await _sdk.startTracking();
      await _sdk.stopTracking();
      return true;
    } on PlatformException {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> probeReady({
    Duration timeout = const Duration(milliseconds: 400),
  }) async {
    try {
      await _sdk.startTracking().timeout(timeout);
      await _sdk.stopTracking();
      return true;
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }

  static final EyedidService _instance = EyedidService._();
  static EyedidService get instance => _instance;

  final _gazeCtrl = StreamController<GazePoint>.broadcast();
  final _statusCtrl = StreamController<String>.broadcast();
  final _calibCtrl = StreamController<CalibrationState>.broadcast();
  final _metricsCtrl = StreamController<prm.ProctorTick>.broadcast();
  final _dropCtrl = StreamController<String>.broadcast();

  // warm gate
  bool _startReady = false;
  final _startReadyCtl = StreamController<bool>.broadcast();
  Completer<void>? _prewarmInflight;
  Completer<void>? _initLock;

  // small local streak checker
  static const int _minFrames = 6; // fast, ~200ms @ 30fps
  static const int _maxDtMs = 220;

  StreamSubscription? _trackSub, _statusSub, _calibSub, _dropSub;

  @override
  Future<bool> ensureCameraPermission() async {
    final ok = await _sdk.checkCameraPermission();
    return ok ? true : await _sdk.requestCameraPermission();
  }

  bool _alreadyInitialized = false;

  @override
  Future<bool> requestCameraPermission() async {
    return await _sdk.requestCameraPermission();
  }

  @override
  Future<String> initialize() async {
    final options =
        GazeTrackerOptionsBuilder()
            .setPreset(CameraPreset.vga640x480)
            .setUseGazeFilter(true)
            .setUseBlink(false)
            .setUseUserStatus(false)
            .build();

    final res = await _sdk.initGazeTracker(
      licenseKey: licenseKey,
      options: options,
    );

    if (res.result &&
        res.message ==
            InitializedResult.gazeTrackerAlreadyInitialized) {
      _alreadyInitialized = true;
      _wireStreams();
      return _sdk.getPlatformVersion();
    } else {}
    throw PlatformException(
      code: 'init_failed',
      message: res.message,
    );
  }

  Future<void> _ensureInitializedWithRetry({
    int maxAttempts = 2,
    Duration backoff = const Duration(milliseconds: 250),
  }) async {
    if (_alreadyInitialized) return;

    // serialize concurrent init attempts
    if (_initLock != null) return _initLock!.future;
    final c = _initLock = Completer<void>();

    String lastMsg = '';
    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        final options =
            GazeTrackerOptionsBuilder()
                .setPreset(CameraPreset.vga640x480)
                .setUseGazeFilter(true)
                .setUseBlink(false)
                .setUseUserStatus(false)
                .build();

        final res = await _sdk.initGazeTracker(
          licenseKey: licenseKey,
          options: options,
        );

        lastMsg = res.message;
        if (res.result &&
            lastMsg ==
                InitializedResult.gazeTrackerAlreadyInitialized) {
          _alreadyInitialized = true;
          _wireStreams(); // safe to call more than once; we cancel existing subs
          c.complete();
          return;
        }

        // If keys missing or permanent failure → don’t retry
        if (lastMsg == InitializedResult.missingKeys ||
            lastMsg ==
                'ERROR_MISSING_KEYS' || // safe alias if plugin differs
            lastMsg == 'Initialization failed due to missing keys.') {
          c.completeError(
            PlatformException(code: 'init_failed', message: lastMsg),
          );
          return;
        }

        // Try a hard reinit between attempts (if available)
        try {
          await _sdk.releaseGazeTracker();
        } catch (_) {}
        await Future.delayed(backoff * attempt);
      }

      c.completeError(
        PlatformException(code: 'init_failed', message: lastMsg),
      );
    } finally {
      _initLock = null; // allow future init attempts
    }
  }

  void _wireStreams() {
    _trackSub?.cancel();
    _statusSub?.cancel();
    _calibSub?.cancel();
    _dropSub?.cancel();

    _trackSub = _sdk.getTrackingEvent().listen((e) {
      final metrics = MetricsInfo(e);
      final ok =
          metrics.gazeInfo.trackingState == TrackingState.success;
      _gazeCtrl.add(
        GazePoint(
          x: metrics.gazeInfo.gaze.x,
          y: metrics.gazeInfo.gaze.y,
          trackingOk: ok, //green point when ok, else red
        ),
      );
      _metricsCtrl.add(
        prm.ProctorTick(
          tsMs: metrics.timestamp,
          tracking: _mapEyedIdTracking(
            metrics.gazeInfo.trackingState,
          ),
          screen: _mapEyedIdScreen(metrics.gazeInfo.screenState),
          x: metrics.gazeInfo.gaze.x,
          y: metrics.gazeInfo.gaze.y,
        ),
      );
    });

    _statusSub = _sdk.getStatusEvent().listen((e) {
      final status = StatusInfo(e);
      debugPrint('Status event: ${status.type}');
      final error = status.errorType ?? StatusErrorType.none;
      _statusCtrl.add(
        status.type == StatusType.start
            ? 'start' // show gaze point
            : error == StatusErrorType.none
            ? 'stop'
            : 'error: ${status.errorType?.name ?? ''}',
      );
    });

    _dropSub = _sdk.getDropEvent().listen((e) {
      final drop = DropInfo(e);
      // handle drop events if needed
      _dropCtrl.add('Dropped at:${drop.timestamp}');
    });

    _calibSub = _sdk.getCalibrationEvent().listen((e) async {
      final calib = CalibrationInfo(e);
      debugPrint('Calibration event: ${calib.type}');
      switch (calib.type) {
        case CalibrationType.nextPoint:
          _calibCtrl.add(
            CalibrationState(
              inProgress: true,
              nextX: calib.next!.x,
              nextY: calib.next!.y,
              progress: 0,
            ),
          );
          await Future<void>.delayed(
            const Duration(milliseconds: 500),
          );
          _sdk.startCollectSamples(); //Ensure the calibration target is displayed before calling this function
          break;
        case CalibrationType.progress:
          _calibCtrl.add(
            CalibrationState(
              inProgress: true,
              progress: calib.progress ?? 0,
            ),
          );
          break;
        case CalibrationType.finished:
        case CalibrationType.canceled:
        case CalibrationType.unknown:
          _calibCtrl.add(const CalibrationState(inProgress: false));
          _sdk.stopTracking();
          break;
      }
    });
  }

  @override
  Future<void> prewarm() async {
    if (_startReady) return;

    // Coalesce concurrent prewarms
    if (_prewarmInflight != null) return _prewarmInflight!.future;
    final c = _prewarmInflight = Completer<void>();

    StreamSubscription? tempSub;
    int streak = 0, lastTs = 0;
    bool gotStreak = false;

    Future<void> cleanup() async {
      await tempSub?.cancel();
      tempSub = null;
      _prewarmInflight = null;
    }

    try {
      // 1) Ensure initialized (with retry)
      await _ensureInitializedWithRetry();

      // 2) Attach a temporary listener for a short success streak
      tempSub = _sdk.getTrackingEvent().listen((e) {
        final m = MetricsInfo(e);
        final ok = m.gazeInfo.trackingState == TrackingState.success;

        final xOk = m.gazeInfo.gaze.x.isFinite;
        final yOk = m.gazeInfo.gaze.y.isFinite;

        final t = m.timestamp;
        final dt = (lastTs == 0) ? 0 : (t - lastTs);
        lastTs = t;
        final dtOk = (lastTs == 0) || (dt <= _maxDtMs);

        if (ok && xOk && yOk && dtOk) {
          if (++streak >= _minFrames && !gotStreak) {
            gotStreak = true;
            _markStartReady(); // <- flip the gate!
            if (!c.isCompleted) c.complete();
          }
        } else {
          streak = 0;
        }
      });

      // 3) Start tracking and wait for streak (short timeout)
      try {
        await _sdk.startTracking();
      } on PlatformException catch (_) {
        // If start fails, try a once-off reinit + retry start
        try {
          await _ensureInitializedWithRetry();
          await _sdk.startTracking();
        } catch (e) {
          // Give up; prewarm stays not ready
        }
      }

      await c.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } finally {
      // 4) Stop if silent (so UI doesn’t observe a visible start)
      try {
        await _sdk.stopTracking();
      } catch (_) {}
      await cleanup();
    }
  }

  prm.TrackingState _mapEyedIdTracking(TrackingState s) {
    switch (s) {
      case TrackingState.success:
        return prm.TrackingState.success;
      case TrackingState.faceMissing:
        return prm.TrackingState.faceMissing;
      case TrackingState.gazeNotFound:
        return prm.TrackingState.gazeNotFound;
    }
  }

  prm.ScreenState _mapEyedIdScreen(ScreenState s) {
    switch (s) {
      case ScreenState.insideOfScreen:
        return prm.ScreenState.insideOfScreen;
      case ScreenState.outsideOfScreen:
        return prm.ScreenState.outsideOfScreen;
      case ScreenState.unknown:
        return prm.ScreenState.unknown;
    }
  }

  // Global Streams to listen to
  @override
  Stream<GazePoint> gaze$() => _gazeCtrl.stream;
  @override
  Stream<String> status$() => _statusCtrl.stream;
  @override
  Stream<CalibrationState> calibration$() => _calibCtrl.stream;
  @override
  Stream<prm.ProctorTick> metrics$() => _metricsCtrl.stream;
  @override
  Stream<String> drop$() => _dropCtrl.stream;

  // SDK version
  @override
  Future<String> get version => _sdk.getPlatformVersion();

  // SDK control methods
  @override
  Future<void> startTracking() => _sdk.startTracking();
  @override
  Future<void> stopTracking() => _sdk.stopTracking();
  @override
  Future<bool> isTracking() => _sdk.isTracking();
  @override
  Future<bool> isCalibrating() => _sdk.isCalibrating();

  @override
  Future<void> startCalibration({bool usePrevious = true}) async {
    await _sdk.startTracking();
    _sdk.startCalibration(
      CalibrationMode.five,
      usePreviousCalibration: usePrevious,
    );
  }

  @override
  Future<void> stopCalibration() async {
    await _sdk.stopCalibration();
    _sdk.stopTracking();
  }

  @override
  void dispose() {
    stopTracking();
    _trackSub?.cancel();
    _statusSub?.cancel();
    _calibSub?.cancel();
    _dropSub?.cancel();
    _gazeCtrl.close();
    _metricsCtrl.close();
    _statusCtrl.close();
    _calibCtrl.close();
    _dropCtrl.close();
    _startReadyCtl.close();
    // _sdk.releaseGazeTracker();
  }

  void _markStartReady() {
    if (_startReady) return;
    _startReady = true;
    if (!_startReadyCtl.isClosed) {
      try {
        _startReadyCtl.add(true);
      } catch (_) {}
    }
  }

  @override
  bool get startReady => _startReady;

  @override
  Stream<bool> startReady$() => _startReadyCtl.stream;
}

GazeService createImpl() => EyedidService.instance;
