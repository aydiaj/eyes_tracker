import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:eye_tracking/eye_tracking.dart';
import 'package:eye_tracking/eye_tracking_platform_interface.dart';
import 'package:eyes_tracker/features/gaze/data/gaze_service.dart';
import 'package:eyes_tracker/features/gaze/models/calibration_state.dart';
import 'package:eyes_tracker/features/gaze/models/gaze_point.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart';

import '../models/proctor_metric.dart' as prm;

class WebGazeService extends GazeService {
  static final _sdk = EyeTracking();

  WebGazeService._();

  static final WebGazeService _instance = WebGazeService._();
  static WebGazeService get instance => _instance;

  final _gazeCtrl = StreamController<GazePoint>.broadcast();
  final _statusCtrl = StreamController<String>.broadcast();
  final _calibCtrl = StreamController<CalibrationState>.broadcast();
  final _metricsCtrl = StreamController<prm.ProctorTick>.broadcast();
  final _dropCtrl = StreamController<String>.broadcast();

  StreamSubscription? _trackSub,
      _statusSub,
      _dropSub,
      _tabSub,
      _keyCopyPasteSub;
  Timer? _ticker; // 30Hz synthesizer

  @override
  Future<String> initialize() async {
    try {
      final res = await _sdk.initialize();
      if (res) {
        await _sdk.setTrackingFrequency(30);
        await _sdk.setAccuracyMode(
          'high',
        ); // 'high', 'medium', or 'fast'
        await _sdk.enableBackgroundTracking(true);
        _hideWebGazerUI();
        BrowserContextMenu.disableContextMenu();
        _wireStreams();
        return version;
      }
      throw PlatformException(code: 'init_failed');
    } catch (e) {
      return 'error';
    }
  }

  static const _confOk = 0.55; // gaze confidence threshold
  static const _faceTimeout = Duration(milliseconds: 500);
  static const _tickEvery = Duration(milliseconds: 33); // ~30Hz

  GazeData? _lastGaze;
  int? _lastGazeMS;

  bool _inDrop = false;

  void _onTick(Timer _) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fresh =
        _lastGazeMS != null &&
        (nowMs - _lastGazeMS!) <= _faceTimeout.inMilliseconds;

    if (!fresh) {
      _maybeEmitDrop();
      _metricsCtrl.add(
        prm.ProctorTick(
          tsMs: _monotonicTsMs(nowMs),
          tracking: prm.TrackingState.faceMissing,
          screen: prm.ScreenState.unknown,
          x: -10,
          y: -10,
        ),
      );
      return;
    } else {}

    final g = _lastGaze!;
    final vp = _viewport();
    final dpr =
        WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio;

    final x = g.x / dpr;
    final y = g.y / dpr;

    final inBounds =
        x >= 0 && y >= 0 && x <= vp.width && y <= vp.height;
    final confOk = g.confidence >= _confOk;

    // drop incident when either confidence is bad or we’re out of bounds
    if (!confOk || !inBounds) {
      _maybeEmitDrop();
    } else if (_inDrop) {
      _inDrop = false;
    }

    final tracking =
        confOk
            ? prm.TrackingState.success
            : prm.TrackingState.gazeNotFound;

    final screen =
        inBounds
            ? prm.ScreenState.insideOfScreen
            : prm.ScreenState.outsideOfScreen;

