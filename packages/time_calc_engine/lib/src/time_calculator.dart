/// Calculator engine for time arithmetic, in hours:minutes(:seconds) or
/// decimal hours.
///
/// In [TimeFormat.hoursMinutes], time entry works like a cash register: each
/// new digit shifts the previous ones one place to the left. The last two
/// digits are minutes, everything before them is hours. Typing 3, 0, 0 shows
/// 0:03 → 0:30 → 3:00. [TimeFormat.hoursMinutesSeconds] works the same with
/// two more places: 3, 0, 0 shows 0:00:03 → 0:00:30 → 0:03:00.
///
/// In [TimeFormat.decimal], times are entered and shown as decimal hours
/// (1.5 = 1 hour 30 minutes).
///
/// In [CalculatorMode.plain] it is an ordinary calculator instead.
///
/// `+` and `−` take a time operand. `×` and `÷` take a plain number
/// (e.g. 2:30 × 3 = 7:30), which is entered normally and may have a decimal.
///
/// Values are kept internally as (fractional) minutes, so switching format
/// mid-calculation only changes how things are shown: seconds hidden by h:mm
/// are rounded for display but not lost.
///
/// With days shown ([TimeCalculator.setShowDays]), h:mm and h:mm:ss values
/// of 24 hours or more are split into days, like a clock: 27:30 shows as
/// "1d 03:30", and −3:00 as "-1d 21:00" (21:00 the day before). Hours always
/// have two digits. Typed digits are padded too (00:03) but only split into
/// days once the entry is used. The `d` key ([TimeCalculator.day]), which
/// takes the place of `00` while days are shown, types days on purpose:
/// 1 d 5 0 0 → 1d 05:00.
library;

enum Op { add, subtract, multiply, divide }

enum TimeFormat { hoursMinutes, hoursMinutesSeconds, decimal }

/// [time]: values are times (h:mm or decimal hours).
/// [plain]: an ordinary calculator; every value is a plain number.
enum CalculatorMode { time, plain }

extension OpSymbol on Op {
  String get symbol => switch (this) {
    Op.add => '+',
    Op.subtract => '−',
    Op.multiply => '×',
    Op.divide => '÷',
  };
}

/// Prefixes whole days, clock style: the remainder is always 0 to 24 hours,
/// so negative values count back from an earlier day. [perDay] is how many
/// [total] units make a day; [format] formats the remainder in minutes.
String _withDays(
  int total,
  int perDay,
  double perMinute,
  String Function(double minutes) format,
) {
  final days = (total / perDay).floor();
  // Clock style: hours always have two digits ("03:00").
  final rest = format((total - days * perDay) / perMinute)
      .padLeft(perMinute == 1 ? 5 : 8, '0');
  return days == 0 ? rest : '${days}d $rest';
}

/// Formats [minutes] as `h:mm`, rounding to the nearest minute. With [days],
/// 24 hours or more is split off as days: 1650 → "1d 03:30".
String formatMinutes(double minutes, {bool days = false}) {
  final total = minutes.round();
  if (days) return _withDays(total, 24 * 60, 1, formatMinutes);
  final sign = total < 0 ? '-' : '';
  final abs = total.abs();
  final mm = (abs % 60).toString().padLeft(2, '0');
  return '$sign${abs ~/ 60}:$mm';
}

/// Formats [minutes] as `h:mm:ss`, rounding to the nearest second. With
/// [days], 24 hours or more is split off as days: "1d 03:30:15".
String formatSeconds(double minutes, {bool days = false}) {
  final total = (minutes * 60).round();
  if (days) return _withDays(total, 24 * 3600, 60, formatSeconds);
  final sign = total < 0 ? '-' : '';
  final abs = total.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$sign${abs ~/ 3600}:${two(abs % 3600 ~/ 60)}:${two(abs % 60)}';
}

/// Formats [minutes] as decimal hours with two places, e.g. 90 → "1.50".
String formatDecimalHours(double minutes) {
  final text = (minutes / 60).toStringAsFixed(2);
  return text == '-0.00' ? '0.00' : text;
}

