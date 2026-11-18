// Generates Play Store screenshots and the feature graphic.
//
// Run: flutter test tool/store/screenshots_test.dart
// Output: store/screenshots/*.png (Google Play),
// store/ios_screenshots/{6.9,6.5,6.3}/*.jpg (App Store), store/feature_graphic.png
//
// Each screenshot renders the real calculator, driven into a state through
// its controller, inside a phone outline with a caption above it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_calculator_widgets/time_calculator_widgets.dart';

const orange = Color(0xFFFF9800);
const keypadStyle = TimeCalculatorKeypadStyle(
  digitColor: Color(0xFF333333),
  digitTextColor: Colors.white,
  functionColor: Color(0xFFA5A5A5),
  functionTextColor: Colors.black,
);

// Logical canvas × pixel ratio = 1080 × 2160 px.
const canvas = Size(400, 800);
const pixelRatio = 2.7;

Future<void> loadFonts() async {
  final flutterRoot = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent
      .parent
      .path;
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    for (final w in ['Light', 'Regular', 'Medium', 'Bold', 'Black'])
      '$fonts/Roboto-$w.ttf',
  ]);
  await load('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  // ⌫ isn't in Roboto; phones fall back to a symbol font, so do the same.
  await load('Symbols', ['/System/Library/Fonts/Apple Symbols.ttf']);
}

ThemeData appTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: Colors.black,
  fontFamily: 'Roboto',
  fontFamilyFallback: const ['Symbols'],
);

