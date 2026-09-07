import 'dart:async';

enum ConnectivityResult {
  wifi,
  mobile,
  ethernet,
  vpn,
  bluetooth,
  other,
  none,
}

class Connectivity {
  static final Connectivity _instance = Connectivity._internal();
  factory Connectivity() => _instance;
  Connectivity._internal();

  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return Stream.value([ConnectivityResult.wifi]);
  }

  Future<List<ConnectivityResult>> checkConnectivity() async {
    return [ConnectivityResult.wifi];
  }
}
