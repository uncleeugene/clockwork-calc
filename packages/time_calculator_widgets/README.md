# time_calculator_widgets

Flutter UI for the [`time_calculator`](../time_calculator) engine: use the whole
calculator, or just the pieces you need.

```yaml
dependencies:
  time_calculator_widgets:
    path: ../hourcalc/packages/time_calculator_widgets
```

```dart
import 'package:time_calculator_widgets/time_calculator_widgets.dart';
```

This also exports the engine (`TimeCalculator`, `Op`, `TimeFormat`, …).

## The whole calculator

```dart
const TimeCalculatorView()   // fills the space it's given
```

Options: `controller`, `keypadStyle`, `showFormatSwitch`, `showSeconds`
(h:mm:ss segment in the switch), `showDaysToggle` (DAYS indicator under the
clear-history button), `showSecondsToggle` (SEC indicator next to it; pair with
`showSeconds: false`), `showHistory`.

### Calculator-style labels instead of the switch

```dart
TimeCalculatorView(
  controller: timeController,
  plainController: plainController,   // adds TIME: tap for a plain calculator
  plainMode: false,                   // start in the plain one?
  onPlainModeChanged: (plain) {},     // e.g. remember it
  showFormatSwitch: false,            // labels take the switch's place
  showDecimalToggle: true,            // DEC
  showSecondsToggle: true,            // SEC (DAYS is on by default)
)
```

The top row then reads `TIME DEC DAYS SEC`, with clear-history on the right.
Each label hides where it doesn't apply. Each calculator keeps its own
calculation and history.

## As an ordinary calculator

```dart
const TimeCalculatorView(mode: CalculatorMode.plain)

// or, for individual pieces:
final controller = TimeCalculatorController.plain();
```

In plain mode the h:mm / decimal switch and the other-format line are hidden.

## Individual pieces

All pieces take a `TimeCalculatorController`. Pieces sharing a controller
stay in sync. You own the controller, so remember to `dispose()` it.

| Widget                   | What it is                                   | Size            |
| ------------------------ | -------------------------------------------- | --------------- |
| `TimeCalculatorKeypad`   | 5-row keypad                                 | needs bounded height |
| `TimeCalculatorDisplay`  | expression line, value, other-format line    | sizes to content |
| `TimeCalculatorHistory`  | tappable list of past calculations           | needs bounded height |
| `TimeCalculatorIndicator` | a lit/dim label to build your own toggles | sizes to content |
| `TimeCalculatorDecimalToggle` | small "DEC" indicator; tap for decimal hours | sizes to content |
| `TimeCalculatorDaysToggle` | small "DAYS" indicator; tap to split results into days. Hidden in decimal | sizes to content |
| `TimeCalculatorSecondsToggle` | small "SEC" indicator; tap for h:mm:ss. Hidden in decimal | sizes to content |
| `TimeFormatSwitch`       | `h:mm | h:mm:ss | decimal` segmented button (`showSeconds: false` for two segments; h:mm then covers h:mm:ss) | sizes to content |

```dart
final controller = TimeCalculatorController();

Column(
  children: [
    TimeCalculatorDisplay(controller: controller),
    SizedBox(height: 320, child: TimeCalculatorKeypad(controller: controller)),
  ],
);

// Read or drive it from your own code:
controller.calculator.displayedMinutes;   // e.g. to save the result
controller.clear();
controller.addListener(() { /* react to every key press */ });
```

## Styling

Colors come from your app's `ColorScheme` by default (digit keys:
`surfaceContainerHighest`, `C`/`⌫`: `secondaryContainer`, operators: `primary`).
Override with `TimeCalculatorKeypadStyle`:

```dart
TimeCalculatorKeypad(
  controller: controller,
  style: const TimeCalculatorKeypadStyle(
    digitColor: Color(0xFF333333),
    digitTextColor: Colors.white,
    fontSize: 24,
    borderRadius: 12,
    spacing: 4,
  ),
)
```

`TimeCalculatorDisplay` has `showExpression`, `showAlternate` and
`valueFontSize`; `TimeCalculatorHistory` has `fade` and `fontSize`.
