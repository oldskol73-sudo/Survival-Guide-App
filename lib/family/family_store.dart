// Family tab data: members, emergency contacts and gathering points. One small JSON file on the
// device (atomic write). Nothing is uploaded; sharing is a passphrase-encrypted QR/paste code the user sends themselves.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

enum EntryKind { member, contact, place }

class FamilyEntry {
  FamilyEntry({required this.id, required this.name, this.phone = '', this.note = ''});
  final String id;
  String name;
  String phone;
  String note;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'note': note};
  static FamilyEntry fromJson(Map<String, dynamic> j) => FamilyEntry(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

class FamilyStore extends ChangeNotifier {
  FamilyStore._(this._file, this.members, this.contacts, this.places, this.countryOverride);
  final File _file;
  final List<FamilyEntry> members;
  final List<FamilyEntry> contacts;
  final List<FamilyEntry> places;

  /// ISO country code chosen by the user for the emergency numbers card (null = follow the phone's region).
  String? countryOverride;

  static FamilyStore? _instance;
  static FamilyStore get instance => _instance!;

  static Future<FamilyStore> load(String stateDir) async {
    final file = File(p.join(stateDir, 'family.json'));
    var members = <FamilyEntry>[], contacts = <FamilyEntry>[], places = <FamilyEntry>[];
    String? country;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      List<FamilyEntry> read(String k) => [for (final e in (j[k] as List? ?? const []).cast<Map<String, dynamic>>()) FamilyEntry.fromJson(e)];
      members = read('members');
      contacts = read('contacts');
      places = read('places');
      country = j['country'] as String?;
    } catch (_) {
      // First run or unreadable file: start empty.
    }
    return _instance = FamilyStore._(file, members, contacts, places, country);
  }

  List<FamilyEntry> list(EntryKind k) => switch (k) {
        EntryKind.member => members,
        EntryKind.contact => contacts,
        EntryKind.place => places,
      };

  Future<void> upsert(EntryKind kind, FamilyEntry e) => _save(() {
        final l = list(kind);
        final i = l.indexWhere((x) => x.id == e.id);
        i < 0 ? l.add(e) : l[i] = e;
      });

  Future<void> remove(EntryKind kind, FamilyEntry e) => _save(() => list(kind).removeWhere((x) => x.id == e.id));

  Future<void> setCountry(String? code) => _save(() => countryOverride = code);

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ----- share / import. Sharing is always encrypted (see family_code.dart); the store only deals in JSON.

  bool get isEmpty => members.isEmpty && contacts.isEmpty && places.isEmpty;

  /// The family details as JSON, ready to be encrypted into a share code. The country choice stays on this phone.
  String exportJson() => jsonEncode(_toJson(withCountry: false));

  /// Older plain-text codes ("SNFAMILY1:"). They can still be imported but this app no longer creates them.
  static const _legacyPrefix = 'SNFAMILY1:';

  /// Imports an older plain-text code. Returns how many new entries were added, or null if it is not valid.
  Future<int?> importCode(String raw) async {
    final code = raw.trim();
    if (!code.startsWith(_legacyPrefix)) return null;
    try {
      return await importJson(utf8.decode(base64Url.decode(code.substring(_legacyPrefix.length))));
    } catch (_) {
      return null;
    }
  }

  /// Merges shared family JSON into this device's data. Returns how many new entries were added, or null if invalid.
  Future<int?> importJson(String json) async {
    Map<String, dynamic> j;
    try {
      j = jsonDecode(json) as Map<String, dynamic>;
      // Parse everything first so a malformed code changes nothing.
      for (final k in const ['members', 'contacts', 'places']) {
        for (final m in (j[k] as List? ?? const []).cast<Map<String, dynamic>>()) {
          FamilyEntry.fromJson(m);
        }
      }
    } catch (_) {
      return null;
    }
    var added = 0;
    await _save(() {
      void merge(String key, List<FamilyEntry> into) {
        for (final m in (j[key] as List? ?? const []).cast<Map<String, dynamic>>()) {
          final e = FamilyEntry.fromJson(m);
          final dup = into.any((x) => x.id == e.id || (x.name == e.name && x.phone == e.phone));
          if (!dup) {
            into.add(e);
            added++;
          }
        }
      }

      merge('members', members);
      merge('contacts', contacts);
      merge('places', places);
    });
    return added;
  }

  Map<String, dynamic> _toJson({bool withCountry = true}) => {
        'members': [for (final e in members) e.toJson()],
        'contacts': [for (final e in contacts) e.toJson()],
        'places': [for (final e in places) e.toJson()],
        if (withCountry) 'country': countryOverride,
      };

  Future<void> _save(void Function() change) async {
    change();
    notifyListeners();
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(_toJson()), flush: true);
    await tmp.rename(_file.path);
  }
}
