import 'package:eyes_tracker/common/connection/connectivity_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/connection/connectivity_check_service.dart';

final networkServiceProvider = Provider<ConnectivityChecker>(
  (ref) => ConnectivityChecker.instanse,
);

/// One-shot check: ref.read(onlineNowProvider.future)
final onlineNowProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(networkServiceProvider).isOnline(),
);

/// Live status (optional): ref.watch(onlineStreamProvider)
/// just piping online$() to the UI
final onlineStreamProvider = StreamProvider.autoDispose<bool>(
  (ref) => ref.read(networkServiceProvider).online$(),
);

//extra logic (manual refresh(), debounce/retry, etc) in controller
final connectivityProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
    );
