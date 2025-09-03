import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectivityChecker {
  ConnectivityChecker._();

  static final ConnectivityChecker _instance =
      ConnectivityChecker._();

  static ConnectivityChecker get instanse => _instance;

  final Connectivity _conn = Connectivity();

  final InternetConnectionChecker _checker =
      InternetConnectionChecker.instance;

  Stream<bool> online$() =>
      _checker.onStatusChange
          .map(
            (s) => s == InternetConnectionStatus.connected,
          ) //slow? check != disconnected
          .distinct();

  Future<bool> hasNetworkInterface() async {
    final result = await _conn.checkConnectivity();

    const online = {
      ConnectivityResult.wifi,
      ConnectivityResult.mobile,
      ConnectivityResult.ethernet,
      ConnectivityResult
          .vpn, // include if you want VPN to count as online
    };

    return result.isNotEmpty && online.contains(result.first);
  }

  Future<bool> isOnline({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final result = await hasNetworkInterface();
    if (!result) return false;
    try {
      return await _checker.hasConnection.timeout(timeout);
    } on TimeoutException {
      return false;
    }
  }
}
