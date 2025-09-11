import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/utils/enum.dart';
import '../features/gaze/controllers/gaze_controller.dart';
import '../features/gaze/controllers/gaze_state.dart';
import '../features/gaze/data/gaze_service.dart';
import '../features/gaze/models/proctor_score.dart';

final gazeServiceProvider = Provider<GazeService>((ref) {
  final s = createGazeService(); // compile-time picks the impl
  ref.onDispose(s.dispose);
  return s;
});

final gazeControllerProvider =
    AutoDisposeNotifierProvider<GazeController, GazeState>(
      GazeController.new, // equivelant // () => GazeController()
    );

// providers for just as needs // sellective providers
final gazeOffsetProvider = Provider.autoDispose<Offset>((ref) {
  // select ensures rebuild ONLY when x or y changes
  final x = ref.watch(gazeControllerProvider.select((c) => c.x));
  final y = ref.watch(gazeControllerProvider.select((c) => c.y));
  return Offset(x, y);
});

final gazeTrackingOkProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    gazeControllerProvider.select((c) => c.trackingOk ?? false),
  );
});

final gazeStartReadyProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    gazeControllerProvider.select((c) => c.startReady),
  );
});

final gazeisWarmingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(gazeControllerProvider.select((c) => c.isWarming));
});

final gazeVisibleProvider = Provider.autoDispose<bool>((ref) {
  final show = ref.watch(
    gazeControllerProvider.select((c) => c.showGaze),
  );
  final cali = ref.watch(
    gazeControllerProvider.select((c) => c.isCaliMode),
  );
  return show && !cali;
});

final gazeVersionProvider = Provider.autoDispose<String>((ref) {
  return ref.watch(gazeControllerProvider.select((s) => s.version));
});
final gazeStatusProvider = Provider.autoDispose<String>((ref) {
  return ref.watch(gazeControllerProvider.select((s) => s.status));
});

final gazeReadyProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(gazeControllerProvider.select((s) => s.ready));
});

final gazeIsRetryingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    gazeControllerProvider.select((s) => s.isRetrying),
  );
});
final gazePhaseProvider = Provider.autoDispose<InitPhase>((ref) {
  return ref.watch(gazeControllerProvider.select((s) => s.phase));
});

final gazeShowGazeProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(gazeControllerProvider.select((s) => s.showGaze));
});

final gazecalibInProgressProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    gazeControllerProvider.select((s) => s.calib.inProgress),
  );
});

final gazecalibNextXProvider = Provider.autoDispose<double>((ref) {
  return ref.watch(
    gazeControllerProvider.select((s) => s.calib.nextX),
  );
});
final gazecalibNextYProvider = Provider.autoDispose<double>((ref) {
  return ref.watch(
    gazeControllerProvider.select((s) => s.calib.nextY),
  );
});

final gazecalibProgressProvider = Provider.autoDispose<double>((ref) {
  return ref.watch(
    gazeControllerProvider.select((s) => s.calib.progress),
  );
});

final gazeproctorDegreeProvider = Provider.autoDispose<double>((ref) {
  return ref.watch(
    gazeControllerProvider.select((s) => s.proctorDegree),
  );
});

final gazeCheatingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(gazeControllerProvider.select((s) => s.cheating));
});

final gazeProctorScoreProvider = Provider.autoDispose<ProctorScore>((
  ref,
) {
  final degree = ref.watch(
    gazeControllerProvider.select((s) => s.proctorDegree),
  );
  final cheating = ref.watch(
    gazeControllerProvider.select((s) => s.cheating),
  );
  return ProctorScore(degree, cheating);
});