/// [days] applies to h:mm and h:mm:ss; decimal hours never show days.
String formatTime(double minutes, TimeFormat format, {bool days = false}) =>
    switch (format) {
      TimeFormat.hoursMinutes => formatMinutes(minutes, days: days),
      TimeFormat.hoursMinutesSeconds => formatSeconds(minutes, days: days),
      TimeFormat.decimal => formatDecimalHours(minutes),
    };

/// Splits raw time digits into hours and two-digit fields: minutes, plus
/// seconds if [seconds]. "130" → [1, 30]; with seconds "13015" → [1, 30, 15].
List<int> _timeFields(String digits, bool seconds) {
  final fields = seconds ? 2 : 1;
  final padded = digits.padLeft(1 + 2 * fields, '0');
  final hoursEnd = padded.length - 2 * fields;
  return [
    int.parse(padded.substring(0, hoursEnd)),
    for (var i = hoursEnd; i < padded.length; i += 2)
      int.parse(padded.substring(i, i + 2)),
  ];
}

/// Formats raw time digits as typed, without normalizing minutes:
/// "3" → "0:03", "300" → "3:00", "90" → "0:90". With [seconds]:
/// "3" → "0:00:03", "13015" → "1:30:15".
String formatTimeDigits(String digits, {bool seconds = false}) {
  final [hours, ...rest] = _timeFields(digits, seconds);
  return [hours, for (final f in rest) f.toString().padLeft(2, '0')].join(':');
}

/// Converts raw time digits to minutes; minutes (and seconds) over 59 carry.
double timeDigitsToMinutes(String digits, {bool seconds = false}) {
  if (digits.isEmpty) return 0;
  final fields = _timeFields(digits, seconds);
  return fields[0] * 60 + fields[1] + (seconds ? fields[2] / 60 : 0);
}

double _parseNumber(String text) =>
    text.isEmpty ? 0 : double.parse(text.endsWith('.') ? '${text}0' : text);

