import 'package:eyes_tracker/features/gaze/ui/pages/gaze_page.dart';
import 'package:eyes_tracker/features/gaze/ui/pages/loading_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/enum.dart';
import '../../../../providers/gaze_providers.dart';
import 'status_page.dart';

class GazeGate extends ConsumerWidget {
  const GazeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(gazePhaseProvider);
    final status = ref.watch(gazeStatusProvider);

    return Scaffold(
      appBar: null,
      body: switch (phase) {
        InitPhase.offline => StatusScreen(
          icon: Icons.wifi_off,
          title: 'Offline',
          message: 'No internet connection detected.',
          actionText: 'Retry',
          onAction:
              () => ref.read(gazeControllerProvider.notifier).retry(),
        ),

        InitPhase.cameradenied => StatusScreen(
          icon: Icons.videocam_off,
          title: 'Camera permission denied',
          message: 'Allow camera to enable eye tracking.',
          actionText: 'Request permission',
          onAction:
              () => ref.read(gazeControllerProvider.notifier).retry(),
          secondaryText: 'Retry',
          onSecondary:
              () => ref.read(gazeControllerProvider.notifier).retry(),
        ),

        InitPhase.timeout => StatusScreen(
          icon: Icons.hourglass_bottom,
          title: 'Taking longer than expected',
          message: status, // includes your watchdog status text
          actionText: 'Try Again',
          onAction:
              () => ref.read(gazeControllerProvider.notifier).retry(),
        ),

        InitPhase.error => StatusScreen(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: status,
          actionText: 'Retry',
          onAction:
              () => ref.read(gazeControllerProvider.notifier).retry(),
        ),

        // loading-ish phases
        InitPhase.idle => const LoadingScreen(),

        InitPhase.connecting => const LoadingScreen(),
        InitPhase.initializing => const LoadingScreen(),

        InitPhase.disposing => const Center(child: Text('Closing…')),
        InitPhase.ready => const GazePage(),
      },
    );
  }
}
