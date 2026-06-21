import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _connectivityStreamController =
      StreamController<ConnectivityResult>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty) {
        _connectivityStreamController.add(results.first);
      } else {
        _connectivityStreamController.add(ConnectivityResult.none);
      }
    });
  }

  Stream<ConnectivityResult> get connectivityStream =>
      _connectivityStreamController.stream;

  Future<bool> isConnected() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.isNotEmpty && results.first != ConnectivityResult.none;
  }
}
