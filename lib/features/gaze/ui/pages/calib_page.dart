import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/ui/widgets/connectivity_bannar.dart';
import '../../../../providers/conn_providers.dart';
import '../../../../providers/gaze_providers.dart';

class CalibPage extends ConsumerWidget {
  const CalibPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: null,
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
                        builder: (context, ref, _) {
                          final inCalib = ref.watch(
                            gazecalibInProgressProvider,
                          );
                          final ctrl = ref.read(
                            gazeControllerProvider.notifier,
                          );
                          if (inCalib) {
                            return ElevatedButton(
                              onPressed: () {
                                ctrl.stopCalibration();
                                Navigator.of(context).pop();
                              },
                              child: const Text('STOP/DONE'),
                            );
                          } else {
                            return Column(
                              children: [
                                /*  ElevatedButton(
                                  onPressed:
                                      () =>
                                          ref
                                              .read(
                                                gazeControllerProvider
                                                    .notifier,
                                              )
                                              .startCalibration(),
                                  child: const Text('START'),
                                ),
                                SizedBox(height: 20), */
                                CalibrationTipsCard(
                                  onDone: () {
                                    if (inCalib) {
                                      ctrl.stopCalibration();
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  onStart:
                                      () =>
                                          ref
                                              .read(
                                                gazeControllerProvider
                                                    .notifier,
                                              )
                                              .startCalibration(),
                                ),
                              ],
                            );
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

                  if (showGaze && inCalib) {
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
}

/// Inline card you can drop anywhere (e.g., in your calibration screen body).
class CalibrationTipsCard extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback? onDone;
  final EdgeInsetsGeometry padding;

  const CalibrationTipsCard({
    super.key,
    required this.onStart,
    this.onDone,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge;
    final bodyStyle = theme.textTheme.bodyMedium;

    Widget bullet(IconData icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: bodyStyle)),
      ],
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.architecture, size: 28),
                const SizedBox(width: 12),
                Text('Calibration Tips', style: titleStyle),
              ],
            ),
            const SizedBox(height: 12),
            bullet(
              Icons.light_mode,
              'Use bright, even lighting — avoid shadows or screen glare.',
            ),
            const SizedBox(height: 8),
            bullet(
              Icons.visibility,
              'Keep your eyes fully visible; avoid hair blocking or glasses glare.',
            ),
            const SizedBox(height: 8),
            bullet(
              Icons.straighten,
              'Sit at a steady, comfortable distance from the screen.',
            ),
            const SizedBox(height: 8),
            bullet(
              Icons.accessibility_new,
              'Keep your head upright and as still as possible during calibration.',
            ),
            const SizedBox(height: 8),
            bullet(
              Icons.phone_iphone,
              'Place the device on a stable surface to prevent camera shake.',
            ),
            const SizedBox(height: 8),
            bullet(
              Icons.grid_on,
              'Look directly at each target dot until calibration completes.',
            ),
            const SizedBox(height: 8),
            bullet(
              Icons.do_not_disturb_on_total_silence,
              'Minimize background movement and sudden lighting changes.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (onDone != null)
                  OutlinedButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.check),
                    label: const Text('Close'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.architecture),
                  label: const Text('Start Calibration'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
