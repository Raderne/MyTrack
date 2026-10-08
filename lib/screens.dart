import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ph.dart';

import 'logic.dart';
import 'main.dart';
import 'store.dart';

void openDetail(BuildContext context, int id) => Navigator.push(context, MaterialPageRoute(builder: (_) => Detail(id)));

void openAdd(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHabit()));

Widget topBar(BuildContext context, IconData icon, String title, [Widget? trailing]) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  child: Row(
    children: [
      IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(icon, size: 18, color: accent),
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: ts(15, w: w5)),
      ),
      ?trailing,
    ],
  ),
);

class Detail extends StatelessWidget {
  const Detail(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final v = store.view(id);
          if (v == null) return const SizedBox();
          final target = v.target;
          Widget tile(String label, String value) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: ts(11, c: n500)),
                  const SizedBox(height: 2),
                  Text(value, style: ts(15, w: w5)),
                ],
              ),
            ),
          );
          return Column(
            children: [
              topBar(
                context,
                Ph.caretLeft,
                v.habit.name,
                Row(
                  children: [
                    const Icon(PhFill.flame, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text('${v.streak} in a row', style: ts(13, c: n300)),
                    IconButton(
                      tooltip: 'Delete habit',
                      onPressed: () => deleteHabit(context, v.habit),
                      icon: const Icon(Ph.trash, size: 18, color: n500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Text('Since last slip', style: ts(12, c: n500)),
                    const SizedBox(height: 2),
                    Text(
                      clock(v.el),
                      style: ts(46, w: w5, ls: -0.03, h: 1.1).copyWith(fontFeatures: tabular),
                    ),
                    const SizedBox(height: 6),
                    Text(v.statusText, style: ts(13, c: statusColor(v))),
                    const SizedBox(height: 14),
                    Bar(v.pct, h: 6),
                    const SizedBox(height: 18),
                    Row(
                      spacing: 8,
                      children: [
                        tile('To beat', target == null ? '—' : fmt(target)),
                        v.best
                            ? tile('Last', v.ints.isEmpty ? '—' : fmt(v.ints.last))
                            : tile('Best', v.bestInterval == null ? '—' : fmt(v.bestInterval!)),
                        tile('Slips', '${v.habit.slips.length}'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Card2(
                      pad: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Intervals', style: ts(12, w: w5)),
                              Flexible(
                                child: Text(
                                  'dashed = current',
                                  textAlign: TextAlign.right,
                                  style: ts(12, c: n500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: 120, child: _Bars(v)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
                      child: Text('History', style: ts(12, w: w5)),
                    ),
                    for (final i in [for (var i = v.ints.length - 1; i >= max(0, v.ints.length - 8); i--) i])
                      _HistoryRow(v, i),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Primary('I did it — log slip', icon: Ph.handPalm, onTap: () => logSlip(context, id)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> deleteHabit(BuildContext context, Habit h) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: surface,
      title: Text('Delete ${h.name}?'),
      content: const Text('The habit and all its intervals are deleted. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          style: TextButton.styleFrom(foregroundColor: fail),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  Navigator.pop(context);
  await store.deleteHabit(h.id);
}

class _Bars extends StatelessWidget {
  const _Bars(this.v);
  final HabitView v;
  @override
  Widget build(BuildContext context) {
    final ints = v.ints, bars = v.bars, start = max(0, ints.length - 6), shown = ints.sublist(start);
    final top = [v.el, ...shown, 1].reduce(max);
    double h(int ms) => max(0.06, ms / top);
    return LayoutBuilder(
      builder: (_, c) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 7,
        children: [
          for (var i = start; i < ints.length; i++)
            Expanded(
              child: Container(
                height: c.maxHeight * h(ints[i]),
                decoration: BoxDecoration(
                  color: bars[i] == null || ints[i] > bars[i]! ? a600 : fail.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          Expanded(
            child: CustomPaint(
              painter: _Dashed(),
              child: SizedBox(height: c.maxHeight * h(v.el)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The in-progress bar: accent-900 fill with a dashed accent edge.
class _Dashed extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = a900);
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke;
    for (final m in (Path()..addRRect(rr.deflate(0.5))).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, d + 3), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => false;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(this.v, this.i);
  final HabitView v;
  final int i;
  @override
  Widget build(BuildContext context) {
    final len = v.ints[i], prev = v.bars[i], up = prev == null || len > prev; // prev: the bar it had to beat
    final color = prev == null ? n500 : (up ? a300 : fail);
    final icon = prev == null ? Ph.flag : (up ? Ph.trendUp : Ph.trendDown);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(fmt(len), style: ts(13, w: w5)),
              ),
              Text(prev == null ? 'first' : '${up ? '+' : '−'}${fmt((len - prev).abs())}', style: ts(12, c: color)),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: Text(
                  shortStamp(DateTime.fromMillisecondsSinceEpoch(v.habit.slips[i + 1])),
                  textAlign: TextAlign.right,
                  style: ts(12, c: n500),
                ),
              ),
            ],
          ),
        ),
        const FadeRule(),
      ],
    );
  }
}

// ——— log sheet + result ———

const _triggers = ['Stress', 'Boredom', 'Social', 'After a meal', 'Tired', 'Autopilot'];

Future<void> logSlip(BuildContext context, int id) async {
  final picked = <String>{};
  final note = TextEditingController();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: surface,
    barrierColor: Colors.black.withValues(alpha: .6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: n500),
    ),
    // Scrolls when the keyboard leaves too little room for the whole sheet.
    builder: (c) => SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.viewInsetsOf(c).bottom),
        child: ListenableBuilder(
          listenable: store,
          builder: (c, _) {
            final v = store.view(id)!, t = v.target;
            return StatefulBuilder(
              builder: (c, set) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: n700, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text('Log a slip · ${v.habit.name}', style: ts(12, c: n500)),
                  const SizedBox(height: 4),
                  Text('This interval: ${fmt(v.el)}', style: ts(22, w: w5)),
                  const SizedBox(height: 4),
                  Text(
                    t == null
                        ? 'First interval. This becomes the bar.'
                        : v.beat
                        ? 'Longer than your ${v.barName} (${fmt(t)}). This one passes.'
                        : 'Not longer than your ${v.barName} (${fmt(t)}). Logging now is a fail.',
                    style: ts(13, c: v.passing ? a300 : fail),
                  ),
                  const SizedBox(height: 18),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Trigger '),
                        TextSpan(
                          text: '· optional',
                          style: ts(12, c: n600),
                        ),
                      ],
                    ),
                    style: ts(12, c: n400),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _triggers)
                        Pill(
                          t,
                          h: 34,
                          px: 13,
                          fs: 12.5,
                          on: picked.contains(t),
                          onTap: () => set(() => picked.contains(t) ? picked.remove(t) : picked.add(t)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Input(note, 'Add a note', h: 42, fs: 13, fill: bg),
                  const SizedBox(height: 18),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            foregroundColor: accent,
                            textStyle: ts(14, w: w5),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Primary('Log slip now', h: 46, fs: 14, onTap: () => Navigator.pop(c, true)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final v = store.view(id)!; // snapshot before the slip changes it
  if (store.prefs['haptics']!) v.passing ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
  await store.logSlip(id, store.now, picked.toList(), note.text.trim());
  if (context.mounted) {
    Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => Result(v)));
  }
}

class Result extends StatelessWidget {
  const Result(this.v, {super.key});
  final HabitView v; // the habit as it was the moment the slip was logged

  @override
  Widget build(BuildContext context) {
    final ok = v.passing, t = v.target;
    final color = ok ? a300 : fail;
    final body = t == null
        ? 'Bar set at ${fmt(v.el)}. Next interval must beat it.'
        : ok
        ? 'You beat your ${v.barName} by ${fmt(v.el - t)}. ${fmt(v.el)} is the new bar. Streak: ${v.streak}.'
        : 'You lasted ${fmt(v.el)}. That is ${fmt(t - v.el)} short of your ${v.barName}. '
              'Your streak of ${v.streak} is gone. Next interval must beat ${fmt(v.best ? t : v.el)}.';
    Widget tile(String label, String value, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts(11, c: n500)),
            Text(
              value,
              style: ts(18, w: w5, c: c),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: ok
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF301718), bg],
                  stops: [0, .6],
                ),
        ),
        padding: const EdgeInsets.fromLTRB(28, 120, 28, 28),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                  boxShadow: [
                    BoxShadow(color: (ok ? accent : const Color(0xFFD06B70)).withValues(alpha: .45), blurRadius: 40),
                  ],
                  color: ok ? bg : const Color(0xFF301718),
                ),
                child: Icon(ok ? Ph.trendUp : Ph.x, size: 38, color: color),
              ),
              const SizedBox(height: 28),
              Text(ok ? 'Passed.' : 'Failed.', style: ts(34, w: w5, ls: -0.02, h: 1.15)),
              const SizedBox(height: 10),
              Text(body, style: ts(15, c: n300, h: 1.5)),
              const SizedBox(height: 28),
              Row(
                spacing: 8,
                children: [
                  tile('This interval', fmt(v.el), color),
                  tile(v.best ? 'Best' : 'Previous', t == null ? '—' : fmt(t), text),
                ],
              ),
              const Spacer(),
              Primary(ok ? 'Start next interval' : 'Accept and restart', onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}

// ——— add habit ———

const _ago = [('Just now', 0), ('1h ago', 1), ('3h ago', 3), ('Yesterday', 20)];

class AddHabit extends StatefulWidget {
  const AddHabit({super.key});
  @override
  State<AddHabit> createState() => _AddHabitState();
}

class _AddHabitState extends State<AddHabit> {
  final name = TextEditingController();
  var icon = 'ph-hand', ago = 0;

  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  Future<void> save() async {
    final id = await store.addHabit(name.text.trim(), icon, DateTime.now().millisecondsSinceEpoch - ago * hour);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Detail(id)));
  }

  @override
  Widget build(BuildContext context) {
    Widget label(String s, double top) => Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Text(s, style: ts(12, c: n400)),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            topBar(context, Ph.x, 'New habit'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('What do you want to do less?', style: ts(12, c: n400)),
                  ),
                  _Input(name, 'e.g. Nail biting', h: 46, fs: 15, fill: surface, autofocus: true),
                  label('Icon', 20),
                  GridView.count(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final MapEntry(:key, value: data) in icons.entries)
                        Material(
                          color: icon == key ? a900 : surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: icon == key ? accent : n800),
                          ),
                          child: InkWell(
                            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onTap: () => setState(() => icon = key),
                            child: Icon(data, size: 20, color: icon == key ? a200 : n400),
                          ),
                        ),
                    ],
                  ),
                  label('When did it last happen?', 20),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final (l, h) in _ago) Pill(l, on: ago == h, onTap: () => setState(() => ago = h))],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Each slip ends an interval. The next one must run longer than '
                      '${store.prefs['beatBest']! ? 'your best so far' : 'the one before'}. '
                      'Shorter or equal is a fail — no exceptions.',
                      style: ts(12, c: n400, h: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Primary('Start the clock', onTap: name.text.trim().isEmpty ? null : save),
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input(this.c, this.hint, {required this.h, required this.fs, required this.fill, this.autofocus = false});
  final TextEditingController c;
  final String hint;
  final double h, fs;
  final Color fill;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    final edge = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: n800),
    );
    return SizedBox(
      height: h,
      child: TextField(
        controller: c,
        autofocus: autofocus,
        textCapitalization: TextCapitalization.sentences,
        style: ts(fs, c: text),
        cursorColor: accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: ts(fs, c: n600),
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: edge,
          enabledBorder: edge,
          focusedBorder: edge.copyWith(borderSide: const BorderSide(color: accent)),
        ),
      ),
    );
  }
}
