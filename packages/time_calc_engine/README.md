# time_calc_engine

Calculator engine for time arithmetic in **hours:minutes** or **decimal hours**.
Pure Dart, no Flutter dependency, no UI: you wire it to your own keys and display.

- **Shift-left entry**: each digit pushes the previous ones left; the last two
  digits are minutes. `3`, `0`, `0` → `0:03` → `0:30` → `3:00`.
- **Colon entry**: `3` `:` `1` `5` → `3:15` (digits before `:` become hours).
  Digits after the last `:` don't shift and aren't limited to two, so it
  converts too: `:` `5` `0` `0` `=` → `8:20`; with seconds, `:` `:` `9` `0` `0`
  `=` → `0:15:00`.
- **Seconds** (optional): `h:mm:ss` with the same shift-left entry
  (`3`, `0`, `0` → `0:00:03` → `0:00:30` → `0:03:00`); a second `:` moves on
  to seconds (`1` `:` `3` `0` `:` `1` `5` → `1:30:15`). Hiding seconds rounds
  the display to the minute but keeps the value.
- **Decimal mode**: times entered and shown as decimal hours (`1.5` = 1:30).
  Switching format mid-calculation re-renders everything, history included.
- `+` / `−` take times; `×` / `÷` take plain numbers (`2:30 × 3 = 7:30`).
- **History** of finished calculations, recallable as operands at full precision.

## Install

```yaml
dependencies:
  time_calc_engine: ^1.0.0
```

## Usage

```dart
import 'package:time_calc_engine/time_calc_engine.dart';

final calc = TimeCalculator();

calc.digit('1');
calc.digit('3');
calc.digit('0');           // display: 1:30
calc.operator(Op.add);
calc.digit('45');          // display: 0:45
calc.equals();

calc.display;              // "2:15"
calc.expression;           // "1:30 + 0:45 ="
calc.displayedMinutes;     // 135.0

calc.setFormat(TimeFormat.decimal);
calc.display;              // "2.25"
```

### Plain mode

The same engine works as an ordinary calculator:

```dart
final calc = TimeCalculator(mode: CalculatorMode.plain);
calc.digit('1'); calc.separator(); calc.digit('5');   // 1.5
calc.operator(Op.multiply); calc.digit('4'); calc.equals();
calc.display;     // "6"
```

Every value is a plain number, `separator()` is always the decimal point,
results are shown to 12 significant digits without float noise
(`0.1 + 0.2` → `0.3`), and the format setting is ignored. Use
`HistoryEntry.resultText(format)` to show history results in either mode.
The mode is fixed for the calculator's lifetime.

### Key handlers

| Key           | Call                                                        |
| ------------- | ----------------------------------------------------------- |
| `0`–`9`, `00` | `digit('7')`, `digit('00')`                                 |
| `.` / `:`     | `separator()` (label: `separatorLabel`, enabled: `separatorEnabled`) |
| `+ − × ÷`     | `operator(Op.add)` … (`op.symbol` gives the label)          |
| `=`           | `equals()`                                                  |
| `C`           | `clear()` (keeps history)                                   |
| `⌫`           | `backspace()`                                               |

### State to render

- `display`: the main value as text (`"Error"` after division by zero).
- `expression`: the running expression, e.g. `"1:30 + 0:45 ="`.
- `displayedMinutes`: the shown value in minutes, or `null` while a plain
  `×`/`÷` number is being typed. Handy for showing the other format.
- `format` / `setFormat(...)`: `TimeFormat.hoursMinutes`,
  `TimeFormat.hoursMinutesSeconds` or `TimeFormat.decimal`.
- `showsSeconds` / `setShowSeconds(...)`: seconds on or off; remembered while in
  decimal mode.
- `showsDays` / `setShowDays(...)`: split h:mm(:ss) values of 24 hours or more
  into days, clock style: 27:30 → `1d 03:30`, −3:00 → `-1d 21:00` (21:00 the
  day before). Hours get two digits, typed ones too (00:03); typed digits split
  into days only once used. Decimal ignores it.
- `day()`: the `d` key, which replaces `00` while `showsDayKey`. Digits typed so
  far become days, the next ones shift into h:mm: `1 d 5 0 0` → `1d 05:00`.
  `dayKeyEnabled` is false once used; backspace undoes it.
  `doubleZeroOrDay()` presses whichever key is showing.
  Turning days off and on while typing re-splits the time: `1d 00:25` ↔ `24:25`.
- `alternateFormat`: the other format (decimal for h:mm(:ss), h:mm or h:mm:ss
  for decimal), for showing a value both ways.
- `history`: list of `HistoryEntry` (oldest first) with `expression(format)`,
  `resultText(format)` (both take `days:`) and `result` (minutes). `recall(entry)` uses a result as the current entry when
  `canRecall` is true; `clearHistory()` empties it.

The engine is a plain mutable object: call a method, then rebuild your UI
(e.g. `setState(() => calc.digit('5'))` in Flutter).

Helpers `formatMinutes`, `formatDecimalHours` and `formatTime` (all with an optional
`days:`) are exported for
formatting minute values yourself.
