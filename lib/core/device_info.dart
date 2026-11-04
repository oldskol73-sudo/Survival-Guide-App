// Dart side of the native DeviceInfo channel (Kotlin: MainActivity.kt, Swift: AppDelegate.swift).
// Every call degrades to null instead of throwing, so a missing native method never crashes the app.

import 'package:flutter/services.dart';

class RadioState {
  const RadioState({this.airplaneMode, this.wifiRadioOn, this.bluetoothOn, this.cellularRadioOn});

  /// null = this platform cannot report it (iOS cannot read airplane mode or Wi-Fi radio power).
  final bool? airplaneMode;
  final bool? wifiRadioOn;
  final bool? bluetoothOn;
  final bool? cellularRadioOn;

  factory RadioState.fromMap(Map<Object?, Object?>? m) => RadioState(
        airplaneMode: m?['airplaneMode'] as bool?,
        wifiRadioOn: m?['wifiRadioOn'] as bool?,
        bluetoothOn: m?['bluetoothOn'] as bool?,
        cellularRadioOn: m?['cellularRadioOn'] as bool?,
      );
}

class DeviceInfo {
  DeviceInfo._();
  static const _ch = MethodChannel('survival_node/device');

  /// Bytes available to the app on the volume holding [path].
  static Future<int?> freeBytes(String path) async {
    try {
      return await _ch.invokeMethod<int>('freeBytes', {'path': path});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<int?> totalRamBytes() => _safeInt('totalRam');
  static Future<int?> availableRamBytes() => _safeInt('availableRam');
  static Future<int?> cpuCores() => _safeInt('cpuCores');

  static Future<RadioState> radioState() async {
    try {
      return RadioState.fromMap(await _ch.invokeMethod<Map<Object?, Object?>>('radioState'));
    } catch (_) {
      return const RadioState();
    }
  }

  static Future<int?> _safeInt(String method) async {
    try {
      return await _ch.invokeMethod<int>(method);
    } catch (_) {
      return null;
    }
  }
}
