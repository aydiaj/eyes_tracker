import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/gaze_providers.dart';

class StatusScreen extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final String? secondaryText;
  final VoidCallback? onSecondary;

  const StatusScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.secondaryText,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            //card
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (actionText != null && onAction != null)
                      Consumer(
                        builder: (context, ref, _) {
                          final isRetrying = ref.watch(
                            gazeIsRetryingProvider,
                          );
                          return isRetrying
                              ? CircularProgressIndicator()
                              : FilledButton(
                                onPressed: onAction,
                                child: Text(actionText!),
                              );
                        },
                      ),
                    if (secondaryText != null &&
                        onSecondary != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onSecondary,
                        child: Text(secondaryText!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
