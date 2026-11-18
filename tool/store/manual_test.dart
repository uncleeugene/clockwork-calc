// Generates a one-page "how it works" picture: the real calculator with
// callouts explaining every control.
//
// Run: flutter test tool/store/manual_test.dart
// Output: store/manual.png
//
// The calculator is rendered once to find where each control is, then again
// with callouts on the nearer side and lines to those spots.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_calculator_widgets/time_calculator_widgets.dart';

import 'screenshots_test.dart' hide main;

// Logical canvas × ratio = 1640 × 1620 px.
const size = Size(820, 810);
const ratio = 2.0;

const phoneLeft = 250.0;
const phoneWidth = 320.0;
const phoneTop = 84.0;
const columnWidth = 218.0;
const margin = 18.0;

/// How a leader line reaches its control. Keys in the middle of the keypad
/// are reached through the gap below their row, so the line doesn't cross
/// other keys.
enum Route { direct, gapBelow }

class Callout {
  const Callout(
    this.finder,
    this.title,
    this.body, {
    this.key = false,
    this.route = Route.direct,
  });

  final Finder finder;
  final String title;
  final String body;

  /// Point at the whole key, not just its label.
  final bool key;
  final Route route;

  Finder get target => key
      ? find.ancestor(of: finder, matching: find.byType(Material)).first
      : finder.first;
}

// Keeps "1d 05:00" and similar together when wrapping.
const nb = ' ';

final callouts = [
  Callout(
    find.text('TIME'),
    'TIME',
    'Lit: time calculator. Tap for a regular one. The time on screen comes '
        'along as decimal hours (8:20 → 8.33).',
  ),
  Callout(
    find.text('DEC'),
    'DEC',
    'Decimal hours: 7:45 ⇄ 7.75. The whole calculation and history follow.',
  ),
  Callout(
    find.text('DAYS'),
    'DAYS',
    'Show days: 27:00 → 1d${nb}03:00. Going below zero counts back: '
        '−1d${nb}21:00.',
  ),
  Callout(find.text('SEC'), 'SEC', 'Show seconds: h:mm:ss.'),
  Callout(
    find.byTooltip('Clear history'),
    'Clear history',
    'Removes all past results.',
  ),
  Callout(
    find.text('1:30 + 0:45 = 2:15', findRichText: true),
    'History',
    'Past calculations. Tap one to use its result again.',
  ),
  Callout(
    find.byKey(const Key('display')),
    'Result',
    'Double-tap to copy it, ready to paste anywhere.',
  ),
  Callout(
    find.text('8.33 h'),
    'Other format',
    'The same value in decimal hours (or h:mm, with DEC on).',
  ),
  Callout(find.text('C'), 'Clear', 'Starts a new calculation.', key: true),
  Callout(
    find.text('⌫'),
    'Backspace',
    'Removes the last digit, then the colon.',
    key: true,
    route: Route.gapBelow,
  ),
  Callout(
    find.text('×'),
    '× and ÷',
    'Multiply or divide time by a plain number: 2:30 × 3 = 7:30.',
    key: true,
  ),
  Callout(
    find.text('4'),
    'Digits shift left',
    'Like a cash register: 3 → 0:03, 30 → 0:30, 300 → 3:00.',
    key: true,
  ),
  Callout(
    find.text('00'),
    '00 / d',
    'Two zeros at once. With DAYS on it becomes d for days: '
        '1${nb}d${nb}5${nb}0${nb}0 → 1d${nb}05:00.',
    key: true,
  ),
  Callout(
    find.text(':'),
    'Colon',
    'Typed digits become hours: 8$nb:${nb}3${nb}0 → 8:30. After it, '
        'minutes of any length: :${nb}5${nb}0${nb}0$nb= → 8:20. With SEC '
        'on, a second colon starts seconds.',
    key: true,
    route: Route.gapBelow,
  ),
];

/// Rough height of a callout box: a title line plus wrapped body lines.
double boxHeight(Callout c) => 22 + (c.body.length / 34).ceil() * 15.5;

class Placed {
  Placed(this.callout, this.path, this.left, this.top);

  final Callout callout;

  /// Leader line, from the callout title to the edge of the control.
  final List<Offset> path;
  final bool left;
  final double top;
}

