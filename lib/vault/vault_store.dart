// Documents vault: IDs, insurance, medical and other records kept ONLY on this device.
//
// Security model
//  * A random 256-bit key is generated once and stored in the platform keystore (Android Keystore /
//    iOS Keychain) through flutter_secure_storage. It never leaves the device and is never written to
//    ordinary files.
//  * Every file in <state>/vault/ (the index and each photo) is encrypted with AES-256-GCM, so copying the
//    folder off the phone yields nothing readable.
//  * The key is only loaded into memory after the user passes the device lock (fingerprint/face, falling
//    back to the phone's PIN/pattern/password). Locking clears it. The vault locks whenever the app goes
//    to the background.
//  * Decrypted photos are held in memory only; no temporary files are written.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;

enum DocCategory {
  identity('Identity', 'ID, passport, license'),
  insurance('Insurance', 'Health, home, auto, life'),
  medical('Medical', 'Records, prescriptions'),
  financial('Financial', 'Accounts, deeds, titles'),
  other('Other', 'Anything else');

  const DocCategory(this.label, this.hint);
  final String label;
  final String hint;
}

class VaultDoc {
  VaultDoc({required this.id, required this.title, required this.category, this.notes = '', List<String>? files, DateTime? created})
      : files = files ?? [],
        created = created ?? DateTime.now();
  final String id;
  String title;
  DocCategory category;
  String notes;

  /// Ids of encrypted photo blobs belonging to this document.
  final List<String> files;
  final DateTime created;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'category': category.name, 'notes': notes, 'files': files, 'created': created.toIso8601String()};

  static VaultDoc fromJson(Map<String, dynamic> j) => VaultDoc(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        category: DocCategory.values.firstWhere((c) => c.name == j['category'], orElse: () => DocCategory.other),
        notes: j['notes'] as String? ?? '',
        files: [...(j['files'] as List? ?? const []).cast<String>()],
        created: DateTime.tryParse(j['created'] as String? ?? ''),
      );
}

enum UnlockResult { ok, cancelled, noDeviceLock, failed }

class VaultStore extends ChangeNotifier {
  VaultStore._(this._dir);
  final Directory _dir;

  static VaultStore? _instance;
  static VaultStore get instance => _instance!;

  static Future<VaultStore> init(String stateDir) async {
    final dir = Directory(p.join(stateDir, 'vault'));
    await dir.create(recursive: true);
    return _instance = VaultStore._(dir);
  }

  static const _keyName = 'survival_node_vault_key';
  static const _secure = MethodChannel('survival_node/secure');
  static final _aes = AesGcm.with256bits();

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  SecretKey? _key;
  List<VaultDoc> _docs = [];

  bool get unlocked => _key != null;
  List<VaultDoc> get docs => List.unmodifiable(_docs);

  // ------------------------------------------------------------------ lock / unlock

  /// Asks for the device lock. The vault refuses to work on a phone with no screen lock at all, because
  /// then anyone holding the phone could open it.
  Future<UnlockResult> unlock() async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockResult.noDeviceLock;
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your documents vault',
        biometricOnly: false, // allow the phone PIN/pattern as a fallback
        persistAcrossBackgrounding: true,
      );
      if (!ok) return UnlockResult.cancelled;
      _key = await _loadOrCreateKey();
      _docs = await _readIndex();
      await _setSecure(true);
      notifyListeners();
      return UnlockResult.ok;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet || LocalAuthExceptionCode.noBiometricsEnrolled || LocalAuthExceptionCode.noBiometricHardware => UnlockResult.noDeviceLock,
        LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled || LocalAuthExceptionCode.timeout => UnlockResult.cancelled,
        _ => UnlockResult.failed,
      };
    } catch (_) {
      _key = null;
      _docs = [];
      return UnlockResult.failed;
    }
  }

  Future<void> lock() async {
    if (_key == null) return;
    _key = null;
    _docs = [];
    await _setSecure(false);
    notifyListeners();
  }

  /// Development only: `flutter build apk --dart-define=VAULT_ALLOW_SCREENSHOTS=true` lets automated
  /// screenshots see the vault. Never set in a real build; the default keeps the screen protected.
  static const _allowScreenshots = bool.fromEnvironment('VAULT_ALLOW_SCREENSHOTS');

  Future<void> _setSecure(bool on) async {
    if (_allowScreenshots && on) return;
    try {
      await _secure.invokeMethod('setSecure', {'on': on});
    } on MissingPluginException {
      // Platform without the flag (iOS handles recents-snapshot separately): not fatal.
    }
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return SecretKey(base64Decode(existing));
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    await _storage.write(key: _keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }

  // ------------------------------------------------------------------ documents

  Future<void> upsert(VaultDoc d) async {
    _need();
    final i = _docs.indexWhere((x) => x.id == d.id);
    i < 0 ? _docs.add(d) : _docs[i] = d;
    await _writeIndex();
    notifyListeners();
  }

  Future<void> delete(VaultDoc d) async {
    _need();
    for (final f in d.files) {
      final file = _blob(f);
      if (await file.exists()) await file.delete();
    }
    _docs.removeWhere((x) => x.id == d.id);
    await _writeIndex();
    notifyListeners();
  }

  /// Encrypts [bytes] and stores them; returns the new blob id to add to the document's [VaultDoc.files].
  Future<String> addPhoto(Uint8List bytes) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    await _writeEncrypted(_blob(id), bytes);
    return id;
  }

  Future<Uint8List> readPhoto(String id) async => await _readEncrypted(_blob(id)) ?? Uint8List(0);

  Future<void> deletePhoto(String id) async {
    final f = _blob(id);
    if (await f.exists()) await f.delete();
  }

  /// Wipes everything, including the key. Used by "Erase vault".
  Future<void> eraseAll() async {
    _key = null;
    _docs = [];
    if (await _dir.exists()) {
      await for (final e in _dir.list()) {
        if (e is File) await e.delete();
      }
    }
    await _storage.delete(key: _keyName);
    await _setSecure(false);
    notifyListeners();
  }

  // ------------------------------------------------------------------ encrypted files

  void _need() {
    if (_key == null) throw StateError('Vault is locked');
  }

  File _blob(String id) => File(p.join(_dir.path, '$id.bin'));
  File get _indexFile => File(p.join(_dir.path, 'index.bin'));

  Future<void> _writeEncrypted(File f, List<int> clear) async {
    _need();
    final box = await _aes.encrypt(clear, secretKey: _key!);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(box.concatenation(), flush: true);
    await tmp.rename(f.path);
  }

  Future<Uint8List?> _readEncrypted(File f) async {
    _need();
    if (!await f.exists()) return null;
    final box = SecretBox.fromConcatenation(await f.readAsBytes(), nonceLength: 12, macLength: 16);
    return Uint8List.fromList(await _aes.decrypt(box, secretKey: _key!));
  }

  Future<List<VaultDoc>> _readIndex() async {
    try {
      final bytes = await _readEncrypted(_indexFile);
      if (bytes == null) return [];
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return [for (final d in (j['docs'] as List).cast<Map<String, dynamic>>()) VaultDoc.fromJson(d)];
    } catch (_) {
      // Wrong key or damaged file. Do not overwrite it silently; surface as an empty vault only in memory.
      return [];
    }
  }

  Future<void> _writeIndex() => _writeEncrypted(_indexFile, utf8.encode(jsonEncode({'docs': [for (final d in _docs) d.toJson()]})));
}