/// The app as it looks on a 390 × 844 phone, with a minimal status bar.
Widget phone(
  TimeCalculatorController controller,
  TimeCalculatorController plain,
  bool plainMode,
) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(40),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: FittedBox(
        child: SizedBox(
          width: 390,
          height: 844,
          child: Theme(
            data: appTheme(),
            child: Material(
              color: Colors.black,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(28, 14, 24, 6),
                    child: Row(
                      children: [
                        Text(
                          '10:10',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.signal_cellular_alt, size: 17),
                        SizedBox(width: 4),
                        Icon(Icons.wifi, size: 17),
                        SizedBox(width: 4),
                        Icon(Icons.battery_full, size: 17),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TimeCalculatorView(
                      controller: controller,
                      plainController: plain,
                      plainMode: plainMode,
                      showFormatSwitch: false,
                      showDecimalToggle: true,
                      showSecondsToggle: true,
                      keypadStyle: keypadStyle,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget screenshot({
  required String title,
  required String subtitle,
  required TimeCalculatorController controller,
  required TimeCalculatorController plain,
  bool plainMode = false,
}) {
  return Container(
    color: orange,
    padding: const EdgeInsets.fromLTRB(28, 34, 28, 0),
    child: Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 31,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16.5,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: Color(0xDD000000),
          ),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 296,
              child: phone(controller, plain, plainMode),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Types a sequence: digits, ':', '.', '+', '-', '*', '/', '='.
void type(TimeCalculatorController c, String keys) {
  for (final k in keys.split(' ')) {
    switch (k) {
      case '+':
        c.operator(Op.add);
      case '-':
        c.operator(Op.subtract);
      case '*':
        c.operator(Op.multiply);
      case '/':
        c.operator(Op.divide);
      case '=':
        c.equals();
      case ':' || '.':
        c.separator();
      default:
        c.digit(k);
    }
  }
}

/// A work week, one running total per day.
void week(TimeCalculatorController c) {
  type(c, '7 4 5 + 8 3 0 =');
  type(c, '+ 6 1 5 =');
  type(c, '+ 8 0 0 =');
  type(c, '+ 7 3 0 =');
}

/// Replaces [png] with a JPEG (no alpha channel), using macOS's sips.
void toJpeg(String png) {
  final jpg = png.replaceFirst(RegExp(r'\.png$'), '.jpg');
  final result = Process.runSync('sips', [
    '-s', 'format', 'jpeg', //
    '-s', 'formatOptions', '92',
    png, '--out', jpg,
  ]);
  if (result.exitCode != 0) throw Exception(result.stderr);
  File(png).deleteSync();
}

Future<void> capture(
  WidgetTester tester,
  Widget child,
  String path, {
  Size size = canvas,
  double ratio = pixelRatio,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      // Material gives the captions the app's text style (Roboto).
      home: RepaintBoundary(
        key: key,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
  // Let images (the icon in the feature graphic) decode, then repaint.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadFonts);

  final shots =
      <
        String,
        (
          String,
          String,
          void Function(
            TimeCalculatorController time,
            TimeCalculatorController plain,
          ),
        )
      >{
        '1_typing': (
          'Type time like\na calculator',
          'Every digit shifts left:\n3 → 0:03  ·  30 → 0:30  ·  300 → 3:00',
          (c, _) {
            type(c, '1 3 0 + 4 5 =');
            type(c, '8 3 0 + 3 0 0');
          },
        ),
        '2_week': (
          'Add up your\nwhole week',
          'Every result stays in the history.\nTap one to use it again.',
          (c, _) {
            week(c);
          },
        ),
        '3_decimal': (
          'Decimal hours?\nOne tap.',
          'Tap DEC: 38:00 becomes 38.00 —\nthe whole calculation follows.',
          (c, _) {
            week(c);
            c.setFormat(TimeFormat.decimal);
          },
        ),
        '4_colon': (
          'Used to a colon?\nIt’s right there.',
          'Type 8 : 3 0 to get 8:30.\nWhatever feels natural.',
          (c, _) {
            type(c, '1 7 1 5 - 8 : 3 0');
          },
        ),
        '5_multiply': (
          'Multiply and\ndivide time',
          '2:30 × 3 = 7:30  ·  9:00 ÷ 4 = 2:15\nShifts, rates, splits — done.',
          (c, _) {
            type(c, '9 0 0 / 4 =');
            type(c, '2 3 0 * 3 =');
          },
        ),
        '6_days': (
          'Past midnight?\nCount the days.',
          'Tap DAYS: 22:00 + 05:00 = 1d 03:00.\nGreat for time zones and long trips.',
          (c, _) {
            c.setShowDays(true);
            type(c, '2 0 0 - 5 0 0 =');
            type(c, '2 2 0 0 + 5 0 0 =');
          },
        ),
        '7_calc': (
          'A regular calculator\nis one tap away.',
          'Tap TIME and 38:30 comes along as 38.5.\nHours × rate: 38.5 × 25 = 962.5',
          (_, p) {
            p
              ..digit('120')
              ..operator(Op.divide)
              ..digit('8')
              ..equals()
              ..enterValue(38.5)
              ..operator(Op.multiply)
              ..digit('25')
              ..equals();
          },
        ),
        '8_no_ads': (
          'Free.\nNo ads. No tracking.',
          'No account, no internet needed.\nJust a calculator.',
          (c, _) {
            type(c, '1 3 0 + 4 5 =');
            type(c, '4 0 0 - 1 2 0 =');
            type(c, '6 4 5');
          },
        ),
      };

  // Google Play: 1080 × 2160. App Store, 6.9" iPhone: 1320 × 2868.
  // Google Play: 1080 × 2160 PNG. App Store: 6.9" (1320 × 2868), 6.5"
  // (1284 × 2778) and 6.3" (1206 × 2622) iPhone, as JPEG: App Store Connect rejects screenshots
  // with an alpha channel, which PNGs rendered here always have.
  const targets = [
    ('store/screenshots', canvas, pixelRatio, false),
    ('store/ios_screenshots/6.9', Size(400, 2868 / 3.3), 3.3, true),
    ('store/ios_screenshots/6.5', Size(400, 2778 / 3.21), 3.21, true),
    ('store/ios_screenshots/6.3', Size(400, 2622 / 3.015), 3.015, true),
  ];
  for (final (dir, size, ratio, jpeg) in targets) {
    for (final MapEntry(key: name, value: (title, subtitle, setUp))
        in shots.entries) {
      testWidgets('screenshot $dir/$name', (tester) async {
        final controller = TimeCalculatorController();
        final plain = TimeCalculatorController.plain();
        setUp(controller, plain);
        await capture(
          tester,
          screenshot(
            title: title,
            subtitle: subtitle,
            controller: controller,
            plain: plain,
            plainMode: name == '7_calc',
          ),
          '$dir/$name.png',
          size: size,
          ratio: ratio,
        );
        if (jpeg) toJpeg('$dir/$name.png');
      });
    }
  }

  testWidgets('feature graphic', (tester) async {
    // 1024 × 500 px.
    await capture(
      tester,
      Container(
        color: orange,
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Row(
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(
                File('assets/icon/icon.png').readAsBytesSync(),
              ),
            ),
            const SizedBox(width: 28),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clockwork Calc',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Hours & minutes calculator.\nDecimal hours in one tap. No ads.',
                    style: TextStyle(
                      fontSize: 17,
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
      ),
      'store/feature_graphic.png',
      size: const Size(1024 / 1.6, 500 / 1.6),
      ratio: 1.6,
    );
  });

  // App Store banner art: 5244 × 2950 (16:9) and 3840 × 1646 (21:9).
  // Key content stays in the middle, since the App Store crops these per
  // device.
  for (final (name, size, ratio) in [
    ('appstore_banner_16x9', const Size(5244 / 4, 2950 / 4), 4.0),
    ('appstore_banner_21x9', const Size(3840 / 3, 1646 / 3), 3.0),
  ]) {
    testWidgets('banner $name', (tester) async {
      final controller = TimeCalculatorController();
      final plain = TimeCalculatorController.plain();
      week(controller);
      final path = 'store/$name.png';
      await capture(
        tester,
        banner(size, controller, plain),
        path,
        size: size,
        ratio: ratio,
      );
      toJpeg(path);
      // Also as PNG, rebuilt from the JPEG so it has no alpha channel, for
      // upload forms that only take PNG.
      final jpg = path.replaceFirst(RegExp(r'\.png$'), '.jpg');
      final result = Process.runSync('sips', [
        '-s', 'format', 'png', //
        jpg, '--out', path,
      ]);
      if (result.exitCode != 0) throw Exception(result.stderr);
    });
  }
}

/// The real app on a phone, cut off at the bottom edge, beside the icon,
/// name and tagline.
Widget banner(
  Size size,
  TimeCalculatorController controller,
  TimeCalculatorController plain,
) {
  final h = size.height;
  final phoneTop = h * 0.11;
  return Container(
    clipBehavior: Clip.hardEdge,
    decoration: const BoxDecoration(color: orange),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: phoneTop),
          child: SizedBox(
            width: h * 0.5,
            height: h - phoneTop,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: double.infinity,
              child: SizedBox(
                width: h * 0.5,
                child: phone(controller, plain, false),
              ),
            ),
          ),
        ),
        SizedBox(width: h * 0.12),
        SizedBox(
          height: h,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: h * 0.22,
                height: h * 0.22,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(h * 0.05),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  File('assets/icon/icon.png').readAsBytesSync(),
                ),
              ),
              SizedBox(height: h * 0.05),
              Text(
                'Clockwork Calc',
                style: TextStyle(
                  fontSize: h * 0.1,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: h * 0.025),
              Text(
                'Add hours and minutes.\nDecimal hours in one tap.',
                style: TextStyle(
                  fontSize: h * 0.048,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xDD000000),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
