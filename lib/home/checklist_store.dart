// Gear kits: built-in starter kits the user can tick off, add to and reset.
// State is one small JSON file (atomic write), so it works fully offline and survives crashes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class Kit {
  const Kit(this.id, this.title, this.subtitle, this.groups);
  final String id;
  final String title;
  final String subtitle;
  final List<(String, List<(String, String?)>)> groups;
}

class KitItem {
  KitItem(this.id, this.kit, this.group, this.title, {this.note, this.custom = false, this.done = false});
  final String id;
  final String kit;
  final String group;
  final String title;
  final String? note;
  final bool custom;
  bool done;
}

/// The original single checklist ("survival") keeps its id format so saved ticks survive the upgrade.
const kits = <Kit>[
  Kit('survival', 'Survival Kit', 'The basics for any emergency', [
    ('Water', [
      ('Water: 1 gallon (4 L) per person per day, 3 days minimum', 'Two weeks is better'),
      ('Water filter or purifier', null),
      ('Unscented household bleach plus dropper', 'For emergency disinfection'),
      ('Metal pot or bottle for boiling', null),
    ]),
    ('Food', [
      ('Non-perishable food, 3 days minimum', null),
      ('Manual can opener', null),
      ('Camp stove and fuel', null),
      ('Eating utensils, cup, pot', null),
    ]),
    ('Medical', [
      ('First-aid kit', null),
      ('Prescription medicines, 7-day supply', null),
      ('Pain, fever and anti-diarrheal medicine', null),
      ('Tourniquet and pressure bandages', null),
      ('Face masks and nitrile gloves', null),
    ]),
    ('Shelter & warmth', [
      ('Tent or tarp with cord', null),
      ('Sleeping bag or wool blankets', null),
      ('Emergency space blankets', null),
      ('Extra clothing, sturdy shoes, rain gear', null),
    ]),
    ('Fire & light', [
      ('Lighter and waterproof matches', null),
      ('Ferro rod or other backup fire starter', null),
      ('Flashlight or headlamp with spare batteries', null),
    ]),
    ('Tools', [
      ('Fixed-blade knife or multi-tool', null),
      ('Duct tape and paracord', null),
      ('Folding saw or hatchet', null),
      ('Work gloves', null),
    ]),
    ('Communication & navigation', [
      ('Hand-crank or battery radio', null),
      ('Whistle', null),
      ('Paper maps of your area and a compass', null),
      ('Power bank and charging cables', null),
    ]),
    ('Documents & cash', [
      ('Copies of ID, insurance and medical records', 'In a waterproof bag'),
      ('Cash in small bills', null),
      ('Emergency contact list on paper', null),
    ]),
    ('Hygiene & sanitation', [
      ('Soap and hand sanitizer', null),
      ('Toilet paper and heavy trash bags', null),
      ('Feminine and infant supplies, if needed', null),
    ]),
  ]),
  Kit('bugout', 'Bug-Out Bag', 'Three days of grab-and-go gear', [
    ('Carry', [
      ('Backpack that fits you, 35-50 L', null),
      ('Water bottles or bladder, 2 L minimum', null),
      ('Water filter or purification tablets', null),
      ('High-calorie food, 3 days', 'Bars, nuts, dehydrated meals'),
    ]),
    ('Shelter & warmth', [
      ('Lightweight tarp or bivy', null),
      ('Space blanket and warm layer', null),
      ('Poncho or rain shell', null),
    ]),
    ('Fire & light', [
      ('Lighter and ferro rod', null),
      ('Headlamp with spare batteries', null),
    ]),
    ('Medical & tools', [
      ('Compact first-aid kit with tourniquet', null),
      ('Multi-tool or knife', null),
      ('Paracord, 50 ft', null),
      ('Whistle and signal mirror', null),
    ]),
    ('Navigation & power', [
      ('Paper map and compass', null),
      ('Power bank and cable', null),
      ('Small radio', null),
    ]),
  ]),
  Kit('docs', 'Documents & Cash Kit', 'Grab your identity and go', [
    ('Identity', [
      ('Driver license or passport copies', null),
      ('Birth and marriage certificates, copies', null),
      ('Social Security and insurance cards, copies', null),
    ]),
    ('Property & finance', [
      ('Home, auto and life insurance policies', null),
      ('Deed, lease and vehicle titles, copies', null),
      ('Bank and credit card account numbers', null),
      ('Cash in small bills', null),
    ]),
    ('Health', [
      ('Medication list and doctor contacts', null),
      ('Vaccination and medical records', null),
    ]),
    ('Storage', [
      ('Waterproof pouch or fire-safe box', null),
      ('Encrypted USB drive with scans', null),
      ('Paper list of family phone numbers', null),
    ]),
  ]),
  Kit('edc', 'Everyday Carry', 'The essentials you carry every day', [
    ('On you', [
      ('Phone and small power bank', null),
      ('Pocket knife or multi-tool', null),
      ('Flashlight', null),
      ('Lighter', null),
      ('Whistle or personal alarm', null),
      ('Cash and a spare key', null),
    ]),
    ('Small first aid', [
      ('Adhesive bandages and gauze', null),
      ('Personal medicines', null),
      ('Hand sanitizer', null),
    ]),
  ]),
  Kit('gethome', 'Get-Home Bag', 'Get home on foot when transit is down', [
    ('Water & food', [
      ('Water, 1-2 L, plus a filter', null),
      ('Snacks for 24 hours', null),
    ]),
    ('Clothing', [
      ('Comfortable walking shoes and spare socks', null),
      ('Rain jacket and warm hat', null),
      ('Work gloves', null),
    ]),
    ('Gear', [
      ('Paper map of your route home', null),
      ('Flashlight or headlamp', null),
      ('First-aid basics and any medicines', null),
      ('Power bank and cable', null),
      ('Cash in small bills', null),
    ]),
  ]),
  Kit('vehicle', 'Vehicle Kit', 'Stay safe if you break down or are stranded', [
    ('Safety & repair', [
      ('Jumper cables or jump pack', null),
      ('Spare tire, jack and lug wrench', null),
      ('Tire inflator or sealant', null),
      ('Reflective triangles or flares', null),
      ('Basic tools and duct tape', null),
    ]),
    ('Stay warm & fed', [
      ('Blankets and extra clothes', null),
      ('Water and non-perishable food', null),
      ('Ice scraper, small shovel, sand or cat litter', 'For traction'),
    ]),
    ('Be found', [
      ('Flashlight and spare batteries', null),
      ('Phone charger for the car', null),
      ('Paper road atlas', null),
      ('Whistle', null),
    ]),
  ]),
  Kit('shelter', 'Shelter in Place', 'Ride out a storm or outage at home', [
    ('Water & food', [
      ('Stored water, 1 gallon per person per day', null),
      ('Shelf-stable food and a manual can opener', null),
    ]),
    ('Power & light', [
      ('Flashlights, lanterns and batteries', null),
      ('Battery or hand-crank radio', null),
      ('Power banks, charged', null),
    ]),
    ('Home', [
      ('Fire extinguisher', null),
      ('Plastic sheeting and duct tape', null),
      ('Tools to shut off utilities', null),
      ('Alternate heat source, used safely', 'Never run generators or grills indoors'),
    ]),
    ('Health', [
      ('First-aid kit and medicines', null),
      ('Sanitation supplies and trash bags', null),
    ]),
  ]),
];

