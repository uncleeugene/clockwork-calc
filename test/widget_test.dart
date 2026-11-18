import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hourcalc/main.dart';

void main() {
  testWidgets('app shows the calculator', (tester) async {
    await tester.pumpWidget(const HourCalcApp());
    for (final k in ['1', '3', '0', '+', '4', '5', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '2:15');
  });

  testWidgets('top row shows TIME DEC DAYS SEC, no switch', (tester) async {
    await tester.pumpWidget(const HourCalcApp());
    for (final label in ['TIME', 'DEC', 'DAYS', 'SEC']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('formatSwitch')), findsNothing);
  });

  testWidgets('DAYS and decimal are remembered between launches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(HourCalcApp(prefs: prefs));
    await tester.tap(find.byKey(const Key('daysToggle')));
    await tester.pump();
    expect(prefs.getBool('days'), isTrue);
    await tester.tap(find.byKey(const Key('decimalToggle')));
    await tester.pump();
    expect(prefs.getBool('decimal'), isTrue);

    // "Relaunch": a fresh app with the same saved settings.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(HourCalcApp(prefs: prefs));
    String display() =>
        tester.widget<Text>(find.byKey(const Key('display'))).data!;
    expect(display(), '0.00');
    await tester.tap(find.byKey(const Key('decimalToggle')));
    await tester.pump();
    for (final k in ['2', '5', '0', '0', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(display(), '1d 01:00');
  });

  testWidgets('SEC is remembered, also through decimal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(HourCalcApp(prefs: prefs));
    await tester.tap(find.byKey(const Key('secondsToggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decimalToggle')));
    await tester.pump();
    expect(prefs.getBool('seconds'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(HourCalcApp(prefs: prefs));
    await tester.tap(find.byKey(const Key('decimalToggle')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('display'))).data,
      '0:00:00',
    );
  });

  testWidgets('plain calculator mode is remembered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(HourCalcApp(prefs: prefs));
    await tester.tap(find.byKey(const Key('timeToggle')));
    await tester.pump();
    expect(prefs.getBool('plain'), isTrue);
    expect(find.text('DEC'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(HourCalcApp(prefs: prefs));
    for (final k in ['7', '.', '5', '+', '1', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('display'))).data,
      '8.5',
    );
  });
}
