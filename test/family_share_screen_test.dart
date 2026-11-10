// flutter test test/family_share_screen_test.dart
// The Share (encrypted QR) screens fit a normal phone: the passphrase box above the keyboard, the QR without scrolling.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:survival_node_mobile/core/theme.dart';
import 'package:survival_node_mobile/family/family_share.dart';
import 'package:survival_node_mobile/family/family_store.dart';

void main() {
  late Directory dir;
  late FamilyStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('family_share_test');
    store = await FamilyStore.load(dir.path);
    await store.upsert(EntryKind.member, FamilyEntry(id: 'm1', name: 'Sarah Miller', note: 'Peanut allergy'));
    await store.upsert(EntryKind.contact, FamilyEntry(id: 'c1', name: 'Dr. Patel', phone: '555-0142'));
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> pumpHost(WidgetTester tester, {double width = 1179, double height = 2556}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: Builder(builder: (context) => Scaffold(body: Center(child: FilledButton(onPressed: () => shareFamilyCode(context, store), child: const Text('Share'))))),
    ));
  }

  testWidgets('passphrase box keeps both fields and Create QR above a 336pt keyboard at large text', (tester) async {
    await pumpHost(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final usable = tester.view.physicalSize.height / 3 - 336;
    expect(find.text('Set a passphrase'), findsOneWidget);
    for (final label in ['Passphrase', 'Type it again']) {
      expect(tester.getRect(find.widgetWithText(TextField, label)).bottom, lessThanOrEqualTo(usable), reason: '$label hidden under the keyboard');
    }
    expect(tester.getRect(find.text('Create QR')).bottom, lessThanOrEqualTo(usable));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [(name: 'iPhone 16 Pro', w: 393.0, h: 852.0), (name: 'small iPhone SE', w: 320.0, h: 568.0)]) {
    testWidgets('QR screen fits without scrolling on ${size.name}', (tester) async {
      await pumpHost(tester, width: size.w * 3, height: size.h * 3);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Passphrase'), 'blue heron lantern');
      await tester.enterText(find.widgetWithText(TextField, 'Type it again'), 'blue heron lantern');
      await tester.tap(find.text('Create QR'));
      await tester.pump();
      // The key derivation runs in a background isolate, which needs real time rather than the test clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 6)));
      await tester.pumpAndSettle();

      final qr = find.byType(QrImageView);
      expect(qr, findsOneWidget);
      final qrRect = tester.getRect(qr);
      expect(qrRect.left, greaterThanOrEqualTo(0));
      expect(qrRect.right, lessThanOrEqualTo(size.w));
      expect(qrRect.width, greaterThanOrEqualTo(180), reason: 'big enough to scan');
      final copy = tester.getRect(find.text('Copy code as text'));
      expect(copy.bottom, lessThanOrEqualTo(size.h), reason: 'Copy button should be visible without scrolling');
      expect(tester.takeException(), isNull);
    });
  }
}
