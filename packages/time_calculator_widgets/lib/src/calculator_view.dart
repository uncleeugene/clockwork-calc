import 'package:flutter/material.dart';

import 'package:time_calc_engine/time_calc_engine.dart';

import 'controller.dart';
import 'display.dart';
import 'format_switch.dart';
import 'history.dart';
import 'keypad.dart';
import 'mode_indicators.dart';

/// The complete calculator: format switch, history, display and keypad.
/// Fills the space it is given.
///
/// Instead of the format switch, the top row can show calculator-style
/// labels: `TIME DEC DAYS SEC` (see [showFormatSwitch], [plainController]).
class TimeCalculatorView extends StatefulWidget {
  const TimeCalculatorView({
    super.key,
    this.controller,
    this.mode = CalculatorMode.time,
    this.keypadStyle = const TimeCalculatorKeypadStyle(),
    this.showFormatSwitch = true,
    this.showSeconds = true,
    this.showDaysToggle = true,
    this.showSecondsToggle = false,
    this.showDecimalToggle = false,
    this.plainController,
    this.plainMode = false,
    this.onPlainModeChanged,
    this.showHistory = true,
  });

  /// Pass one to read or drive the calculator from outside; otherwise the
  /// view creates its own.
  final TimeCalculatorController? controller;

  /// Time or plain calculator. Only used when [controller] is null; otherwise
  /// the controller's calculator decides.
  final CalculatorMode mode;
  final TimeCalculatorKeypadStyle keypadStyle;

  /// The h:mm / decimal segmented switch at the top. When false, the top row
  /// holds the indicator labels instead, with the clear-history button on
  /// the right.
  final bool showFormatSwitch;

  /// Offer the h:mm:ss segment in the format switch.
  final bool showSeconds;

  /// Show the DAYS indicator under the clear-history button.
  final bool showDaysToggle;

  /// Show a SEC indicator next to DAYS that turns seconds on and off. Use it
  /// with [showSeconds] false, instead of the h:mm:ss segment.
  final bool showSecondsToggle;

  /// Show a DEC indicator for decimal hours, first among the time labels.
  /// Use it with [showFormatSwitch] false.
  final bool showDecimalToggle;

  /// A plain calculator to switch to. When given, a TIME label leads the
  /// indicators: lit for the time calculator, tap it for this one. Each
  /// keeps its own calculation and history, but the time shown comes along
  /// as decimal hours (8:20 → 8.33333333333), ready for e.g. `× rate`.
  final TimeCalculatorController? plainController;

  /// Show [plainController] first.
  final bool plainMode;

  /// Called when the TIME label switches calculators, e.g. to remember it.
  final ValueChanged<bool>? onPlainModeChanged;
  final bool showHistory;

  @override
  State<TimeCalculatorView> createState() => _TimeCalculatorViewState();
}

class _TimeCalculatorViewState extends State<TimeCalculatorView> {
  TimeCalculatorController? _ownController;
  late bool _plain = widget.plainMode && widget.plainController != null;

  void _togglePlain() {
    if (!_plain) {
      // Bring the time shown along as decimal hours, so "× rate" is next.
      final minutes = _controller.calculator.displayedMinutes;
      if (minutes != null && minutes != 0) {
        widget.plainController!.enterValue(minutes / 60);
      }
    }
    setState(() => _plain = !_plain);
    widget.onPlainModeChanged?.call(_plain);
  }

  TimeCalculatorController get _controller =>
      widget.controller ??
      (_ownController ??= TimeCalculatorController(
        TimeCalculator(mode: widget.mode),
      ));

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plain = _plain && widget.plainController != null;
    final controller = plain ? widget.plainController! : _controller;
    // The h:mm / decimal switch means nothing to a plain calculator.
    final showSwitch =
        widget.showFormatSwitch && !controller.calculator.isPlain;
    final labels = [
      if (widget.plainController != null)
        TimeCalculatorIndicator(
          key: const Key('timeToggle'),
          label: 'TIME',
          semanticLabel: 'Time calculator',
          on: !plain,
          onTap: _togglePlain,
        ),
      // The time labels hide themselves where they don't apply.
      if (widget.showDecimalToggle)
        TimeCalculatorDecimalToggle(controller: controller),
      if (widget.showDaysToggle)
        TimeCalculatorDaysToggle(controller: controller),
      if (widget.showSecondsToggle)
        TimeCalculatorSecondsToggle(controller: controller),
    ];
    final indicators = labels.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: labels);
    // Without the switch, the labels take its place in the top row.
    final labelsOnTop = !widget.showFormatSwitch && indicators != null;
    final overlay = labelsOnTop ? null : indicators;
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (labelsOnTop)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _LabelBar(
                      controller: controller,
                      labels: indicators,
                      showClearHistory: widget.showHistory,
                    ),
                  )
                else if (showSwitch || widget.showHistory)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _TopBar(
                      controller: controller,
                      showSwitch: showSwitch,
                      showSeconds: widget.showSeconds,
                      showClearHistory: widget.showHistory,
                    ),
                  ),
                if (widget.showHistory)
                  Expanded(
                    // The indicators sit over the faded top of the history,
                    // so they take no space from it.
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TimeCalculatorHistory(controller: controller),
                        ),
                        if (overlay != null)
                          Positioned(top: 0, left: 0, child: overlay),
                      ],
                    ),
                  )
                else if (overlay != null)
                  Align(alignment: Alignment.centerLeft, child: overlay),
                // Full width, so a double-tap anywhere in the area copies.
                TimeCalculatorDisplay(
                  controller: controller,
                  hideFinishedExpression: widget.showHistory,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TimeCalculatorKeypad(
              controller: controller,
              style: widget.keypadStyle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Indicator labels on the left, clear-history button on the right.
class _LabelBar extends StatelessWidget {
  const _LabelBar({
    required this.controller,
    required this.labels,
    required this.showClearHistory,
  });

  final TimeCalculatorController controller;
  final Widget labels;
  final bool showClearHistory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          // Scales down rather than overflowing on very narrow screens.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: labels),
            ),
          ),
          SizedBox(
            width: 48,
            child: _ClearHistoryButton(
              controller: controller,
              show: showClearHistory,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only while there is history to clear.
class _ClearHistoryButton extends StatelessWidget {
  const _ClearHistoryButton({required this.controller, required this.show});

  final TimeCalculatorController controller;
  final bool show;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => !show || controller.calculator.history.isEmpty
        ? const SizedBox.shrink()
        : IconButton(
            tooltip: 'Clear history',
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.54),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: controller.clearHistory,
          ),
  );
}

/// Format switch, with a clear-history button on the left when useful.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.showSwitch,
    required this.showSeconds,
    required this.showClearHistory,
  });

  final TimeCalculatorController controller;
  final bool showSwitch;
  final bool showSeconds;
  final bool showClearHistory;

  @override
  Widget build(BuildContext context) {
    // Fixed height so nothing jumps when the clear button appears.
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: _ClearHistoryButton(
              controller: controller,
              show: showClearHistory,
            ),
          ),
          // No balancing spacer on the right with seconds: the three-segment
          // switch needs that width on 360-wide phones. Very narrow screens
          // scale it down rather than wrapping its labels.
          Expanded(
            child: Center(
              child: showSwitch
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TimeFormatSwitch(
                        controller: controller,
                        showSeconds: showSeconds,
                      ),
                    )
                  : null,
            ),
          ),
          // The two-segment switch fits with room to spare, so keep it centred.
          if (!showSeconds) const SizedBox(width: 48),
        ],
      ),
    );
  }
}