/// The point of [rect] nearest to [p], pushed a little outside it.
Offset nearestEdge(Rect rect, Offset p) {
  final r = rect.inflate(3);
  return Offset(p.dx.clamp(r.left, r.right), p.dy.clamp(r.top, r.bottom));
}

/// Puts each callout on the side nearer its control, as close to the
/// control's height as the callouts above it allow.
List<Placed> place(Map<Callout, Rect> rects) {
  final placed = <Placed>[];
  for (final left in [true, false]) {
    final side =
        callouts.where((c) {
            final x = rects[c]!.center.dx;
            return (x < phoneLeft + phoneWidth / 2) == left;
          }).toList()
          ..sort((a, b) => rects[a]!.center.dy.compareTo(rects[b]!.center.dy));
    var nextTop = phoneTop - 10;
    final tops = <double>[];
    for (final c in side) {
      final top = math.max(rects[c]!.center.dy - 10, nextTop);
      tops.add(top);
      nextTop = top + boxHeight(c) + 10;
    }
    // Pull everything up if the last one runs off the bottom.
    final shift = math.max(0.0, nextTop - (size.height - margin));
    for (var i = 0; i < side.length; i++) {
      final c = side[i];
      final rect = rects[c]!;
      final top = tops[i] - shift;
      final start = Offset(
        left ? margin + columnWidth + 6 : size.width - margin - columnWidth - 6,
        top + 10,
      );
      final path = switch (c.route) {
        Route.direct => [start, nearestEdge(rect, start)],
        Route.gapBelow => () {
          // Along the gap under the key's row, then up into the key.
          final gap = rect.bottom + 4.5;
          final edge = left ? phoneLeft + 10 : phoneLeft + phoneWidth - 10;
          return [
            start,
            Offset(edge, gap),
            Offset(rect.center.dx, gap),
            Offset(rect.center.dx, rect.bottom + 2),
          ];
        }(),
      };
      placed.add(Placed(c, path, left, top));
    }
  }
  return placed;
}

Widget scene(
  TimeCalculatorController time,
  TimeCalculatorController plain,
  List<Placed> placed,
) {
  return Container(
    color: orange,
    child: Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 22,
          child: Text(
            'Clockwork Calc: what everything does',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        Positioned(
          left: phoneLeft,
          top: phoneTop,
          width: phoneWidth,
          child: phone(time, plain, false),
        ),
        Positioned.fill(child: CustomPaint(painter: Lines(placed))),
        for (final p in placed)
          Positioned(
            left: p.left ? margin : size.width - margin - columnWidth,
            top: p.top,
            width: columnWidth,
            child: Column(
              crossAxisAlignment: p.left
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  p.callout.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Text(
                  p.callout.body,
                  textAlign: p.left ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Color(0xDD000000),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Leader lines from each callout's title to its control: white with a
/// dark edge, so they show on both the orange and the black phone.
class Lines extends CustomPainter {
  Lines(this.placed);

  final List<Placed> placed;

  @override
  void paint(Canvas canvas, Size size) {
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final under = stroke(Colors.black, 3.2);
    final over = stroke(Colors.white, 1.4);
    for (final p in placed) {
      final path = Path()..addPolygon(p.path, false);
      final end = p.path.last;
      canvas
        ..drawPath(path, under)
        ..drawPath(path, over)
        ..drawCircle(end, 4, Paint()..color = Colors.black)
        ..drawCircle(end, 2.6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(Lines old) => true;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('manual', (tester) async {
    final time = TimeCalculatorController();
    final plain = TimeCalculatorController.plain();
    type(time, '1 3 0 + 4 5 =');
    type(time, '4 0 0 - 1 2 0 =');
    type(time, '5 0 0 + 3 2 0 =');
    const path = 'store/manual.png';

    // First pass: where is everything?
    await capture(
      tester,
      scene(time, plain, []),
      path,
      size: size,
      ratio: ratio,
    );
    final rects = {for (final c in callouts) c: tester.getRect(c.target)};

    await capture(
      tester,
      scene(time, plain, place(rects)),
      path,
      size: size,
      ratio: ratio,
    );
  });
}
