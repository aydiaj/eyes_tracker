import 'dart:async';

import 'package:eyes_tracker/common/connection/connectivity_check_service.dart';
import 'package:eyes_tracker/providers/conn_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityState {
  final bool online;
  final bool hasInterface;

  const ConnectivityState({
    required this.online,
    required this.hasInterface,
  });

  ConnectivityState copyWith({bool? online, bool? hasInterface}) =>
      ConnectivityState(
        online: online ?? this.online,
        hasInterface: hasInterface ?? this.hasInterface,
      );
}

class ConnectivityController extends Notifier<ConnectivityState> {
  late final ConnectivityChecker _svc;
  ConnectivityController();

  StreamSubscription<bool>? _onlineSub;

  @override
  ConnectivityState build() {
    _svc = ref.read(networkServiceProvider);
    Future.microtask(_wireStreams);
    ref.onDispose(() => _onlineSub?.cancel());
    return const ConnectivityState(
      online: false,
      hasInterface: false,
    );
  }

  Future<void> _wireStreams() async {
    _onlineSub?.cancel();
    _onlineSub = _svc.online$().listen((isOnline) async {
      state = state.copyWith(
        online: isOnline,
        hasInterface: await _svc.hasNetworkInterface(), //new
      );
    });
  }

  Future<bool> ensureBaseline() async {
    final hasIf = await _svc.hasNetworkInterface();
    final isOn = await _svc.isOnline();
    state = state.copyWith(online: isOn, hasInterface: hasIf);
    return isOn;
  }

  Future<void> refresh() async => ensureBaseline();
}