/// Formats a plain number to 12 significant digits, hiding float noise
/// (0.1 + 0.2 → "0.3") and trailing zeros.
String _formatNumber(double value) {
  if (value == 0) return '0';
  if (value == value.truncateToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  final text = value.toStringAsPrecision(12);
  final [mantissa, ...exponent] = text.split('e');
  final trimmed = mantissa.contains('.')
      ? mantissa.replaceFirst(RegExp(r'\.?0+$'), '')
      : mantissa;
  return exponent.isEmpty ? trimmed : '${trimmed}e${exponent.single}';
}

/// An item on the expression line. Times are stored as minutes and formatted
/// on demand, so they follow the current [TimeFormat]; plain numbers and
/// operators are stored as text.
class _Token {
  _Token.time(double this.minutes) : text = '';
  _Token.text(this.text) : minutes = null;

  final double? minutes;
  final String text;

  String format(TimeFormat f, bool days) =>
      minutes == null ? text : formatTime(minutes!, f, days: days);
}

/// A finished calculation, e.g. "1:30 + 0:45 =" with result 135 minutes.
class HistoryEntry {
  HistoryEntry._(this._tokens, this.result, this._isTime);

  final List<_Token> _tokens;
  final bool _isTime;

  /// Result in minutes, or the plain number in [CalculatorMode.plain].
  final double result;

  String resultText(TimeFormat f, {bool days = false}) =>
      _isTime ? formatTime(result, f, days: days) : _formatNumber(result);

  String expression(TimeFormat f, {bool days = false}) =>
      _tokens.map((t) => t.format(f, days)).join(' ');
}

class TimeCalculator {
  TimeCalculator({this.mode = CalculatorMode.time});

  static const maxTimeDigits = 7; // up to 99999:99
  static const maxTimeDigitsWithSeconds = 9; // up to 99999:99:99
  static const maxNumberLength = 8;
  static const maxPlainNumberLength = 12;
  static const maxHistory = 100;
  static const maxDayDigits = 3; // up to 999d
  static const maxHourDigits = 5; // before `:`, up to 99999
  static const maxFieldDigits = 6; // after `:`, up to 999999 min or s

  bool _decimal = false;
  bool _seconds = false;
  bool _days = false;
  String _entry = '';

  /// After `:`, the typed time as separate fields: hours, minutes and (after
  /// a second `:`) seconds. Digits go into the last field, which can grow
  /// past two digits: : 5 0 0 is 500 minutes. Null before any colon; [_entry]
  /// is then empty.
  List<String>? _fields;

  /// Days typed before `d`; [_entry] then holds the hours and minutes. Null
  /// before any `d`.
  String? _dayDigits;

  /// A result recalled from history, used as the entry at full precision.
  double? _recalled;
  double? _acc;
  Op? _op;
  final List<_Token> _tape = [];
  bool _done = false;
  bool _error = false;
  final List<HistoryEntry> _history = [];

  /// Finished calculations, oldest first.
  List<HistoryEntry> get history => List.unmodifiable(_history);

  bool get _hasEntry => _typing || _recalled != null;

  bool get _typing =>
      _entry.isNotEmpty || _dayDigits != null || _fields != null;

  /// Fixed for the calculator's lifetime.
  final CalculatorMode mode;

  bool get isPlain => mode == CalculatorMode.plain;

  /// History results can be recalled except as a time calculator's × or ÷
  /// operand.
  bool get canRecall => !_error && (isPlain || !_multiplierEntry);

  /// The format values are shown in.
  TimeFormat get format => _decimal
      ? TimeFormat.decimal
      : _seconds
      ? TimeFormat.hoursMinutesSeconds
      : TimeFormat.hoursMinutes;

  /// Whether seconds are shown. In decimal mode this is remembered for
  /// [alternateFormat] and for switching back.
  bool get showsSeconds => _seconds;

  /// The "other" format, handy for showing a value both ways: decimal for
  /// h:mm(:ss), and h:mm or h:mm:ss for decimal.
  /// Whether h:mm and h:mm:ss values of 24 hours or more are split into
  /// days. Ignored by decimal hours.
  bool get showsDays => _days;

  TimeFormat get alternateFormat => _decimal
      ? (_seconds ? TimeFormat.hoursMinutesSeconds : TimeFormat.hoursMinutes)
      : TimeFormat.decimal;

  int get _fieldCount => _seconds ? 2 : 1;

  int get _maxTimeDigits => _seconds ? maxTimeDigitsWithSeconds : maxTimeDigits;

  bool get _multiplierEntry => _op == Op.multiply || _op == Op.divide;

  /// True when the next operand is a plain number: always in plain mode,
  /// otherwise after × or ÷.
  bool get numberMode => isPlain || _multiplierEntry;

  int get _maxNumberLength => isPlain ? maxPlainNumberLength : maxNumberLength;

  String _formatValue(double v) =>
      isPlain ? _formatNumber(v) : formatTime(v, format, days: _days);

  _Token _valueToken(double v) =>
      isPlain ? _Token.text(_formatNumber(v)) : _Token.time(v);

  /// True when the current entry is typed as a normal number (with optional
  /// decimal point) rather than shifted-in h:mm digits.
  bool get _plainEntry => numberMode || _decimal;

  /// The key next to 0: `.` for plain numbers, `:` for h:mm entry.
  String get separatorLabel => _plainEntry ? '.' : ':';

  bool get separatorEnabled => !_error;

  /// Whether the key next to 0 is `d` (days) rather than `00`: when days
  /// are shown and a time is being typed in h:mm(:ss).
  bool get showsDayKey => _days && !isPlain && !_plainEntry;

  /// `d` works once per entry, before any `:`.
  bool get dayKeyEnabled =>
      showsDayKey && !_error && _dayDigits == null && _fields == null;

  bool get hasError => _error;

  /// True right after `=`, while the result is shown.
  bool get isFinished => _done;

  /// Whether a value is being typed (or was recalled) for the current
  /// operand. False right after an operator, while [display] still shows the
  /// running total.
  bool get hasEntry => !_error && _hasEntry;

  /// What `=` would give now, formatted like [display]; null when there is
  /// no operation to work out yet, or it would fail (÷ 0).
  String? get preview {
    if (_error || _done || _op == null || !_hasEntry) return null;
    final value = numberMode
        ? _recalled ?? _parseNumber(_entry)
        : _entryMinutes;
    final result = switch (_op!) {
      Op.add => _acc! + value,
      Op.subtract => _acc! - value,
      Op.multiply => _acc! * value,
      Op.divide => value == 0 ? null : _acc! / value,
    };
    return result == null || !result.isFinite ? null : _formatValue(result);
  }

  /// The big number on screen.
  String get display {
    if (_error) return 'Error';
    if (_recalled != null) return _formatValue(_recalled!);
    if (_typing) {
      if (_plainEntry) return _entry;
      final typed = _fields == null
          ? formatTimeDigits(_entry, seconds: _seconds)
          : _formatFields(_fields!);
      if (!_days) return typed;
      // With days shown, hours get two digits like a clock: 0:03 → 00:03.
      final clock = typed.indexOf(':') == 1 ? '0$typed' : typed;
      final days = _dayDigits;
      return days == null ? clock : '${int.parse(days)}d $clock';
    }
    return _formatValue(_acc ?? 0);
  }

  /// The expression line above the display, e.g. "1:30 + 0:45 =".
  String get expression => _tape.map((t) => t.format(format, _days)).join(' ');

  /// Minutes value currently shown, or null when showing a plain number
  /// (always null in plain mode).
  double? get displayedMinutes {
    if (_error || isPlain) return null;
    if (_recalled != null) return _recalled;
    if (_typing) {
      if (numberMode) return null;
      return _entryMinutes;
    }
    return _acc ?? 0;
  }

  /// Typed fields as shown: hours, then minutes and seconds with at least
  /// two digits. ["1", "5"] → "1:05"; ["", "500"] → "0:500".
  String _formatFields(List<String> fields) {
    int n(String f) => f.isEmpty ? 0 : int.parse(f);
    return [
      n(fields[0]),
      for (var i = 1; i <= _fieldCount; i++)
        (i < fields.length ? fields[i] : '').padLeft(2, '0'),
    ].join(':');
  }

  double get _entryMinutes {
    if (_recalled != null) return _recalled!;
    if (_decimal) return _parseNumber(_entry) * 60;
    final days = int.parse(_dayDigits ?? '0') * 24 * 60;
    final fields = _fields;
    if (fields == null) {
      return timeDigitsToMinutes(_entry, seconds: _seconds) + days;
    }
    double n(int i) =>
        i < fields.length && fields[i].isNotEmpty ? double.parse(fields[i]) : 0;
    return days + n(0) * 60 + n(1) + n(2) / 60;
  }

  /// Switches between h:mm, h:mm:ss and decimal hours. The running
  /// calculation is kept; a time being typed is converted to the new format.
  /// Choosing decimal keeps the seconds setting for [alternateFormat].
  void setFormat(TimeFormat format) => _changeFormat(
    decimal: format == TimeFormat.decimal,
    seconds: format == TimeFormat.decimal
        ? _seconds
        : format == TimeFormat.hoursMinutesSeconds,
  );

  /// Shows or hides seconds without leaving decimal mode.
  void setShowSeconds(bool seconds) =>
      _changeFormat(decimal: _decimal, seconds: seconds);

  void _changeFormat({required bool decimal, required bool seconds}) {
    if (isPlain) return;
    final before = format;
    final convertEntry = _typing && !numberMode && !_done;
    final minutes = convertEntry ? _entryMinutes : 0.0;
    _decimal = decimal;
    _seconds = seconds;
    if (format == before) return;
    _fields = null;
    if (!convertEntry) return;
    if (decimal) {
      _dayDigits = null;
      final places = seconds ? 4 : 2;
      _entry = _formatNumber(
        double.parse((minutes / 60).toStringAsFixed(places)),
      );
      return;
    }
    _setTypedTime(minutes);
  }

  /// Replaces the time being typed with [minutes], split into days when
  /// they're shown: 29:00 → 1d 05:00.
  void _setTypedTime(double minutes) {
    _dayDigits = null;
    _fields = null;
    if (_days) {
      final whole = (minutes / (24 * 60)).floor();
      if (whole >= 1 && '$whole'.length <= maxDayDigits) {
        _dayDigits = '$whole';
        return _setTimeEntry(minutes - whole * 24 * 60);
      }
    }
    _setTimeEntry(minutes);
  }

  /// Sets [_entry] to the h:mm(:ss) digits for [minutes]; days fold into
  /// hours.
  void _setTimeEntry(double minutes) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (_seconds) {
      final total = (minutes * 60).round();
      _entry = '${total ~/ 3600}${two(total % 3600 ~/ 60)}${two(total % 60)}';
    } else {
      final total = minutes.round();
      _entry = '${total ~/ 60}${two(total % 60)}';
    }
    _entry = _entry.replaceFirst(RegExp('^0+'), '');
  }

  /// Shows or hides days for h:mm and h:mm:ss values. Only changes how
  /// values are shown; nothing is recalculated.
  void setShowDays(bool days) {
    if (isPlain || days == _days) return;
    _days = days;
    // Re-split a time being typed so it matches: 1d 05:00 ↔ 29:00.
    if (!_typing || _plainEntry || _done) return;
    _setTypedTime(_entryMinutes);
  }

  /// Uses a history result as the current entry.
  void recall(HistoryEntry entry) => enterValue(entry.result);

  /// Uses [value] as the current entry, at full precision, as if typed:
  /// minutes in time mode, a plain number in plain mode. Clears an error.
  /// Does nothing where a value can't go (see [canRecall]).
  void enterValue(double value) {
    if (_error) _reset();
    if (!canRecall) return;
    if (_done) _reset();
    _entry = '';
    _fields = null;
    _dayDigits = null;
    _recalled = value;
  }

  void clearHistory() => _history.clear();

  /// Typing after a recall starts a fresh entry.
  void _dropRecall() {
    if (_recalled == null) return;
    _recalled = null;
    _entry = '';
  }

  void digit(String digits) {
    if (_error || _done) _reset();
    _dropRecall();
    for (final d in digits.split('')) {
      if (_plainEntry) {
        if (_entry.length >= _maxNumberLength) return;
        _entry = _entry == '0' ? d : _entry + d;
      } else {
        final fields = _fields;
        if (fields != null) {
          // After `:`, digits go into the last field without shifting.
          final last = fields.last;
          if (last.isEmpty && d == '0') continue;
          if (last.length >= maxFieldDigits) return;
          fields.last = last + d;
          continue;
        }
        if (_entry.isEmpty && d == '0') continue; // leading zeros do nothing
        if (_entry.length >= _maxTimeDigits) return;
        _entry += d;
      }
    }
  }

  /// Presses `.` or `:`, whichever applies to the current entry.
  void separator() => _plainEntry ? decimalPoint() : colon();

  void decimalPoint() {
    if (_error) return;
    if (_done) _reset();
    _dropRecall();
    if (!_plainEntry) return;
    if (_entry.contains('.') || _entry.length >= _maxNumberLength) return;
    _entry = _entry.isEmpty ? '0.' : '$_entry.';
  }

  /// Presses `00`, or `d` when [showsDayKey].
  void doubleZeroOrDay() => showsDayKey ? day() : digit('00');

  /// Makes the digits typed so far whole days: 1 → 1d 00:00. Following
  /// digits shift into the hours and minutes as usual, and `:` still works:
  /// 1 d 5 : 3 0 → 1d 05:30. Only while [showsDayKey].
  void day() {
    if (_error) return;
    if (_done) _reset();
    _dropRecall();
    if (!dayKeyEnabled) return;
    if (_entry.isEmpty || _entry.length > maxDayDigits) return;
    _dayDigits = _entry;
    _entry = '';
  }

  /// Makes the digits typed so far whole hours: 3 → 3:00. Following digits
  /// are minutes, as many as you like: 1 : 5 0 0 is 1 hour 500 minutes,
  /// shown as 1:500 until used (then 9:20). With seconds shown, a second `:`
  /// moves on to the seconds: 1 : 3 0 : 1 5 → 1:30:15, : : 9 0 0 → 0:15:00.
  void colon() {
    if (_error) return;
    if (_done) _reset();
    _dropRecall();
    if (_plainEntry) return;
    final fields = _fields;
    if (fields == null) {
      if (_entry.length > maxHourDigits) return;
      _fields = [_entry, ''];
      _entry = '';
    } else if (fields.length <= _fieldCount) {
      fields.add('');
    }
  }

  void backspace() {
    if (_error) return _reset();
    if (_done) return;
    if (_recalled != null) return _dropRecall();
    final fields = _fields;
    if (fields != null) {
      final last = fields.last;
      if (last.isNotEmpty) {
        fields.last = last.substring(0, last.length - 1);
      } else if (fields.length > 2) {
        fields.removeLast(); // undo the second colon
      } else {
        // Undo the first colon: the hours become the typed digits again.
        _entry = fields.first;
        _fields = null;
      }
      return;
    }
    if (_entry.isEmpty) {
      // Undo `d`: the days become the typed digits again.
      if (_dayDigits != null) {
        _entry = _dayDigits!;
        _dayDigits = null;
      }
      return;
    }
    _entry = _entry.substring(0, _entry.length - 1);
  }

  void clear() => _reset();

  void operator(Op op) {
    if (_error) return;
    if (_done) {
      // Continue calculating with the previous result.
      _done = false;
      _tape
        ..clear()
        ..add(_valueToken(_acc!));
    } else if (!_hasEntry) {
      if (_op != null) {
        // Pressing another operator replaces the pending one.
        _op = op;
        _tape[_tape.length - 1] = _Token.text(op.symbol);
        return;
      }
      _acc ??= 0;
      _tape.add(_valueToken(_acc!));
    } else {
      _commitEntry();
      if (_error) return;
    }
    _op = op;
    _tape.add(_Token.text(op.symbol));
  }

  void equals() {
    if (_error || _done) return;
    if (_op == null && !_hasEntry) return;
    if (!_hasEntry) {
      // "1:30 + =" — drop the dangling operator.
      _tape.removeLast();
    } else {
      _commitEntry();
      if (_error) return;
    }
    _op = null;
    _tape.add(_Token.text('='));
    _done = true;
    _history.add(HistoryEntry._(List.of(_tape), _acc!, !isPlain));
    if (_history.length > maxHistory) _history.removeAt(0);
  }

  void _commitEntry() {
    final double value;
    if (numberMode) {
      value = _recalled ?? _parseNumber(_entry);
      _tape.add(_Token.text(_formatNumber(value)));
    } else {
      value = _entryMinutes;
      _tape.add(_Token.time(value));
    }
    _entry = '';
    _fields = null;
    _dayDigits = null;
    _recalled = null;
    _acc = switch (_op) {
      null => value,
      Op.add => _acc! + value,
      Op.subtract => _acc! - value,
      Op.multiply => _acc! * value,
      Op.divide => value == 0 ? null : _acc! / value,
    };
    if (_acc == null || !_acc!.isFinite) _error = true;
  }

  void _reset() {
    _entry = '';
    _fields = null;
    _dayDigits = null;
    _recalled = null;
    _acc = null;
    _op = null;
    _tape.clear();
    _done = false;
    _error = false;
  }
}
