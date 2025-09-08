import 'package:eyes_tracker/common/utils/enum.dart';
import 'package:eyes_tracker/features/gaze/models/proctor_score.dart';
import 'package:eyes_tracker/features/gaze/ui/pages/calib_page.dart';
import 'package:eyes_tracker/providers/conn_providers.dart';
import 'package:eyes_tracker/providers/gaze_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../../common/ui/widgets/connectivity_bannar.dart';
import '../widgets/gaze_dot.dart';

class GazePage extends ConsumerStatefulWidget {
  const GazePage({super.key});

  @override
  ConsumerState<GazePage> createState() => _GazePageState();
}

class _GazePageState extends ConsumerState<GazePage> {
  static const _scope = 'home_calibration';
  final _calibrationKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    ShowcaseView.register(
      scope: _scope,
      onFinish: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('did_run', true);
      },
      onDismiss: (key) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('did_run', true);
      },
    );

    _maybeStartShowcase();
  }

  Future<void> _maybeStartShowcase() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('did_run') ?? false;
    if (shown) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ShowcaseView.getNamed(
          _scope,
        ).startShowCase([_calibrationKey]);
      } catch (e) {
        debugPrint('Showcase start failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor:
            Theme.of(context).colorScheme.onPrimaryContainer,

        title: const Text('Eye Tracker Demo'),
        actions: [
          Showcase(
            key: _calibrationKey,
            title: 'Calibration setup',
            description:
                'Start here to calibrate the camera & screen.\n'
                'Do this once for best tracking accuracy.',
            toolTipMargin: 8,
            titlePadding: EdgeInsets.symmetric(vertical: 8),
            descriptionPadding: EdgeInsets.only(bottom: 4),
            descTextStyle: TextStyle(fontSize: 14),
            disableBarrierInteraction: true,
            showArrow: true,
            tooltipActionConfig: const TooltipActionConfig(
              alignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              gapBetweenContentAndAction: 10,
              position: TooltipActionPosition.outside,
            ),
            tooltipActions: [
              TooltipActionButton(
                type: TooltipDefaultActionType.skip,
                padding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                borderRadius: BorderRadius.all(Radius.circular(8)),
                // border: Border.fromBorderSide(BorderSide()),
                //backgroundColor: Colors.transparent,
                textStyle: TextStyle(color: Colors.white),
                name: "OK",
                onTap: ShowcaseView.getNamed(_scope).dismiss,
              ),
            ],
            child: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CalibPage(),
                  ),
                );
                /* ref
                    .read(gazeControllerProvider.notifier)
                    .startCalibration(); */
              },
              icon: Icon(Icons.architecture),
              tooltip: 'Calibration setup',
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          // Send to controller after this frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(gazeControllerProvider.notifier)
                .updateScreenSize(size);
          });

          return Stack(
            children: [
              Consumer(
                builder: (ctx, ref, _) {
                  final conn = ref.watch(connectivityProvider);
                  return ConnectivityBannar(
                    isConnected: conn.online,
                    hasIF: conn.hasInterface,
                  );
                },
              ),
              RepaintBoundary(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Consumer(
                        builder:
                            (context, ref, _) => Text(
                              'SDK version: ${ref.watch(gazeVersionProvider)}',
                              style:
                                  Theme.of(
                                    context,
                                  ).textTheme.labelLarge,
                            ),
                      ),
                      // Icon(Icons.architecture),
                      Consumer(
                        builder:
                            (context, ref, _) => Text(
                              'State: ${ref.watch(gazeStatusProvider)}',
                              style:
                                  Theme.of(
                                    context,
                                  ).textTheme.labelLarge,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Consumer(
                        builder: (context, ref, _) {
                          final isCalib = ref.watch(
                            gazecalibInProgressProvider,
                          );
                          return Visibility(
                            visible: !isCalib,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                Consumer(
                                  builder: (context, ref, _) {
                                    final ready = ref.watch(
                                      gazeReadyProvider,
                                    );
                                    if (!ready) {
                                      return const SizedBox.shrink();
                                    }

                                    final showGaze = ref.watch(
                                      gazeShowGazeProvider,
                                    );

                                    final currentStatus = ref.watch(
                                      gazeStatusProvider,
                                    );

                                    final ctrl = ref.read(
                                      gazeControllerProvider.notifier,
                                    );

                                    return showGaze
                                        ? ElevatedButton(
                                          onPressed: () {
                                            ctrl.stopTracking().then((
                                              score,
                                            ) {
                                              if (context.mounted) {
                                                showScoreDialog(
                                                  context,
                                                  score,
                                                );
                                              }
                                            });
                                          },
                                          child: Text(
                                            'STOP TRACKING',
                                          ),
                                        )
                                        : currentStatus ==
                                            'Warming Up'
                                        ? Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 100,
                                              ),
                                          child:
                                              CircularProgressIndicator(),
                                        )
                                        : ElevatedButton(
                                          onPressed: () {
                                            ctrl.startTracking();
                                          },
                                          child: Text(
                                            'START TRACKING',
                                          ),
                                        );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      8.0,
                                    ),
                                    child: Text(
                                      'For more accurate tracking results, \n'
                                      'please complete the calibration \n by clicking the '
                                      'button in the App Bar.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium!
                                          .copyWith(
                                            fontWeight:
                                                FontWeight.w400,
                                            // fontSize: 16,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      /* const SizedBox(height: 12),
                    Consumer(builder: (context, ref, _) {
                      final score = ref.watch(gazeProctorScoreProvider);
                      return
                    Text(
                      'Proctor degree: ${score.degree.toStringAsFixed(1)}'
                      '${score.cheating ? "  (cheating)" : ""}',
                    );
                    },),
                    const SizedBox(height: 12), */
                      Consumer(
                        builder: (context, ref, _) {
                          final inCalib = ref.watch(
                            gazecalibInProgressProvider,
                          );
                          final ready = ref.watch(gazeReadyProvider);
                          final ctrl = ref.read(
                            gazeControllerProvider.notifier,
                          );
                          if (ready && inCalib) {
                            //&& showGaze && !inCalib == START
                            return ElevatedButton(
                              onPressed: () => ctrl.stopCalibration(),
                              child: const Text('STOP CALIBRATION'),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              Consumer(
                builder: (context, ref, _) {
                  final inCalib = ref.watch(
                    gazecalibInProgressProvider,
                  );
                  final showGaze = ref.watch(gazeShowGazeProvider);
                  final nextX = ref.watch(gazecalibNextXProvider);
                  final nextY = ref.watch(gazecalibNextYProvider);
                  final progress = ref.watch(
                    gazecalibProgressProvider,
                  );

                  if (showGaze && !inCalib) {
                    return GazeDot(
                      offset: ref.watch(gazeOffsetProvider),
                      ok: ref.watch(gazeTrackingOkProvider),
                    );
                  } else if (inCalib) {
                    return Positioned(
                      left: nextX - 10,
                      top: nextY - 10,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey,
                        ),
                      ),
                    );
                  }
                  {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  showScoreDialog(BuildContext ctx, ProctorScore score) {
    showDialog(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: const Text('Proctor result'),
            content: Text(
              'Degree: ${score.degree.toStringAsFixed(1)}'
              '\nStatus: ${score.cheating ? 'Cheating suspected' : 'OK'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
