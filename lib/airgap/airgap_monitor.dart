// Watches every radio the platform will tell us about and reduces it to one AirGapStatus.
//
// Sources
//   connectivity_plus     active network paths (Wi-Fi, cellular, Ethernet, VPN, Bluetooth PAN, satellite)
//   flutter_blue_plus     Bluetooth adapter on/off (state only; the app never scans or connects)
//   DeviceInfo channel    Android: airplane-mode flag, Wi-Fi radio enabled, cellular data/radio state
//
// Platform limits (surfaced in the UI, never hidden):
//   * iOS exposes no airplane-mode flag and no Wi-Fi radio power state; only "is there a path".
//     A Wi-Fi radio that is on but not joined looks offline. Status there is "unconfirmed" until the
//     user confirms Airplane Mode in Control Center.
//   * No third-party app can turn radios off on either OS. We detect and instruct.

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/device_info.dart';

enum AirGapLevel {
  sealed, // every reportable radio is off
  unconfirmed, // nothing active detected, but the platform cannot prove radios are off (iOS)
  exposed, // at least one radio or network path is active
}

class AirGapStatus {
  const AirGapStatus({
    required this.level,
    required this.activeInterfaces,
    required this.warnings,
    required this.checkedAt,
    this.userConfirmedAirplane = false,
  });

  final AirGapLevel level;
  final List<String> activeInterfaces; // human-readable: "Wi-Fi", "Cellular", "Bluetooth", ...
  final List<String> warnings; // platform limits worth telling the user
  final DateTime checkedAt;
  final bool userConfirmedAirplane;

  bool get isSafe => level == AirGapLevel.sealed;

  static final initial = AirGapStatus(level: AirGapLevel.unconfirmed, activeInterfaces: const [], warnings: const [], checkedAt: DateTime.fromMillisecondsSinceEpoch(0));
}

class AirGapMonitor extends ValueNotifier<AirGapStatus> {
  AirGapMonitor._() : super(AirGapStatus.initial);
  static final AirGapMonitor instance = AirGapMonitor._();

  final _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<BluetoothAdapterState>? _btSub;
  Timer? _poll;
  List<ConnectivityResult> _paths = const [ConnectivityResult.none];
  BluetoothAdapterState _bt = BluetoothAdapterState.unknown;
  bool _userConfirmedAirplane = false;
  bool _started = false;

  Future<void> start({Duration pollEvery = const Duration(seconds: 5)}) async {
    if (_started) return;
    _started = true;
    _connSub = _conn.onConnectivityChanged.listen((r) {
      _paths = r;
      _userConfirmedAirplane = false; // a path change invalidates a manual confirmation
      _evaluate();
    });
    try {
      if (await FlutterBluePlus.isSupported) {
        _btSub = FlutterBluePlus.adapterState.listen((s) {
          _bt = s;
          _evaluate();
        });
      }
    } catch (_) {
      _bt = BluetoothAdapterState.unknown; // permission denied or no BT hardware
    }
    // Radio flags (airplane, Wi-Fi radio) have no stream on Android without extra receivers, so poll.
    // 5 s is cheap: one binder call, no wakelock, and it stops while the app is backgrounded.
    _poll = Timer.periodic(pollEvery, (_) => _evaluate());
    await refresh();
  }

  Future<void> refresh() async {
    try {
      _paths = await _conn.checkConnectivity();
    } catch (_) {}
    await _evaluate();
  }

  /// iOS only: the user asserts Airplane Mode is on (we cannot read it). Cleared on any path change.
  void confirmAirplaneMode() {
    _userConfirmedAirplane = true;
    _evaluate();
  }

  void pause() {
    _poll?.cancel();
    _poll = null;
  }

  void resume() {
    _poll ??= Timer.periodic(const Duration(seconds: 5), (_) => _evaluate());
    refresh();
  }

  Future<void> _evaluate() async {
    final radio = await DeviceInfo.radioState();
    final active = <String>{};
    final warnings = <String>[];

    for (final p in _paths) {
      switch (p) {
        case ConnectivityResult.wifi:
          active.add('Wi-Fi (connected)');
        case ConnectivityResult.mobile:
          active.add('Cellular data');
        case ConnectivityResult.ethernet:
          active.add('Ethernet / USB tether');
        case ConnectivityResult.vpn:
          active.add('VPN');
        case ConnectivityResult.bluetooth:
          active.add('Bluetooth tether');
        case ConnectivityResult.satellite:
          active.add('Satellite link');
        case ConnectivityResult.other:
          active.add('Other network');
        case ConnectivityResult.none:
          break;
      }
    }
    if (radio.wifiRadioOn == true) active.add('Wi-Fi radio on (scanning)');
    if (radio.cellularRadioOn == true && radio.airplaneMode != true) active.add('Cellular radio on');
    if (_bt == BluetoothAdapterState.on || radio.bluetoothOn == true) active.add('Bluetooth on');

    final canProve = Platform.isAndroid && radio.airplaneMode != null && radio.wifiRadioOn != null;
    if (Platform.isIOS) {
      warnings.add('iOS cannot report whether Wi-Fi or cellular radios are powered. Turn on Airplane Mode in Control Center and confirm below.');
    }
    if (radio.airplaneMode == true && (_bt == BluetoothAdapterState.on || radio.wifiRadioOn == true)) {
      warnings.add('Airplane Mode is on, but Wi-Fi or Bluetooth was switched back on afterwards. Turn them off separately.');
    }
    if (_bt == BluetoothAdapterState.unauthorized) {
      warnings.add('Bluetooth state is hidden because permission was denied. Check it manually.');
    }
    warnings.add('GPS is receive-only and does not break the air gap.');

    final AirGapLevel level;
    if (active.isNotEmpty) {
      level = AirGapLevel.exposed;
    } else if (canProve || _userConfirmedAirplane) {
      level = AirGapLevel.sealed;
    } else {
      level = AirGapLevel.unconfirmed;
    }

    value = AirGapStatus(
      level: level,
      activeInterfaces: active.toList(),
      warnings: warnings,
      checkedAt: DateTime.now(),
      userConfirmedAirplane: _userConfirmedAirplane,
    );
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _btSub?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}
