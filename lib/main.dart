import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_calculator_widgets/time_calculator_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The layout is made for a tall screen; landscape phones overflow.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(HourCalcApp(prefs: prefs));
}

class HourCalcApp extends StatefulWidget {
  const HourCalcApp({super.key, this.prefs});

  /// Where the mode, DEC, DAYS and SEC settings are remembered between
  /// launches.
  /// Null (as in tests) means nothing is saved.
  final SharedPreferences? prefs;

  @override
  State<HourCalcApp> createState() => _HourCalcAppState();
}

class _HourCalcAppState extends State<HourCalcApp> {
  static const _decimalKey = 'decimal';
  static const _daysKey = 'days';
  static const _secondsKey = 'seconds';
  static const _plainKey = 'plain';

  final _controller = TimeCalculatorController();
  final _plainController = TimeCalculatorController.plain();

  @override
  void initState() {
    super.initState();
    final prefs = widget.prefs;
    if (prefs == null) return;
    final calc = _controller.calculator;
    // Seconds first: decimal remembers them for switching back.
    calc.setShowSeconds(prefs.getBool(_secondsKey) ?? false);
    if (prefs.getBool(_decimalKey) ?? false) {
      calc.setFormat(TimeFormat.decimal);
    }
    calc.setShowDays(prefs.getBool(_daysKey) ?? false);
    _controller.addListener(_save);
  }

  void _save() {
    final prefs = widget.prefs!;
    final calc = _controller.calculator;
    final decimal = calc.format == TimeFormat.decimal;
    if (prefs.getBool(_decimalKey) != decimal) {
      prefs.setBool(_decimalKey, decimal);
    }
    if (prefs.getBool(_daysKey) != calc.showsDays) {
      prefs.setBool(_daysKey, calc.showsDays);
    }
    if (prefs.getBool(_secondsKey) != calc.showsSeconds) {
      prefs.setBool(_secondsKey, calc.showsSeconds);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _plainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clockwork Calc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: Scaffold(
        body: SafeArea(
          child: TimeCalculatorView(
            controller: _controller,
            // Calculator-style labels instead of a switch: TIME DEC DAYS SEC.
            plainController: _plainController,
            plainMode: widget.prefs?.getBool(_plainKey) ?? false,
            onPlainModeChanged: (plain) =>
                widget.prefs?.setBool(_plainKey, plain),
            showFormatSwitch: false,
            showDecimalToggle: true,
            showSecondsToggle: true,
            keypadStyle: const TimeCalculatorKeypadStyle(
              digitColor: Color(0xFF333333),
              digitTextColor: Colors.white,
              functionColor: Color(0xFFA5A5A5),
              functionTextColor: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
