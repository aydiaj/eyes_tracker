import 'package:flutter/material.dart';

import '../../../../common/ui/widgets/app_spinner.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppSpinner(
              icon: Icons.center_focus_strong,
              size: 64,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            //const SizedBox(height: 20),
            //Icon(Icons.center_focus_strong, size: 100, color: Colors.grey[400],),
            //LinearProgressIndicator(),
            //Text('Tracking engine is starting...'),
          ],
        ),
      ),
    );
  }
}
