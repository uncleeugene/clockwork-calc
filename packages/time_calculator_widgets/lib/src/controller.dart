import 'package:flutter/foundation.dart';
import 'package:time_calc_engine/time_calc_engine.dart';

/// Wraps a [TimeCalculator] and notifies listeners after every action, so
/// separate widgets (keypad, display, history…) stay in sync.
class TimeCalculatorController extends ChangeNotifier {
  TimeCalculatorController([TimeCalculator? calculator])
    : calculator = calculator ?? TimeCalculator();

  /// A controller for an ordinary (non-time) calculator.
  TimeCalculatorController.plain()
    : calculator = TimeCalculator(mode: CalculatorMode.plain);

  /// The engine. Read state from it freely; change it through the methods
  /// below (or [update]) so listeners are notified.
  final TimeCalculator calculator;

  /// Runs any engine action and notifies listeners.
  void update(void Function(TimeCalculator calc) action) {
    action(calculator);
    notifyListeners();
  }

  void digit(String digits) => update((c) => c.digit(digits));
  void separator() => update((c) => c.separator());
  void day() => update((c) => c.day());
  void doubleZeroOrDay() => update((c) => c.doubleZeroOrDay());
  void operator(Op op) => update((c) => c.operator(op));
  void equals() => update((c) => c.equals());
  void clear() => update((c) => c.clear());
  void backspace() => update((c) => c.backspace());
  void setFormat(TimeFormat format) => update((c) => c.setFormat(format));
  void setShowSeconds(bool seconds) => update((c) => c.setShowSeconds(seconds));
  void setShowDays(bool days) => update((c) => c.setShowDays(days));
  void recall(HistoryEntry entry) => update((c) => c.recall(entry));
  void enterValue(double value) => update((c) => c.enterValue(value));
  void clearHistory() => update((c) => c.clearHistory());
}
