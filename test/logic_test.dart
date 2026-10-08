import 'package:flutter_test/flutter_test.dart';
import 'package:mytrack/logic.dart';

void main() {
  test('fmt', () {
    expect(fmt(65 * 1000), '1m 05s');
    expect(fmt(2 * hour + 5 * minute), '2h 05m');
    expect(fmt(50 * hour), '2d 2h');
    expect(fmt(-5), '0m 00s');
    expect(clock(3 * hour + 7 * minute + 9000), '03:07:09');
  });

  test('interval rule: beat the last interval', () {
    // start, then intervals of 1h, 2h, 3h; 4h since the last slip
    final h = Habit(1, 'x', 'ph-hand', [0, hour, 3 * hour, 6 * hour]);
    final beating = HabitView(h, 10 * hour, best: false);
    expect(beating.ints, [hour, 2 * hour, 3 * hour]);
    expect(beating.target, 3 * hour);
    expect(beating.beat, isTrue);
    expect(beating.streak, 3); // two past passes + the one in progress
    expect(beating.outcomes, [true, true]);

    final equal = HabitView(h, 9 * hour, best: false); // equal is a fail
    expect(equal.beat, isFalse);
    expect(equal.passing, isFalse);
    expect(equal.streak, 2);
    expect(equal.pct, 1);

    final first = HabitView(Habit(2, 'y', 'ph-hand', [0]), hour);
    expect(first.target, isNull);
    expect(first.passing, isTrue);
    expect(first.streak, 0);
  });

  test('daily summary', () {
    // intervals 1h, 2h (pass), 1h (fail); 3h since the last slip
    final h = Habit(1, 'x', 'ph-hand', [0, hour, 3 * hour, 4 * hour]);
    expect(summaryAt([h], 7 * hour, best: false), (1, 1, 1)); // beating 1h bar; both outcomes ended within 24h
    expect(summaryAt([h], 27 * hour + 1, best: false), (1, 0, 1)); // the pass ended at 3h, now outside the window
  });

  test('interval rule: beat the best interval', () {
    // intervals 2h, 1h, 1.5h; 1.8h since the last slip
    final h = Habit(1, 'x', 'ph-hand', [0, 2 * hour, 3 * hour, 9 * hour ~/ 2]);
    final now = 9 * hour ~/ 2 + 18 * hour ~/ 10;

    final best = HabitView(h, now);
    expect(best.bars, [null, 2 * hour, 2 * hour]);
    expect(best.outcomes, [false, false]); // 1.5h beat the last (1h) but not the best (2h)
    expect(best.target, 2 * hour);
    expect(best.beat, isFalse);
    expect(best.streak, 0);

    final last = HabitView(h, now, best: false);
    expect(last.bars, [null, 2 * hour, hour]);
    expect(last.outcomes, [false, true]);
    expect(last.target, 3 * hour ~/ 2);
    expect(last.beat, isTrue);
    expect(last.streak, 2);
  });
}
