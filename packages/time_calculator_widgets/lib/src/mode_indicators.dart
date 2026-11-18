import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_calc_engine/time_calc_engine.dart';

import 'controller.dart';

/// A small label like the mode indicators on a calculator screen: lit in
/// the primary color when [on], dim otherwise. Tapping calls [onTap].
class TimeCalculatorIndicator extends StatelessWidget {
  const TimeCalculatorIndicator({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  /// Read by screen readers instead of [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: on,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: on
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A "DEC" indicator: lit while showing decimal hours; tapping switches
/// between decimal and h:mm (or h:mm:ss, if seconds are on). Hidden in plain
/// mode. An alternative to [TimeFormatSwitch].
class TimeCalculatorDecimalToggle extends StatelessWidget {
  const TimeCalculatorDecimalToggle({
    super.key,
    required this.controller,
    this.label = 'DEC',
  });

  final TimeCalculatorController controller;
  final String label;

  @override
  Widget build(BuildContext context) => _ModeIndicator(
    tapKey: const Key('decimalToggle'),
    controller: controller,
    label: label,
    semanticLabel: 'Decimal hours',
    hideInDecimal: false,
    isOn: (calc) => calc.format == TimeFormat.decimal,
    toggle: (calc, on) => calc.setFormat(
      on
          ? TimeFormat.decimal
          : calc.showsSeconds
          ? TimeFormat.hoursMinutesSeconds
          : TimeFormat.hoursMinutes,
    ),
  );
}

/// A small "DAYS" indicator: tapping it switches days on or off
/// ([TimeCalculator.setShowDays]); it is lit while days are shown. Hidden in
/// decimal hours and plain mode, where days don't apply.
class TimeCalculatorDaysToggle extends StatelessWidget {
  const TimeCalculatorDaysToggle({
    super.key,
    required this.controller,
    this.label = 'DAYS',
  });

  final TimeCalculatorController controller;
  final String label;

  @override
  Widget build(BuildContext context) => _ModeIndicator(
    tapKey: const Key('daysToggle'),
    controller: controller,
    label: label,
    semanticLabel: 'Show days',
    isOn: (calc) => calc.showsDays,
    toggle: (calc, on) => calc.setShowDays(on),
  );
}

/// A small "SEC" indicator: tapping it switches between h:mm and h:mm:ss
/// ([TimeCalculator.setShowSeconds]); it is lit while seconds are shown.
/// Hidden in decimal hours and plain mode. Pair it with
/// `TimeFormatSwitch(showSeconds: false)`.
class TimeCalculatorSecondsToggle extends StatelessWidget {
  const TimeCalculatorSecondsToggle({
    super.key,
    required this.controller,
    this.label = 'SEC',
  });

  final TimeCalculatorController controller;
  final String label;

  @override
  Widget build(BuildContext context) => _ModeIndicator(
    tapKey: const Key('secondsToggle'),
    controller: controller,
    label: label,
    semanticLabel: 'Show seconds',
    isOn: (calc) => calc.showsSeconds,
    toggle: (calc, on) => calc.setShowSeconds(on),
  );
}

/// An indicator bound to a controller's calculator; hidden where it doesn't
/// apply.
class _ModeIndicator extends StatelessWidget {
  const _ModeIndicator({
    required this.tapKey,
    required this.controller,
    required this.label,
    required this.semanticLabel,
    required this.isOn,
    required this.toggle,
    this.hideInDecimal = true,
  });

  /// On the tappable part, so it's only found while the indicator shows.
  final Key tapKey;
  final TimeCalculatorController controller;
  final String label;
  final String semanticLabel;
  final bool Function(TimeCalculator calc) isOn;
  final void Function(TimeCalculator calc, bool on) toggle;
  final bool hideInDecimal;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final calc = controller.calculator;
        if (calc.isPlain ||
            (hideInDecimal && calc.format == TimeFormat.decimal)) {
          return const SizedBox.shrink();
        }
        final on = isOn(calc);
        return TimeCalculatorIndicator(
          key: tapKey,
          label: label,
          semanticLabel: semanticLabel,
          on: on,
          onTap: () => controller.update((c) => toggle(c, !on)),
        );
      },
    );
  }
}
