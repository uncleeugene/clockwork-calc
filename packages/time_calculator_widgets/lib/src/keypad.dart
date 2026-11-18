import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_calc_engine/time_calc_engine.dart';

import 'controller.dart';

/// Colors and shape of [TimeCalculatorKeypad]. Unset colors come from the
/// ambient [ColorScheme].
class TimeCalculatorKeypadStyle {
  const TimeCalculatorKeypadStyle({
    this.digitColor,
    this.digitTextColor,
    this.functionColor,
    this.functionTextColor,
    this.operatorColor,
    this.operatorTextColor,
    this.fontSize = 28,
    this.borderRadius = 24,
    this.spacing = 6,
  });

  final Color? digitColor;
  final Color? digitTextColor;

  /// `C` and `⌫` keys.
  final Color? functionColor;
  final Color? functionTextColor;

  /// `+ − × ÷ =` keys.
  final Color? operatorColor;
  final Color? operatorTextColor;

  final double fontSize;
  final double borderRadius;

  /// Gap around each key.
  final double spacing;
}

enum _KeyKind { digit, function, operator }

/// The 5-row calculator keypad. The `00` key becomes `d` (days) while
/// [TimeCalculator.showsDayKey]. Needs a bounded height: put it in an
/// [Expanded], [SizedBox] or similar.
class TimeCalculatorKeypad extends StatelessWidget {
  const TimeCalculatorKeypad({
    super.key,
    required this.controller,
    this.style = const TimeCalculatorKeypadStyle(),
    this.haptics = true,
  });

  final TimeCalculatorController controller;
  final TimeCalculatorKeypadStyle style;

  /// Light haptic click on every key press.
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final calc = controller.calculator;
        final scheme = Theme.of(context).colorScheme;

        Widget key(
          String label,
          VoidCallback action, {
          _KeyKind kind = _KeyKind.digit,
          bool enabled = true,
        }) {
          final (bg, fg) = switch (kind) {
            _KeyKind.digit => (
              style.digitColor ?? scheme.surfaceContainerHighest,
              style.digitTextColor ?? scheme.onSurface,
            ),
            _KeyKind.function => (
              style.functionColor ?? scheme.secondaryContainer,
              style.functionTextColor ?? scheme.onSecondaryContainer,
            ),
            _KeyKind.operator => (
              style.operatorColor ?? scheme.primary,
              style.operatorTextColor ?? scheme.onPrimary,
            ),
          };
          final radius = BorderRadius.circular(style.borderRadius);
          return Padding(
            padding: EdgeInsets.all(style.spacing),
            child: Material(
              color: enabled ? bg : bg.withValues(alpha: 0.35),
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: enabled
                    ? () {
                        if (haptics) HapticFeedback.selectionClick();
                        action();
                      }
                    : null,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: style.fontSize,
                      color: enabled ? fg : fg.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        Widget row(List<Widget> keys) => Expanded(
          child: Row(children: [for (final k in keys) Expanded(child: k)]),
        );
        Widget digit(String d) => key(d, () => controller.digit(d));
        Widget op(Op o) => key(
          o.symbol,
          () => controller.operator(o),
          kind: _KeyKind.operator,
        );

        return Column(
          children: [
            row([
              key('C', controller.clear, kind: _KeyKind.function),
              key('⌫', controller.backspace, kind: _KeyKind.function),
              op(Op.divide),
              op(Op.multiply),
            ]),
            row([digit('7'), digit('8'), digit('9'), op(Op.subtract)]),
            row([digit('4'), digit('5'), digit('6'), op(Op.add)]),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        row([digit('1'), digit('2'), digit('3')]),
                        row([
                          // `d` (days) while typing a time with days shown.
                          calc.showsDayKey
                              ? key(
                                  'd',
                                  controller.day,
                                  enabled: calc.dayKeyEnabled,
                                )
                              : digit('00'),
                          digit('0'),
                          key(
                            calc.separatorLabel,
                            controller.separator,
                            enabled: calc.separatorEnabled,
                          ),
                        ]),
                      ],
                    ),
                  ),
                  Expanded(
                    child: key('=', controller.equals, kind: _KeyKind.operator),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
