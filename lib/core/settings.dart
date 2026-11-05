// Persisted user settings. Written atomically (tmp + rename) so a crash never leaves a half file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AppSettings extends ChangeNotifier {
  AppSettings._(this._file);
  final File _file;

  bool lowPowerMode = false; // halves threads, caps tokens, pauses background embedding
  bool backgroundEmbedding = true; // embed new documents automatically after indexing
  bool sealed = false; // Stage B: NetworkLockdown active
  bool verifyOnOpen = true; // re-hash a library file before opening it
  bool tourSeen = false; // the first-launch "How to use" tour has been shown
  int volumeIndex = 0; // index into StoragePaths.availableVolumes()
  Set<String> enabledCategories = {};

  static late AppSettings instance;

  static Future<AppSettings> load(String stateDir, Iterable<String> defaultCategories) async {
    final s = AppSettings._(File(p.join(stateDir, 'settings.json')));
    s.enabledCategories = defaultCategories.toSet();
    try {
      final j = jsonDecode(await s._file.readAsString()) as Map<String, dynamic>;
      s.lowPowerMode = j['lowPowerMode'] as bool? ?? false;
      s.backgroundEmbedding = j['backgroundEmbedding'] as bool? ?? true;
      s.sealed = j['sealed'] as bool? ?? false;
      s.verifyOnOpen = j['verifyOnOpen'] as bool? ?? true;
      s.tourSeen = j['tourSeen'] as bool? ?? false;
      s.volumeIndex = j['volumeIndex'] as int? ?? 0;
      s.enabledCategories = {...(j['enabledCategories'] as List? ?? defaultCategories.toList()).cast<String>()};
    } catch (_) {
      // First run or unreadable file: keep defaults.
    }
    instance = s;
    return s;
  }

  Future<void> update(void Function(AppSettings s) change) async {
    change(this);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'lowPowerMode': lowPowerMode,
      'backgroundEmbedding': backgroundEmbedding,
      'sealed': sealed,
      'verifyOnOpen': verifyOnOpen,
      'tourSeen': tourSeen,
      'volumeIndex': volumeIndex,
      'enabledCategories': enabledCategories.toList(),
    }), flush: true);
    await tmp.rename(_file.path);
    notifyListeners();
  }
}
