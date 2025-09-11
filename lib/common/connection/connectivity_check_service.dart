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

  /*   Future<bool> hasNetworkInterface() async {
    final result = await _conn.checkConnectivity();
    return result.isNotEmpty &&
        result.first != ConnectivityResult.none;
  } */

  Future<bool> hasNetworkInterface() async {
    // Deliberately use dynamic to avoid a failing as-check on web.
    final dynamic raw = await _conn.checkConnectivity();

    // Normalize to List<ConnectivityResult>
    late List<ConnectivityResult> list;
    if (raw is ConnectivityResult) {
      list = [raw];
    } else if (raw is List) {
      // Some older web impls hand back a JS array of enums/ints—filter safely.
      list = raw.whereType<ConnectivityResult>().toList();
      // If your web impl returns ints, map them:
      if (list.isEmpty && raw.isNotEmpty && raw.first is int) {
        list =
            (raw as List<int>)
                .map((i) => ConnectivityResult.values[i])
                .toList();
      }
    } else {
      list = const <ConnectivityResult>[];
    }

    if (list.isEmpty) return false;

    const online = {
      ConnectivityResult.wifi,
      ConnectivityResult.mobile,
      ConnectivityResult.ethernet,
      ConnectivityResult.vpn,
      ConnectivityResult.other,
      // On web you sometimes just get wifi/other; treat anything-but-none as “has interface”.
    };

    return list.any(
      (r) => r != ConnectivityResult.none && online.contains(r),
    );
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