class ChecklistStore extends ChangeNotifier {
  ChecklistStore._(this._file, this.items);
  final File _file;
  final List<KitItem> items;

  static ChecklistStore? _instance;
  static ChecklistStore get instance => _instance!;

  static String _id(Kit k, String group, int i) => k.id == 'survival' ? '$group#$i' : '${k.id}:$group#$i';

  static Future<ChecklistStore> load(String stateDir) async {
    final file = File(p.join(stateDir, 'checklist.json'));
    final items = <KitItem>[
      for (final k in kits)
        for (final (group, entries) in k.groups)
          for (var i = 0; i < entries.length; i++) KitItem(_id(k, group, i), k.id, group, entries[i].$1, note: entries[i].$2),
    ];
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final done = {...(j['done'] as List? ?? const []).cast<String>()};
      for (final it in items) {
        it.done = done.contains(it.id);
      }
      for (final c in (j['custom'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        items.add(KitItem(c['id'] as String, c['kit'] as String? ?? 'survival', 'My items', c['title'] as String, custom: true, done: done.contains(c['id'])));
      }
    } catch (_) {
      // First run or unreadable file: start from the unticked starter kits.
    }
    return _instance = ChecklistStore._(file, items);
  }

  Kit kit(String id) => kits.firstWhere((k) => k.id == id);
  Iterable<KitItem> itemsFor(String kitId) => items.where((i) => i.kit == kitId);
  int totalFor(String kitId) => itemsFor(kitId).length;
  int doneFor(String kitId) => itemsFor(kitId).where((i) => i.done).length;
  List<String> groupsFor(String kitId) => {for (final i in itemsFor(kitId)) i.group}.toList();

  Future<void> toggle(KitItem item) => _save(() => item.done = !item.done);

  Future<void> add(String kitId, String title) {
    final t = title.trim();
    if (t.isEmpty) return Future.value();
    return _save(() => items.add(KitItem('custom#${DateTime.now().microsecondsSinceEpoch}', kitId, 'My items', t, custom: true)));
  }

  Future<void> remove(KitItem item) => _save(() => items.remove(item));

  Future<void> resetTicks(String kitId) => _save(() {
        for (final i in itemsFor(kitId)) {
          i.done = false;
        }
      });

  Future<void> _save(void Function() change) async {
    change();
    notifyListeners();
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'done': [for (final i in items) if (i.done) i.id],
        'custom': [for (final i in items) if (i.custom) {'id': i.id, 'kit': i.kit, 'title': i.title}],
      }),
      flush: true,
    );
    await tmp.rename(_file.path);
  }
}
