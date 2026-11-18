import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_calc_engine/time_calc_engine.dart';

import 'controller.dart';

/// Expression line, big current value, and the value in the other format
/// underneath (e.g. "2:15" with "2.25 h"). Right-aligned; sizes to content.
///
/// Double-tapping it copies the value as shown (e.g. "2:15") to the
/// clipboard.
class TimeCalculatorDisplay extends StatelessWidget {
  const TimeCalculatorDisplay({
    super.key,
    required this.controller,
    this.showExpression = true,
    this.hideFinishedExpression = false,
    this.showAlternate = true,
    this.valueFontSize = 80,
    this.copyOnDoubleTap = true,
    this.onCopied,
  });

  final TimeCalculatorController controller;
  final bool showExpression;

  /// Blank the expression line after `=`. Useful next to
  /// [TimeCalculatorHistory], which already shows the finished calculation.
  /// The line keeps its height so the layout doesn't jump.
  final bool hideFinishedExpression;

  /// Show the current value in the other format below the main value.
  /// Never shown for a plain calculator.
  final bool showAlternate;

  /// Maximum size of the main value; it shrinks to fit the width.
  final double valueFontSize;

  /// Double-tap copies the shown value to the clipboard.
  final bool copyOnDoubleTap;

  /// Called with the copied text. If null, a "Copied …" snack bar is shown
  /// (when there is a [ScaffoldMessenger] above this widget).
  final ValueChanged<String>? onCopied;

  Future<void> _copy(BuildContext context) async {
    final calc = controller.calculator;
    if (calc.hasError) return;
    final text = calc.display;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (onCopied != null) return onCopied!(text);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Copied $text'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final calc = controller.calculator;
        final minutes = calc.displayedMinutes;
        final alt = calc.alternateFormat;
        final altText = minutes == null
            ? ''
            : alt == TimeFormat.decimal
            ? '${formatDecimalHours(minutes)} h'
            : formatTime(minutes, alt, days: calc.showsDays);
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showExpression)
              Text(
                hideFinishedExpression && calc.isFinished
                    ? ''
                    : calc.expression,
                key: const Key('expression'),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: valueFontSize * 0.275,
                  color: onSurface.withValues(alpha: 0.54),
                ),
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                calc.display,
                key: const Key('display'),
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w300,
                  color: onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (showAlternate && !calc.isPlain)
              Text(
                altText,
                style: TextStyle(
                  fontSize: valueFontSize * 0.225,
                  color: onSurface.withValues(alpha: 0.38),
                ),
              ),
          ],
        );
        if (!copyOnDoubleTap) return column;
        return GestureDetector(
          key: const Key('displayArea'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => _copy(context),
          child: column,
        );
      },
    );
  }
}
