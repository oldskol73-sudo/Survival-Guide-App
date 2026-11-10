// Encrypted family code: the text behind the Share QR code and the copy/paste option.
//
// The family details are compressed, then encrypted with AES-256-GCM using a key derived from a passphrase
// the sender chooses (PBKDF2-HMAC-SHA256). The QR code carries only the ciphertext, so anyone who photographs
// or forwards it learns nothing without the passphrase. The passphrase is never put in the code: the sender
// tells it to the receiver separately.
//
// Wire format (after the "SNFAMILY2:" prefix, base64url without padding):
//   version (1 byte) | PBKDF2 iterations (4 bytes, big-endian) | salt (16) | nonce (12) | ciphertext | GCM tag (16)
// The first 33 bytes (everything before the ciphertext) are authenticated as associated data, so changing the
// iteration count, salt or nonce makes decryption fail instead of weakening the key.

import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

enum FamilyCodeError {
  /// Not something this app produced (or too damaged to read).
  notACode,

  /// The authentication tag did not match: wrong passphrase, or the code was altered.
  wrongPassphraseOrDamaged,
}

class FamilyCodeException implements Exception {
  const FamilyCodeException(this.error);
  final FamilyCodeError error;
  @override
  String toString() => 'FamilyCodeException($error)';
}

class FamilyCode {
  FamilyCode._();

  /// Encrypted codes. The older plain-text codes ("SNFAMILY1:") can still be imported but are never produced.
  static const prefix = 'SNFAMILY2:';
  static const legacyPrefix = 'SNFAMILY1:';

  static const minPassphraseLength = 8;

  /// Work factor for the key derivation. Slow on purpose, so guessing a passphrase is expensive.
  static const defaultIterations = 200000;

  static const _version = 1;
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _headerLength = 1 + 4 + _saltLength + _nonceLength;

  /// A code asking for more work than this is rejected, so a crafted code cannot freeze the phone.
  static const _maxIterations = 2000000;
  static const _maxPlainBytes = 1 << 20;

  static bool isEncrypted(String code) => code.trim().startsWith(prefix);
  static bool isLegacy(String code) => code.trim().startsWith(legacyPrefix);

  /// Encrypts [plainJson] and returns the code. Runs the slow key derivation off the UI thread.
  static Future<String> seal(String plainJson, String passphrase, {int iterations = defaultIterations}) =>
      Isolate.run(() => _seal(plainJson, passphrase, iterations));

  /// Decrypts a code made by [seal]. Throws [FamilyCodeException] if it is not a code or the passphrase is wrong.
  static Future<String> open(String code, String passphrase) => Isolate.run(() => _open(code, passphrase));

  static Future<String> _seal(String plainJson, String passphrase, int iterations) async {
    final random = Random.secure();
    Uint8List randomBytes(int n) => Uint8List.fromList([for (var i = 0; i < n; i++) random.nextInt(256)]);
    final salt = randomBytes(_saltLength);
    final nonce = randomBytes(_nonceLength);

    final header = BytesBuilder()
      ..addByte(_version)
      ..add((ByteData(4)..setUint32(0, iterations)).buffer.asUint8List())
      ..add(salt)
      ..add(nonce);
    final headerBytes = header.toBytes();

    final key = await _deriveKey(passphrase, salt, iterations);
    final box = await AesGcm.with256bits().encrypt(
      zlib.encode(utf8.encode(plainJson)),
      secretKey: key,
      nonce: nonce,
      aad: headerBytes,
    );
    final out = BytesBuilder()
      ..add(headerBytes)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return prefix + base64Url.encode(out.toBytes()).replaceAll('=', '');
  }

  static Future<String> _open(String code, String passphrase) async {
    final text = code.trim();
    if (!text.startsWith(prefix)) throw const FamilyCodeException(FamilyCodeError.notACode);

    Uint8List bytes;
    try {
      bytes = base64Url.decode(base64Url.normalize(text.substring(prefix.length)));
    } catch (_) {
      throw const FamilyCodeException(FamilyCodeError.notACode);
    }
    if (bytes.length < _headerLength + _macLength || bytes[0] != _version) {
      throw const FamilyCodeException(FamilyCodeError.notACode);
    }

    final iterations = ByteData.sublistView(bytes, 1, 5).getUint32(0);
    if (iterations < 1 || iterations > _maxIterations) throw const FamilyCodeException(FamilyCodeError.notACode);

    final header = Uint8List.sublistView(bytes, 0, _headerLength);
    final salt = Uint8List.sublistView(bytes, 5, 5 + _saltLength);
    final nonce = Uint8List.sublistView(bytes, 5 + _saltLength, _headerLength);
    final cipherText = Uint8List.sublistView(bytes, _headerLength, bytes.length - _macLength);
    final mac = Mac(Uint8List.sublistView(bytes, bytes.length - _macLength));

    try {
      final key = await _deriveKey(passphrase, salt, iterations);
      final plain = await AesGcm.with256bits().decrypt(SecretBox(cipherText, nonce: nonce, mac: mac), secretKey: key, aad: header);
      final inflated = zlib.decode(plain);
      if (inflated.length > _maxPlainBytes) throw const FamilyCodeException(FamilyCodeError.notACode);
      return utf8.decode(inflated);
    } on FamilyCodeException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const FamilyCodeException(FamilyCodeError.wrongPassphraseOrDamaged);
    } catch (_) {
      throw const FamilyCodeException(FamilyCodeError.wrongPassphraseOrDamaged);
    }
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt, int iterations) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256).deriveKeyFromPassword(password: passphrase.trim(), nonce: salt);
}
