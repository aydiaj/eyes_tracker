import 'dart:async';
import '../models/gaze_point.dart';
import '../models/calibration_state.dart';
import '../models/proctor_metric.dart';

import 'eyedid_service.dart'
    if (dart.library.html) 'webgaze_service.dart';

abstract class GazeService {
  Future<String> initialize();

  Future<bool> ensureCameraPermission();

  Future<bool> requestCameraPermission();

  Future<void> startTracking();
  Future<void> stopTracking();

  Future<bool> isTracking();

  Future<bool> isCalibrating();

  Future<void> startCalibration({bool usePrevious = true});
  Future<void> stopCalibration();

  Future<String> get version;
  bool get startReady;

  Future<void> prewarm();

  Stream<bool> startReady$();
  Stream<GazePoint> gaze$();
  Stream<String> status$();
  Stream<CalibrationState> calibration$();
  Stream<ProctorTick> metrics$();
  Stream<String> drop$();

  void dispose();
}

GazeService createGazeService() => createImpl();
