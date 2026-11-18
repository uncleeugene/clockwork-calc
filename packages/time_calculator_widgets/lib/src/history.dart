import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';

/// Past calculations, newest at the bottom, older ones fading out towards
/// the top. Tapping one recalls its result. Needs a bounded height.
class TimeCalculatorHistory extends StatelessWidget {
  const TimeCalculatorHistory({
    super.key,
    required this.controller,
    this.fade = true,
    this.fontSize = 18,
  });

  final TimeCalculatorController controller;

  /// Fade older entries out towards the top edge.
  final bool fade;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final calc = controller.calculator;
        final history = calc.history;
        final list = ListView.builder(
          key: const Key('history'),
          reverse: true,
          itemCount: history.length,
          itemBuilder: (context, i) {
            final entry = history[history.length - 1 - i];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: calc.canRecall
                  ? () {
                      HapticFeedback.selectionClick();
                      controller.recall(entry);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${entry.expression(calc.format, days: calc.showsDays)} ',
                      ),
                      TextSpan(
                        text: entry.resultText(
                          calc.format,
                          days: calc.showsDays,
                        ),
                        style: TextStyle(color: scheme.primary),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: scheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ),
            );
          },
        );
        if (!fade) return list;
        return ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0, 0.35],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: list,
        );
      },
    );
  }
}
