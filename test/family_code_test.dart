// flutter test test/family_code_test.dart
// Covers the passphrase-encrypted family code (QR / paste) and how the family store merges what it decrypts.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:survival_node_mobile/family/family_code.dart';
import 'package:survival_node_mobile/family/family_store.dart';

const _fast = 1000; // low work factor so the tests run quickly; the real default is FamilyCode.defaultIterations

String _sampleJson({int members = 3}) => jsonEncode({
      'members': [
        for (var i = 0; i < members; i++) {'id': 'm$i', 'name': 'Sarah Miller $i', 'phone': '555-014$i', 'note': 'Peanut allergy, carries an EpiPen. Blood type O+.'},
      ],
      'contacts': [
        {'id': 'c1', 'name': 'Dr. Patel', 'phone': '555-0188', 'note': 'Pediatrician'},
      ],
      'places': [
        {'id': 'p1', 'name': "Grandma's house", 'phone': '', 'note': '12 Maple Lane. Back door key under the blue pot.'},
      ],
    });

void main() {
  group('FamilyCode', () {
    test('round trip returns exactly what was sealed', () async {
      final json = _sampleJson();
      final code = await FamilyCode.seal(json, 'correct horse battery', iterations: _fast);
      expect(FamilyCode.isEncrypted(code), isTrue);
      expect(await FamilyCode.open(code, 'correct horse battery'), json);
    });

    test('the code does not contain the readable details', () async {
      final code = await FamilyCode.seal(_sampleJson(), 'correct horse battery', iterations: _fast);
      for (final secret in ['Sarah', 'Patel', 'Maple', 'EpiPen', '555-0']) {
        expect(code.contains(secret), isFalse, reason: 'plaintext "$secret" leaked into the code');
        // ...nor in its base64 payload decoded to bytes
        final bytes = base64Url.decode(base64Url.normalize(code.substring(FamilyCode.prefix.length)));
        expect(latin1.decode(bytes, allowInvalid: true).contains(secret), isFalse);
      }
    });

    test('surrounding spaces in the passphrase do not matter, but case does', () async {
      final code = await FamilyCode.seal(_sampleJson(), '  open sesame  ', iterations: _fast);
      expect(await FamilyCode.open(code, 'open sesame'), _sampleJson());
      await expectLater(FamilyCode.open(code, 'Open Sesame'), throwsA(isA<FamilyCodeException>()));
    });

    test('a wrong passphrase is refused', () async {
      final code = await FamilyCode.seal(_sampleJson(), 'right passphrase', iterations: _fast);
      await expectLater(
        FamilyCode.open(code, 'wrong passphrase'),
        throwsA(isA<FamilyCodeException>().having((e) => e.error, 'error', FamilyCodeError.wrongPassphraseOrDamaged)),
      );
    });

    test('altering any part of the code is detected', () async {
      final code = await FamilyCode.seal(_sampleJson(), 'right passphrase', iterations: _fast);
      final payload = base64Url.decode(base64Url.normalize(code.substring(FamilyCode.prefix.length)));
      // One flipped bit in the header (iteration count, salt, nonce), the ciphertext and the tag.
      for (final index in [3, 10, 25, 40, payload.length - 5, payload.length - 1]) {
        final changed = Uint8List.fromList(payload)..[index] ^= 0x01;
        final tampered = FamilyCode.prefix + base64Url.encode(changed).replaceAll('=', '');
        await expectLater(FamilyCode.open(tampered, 'right passphrase'), throwsA(isA<FamilyCodeException>()), reason: 'byte $index');
      }
    });

    test('two codes for the same data differ (fresh salt and nonce each time)', () async {
      final a = await FamilyCode.seal(_sampleJson(), 'right passphrase', iterations: _fast);
      final b = await FamilyCode.seal(_sampleJson(), 'right passphrase', iterations: _fast);
      expect(a, isNot(b));
    });

    test('things that are not codes are rejected', () async {
      for (final junk in ['', 'hello', 'SNFAMILY2:', 'SNFAMILY2:!!!!', 'SNFAMILY2:AAAA', 'https://example.com']) {
        await expectLater(
          FamilyCode.open(junk, 'whatever pass'),
          throwsA(isA<FamilyCodeException>().having((e) => e.error, 'error', FamilyCodeError.notACode)),
          reason: junk,
        );
      }
    });

    test('a code demanding an absurd amount of work is rejected, not run', () async {
      final bytes = BytesBuilder()
        ..addByte(1)
        ..add((ByteData(4)..setUint32(0, 4000000000)).buffer.asUint8List())
        ..add(Uint8List(16 + 12 + 40));
      final code = FamilyCode.prefix + base64Url.encode(bytes.toBytes()).replaceAll('=', '');
      final stopwatch = Stopwatch()..start();
      await expectLater(
        FamilyCode.open(code, 'whatever pass'),
        throwsA(isA<FamilyCodeException>().having((e) => e.error, 'error', FamilyCodeError.notACode)),
      );
      expect(stopwatch.elapsed.inSeconds, lessThan(5));
    });

    test('a realistic family fits in one QR code', () async {
      final code = await FamilyCode.seal(_sampleJson(members: 8), 'correct horse battery', iterations: _fast);
      final status = QrValidator.validate(data: code, version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.L).status;
      expect(status, QrValidationStatus.valid, reason: 'code is ${code.length} characters');
    });

    test('works at the real work factor', () async {
      final stopwatch = Stopwatch()..start();
      final code = await FamilyCode.seal(_sampleJson(), 'correct horse battery');
      expect(await FamilyCode.open(code, 'correct horse battery'), _sampleJson());
      // ignore: avoid_print
      print('seal + open at ${FamilyCode.defaultIterations} iterations: ${stopwatch.elapsedMilliseconds} ms (VM, debug)');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('FamilyStore import', () {
    late Directory dir;
    late FamilyStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('family_test');
      store = await FamilyStore.load(dir.path);
    });
    tearDown(() => dir.delete(recursive: true));

    test('merges new entries and skips duplicates', () async {
      expect(await store.importJson(_sampleJson()), 5);
      expect(store.members.length, 3);
      expect(await store.importJson(_sampleJson()), 0, reason: 'second import adds nothing');
      expect(store.members.length, 3);
    });

    test('malformed data changes nothing', () async {
      await store.importJson(_sampleJson());
      expect(await store.importJson('not json'), isNull);
      expect(await store.importJson('{"members": [{"id": 5}]}'), isNull);
      expect(store.members.length, 3);
    });

    test('imported data survives a restart', () async {
      await store.importJson(_sampleJson());
      final again = await FamilyStore.load(dir.path);
      expect(again.contacts.single.name, 'Dr. Patel');
    });

    test('exportJson then importJson into a fresh phone copies everything, but not the country choice', () async {
      await store.importJson(_sampleJson());
      await store.setCountry('CA');
      final other = Directory.systemTemp.createTempSync('family_test2');
      addTearDown(() => other.deleteSync(recursive: true));
      final fresh = await FamilyStore.load(other.path);
      expect(await fresh.importJson(store.exportJson()), 5);
      expect(fresh.places.single.name, "Grandma's house");
      expect(fresh.countryOverride, isNull);
    });

    test('older plain-text codes can still be imported', () async {
      final legacy = 'SNFAMILY1:${base64Url.encode(utf8.encode(_sampleJson()))}';
      expect(await store.importCode(legacy), 5);
      expect(await store.importCode('SNFAMILY1:garbage'), isNull);
      expect(await store.importCode('SNFAMILY2:whatever'), isNull);
    });
  });
}