    _metricsCtrl.add(
      prm.ProctorTick(
        tsMs: _monotonicTsMs(g.timestamp.millisecondsSinceEpoch),
        tracking: tracking,
        screen: screen,
        x: x,
        y: y,
      ),
    );
  }

  int _lastMonoTs = 0;

  /// Unified clock
  /// Call this every time before you emit into `_metricsCtrl`.
  int _monotonicTsMs(int tsMs) {
    if (tsMs <= _lastMonoTs) {
      _lastMonoTs = _lastMonoTs + 1;
    } else {
      _lastMonoTs = tsMs;
    }
    return _lastMonoTs;
  }

  void _maybeEmitDrop() {
    if (_inDrop) return;
    _inDrop = true;
    _dropCtrl.add('drop:${DateTime.now().millisecondsSinceEpoch}');
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickEvery, _onTick);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _wireStreams() {
    _trackSub?.cancel();
    _statusSub?.cancel();
    _dropSub?.cancel();
    _tabSub?.cancel();
    _keyCopyPasteSub?.cancel();

    _tabSub = document.onVisibilityChange.listen((e) async {
      final inTracking = await isTracking();
      if (inTracking) {
        _metricsCtrl.add(
          prm.ProctorTick(
            screen: prm.ScreenState.changetab,
            x: 0,
            y: 0,
            tracking: prm.TrackingState.faceMissing,
            tsMs: _monotonicTsMs(
              DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        );
      }
    });

    _keyCopyPasteSub = window.onKeyDown.listen((e) async {
      //copy&paste
      bool isCopyPaste = e.ctrlKey;
      final inTracking = await isTracking();
      if (inTracking) {
        if (isCopyPaste) {
          _metricsCtrl.add(
            prm.ProctorTick(
              screen: prm.ScreenState.insideOfScreen,
              x: 0,
              y: 0,
              tracking: prm.TrackingState.copypaste,
              tsMs: _monotonicTsMs(
                DateTime.now().millisecondsSinceEpoch,
              ),
            ),
          );
        }
      }
    });

    _trackSub = _sdk.getGazeStream().listen((e) {
      final hasSignificantChange =
          _lastGaze == null ||
          (e.x - _lastGaze!.x).abs() > 5.0 ||
          (e.y - _lastGaze!.y).abs() > 5.0;

      _lastGazeMS = DateTime.now().millisecondsSinceEpoch;

      if (hasSignificantChange) {
        _lastGaze = e;
        final ok = e.confidence >= _confOk;

        final dpr =
            WidgetsBinding
                .instance
                .platformDispatcher
                .views
                .first
                .devicePixelRatio;

        final x = e.x / dpr;
        final y = e.y / dpr;

        _gazeCtrl.add(
          GazePoint(
            x: x,
            y: y,
            trackingOk: ok, //green point when ok, else red
          ),
        );
      }

      // debugPrint('$x    $y');

      /* final inBounds =
          x >= 0 && y >= 0 && x <= vp.width && y <= vp.height;

      _metricsCtrl.add(
        prm.ProctorTick(
          tsMs: _monotonicTsMs(_lastGazeMS!),
          tracking:
              ok
                  ? prm.TrackingState.success
                  : prm.TrackingState.gazeNotFound,
          screen:
              inBounds
                  ? prm.ScreenState.insideOfScreen
                  : prm.ScreenState.outsideOfScreen,
          x: x,
          y: y,
        ),
      ); */
    });

    _statusSub = _sdk.getState().asStream().listen((e) {
      final EyeTrackingState status = e;
      debugPrint('Status event: ${status.name}');
      _statusCtrl.add(status.name);
    });
  }

  Size _viewport() {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final s = v.physicalSize / v.devicePixelRatio;
    return Size(s.width, s.height);
  }

  // Internal calibration state
  List<CalibrationPoint> _points = const [];
  int _idx = -1;
  bool _calibrating = false;
  bool _cancelRequested = false;
  Timer? _progressTimer;

  Duration showDelay = const Duration(milliseconds: 500);
  Duration collectDuration = const Duration(milliseconds: 2000);
  Duration progressTick = const Duration(milliseconds: 100);

  ({double w, double h}) _screenSize() {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = v.physicalSize / v.devicePixelRatio;
    return (w: size.width, h: size.height);
  }

  @override
  Future<void> startCalibration({bool usePrevious = true}) async {
    if (_calibrating) return; // already running
    _cancelRequested = false;

    // Build points (5-point pattern) based on current screen
    final screenSize = _screenSize();
    _points = EyeTracking.createStandardCalibration(
      screenWidth: screenSize.w,
      screenHeight: screenSize.h,
    );

    final ok = await _sdk.startCalibration(_points);
    if (!ok) throw StateError('startCalibration failed');

    _calibrating = true;
    _idx = 0;

    // Kick off the automatic loop
    _runNextPoint();
  }

  void _runNextPoint() {
    if (_cancelRequested || !_calibrating) return;

    // Finished?
    if (_idx >= _points.length) {
      _finishCalibration();
      return;
    }

    final p = _points[_idx];

    // Emit "next point" like EyedID
    _calibCtrl.add(
      CalibrationState(
        inProgress: true,
        nextX: p.x,
        nextY: p.y,
        progress: 0,
      ),
    );

    // Wait a short delay so UI can draw the target, then start collecting
    Future<void>.delayed(showDelay, () => _collectCurrentPoint(p));
  }

  Future<void> _collectCurrentPoint(CalibrationPoint p) async {
    if (_cancelRequested || !_calibrating) return;

    // Emit smooth progress during collection
    final totalMs = collectDuration.inMilliseconds;
    int elapsed = 0;

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(progressTick, (t) {
      elapsed += progressTick.inMilliseconds;
      final progress = (elapsed / totalMs).clamp(0.0, 1.0);
      _calibCtrl.add(
        CalibrationState(inProgress: true, progress: progress),
      );
      if (elapsed >= totalMs) t.cancel();
    });

    // Wait until collection time elapses
    await Future<void>.delayed(collectDuration);
    _progressTimer?.cancel();

    if (_cancelRequested || !_calibrating) return;

    // Tell SDK we collected this point
    bool ok;
    do {
      ok = await _sdk.addCalibrationPoint(p);
    } while (!ok);

    _idx++;
    _runNextPoint();
  }

  Future<void> _finishCalibration() async {
    if (!_calibrating) return;
    _progressTimer?.cancel();
    await _sdk.finishCalibration();
    final acc = await _sdk.getCalibrationAccuracy().catchError(
      (_) => 0.0,
    );

    _calibrating = false;
    _idx = -1;
    _calibCtrl.add(const CalibrationState(inProgress: false));

    debugPrint(
      'Calibration accuracy: ${(acc * 100).toStringAsFixed(1)}%',
    );
  }

  @override
  Future<void> stopCalibration() async {
    // Treat as cancel -> stop timers, clear, emit false
    _cancelRequested = true;
    _progressTimer?.cancel();
    if (_calibrating) {
      await _sdk.clearCalibration();
      _calibrating = false;
      _idx = -1;
      _calibCtrl.add(const CalibrationState(inProgress: false));
    }
  }

  Future<void> cancelCalibration() async => stopCalibration();

  @override
  Future<bool> ensureCameraPermission() async {
    final ok = await _sdk.hasCameraPermission();
    return ok ? true : await _sdk.requestCameraPermission();
  }

  @override
  Future<bool> requestCameraPermission() =>
      _sdk.requestCameraPermission();

  @override
  Future<bool> isCalibrating() async {
    final state = await _sdk.getState();
    return state == EyeTrackingState.calibrating;
  }

  @override
  Future<bool> isTracking() async {
    final state = await _sdk.getState();
    return state == EyeTrackingState.tracking;
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

  /* @override
  Stream<prm.ProctorTick> metrics$() => _buildMetricsStream();
 */
  @override
  Stream<String> drop$() => _dropCtrl.stream;

  @override
  void dispose() {
    stopTracking();
    _trackSub?.cancel();
    _statusSub?.cancel();
    _dropSub?.cancel();
    _tabSub?.cancel();
    _keyCopyPasteSub?.cancel();
    _ticker?.cancel();
    _gazeCtrl.close();
    _metricsCtrl.close();
    _statusCtrl.close();
    _calibCtrl.close();
    _dropCtrl.close();
  }

  @override
  Future<void> startTracking() async {
    if (await _sdk.startTracking()) {
      _statusCtrl.add(EyeTrackingState.tracking.name);
      _startTicker();
    }
  }

  @override
  Future<void> stopTracking() async {
    if (await _sdk.stopTracking()) {
      _statusCtrl.add('stopped');
      _stopTicker();
    }
    //  _statusSub?.cancel();
  }

  @override
  Future<String> get version async {
    final version = await _sdk.getPlatformVersion() ?? 'unknown';
    return version;
  }

  void _evalJS(String code) {
    (window as JSObject).callMethodVarArgs('eval'.toJS, [code.toJS]);
  }

  void _hideWebGazerUI() {
    try {
      _evalJS(r"""
      (function () {
        function hide(el) {
          if (!el) return;
          el.style.display = 'none';
          el.style.visibility = 'hidden';
          el.style.opacity = '0';
          el.style.pointerEvents = 'none';
          el.style.position = 'fixed';
          el.style.left = '-9999px';
          el.style.top = '-9999px';
          el.setAttribute('aria-hidden', 'true');
        }

        // Use WebGazer API if available
        if (window.webgazer) {
          try { window.webgazer.showVideo(false); } catch (e) {}
          try { window.webgazer.showFaceOverlay(false); } catch (e) {}
          try { window.webgazer.showFaceFeedbackBox(false); } catch (e) {}
          try { window.webgazer.showPredictionPoints(false); } catch (e) {}
        }

        // Hide existing nodes
        hide(document.getElementById('webgazerVideoFeed'));
        hide(document.getElementById('webgazerFaceOverlay'));
        hide(document.getElementById('webgazerGazeDot'));

        // Keep hiding if WebGazer recreates them
        if (!window.__wgHideMO) {
          const mo = new MutationObserver((mutList) => {
            for (const m of mutList) {
              for (const n of m.addedNodes) {
                if (!(n instanceof Element)) continue;
                if (n.id === 'webgazerVideoFeed' ||
                    n.id === 'webgazerFaceOverlay' ||
                    n.id === 'webgazerGazeDot') {
                  hide(n);
                }
                const v = n.querySelector?.('#webgazerVideoFeed');
                if (v) hide(v);
                const o = n.querySelector?.('#webgazerFaceOverlay');
                if (o) hide(o);
                const d = n.querySelector?.('#webgazerGazeDot');
                if (d) hide(d);
              }
            }
          });
          mo.observe(document.body, { childList: true, subtree: true });
          window.__wgHideMO = mo;
        }
      })();
    """);
    } catch (e) {
      // ignore
    }
  }
}

// Required for conditional import
GazeService createImpl() => WebGazeService.instance;
