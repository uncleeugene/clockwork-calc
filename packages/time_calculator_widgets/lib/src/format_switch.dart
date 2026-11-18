import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_calculator/time_calculator.dart';

import 'controller.dart';
import 'mode_indicators.dart';

/// Segmented `h:mm | h:mm:ss | decimal` switch. Set [showSeconds] to false
/// for a two-segment `h:mm | decimal` switch; its h:mm segment then covers
/// h:mm:ss too and leaves the seconds setting alone (e.g. for a
/// [TimeCalculatorSecondsToggle]).
class TimeFormatSwitch extends StatelessWidget {
  const TimeFormatSwitch({
    super.key,
    required this.controller,
    this.showSeconds = true,
    this.hoursMinutesLabel = 'h:mm',
    this.hoursMinutesSecondsLabel = 'h:mm:ss',
    this.decimalLabel = 'decimal',
  });

  final TimeCalculatorController controller;

  /// Offer the h:mm:ss segment.
  final bool showSeconds;
  final String hoursMinutesLabel;
  final String hoursMinutesSecondsLabel;
  final String decimalLabel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SegmentedButton<TimeFormat>(
        key: const Key('formatSwitch'),
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        ),
        segments: [
          ButtonSegment(
            value: TimeFormat.hoursMinutes,
            label: Text(hoursMinutesLabel),
          ),
          if (showSeconds)
            ButtonSegment(
              value: TimeFormat.hoursMinutesSeconds,
              label: Text(hoursMinutesSecondsLabel),
            ),
          ButtonSegment(value: TimeFormat.decimal, label: Text(decimalLabel)),
        ],
        selected: {
          !showSeconds &&
                  controller.calculator.format == TimeFormat.hoursMinutesSeconds
              ? TimeFormat.hoursMinutes
              : controller.calculator.format,
        },
        onSelectionChanged: (s) {
          HapticFeedback.selectionClick();
          final calc = controller.calculator;
          // Without its own segment, h:mm:ss comes back with h:mm.
          controller.setFormat(
            !showSeconds &&
                    s.single == TimeFormat.hoursMinutes &&
                    calc.showsSeconds
                ? TimeFormat.hoursMinutesSeconds
                : s.single,
          );
        },
      ),
    );
  }
}
