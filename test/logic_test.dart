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

  test('interval rule', () {
    // start, then intervals of 1h, 2h, 3h; 4h since the last slip
    final h = Habit(1, 'x', 'ph-hand', [0, hour, 3 * hour, 6 * hour]);
    final beating = HabitView(h, 10 * hour);
    expect(beating.ints, [hour, 2 * hour, 3 * hour]);
    expect(beating.target, 3 * hour);
    expect(beating.beat, isTrue);
    expect(beating.streak, 3); // two past passes + the one in progress
    expect(beating.outcomes, [true, true]);

    final equal = HabitView(h, 9 * hour); // equal is a fail
    expect(equal.beat, isFalse);
    expect(equal.passing, isFalse);
    expect(equal.streak, 2);
    expect(equal.pct, 1);

    final first = HabitView(Habit(2, 'y', 'ph-hand', [0]), hour);
    expect(first.target, isNull);
    expect(first.passing, isTrue);
    expect(first.streak, 0);
  });
}
