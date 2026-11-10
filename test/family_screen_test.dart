// flutter test test/family_screen_test.dart
// The Family sections keep their saved entries hidden until tapped, and the add box fits above the keyboard.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survival_node_mobile/core/theme.dart';
import 'package:survival_node_mobile/family/family_screen.dart';
import 'package:survival_node_mobile/family/family_store.dart';

void main() {
  late Directory dir;
  late FamilyStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('family_screen_test');
    store = await FamilyStore.load(dir.path);
    await store.upsert(EntryKind.member, FamilyEntry(id: 'm1', name: 'Sarah Miller'));
    await store.upsert(EntryKind.place, FamilyEntry(id: 'p1', name: "Grandma's house"));
    await store.upsert(EntryKind.contact, FamilyEntry(id: 'c1', name: 'Dr. Patel', phone: '555-0142'));
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556); // iPhone 16 Pro, 3x
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.build(), home: const Scaffold(body: FamilyScreen())));
    await tester.pump();
  }

  /// The tile's visible title ("Family Members  ·  1"). Tapping its text lands on the tile's InkWell.
  Finder tile(String label) => find.textContaining(label);

  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('saved entries start hidden and open when the picture is tapped', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Sarah Miller'), findsNothing);
    expect(find.text("Grandma's house"), findsNothing);
    expect(find.text('Dr. Patel'), findsNothing);

    await reveal(tester, tile('Family Members'));
    await tester.tap(tile('Family Members'));
    await tester.pumpAndSettle();
    expect(find.text('Sarah Miller'), findsOneWidget);
    expect(find.text("Grandma's house"), findsNothing, reason: 'other sections stay closed');

    await tester.tap(tile('Family Members'));
    await tester.pumpAndSettle();
    expect(find.text('Sarah Miller'), findsNothing);
  });

  testWidgets('emergency contacts open the same way', (tester) async {
    await pumpScreen(tester);
    await reveal(tester, tile('My Emergency Contacts'));
    expect(find.text('Dr. Patel'), findsNothing);
    await tester.tap(tile('My Emergency Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Patel'), findsOneWidget);
  });

  testWidgets('gathering points open the same way', (tester) async {
    await pumpScreen(tester);
    await reveal(tester, tile('Gathering Points'));
    await tester.tap(tile('Gathering Points'));
    await tester.pumpAndSettle();
    expect(find.text("Grandma's house"), findsOneWidget);
  });

  testWidgets('the plus button adds without opening the list first', (tester) async {
    await pumpScreen(tester);
    await reveal(tester, find.byTooltip('Add to Family Members'));
    await tester.tap(find.byTooltip('Add to Family Members'));
    await tester.pumpAndSettle();
    expect(find.text('New family member'), findsOneWidget);
  });

  testWidgets('the add box keeps Name, Phone and notes above a 336pt keyboard, even at large text', (tester) async {
    await pumpScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6; // a large accessibility text size
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    await tester.pump();

    await reveal(tester, find.byTooltip('Add to Emergency Contacts'));
    await tester.tap(find.byTooltip('Add to Emergency Contacts'));
    await tester.pumpAndSettle();

    expect(find.text('New contact'), findsOneWidget);
    final screenH = tester.view.physicalSize.height / 3;
    final usable = screenH - 336;
    for (final f in [find.widgetWithText(TextField, 'Name'), find.widgetWithText(TextField, 'Phone')]) {
      final r = tester.getRect(f);
      expect(r.bottom, lessThanOrEqualTo(usable), reason: '${f.describeMatch(Plurality.one)} hidden under the keyboard');
    }
    // Save and Cancel must stay reachable too.
    expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(usable));
    final title = tester.getSize(find.text('New contact'));
    expect(title.height, lessThan(60), reason: 'title should be one line, not three');
  });
}
