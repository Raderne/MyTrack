// Pure interval rules — no Flutter imports, so it's testable with plain `dart test`.
import 'dart:math';

const hour = 3600000, minute = 60000;

String _p(int n) => n.toString().padLeft(2, '0');

String fmt(int ms) {
  ms = max(0, ms);
  final m = ms ~/ minute, h = m ~/ 60, d = h ~/ 24;
  if (d > 0) return '${d}d ${h % 24}h';
  if (h > 0) return '${h}h ${_p(m % 60)}m';
  return '${m}m ${_p(ms ~/ 1000 % 60)}s';
}

String clock(int ms) {
  final s = max(0, ms) ~/ 1000;
  return '${_p(s ~/ 3600)}:${_p(s ~/ 60 % 60)}:${_p(s % 60)}';
}

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Wednesday, Oct 8"
String todayLabel(DateTime d) => '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// "Wed 3:42 PM"
String shortStamp(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_days[d.weekday - 1].substring(0, 3)} $h12:${_p(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

class Habit {
  Habit(this.id, this.name, this.icon, this.slips);
  final int id;
  final String name, icon;

  /// Epoch ms. The first entry is when the clock started, every later one is a slip.
  final List<int> slips;
}

/// A habit seen at a moment in time.
class HabitView {
  HabitView(this.habit, int now)
    : ints = [for (var i = 1; i < habit.slips.length; i++) habit.slips[i] - habit.slips[i - 1]],
      el = now - habit.slips.last;

  final Habit habit;
  final List<int> ints;
  final int el;

  int? get target => ints.isEmpty ? null : ints.last;
  bool get beat => target != null && el > target!;

  /// Logging a slip right now would pass.
  bool get passing => target == null || beat;

  int get streak {
    var n = 0;
    for (var i = ints.length - 1; i > 0 && ints[i] > ints[i - 1]; i--) {
      n++;
    }
    return n + (beat ? 1 : 0);
  }

  double get pct => target == null || target == 0 ? 1 : min(1, el / target!);

  /// For each interval after the first: was it longer than the one before?
  List<bool> get outcomes => [for (var i = 1; i < ints.length; i++) ints[i] > ints[i - 1]];

  int? get best => ints.isEmpty ? null : ints.reduce(max);

  String get statusText => target == null
      ? 'First interval — this sets the bar'
      : beat
      ? 'Beaten by ${fmt(el - target!)} — keep going'
      : "${fmt(target! - el)} left or it's a fail";

  String get targetText => target == null ? '—' : 'Last ${fmt(target!)}';
}
