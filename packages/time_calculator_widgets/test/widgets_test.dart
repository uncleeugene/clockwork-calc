import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_calculator_widgets/time_calculator_widgets.dart';

Widget app([TimeCalculatorController? controller]) => MaterialApp(
  home: Scaffold(body: TimeCalculatorView(controller: controller)),
);

void main() {
  testWidgets('tapping keys updates the display', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('display')), findsOneWidget);

    for (final k in ['3', '0', '0', '+', '4', '5', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '3:45');
  });

  testWidgets('format switch toggles the display', (tester) async {
    await tester.pumpWidget(app());
    for (final k in ['1', '3', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    await tester.tap(find.text('decimal'));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '1.5');
    expect(find.text('1:30'), findsOneWidget); // secondary line
  });

  testWidgets('history shows past results and recalls them', (tester) async {
    await tester.pumpWidget(app());
    for (final k in ['1', '3', '0', '+', '4', '5', '=', 'C']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    final item = find.descendant(
      of: find.byKey(const Key('history')),
      matching: find.textContaining('1:30 + 0:45 = 2:15', findRichText: true),
    );
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '2:15');
  });

  testWidgets('separate widgets share one controller', (tester) async {
    final controller = TimeCalculatorController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TimeCalculatorDisplay(controller: controller),
              SizedBox(
                height: 300,
                child: TimeCalculatorKeypad(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
    for (final k in ['2', ':', '1', '5']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '2:15');
    controller.clear();
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '0:00');
  });

  testWidgets('plain mode is an ordinary calculator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TimeCalculatorView(mode: CalculatorMode.plain)),
      ),
    );
    expect(find.byKey(const Key('formatSwitch')), findsNothing);
    for (final k in ['1', '.', '5', '×', '4', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '6');
    expect(
      find.textContaining('1.5 × 4 = 6', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('plain controller drives standalone widgets', (tester) async {
    final controller = TimeCalculatorController.plain();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TimeCalculatorDisplay(controller: controller),
              Expanded(child: TimeCalculatorKeypad(controller: controller)),
            ],
          ),
        ),
      ),
    );
    for (final k in ['9', '÷', '4', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('display'))).data, '2.25');
  });

  testWidgets('finished expression is shown once, in the history', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    String expression() =>
        tester.widget<Text>(find.byKey(const Key('expression'))).data!;
    for (final k in ['1', '3', '0', '+', '4', '5']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(expression(), '1:30 +');
    await tester.tap(find.text('='));
    await tester.pump();
    expect(expression(), '');
    expect(
      find.textContaining('1:30 + 0:45 = 2:15', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(expression(), '2:15 +');
  });

  testWidgets('without history the display keeps the finished expression', (
    tester,
  ) async {
    final controller = TimeCalculatorController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimeCalculatorDisplay(controller: controller)),
      ),
    );
    controller
      ..digit('100')
      ..operator(Op.add)
      ..digit('100')
      ..equals();
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('expression'))).data,
      '1:00 + 1:00 =',
    );
  });

  testWidgets('h:mm:ss segment shows seconds', (tester) async {
    await tester.pumpWidget(app());
    String display() =>
        tester.widget<Text>(find.byKey(const Key('display'))).data!;
    await tester.tap(find.text('h:mm:ss'));
    await tester.pump();
    for (final k in ['1', ':', '3', '0', ':', '4', '5']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(display(), '1:30:45');
    expect(find.text('1.51 h'), findsOneWidget);
    await tester.tap(find.text('decimal'));
    await tester.pump();
    expect(display(), '1.5125');
    expect(find.text('1:30:45'), findsOneWidget); // remembered seconds
  });

  group('double-tap to copy', () {
    late List<String> copied;

    setUp(() {
      copied = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    Future<void> doubleTap(WidgetTester tester, Finder finder) async {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(finder);
      // Let the double-tap recognizer's timer run out.
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('copies the shown value and confirms', (tester) async {
      final controller = TimeCalculatorController()
        ..digit('130')
        ..operator(Op.add)
        ..digit('45')
        ..equals();
      await tester.pumpWidget(app(controller));
      await doubleTap(tester, find.byKey(const Key('display')));
      expect(copied, ['2:15']);
      expect(find.text('Copied 2:15'), findsOneWidget);

      controller.setFormat(TimeFormat.decimal);
      await tester.pump();
      await doubleTap(tester, find.byKey(const Key('display')));
      expect(copied.last, '2.25');
      await tester.pumpAndSettle(const Duration(seconds: 2)); // snack bar
    });

    testWidgets('anywhere in the display area, not only on the digits', (
      tester,
    ) async {
      await tester.pumpWidget(app(TimeCalculatorController()..digit('5')));
      final area = tester.getRect(find.byKey(const Key('displayArea')));
      await tester.tapAt(area.centerLeft + const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(area.centerLeft + const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(copied, ['0:05']);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('nothing is copied on Error', (tester) async {
      final controller = TimeCalculatorController()
        ..digit('100')
        ..operator(Op.divide)
        ..digit('0')
        ..equals();
      await tester.pumpWidget(app(controller));
      await doubleTap(tester, find.byKey(const Key('display')));
      expect(copied, isEmpty);
    });

    testWidgets('onCopied replaces the snack bar', (tester) async {
      final controller = TimeCalculatorController()..digit('5');
      String? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeCalculatorDisplay(
              controller: controller,
              onCopied: (t) => got = t,
            ),
          ),
        ),
      );
      await doubleTap(tester, find.byKey(const Key('display')));
      expect(got, '0:05');
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('DAYS indicator splits results into days', (tester) async {
    await tester.pumpWidget(app());
    String display() =>
        tester.widget<Text>(find.byKey(const Key('display'))).data!;
    for (final k in ['2', '2', '0', '0', '+', '5', '0', '0', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(display(), '27:00');
    await tester.tap(find.byKey(const Key('daysToggle')));
    await tester.pump();
    expect(display(), '1d 03:00');
    expect(find.text('1d 03:00', findRichText: true), findsWidgets); // history
    // Hidden in decimal mode, where days don't apply.
    await tester.tap(find.text('decimal'));
    await tester.pump();
    expect(find.byKey(const Key('daysToggle')), findsNothing);
    expect(display(), '27.00');
    expect(find.text('1d 03:00'), findsOneWidget); // secondary line
  });

  testWidgets('d key types days while DAYS is on', (tester) async {
    await tester.pumpWidget(app());
    String display() =>
        tester.widget<Text>(find.byKey(const Key('display'))).data!;
    expect(find.text('d'), findsNothing);
    await tester.tap(find.byKey(const Key('daysToggle')));
    await tester.pump();
    expect(find.text('00'), findsNothing);
    for (final k in ['1', 'd', '5', '0', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(display(), '1d 05:00');
    await tester.tap(find.text('×'));
    await tester.pump();
    expect(find.text('00'), findsOneWidget); // plain number after ×
  });

  testWidgets('SEC indicator turns seconds on and off', (tester) async {
    final controller = TimeCalculatorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeCalculatorView(
            controller: controller,
            showSeconds: false,
            showSecondsToggle: true,
          ),
        ),
      ),
    );
    String display() =>
        tester.widget<Text>(find.byKey(const Key('display'))).data!;
    expect(find.text('h:mm:ss'), findsNothing);
    await tester.tap(find.byKey(const Key('secondsToggle')));
    await tester.pump();
    for (final k in ['1', '3', '0', '1', '5']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(display(), '1:30:15');
    final h = tester.widget<SegmentedButton<TimeFormat>>(
      find.byKey(const Key('formatSwitch')),
    );
    expect(h.selected, {TimeFormat.hoursMinutes});
    // Through decimal and back keeps seconds.
    await tester.tap(find.text('decimal'));
    await tester.pump();
    expect(find.byKey(const Key('secondsToggle')), findsNothing);
    await tester.tap(find.text('h:mm'));
    await tester.pump();
    expect(display(), '1:30:15');
    await tester.tap(find.byKey(const Key('secondsToggle')));
    await tester.pump();
    expect(display(), '1:30');
  });

  testWidgets('TIME DEC DAYS SEC labels replace the switch', (tester) async {
    final time = TimeCalculatorController();
    final plain = TimeCalculatorController.plain();
    addTearDown(time.dispose);
    addTearDown(plain.dispose);
    final modes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeCalculatorView(
            controller: time,
            plainController: plain,
            onPlainModeChanged: modes.add,
            showFormatSwitch: false,
            showDecimalToggle: true,
            showSecondsToggle: true,
          ),
        ),
      ),
    );
    String display() =>
        tester.widget<Text>(find.byKey(const Key('display'))).data!;
    Finder label(String k) => find.byKey(Key(k));
    expect(find.byKey(const Key('formatSwitch')), findsNothing);
    for (final k in ['timeToggle', 'decimalToggle', 'daysToggle']) {
      expect(label(k), findsOneWidget);
    }

    for (final k in ['1', '3', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    // DEC: decimal hours; DAYS and SEC hide.
    await tester.tap(label('decimalToggle'));
    await tester.pump();
    expect(display(), '1.5');
    expect(label('daysToggle'), findsNothing);
    expect(label('secondsToggle'), findsNothing);
    await tester.tap(label('decimalToggle'));
    await tester.pump();
    expect(display(), '1:30');

    // TIME off: a plain calculator with its own state; time labels hide.
    // The time shown comes along as decimal hours.
    await tester.tap(label('timeToggle'));
    await tester.pump();
    expect(modes, [true]);
    expect(label('decimalToggle'), findsNothing);
    expect(display(), '1.5');
    for (final k in ['×', '2', '0', '=']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(display(), '30');

    // Back to time: the time calculation is still there.
    await tester.tap(label('timeToggle'));
    await tester.pump();
    expect(modes, [true, false]);
    expect(display(), '1:30');
  });

  testWidgets('switching to plain skips 0:00 and × operands', (
    tester,
  ) async {
    final time = TimeCalculatorController();
    final plain = TimeCalculatorController.plain();
    addTearDown(time.dispose);
    addTearDown(plain.dispose);
    Widget view(bool plainMode) => MaterialApp(
      home: Scaffold(
        body: TimeCalculatorView(
          key: ValueKey(plainMode),
          controller: time,
          plainController: plain,
          plainMode: plainMode,
          showFormatSwitch: false,
        ),
      ),
    );
    plain.digit('42');
    await tester.pumpWidget(view(false));
    await tester.tap(find.byKey(const Key('timeToggle')));
    await tester.pump();
    expect(plain.calculator.display, '42'); // 0:00 brought nothing

    time
      ..digit('230')
      ..operator(Op.multiply)
      ..digit('3');
    await tester.pumpWidget(view(false));
    await tester.tap(find.byKey(const Key('timeToggle')));
    await tester.pump();
    expect(plain.calculator.display, '42'); // "3" after × isn't a time
  });
}
