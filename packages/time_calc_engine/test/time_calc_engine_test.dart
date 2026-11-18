import 'package:test/test.dart';
import 'package:time_calc_engine/time_calc_engine.dart';

void main() {
  group('TimeCalculator', () {
    TimeCalculator typed(String keys) {
      final c = TimeCalculator();
      for (final k in keys.split(' ')) {
        switch (k) {
          case '+':
            c.operator(Op.add);
          case '-':
            c.operator(Op.subtract);
          case '*':
            c.operator(Op.multiply);
          case '/':
            c.operator(Op.divide);
          case '=':
            c.equals();
          case '.':
            c.decimalPoint();
          case ':':
            c.colon();
          case '<':
            c.backspace();
          default:
            c.digit(k);
        }
      }
      return c;
    }

    test('digits shift left', () {
      expect(typed('3').display, '0:03');
      expect(typed('3 0').display, '0:30');
      expect(typed('3 0 0').display, '3:00');
      expect(typed('1 2 3 4 5').display, '123:45');
      expect(typed('3 00').display, '3:00');
    });

    test('leading zeros are ignored, backspace shifts right', () {
      expect(typed('0 0 5').display, '0:05');
      expect(typed('3 0 0 <').display, '0:30');
    });

    test('colon forces typed digits into hours', () {
      expect(typed('3 :').display, '3:00');
      expect(typed('3 : 1').display, '3:01');
      expect(typed('3 : 1 5').display, '3:15');
      expect(typed('3 : 1 5 9').display, '3:159'); // minutes keep going
      expect(typed('1 2 : 00').display, '12:00');
      expect(typed(':').display, '0:00');
      expect(typed(': 4 5').display, '0:45');
      expect(typed('3 : :').display, '3:00');
      expect(typed('2 : 1 5 + 1 : 3 0 =').display, '3:45');
    });

    test('backspace after colon', () {
      expect(typed('3 : 1 5 <').display, '3:01');
      expect(typed('3 : 1 5 < <').display, '3:00');
      expect(typed('3 : 1 5 < < <').display, '0:03');
      expect(typed('3 : < 0').display, '0:30');
    });

    test('minutes after the colon are not limited to two digits', () {
      final c = typed(': 5 0 0');
      expect(c.display, '0:500');
      expect(c.displayedMinutes, 500);
      c.equals();
      expect(c.display, '8:20');
      expect(c.expression, '8:20 =');
      expect(typed('1 : 5 0 0 =').display, '9:20');
      expect(typed(': 9 0 + 1 : 3 0 =').display, '3:00');
      expect(typed(': 0 0 5').display, '0:05'); // leading zeros skipped
      expect(typed(': 1 2 3 4 5 6 7').display, '0:123456'); // 6 digits max
      expect(typed(': 5 0 0 < <').display, '0:05');
    });

    test('addition and subtraction', () {
      final c = typed('1 3 0 + 4 5 =');
      expect(c.display, '2:15');
      expect(c.expression, '1:30 + 0:45 =');
      expect(typed('1 0 0 - 1 3 0 =').display, '-0:30');
    });

    test('minutes over 59 carry into hours', () {
      expect(typed('9 0 + 0 =').display, '1:30');
    });

    test('multiply and divide by a plain number', () {
      expect(typed('2 3 0 * 3 =').display, '7:30');
      expect(typed('1 0 0 * 1 . 5 =').display, '1:30');
      expect(typed('1 0 0 / 3 =').display, '0:20');
      expect(typed('1 0 0 / 3 * 3 =').display, '1:00');
      expect(typed('1 0 0 / 0 =').display, 'Error');
    });

    test('chaining and continuing after equals', () {
      expect(typed('1 0 0 + 3 0 + 1 5 =').display, '1:45');
      expect(typed('1 0 0 + 3 0 = + 3 0 =').display, '2:00');
      expect(typed('1 0 0 + 3 0 = 5').display, '0:05');
    });

    test('operator replaces pending operator', () {
      final c = typed('1 0 0 + * 2 =');
      expect(c.display, '2:00');
      expect(c.expression, '1:00 × 2 =');
    });
  });

  group('decimal format', () {
    test('entry and results are decimal hours', () {
      final c = TimeCalculator()..setFormat(TimeFormat.decimal);
      c
        ..digit('1')
        ..decimalPoint()
        ..digit('5');
      expect(c.display, '1.5');
      c
        ..operator(Op.add)
        ..digit('2')
        ..equals();
      expect(c.display, '3.50');
      expect(c.expression, '1.50 + 2.00 =');
    });

    test('switching re-renders the calculation', () {
      final c = TimeCalculator()
        ..digit('1')
        ..digit('3')
        ..digit('0')
        ..operator(Op.add)
        ..digit('4')
        ..digit('5')
        ..equals();
      expect(c.display, '2:15');
      c.setFormat(TimeFormat.decimal);
      expect(c.display, '2.25');
      expect(c.expression, '1.50 + 0.75 =');
      c.setFormat(TimeFormat.hoursMinutes);
      expect(c.expression, '1:30 + 0:45 =');
    });

    test('switching converts the entry being typed', () {
      final c = TimeCalculator()
        ..digit('1')
        ..digit('3')
        ..digit('0');
      c.setFormat(TimeFormat.decimal);
      expect(c.display, '1.5');
      c.setFormat(TimeFormat.hoursMinutes);
      expect(c.display, '1:30');
      c.digit('0');
      expect(c.display, '13:00');
    });

    test('mixing formats within one calculation', () {
      final c = TimeCalculator()
        ..digit('1')
        ..digit('3')
        ..digit('0')
        ..operator(Op.add)
        ..setFormat(TimeFormat.decimal)
        ..digit('2')
        ..decimalPoint()
        ..digit('5')
        ..equals();
      expect(c.display, '4.00');
    });

    test('decimal results are not rounded to whole minutes', () {
      final c = TimeCalculator()..setFormat(TimeFormat.decimal);
      c
        ..digit('1')
        ..operator(Op.divide)
        ..digit('8')
        ..equals();
      expect(c.display, '0.13'); // 0.125 h = 7.5 min
    });
  });

  group('history', () {
    TimeCalculator calc() => TimeCalculator()
      ..digit('130')
      ..operator(Op.add)
      ..digit('45')
      ..equals();

    test('isFinished is true only after equals', () {
      final c = TimeCalculator()..digit('1');
      expect(c.isFinished, isFalse);
      c
        ..operator(Op.add)
        ..digit('1')
        ..equals();
      expect(c.isFinished, isTrue);
      c.operator(Op.add);
      expect(c.isFinished, isFalse);
    });

    test('equals adds an entry, clear keeps it', () {
      final c = calc()..clear();
      expect(c.history, hasLength(1));
      expect(
        c.history.single.expression(TimeFormat.hoursMinutes),
        '1:30 + 0:45 =',
      );
      expect(c.history.single.result, 135);
      c.clearHistory();
      expect(c.history, isEmpty);
    });

    test('recall uses the result as an operand', () {
      final c = calc()
        ..digit('100')
        ..operator(Op.add)
        ..recall(calc().history.single)
        ..equals();
      expect(c.display, '3:15');
      expect(c.expression, '1:00 + 2:15 =');
    });

    test('recall keeps full precision', () {
      final c = TimeCalculator()
        ..digit('100')
        ..operator(Op.divide)
        ..digit('8')
        ..equals();
      final eighth = c.history.single;
      c
        ..recall(eighth)
        ..operator(Op.multiply)
        ..digit('8')
        ..equals();
      expect(c.display, '1:00');
    });

    test('typing after recall replaces it', () {
      final c = TimeCalculator()..recall(calc().history.single);
      expect(c.display, '2:15');
      c.digit('5');
      expect(c.display, '0:05');
      c.recall(calc().history.single);
      c.backspace();
      expect(c.display, '0:00');
    });

    test('no recall as a × operand', () {
      final c = TimeCalculator()
        ..digit('100')
        ..operator(Op.multiply);
      expect(c.canRecall, isFalse);
      c.recall(calc().history.single);
      expect(c.display, '1:00');
    });
  });

  group('plain mode', () {
    TimeCalculator plain(List<Object> keys) {
      final c = TimeCalculator(mode: CalculatorMode.plain);
      for (final k in keys) {
        switch (k) {
          case Op op:
            c.operator(op);
          case '.':
            c.separator();
          case '=':
            c.equals();
          case '<':
            c.backspace();
          case String d:
            c.digit(d);
        }
      }
      return c;
    }

    test('ordinary number entry and arithmetic', () {
      expect(plain(['1', '2', '3']).display, '123');
      expect(plain(['1', '.', '5']).display, '1.5');
      expect(plain(['1', '2', '<']).display, '1');
      expect(plain(['12', Op.add, '30', '=']).display, '42');
      expect(plain(['7', Op.subtract, '10', '=']).display, '-3');
      expect(plain(['2', '.', '5', Op.multiply, '4', '=']).display, '10');
      expect(plain(['1', Op.divide, '3', '=']).display, '0.333333333333');
      expect(plain(['1', Op.divide, '0', '=']).display, 'Error');
    });

    test('hides floating point noise', () {
      final c = plain(['0', '.', '1', Op.add, '0', '.', '2', '=']);
      expect(c.display, '0.3');
      expect(c.expression, '0.1 + 0.2 =');
    });

    test('separator is always a decimal point', () {
      final c = TimeCalculator(mode: CalculatorMode.plain);
      expect(c.separatorLabel, '.');
      expect(c.displayedMinutes, isNull);
      c.setFormat(TimeFormat.decimal); // ignored
      expect(c.format, TimeFormat.hoursMinutes);
    });

    test('history and recall', () {
      final c = plain(['6', Op.multiply, '7', '=']);
      final entry = c.history.single;
      expect(entry.expression(c.format), '6 × 7 =');
      expect(entry.resultText(c.format), '42');
      c
        ..digit('2')
        ..operator(Op.multiply)
        ..recall(entry)
        ..equals();
      expect(c.display, '84');
    });
  });

  group('seconds', () {
    TimeCalculator hms(String keys) {
      final c = TimeCalculator()..setFormat(TimeFormat.hoursMinutesSeconds);
      for (final k in keys.split(' ')) {
        switch (k) {
          case '':
            break;
          case '+':
            c.operator(Op.add);
          case '-':
            c.operator(Op.subtract);
          case '*':
            c.operator(Op.multiply);
          case '/':
            c.operator(Op.divide);
          case '=':
            c.equals();
          case ':':
            c.separator();
          case '<':
            c.backspace();
          default:
            c.digit(k);
        }
      }
      return c;
    }

    test('digits shift left through seconds', () {
      expect(hms('').display, '0:00:00');
      expect(hms('3').display, '0:00:03');
      expect(hms('3 0').display, '0:00:30');
      expect(hms('3 0 0').display, '0:03:00');
      expect(hms('3 0 0 0 0').display, '3:00:00');
      expect(hms('1 3 0 1 5').display, '1:30:15');
      expect(hms('1 3 0 1 5 <').display, '0:13:01');
    });

    test('colons fill hours, then minutes, then seconds', () {
      expect(hms('1 :').display, '1:00:00');
      expect(hms('1 : 3 0').display, '1:30:00');
      expect(hms('1 : 3 0 : 1 5').display, '1:30:15');
      expect(hms('1 : 3 0 : 1 5 9').display, '1:30:159'); // keeps going
      expect(hms('1 : : 5').display, '1:00:05');
      expect(hms('1 : 3 0 : : :').display, '1:30:00'); // extra colons ignored
    });

    test('backspace walks back through colon fields', () {
      expect(hms('1 : 3 0 : 1 5 <').display, '1:30:01');
      expect(hms('1 : 3 0 : 1 5 < <').display, '1:30:00');
      expect(hms('1 : 3 0 : < 7').display, '1:307:00'); // back in minutes
      expect(hms('1 : 3 0 : < < 7').display, '1:37:00'); // 03 ← 7
      expect(hms('1 : <').display, '0:00:01');
    });

    test('seconds after the second colon are not limited either', () {
      final c = hms(': : 9 0 0');
      expect(c.display, '0:00:900');
      c.equals();
      expect(c.display, '0:15:00');
      expect(hms(': : 9 0 0 0 =').display, '2:30:00');
      expect(hms(': 5 0 0 =').display, '8:20:00'); // still minutes
      expect(hms(': 5 0 0 : 3 0 =').display, '8:20:30');
    });

    test('arithmetic keeps seconds', () {
      expect(hms('4 5 3 0 + 2 0 4 5 =').display, '1:06:15');
      expect(hms('1 0 0 0 0 / 7 =').display, '0:08:34'); // 514.29 s
      expect(hms('2 3 0 0 - 1 0 0 0 0 =').display, '-0:37:00');
    });

    test('hiding seconds rounds the display but keeps the value', () {
      final c = hms('1 3 0 4 5 + 1 =');
      expect(c.display, '1:30:46');
      c.setFormat(TimeFormat.hoursMinutes);
      expect(c.display, '1:31');
      expect(c.history.single.expression(c.format), '1:31 + 0:00 =');
      c.setFormat(TimeFormat.hoursMinutesSeconds);
      expect(c.display, '1:30:46');
      expect(c.history.single.expression(c.format), '1:30:45 + 0:00:01 =');
    });

    test('converting the entry being typed', () {
      final c = hms('1 3 0 4 5');
      c.setFormat(TimeFormat.hoursMinutes);
      expect(c.display, '1:31');
      final d = hms('1 3 0 4 5')..setFormat(TimeFormat.decimal);
      expect(d.display, '1.5125'); // 4 places so seconds survive
      d.setFormat(TimeFormat.hoursMinutesSeconds);
      expect(d.display, '1:30:45');
      final e = TimeCalculator()
        ..digit('130')
        ..setFormat(TimeFormat.hoursMinutesSeconds);
      expect(e.display, '1:30:00');
    });

    test('decimal mode remembers the seconds setting', () {
      final c = hms('1 3 0 4 5 + 0 =')..setFormat(TimeFormat.decimal);
      expect(c.format, TimeFormat.decimal);
      expect(c.showsSeconds, isTrue);
      expect(c.alternateFormat, TimeFormat.hoursMinutesSeconds);
      expect(c.display, '1.51');
      c.setShowSeconds(false);
      expect(c.format, TimeFormat.decimal);
      expect(c.alternateFormat, TimeFormat.hoursMinutes);
      c.setShowSeconds(true);
      c.setFormat(TimeFormat.hoursMinutes);
      expect(c.showsSeconds, isFalse);
      expect(TimeCalculator().alternateFormat, TimeFormat.decimal);
    });

    test('formatSeconds', () {
      expect(formatSeconds(90.75), '1:30:45');
      expect(formatSeconds(-0.5), '-0:00:30');
      expect(formatSeconds(59.999), '1:00:00');
    });
  });

  group('enterValue', () {
    test('a plain calculator continues from the value', () {
      final c = TimeCalculator(mode: CalculatorMode.plain)
        ..enterValue(500 / 60);
      expect(c.display, '8.33333333333');
      c
        ..operator(Op.multiply)
        ..digit('25')
        ..equals();
      expect(c.display, '208.333333333');
    });

    test('becomes the next operand mid-calculation, or starts fresh', () {
      final c = TimeCalculator(mode: CalculatorMode.plain)
        ..digit('100')
        ..operator(Op.add)
        ..enterValue(2.5)
        ..equals();
      expect(c.display, '102.5');
      c.enterValue(4); // after =, a new calculation
      expect(c.expression, '');
      expect(c.display, '4');
      final e = TimeCalculator(mode: CalculatorMode.plain)
        ..digit('1')
        ..operator(Op.divide)
        ..digit('0')
        ..equals()
        ..enterValue(3);
      expect(e.display, '3'); // clears the error
    });
  });

  group('days', () {
    TimeCalculator withDays() => TimeCalculator()..setShowDays(true);

    test('formatMinutes splits days clock style', () {
      expect(formatMinutes(1650, days: true), '1d 03:30');
      expect(formatMinutes(1440, days: true), '1d 00:00');
      expect(formatMinutes(90, days: true), '01:30');
      expect(formatMinutes(-180, days: true), '-1d 21:00');
      expect(formatMinutes(-1440, days: true), '-1d 00:00');
      expect(formatMinutes(-1500, days: true), '-2d 23:00');
      expect(formatMinutes(1650), '27:30');
      expect(formatSeconds(1650.25, days: true), '1d 03:30:15');
      expect(formatSeconds(-0.5, days: true), '-1d 23:59:30');
      expect(formatTime(1650, TimeFormat.decimal, days: true), '27.50');
    });

    test('time zone: 22:00 + 5:00 is 3:00 the next day', () {
      final c = withDays()
        ..digit('2200')
        ..operator(Op.add)
        ..digit('500')
        ..equals();
      expect(c.display, '1d 03:00');
      expect(c.expression, '22:00 + 05:00 =');
      expect(c.history.single.resultText(c.format, days: true), '1d 03:00');
      expect(c.history.single.resultText(c.format), '27:00');
    });

    test('negative results count back from the day before', () {
      final c = withDays()
        ..digit('200')
        ..operator(Op.subtract)
        ..digit('500')
        ..equals();
      expect(c.display, '-1d 21:00');
      c.setShowDays(false);
      expect(c.display, '-3:00');
    });

    test('typing pads hours but splits days only when used', () {
      expect((withDays()..digit('3')).display, '00:03');
      expect((withDays()..digit('300')).display, '03:00');
      final c = withDays()..digit('3000');
      expect(c.display, '30:00');
      c.operator(Op.add);
      expect(c.expression, '1d 06:00 +');
    });

    group('d key', () {
      test('replaces 00 only while typing a time with days on', () {
        expect(TimeCalculator().showsDayKey, isFalse);
        final c = withDays();
        expect(c.showsDayKey, isTrue);
        c
          ..digit('230')
          ..operator(Op.multiply);
        expect(c.showsDayKey, isFalse); // plain number after ×
        c.setFormat(TimeFormat.decimal);
        expect(c.showsDayKey, isFalse);
      });

      test('typed digits become days, then shift into hours', () {
        final c = withDays()
          ..digit('1')
          ..day();
        expect(c.display, '1d 00:00');
        expect(c.dayKeyEnabled, isFalse);
        c.digit('5');
        expect(c.display, '1d 00:05');
        c.digit('00');
        expect(c.display, '1d 05:00');
        expect(c.displayedMinutes, 29 * 60);
        c
          ..operator(Op.add)
          ..digit('2200')
          ..equals();
        expect(c.display, '2d 03:00');
        expect(c.expression, '1d 05:00 + 22:00 =');
      });

      test('colon works after d', () {
        final c = withDays()
          ..digit('2')
          ..day()
          ..digit('6')
          ..colon()
          ..digit('30');
        expect(c.display, '2d 06:30');
        expect(c.dayKeyEnabled, isFalse);
      });

      test('hours over 24 carry once used', () {
        final c = withDays()
          ..digit('1')
          ..day()
          ..digit('3000');
        expect(c.display, '1d 30:00');
        c.equals();
        expect(c.display, '2d 06:00');
      });

      test('backspace undoes d', () {
        final c = withDays()
          ..digit('12')
          ..day()
          ..digit('3');
        c.backspace();
        expect(c.display, '12d 00:00');
        c.backspace();
        expect(c.display, '00:12');
        expect(c.dayKeyEnabled, isTrue);
      });

      test('does nothing on an empty entry or too many digits', () {
        final c = withDays()..day();
        expect(c.display, '00:00');
        c
          ..digit('1234')
          ..day();
        expect(c.display, '12:34');
      });

      test('switching days off or to decimal folds days into hours', () {
        final c = withDays()
          ..digit('1')
          ..day()
          ..digit('500');
        c.setShowDays(false);
        expect(c.display, '29:00');
        final d = withDays()
          ..digit('1')
          ..day()
          ..digit('500')
          ..setFormat(TimeFormat.decimal);
        expect(d.display, '29');
      });

      test('turning days off and on again re-splits the entry', () {
        final c = withDays()
          ..digit('1')
          ..day()
          ..digit('25');
        expect(c.display, '1d 00:25');
        c.setShowDays(false);
        expect(c.display, '24:25');
        c.setShowDays(true);
        expect(c.display, '1d 00:25');
        c.digit('3'); // typing continues in the hours and minutes
        expect(c.display, '1d 02:53');
        expect(c.dayKeyEnabled, isFalse);
      });

      test('turning days on splits a long typed time', () {
        final c = TimeCalculator()..digit('3000');
        c.setShowDays(true);
        expect(c.display, '1d 06:00');
        final short = TimeCalculator()..digit('230');
        short.setShowDays(true);
        expect(short.display, '02:30');
        expect(short.dayKeyEnabled, isTrue);
      });

      test('seconds on and off keep typed days', () {
        final c = withDays()
          ..digit('1')
          ..day()
          ..digit('500');
        c.setShowSeconds(true);
        expect(c.display, '1d 05:00:00');
        c.digit('1');
        expect(c.display, '1d 50:00:01');
        c.equals();
        expect(c.display, '3d 02:00:01');
        final d = withDays()
          ..setShowSeconds(true)
          ..digit('1')
          ..day()
          ..digit('3015');
        expect(d.display, '1d 00:30:15');
        d.setShowSeconds(false);
        expect(d.display, '1d 00:30');
      });

      test('long minutes with days', () {
        final c = withDays()
          ..colon()
          ..digit('3000');
        expect(c.display, '00:3000');
        c.equals();
        expect(c.display, '2d 02:00');
        final d = withDays()
          ..digit('1')
          ..day()
          ..digit('5')
          ..colon()
          ..digit('90');
        expect(d.display, '1d 05:90');
        d.equals();
        expect(d.display, '1d 06:30');
      });

      test('doubleZeroOrDay picks the right key', () {
        final c = TimeCalculator()
          ..digit('3')
          ..doubleZeroOrDay();
        expect(c.display, '3:00');
        final d = withDays()
          ..digit('3')
          ..doubleZeroOrDay();
        expect(d.display, '3d 00:00');
      });
    });

    test('decimal ignores days; plain mode cannot enable them', () {
      final c = withDays()
        ..digit('3000')
        ..equals()
        ..setFormat(TimeFormat.decimal);
      expect(c.display, '30.00');
      expect(c.showsDays, isTrue); // remembered for switching back
      c.setFormat(TimeFormat.hoursMinutes);
      expect(c.display, '1d 06:00');
      final plain = TimeCalculator(mode: CalculatorMode.plain)
        ..setShowDays(true);
      expect(plain.showsDays, isFalse);
    });
  });

  group('preview', () {
    test('shows what = would give while the second operand is typed', () {
      final c = TimeCalculator(mode: CalculatorMode.plain)..digit('2');
      expect(c.preview, isNull);
      expect(c.hasEntry, isTrue);
      c.operator(Op.add);
      expect(c.hasEntry, isFalse);
      expect(c.preview, isNull);
      c
        ..digit('3')
        ..decimalPoint()
        ..digit('5');
      expect(c.preview, '5.5');
      c.operator(Op.multiply);
      c.digit('2');
      expect(c.preview, '11');
      c.equals();
      expect(c.preview, isNull);
    });

    test('follows time format and skips division by zero', () {
      final c = TimeCalculator()
        ..digit('130')
        ..operator(Op.add)
        ..digit('45');
      expect(c.preview, '2:15');
      c
        ..operator(Op.divide)
        ..digit('0');
      expect(c.preview, isNull);
      expect(c.hasError, isFalse);
    });

    test('uses a recalled value', () {
      final c = TimeCalculator(mode: CalculatorMode.plain)..enterValue(120.5);
      expect(c.hasEntry, isTrue);
      c
        ..operator(Op.subtract)
        ..enterValue(0.5);
      expect(c.preview, '120');
    });
  });
}
