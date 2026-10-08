import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ph.dart';

import 'logic.dart';
import 'screens.dart';
import 'store.dart';
import 'system.dart';
import 'update.dart';

// Nocturne tokens (bad-habits-tracking-app/project/_ds/.../styles.css)
const bg = Color(0xFF161826), surface = Color(0xFF232532), text = Color(0xFFE9E9ED);
const accent = Color(0xFF9184D9), divider = Color(0x29E9E9ED);
const n300 = Color(0xFFCFD3E5), n400 = Color(0xFFB2B6CA), n500 = Color(0xFF9397AB), n600 = Color(0xFF75798C);
const n700 = Color(0xFF595D6C), n800 = Color(0xFF3F424D), n900 = Color(0xFF292B31);
const a200 = Color(0xFFE7E5FE), a300 = Color(0xFFD2CEFD), a500 = Color(0xFF968AE0), a600 = Color(0xFF796CBF);
const a700 = Color(0xFF5D5294), a800 = Color(0xFF423A6A), a900 = Color(0xFF2B2741);
const section = Color(0xFF262A60), sectionGlow = Color(0xFF353B80), sectionGhost = Color(0xFF4C5397);
const fail = Color(0xFFEF9497); // oklch(0.76 0.11 18)
const tabular = [FontFeature.tabularFigures()];

TextStyle ts(double size, {FontWeight w = FontWeight.w400, Color? c, double? ls, double? h}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, letterSpacing: ls == null ? null : ls * size, height: h);
const w5 = FontWeight.w500;

final icons = <String, IconData>{
  'ph-cigarette': Ph.cigarette,
  'ph-device-mobile': Ph.deviceMobile,
  'ph-cookie': Ph.cookie,
  'ph-moon': Ph.moon,
  'ph-wine': Ph.wine,
  'ph-game-controller': Ph.gameController,
  'ph-coffee': Ph.coffee,
  'ph-hamburger': Ph.hamburger,
  'ph-shopping-cart': Ph.shoppingCart,
  'ph-television': Ph.television,
  'ph-hand': Ph.hand,
  'ph-lightning': Ph.lightning,
};
IconData iconOf(String key) => icons[key] ?? Ph.hand;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    MaterialApp(
      title: 'MyTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: accent, surface: surface, onSurface: text, error: fail),
        fontFamily: GoogleFonts.inter().fontFamily,
        splashFactory: InkSparkle.splashFactory,
      ),
      navigatorKey: nav,
      scaffoldMessengerKey: messenger,
      home: const Shell(),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  var tab = 0, splash = true;

  @override
  void initState() {
    super.initState();
    // Splash stays up for its full 1.8s and until the DB is loaded.
    Future.wait([store.init(), Future.delayed(const Duration(milliseconds: 1800))]).then((_) {
      setState(() => splash = false);
      initSystem(openUri).then((_) => store.sync());
      checkForUpdate().then((r) {
        if (r != null) {
          messenger.currentState?.showSnackBar(
            SnackBar(
              content: Text('MyTrack ${r.version} is available'),
              action: SnackBarAction(label: 'Update', onPressed: () => showUpdate(nav.currentState!.overlay!.context)),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const nav = [
      (Ph.listChecks, PhFill.listChecks, 'Habits'),
      (Ph.chartBar, PhFill.chartBar, 'Stats'),
      (Ph.gearSix, PhFill.gearSix, 'Settings'),
    ];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: splash
          ? const Splash()
          : Scaffold(
              body: SafeArea(
                bottom: false,
                child: ListenableBuilder(
                  listenable: store,
                  builder: (_, _) => [const Home(), const Stats(), const Settings()][tab],
                ),
              ),
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  color: bg,
                  border: Border(top: BorderSide(color: n900)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 62,
                    child: Row(
                      children: [
                        for (final (i, (off, on, label)) in nav.indexed)
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => tab = i),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(tab == i ? on : off, size: 22, color: tab == i ? a300 : n500),
                                  const SizedBox(height: 3),
                                  Text(
                                    label,
                                    style: ts(11, w: w5, c: tab == i ? a300 : n500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

final nav = GlobalKey<NavigatorState>();
final messenger = GlobalKey<ScaffoldMessengerState>();

/// Deep links from notifications and widgets: mytrack://open?id=N, mytrack://log?id=N
void openUri(Uri u) {
  final id = int.tryParse(u.queryParameters['id'] ?? ''), ctx = nav.currentState?.overlay?.context;
  if (id == null || ctx == null || store.view(id) == null) return;
  nav.currentState!.popUntil((r) => r.isFirst);
  openDetail(ctx, id);
  if (u.host == 'log') logSlip(ctx, id);
}

// ——— shared pieces ———

/// The launcher mark: three bars, each taller than the last. [s] scales from the 112px splash size.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.s = 1});
  final double s;
  @override
  Widget build(BuildContext context) => Container(
    width: 112 * s,
    height: 112 * s,
    padding: EdgeInsets.fromLTRB(26 * s, 0, 26 * s, 27 * s),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32 * s),
      gradient: const LinearGradient(
        begin: Alignment(-0.5, -0.87),
        end: Alignment(0.5, 0.87),
        colors: [sectionGhost, section],
        stops: [0, 0.7],
      ),
      border: Border.all(color: a700),
      boxShadow: [BoxShadow(color: sectionGlow, blurRadius: 60 * s)],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (h, c) in [(21.0, a700), (37.0, a500), (58.0, a200)])
          Container(
            width: 15 * s,
            height: h * s,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(5 * s),
              boxShadow: c == a200 ? [BoxShadow(color: a500, blurRadius: 14 * s)] : null,
            ),
          ),
      ],
    ),
  );
}

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext context) => SizedBox.expand(
    // AnimatedSwitcher would otherwise shrink it to its content
    child: Material(
      color: bg,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 0.9,
            colors: [section, Color(0x00262A60)],
            stops: [0, 0.7],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppMark(),
                const SizedBox(height: 22),
                Text(
                  'MyTrack',
                  style: ts(30, w: w5, ls: -0.025, c: text),
                ),
                const SizedBox(height: 4),
                Text('Make every gap longer.', style: ts(13, c: n400)),
              ],
            ),
            Positioned(
              bottom: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: SizedBox(
                  width: 120,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1800),
                    builder: (_, v, _) =>
                        LinearProgressIndicator(value: v, minHeight: 2, color: accent, backgroundColor: n800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Surface card with the 1px edge Nocturne uses instead of shadows.
class Card2 extends StatelessWidget {
  const Card2({
    super.key,
    required this.child,
    this.pad = const EdgeInsets.all(14),
    this.onTap,
    this.r = 14,
    this.border = true,
  });
  final Widget child;
  final EdgeInsets pad;
  final VoidCallback? onTap;
  final double r;
  final bool border;
  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
      side: border ? const BorderSide(color: n800) : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: pad, child: child),
    ),
  );
}

class Bar extends StatelessWidget {
  const Bar(this.pct, {super.key, this.h = 4});
  final double pct, h;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(h / 2),
    child: LinearProgressIndicator(value: pct, minHeight: h, color: accent, backgroundColor: n800),
  );
}

/// A rule that fades out over 48px at each end.
class FadeRule extends StatelessWidget {
  const FadeRule({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final f = min(0.5, 48 / c.maxWidth);
      return Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: const [Colors.transparent, divider, divider, Colors.transparent],
            stops: [0, f, 1 - f, 1],
          ),
        ),
      );
    },
  );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.on, required this.onTap, this.h = 36, this.px = 14, this.fs = 13});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final double h, px, fs;
  @override
  Widget build(BuildContext context) => Material(
    color: on ? a900 : Colors.transparent,
    shape: StadiumBorder(side: BorderSide(color: on ? accent : n700)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: px),
        alignment: Alignment.center,
        child: Text(label, style: ts(fs, c: on ? a200 : n300)),
      ),
    ),
  );
}

/// Nocturne primary: an accent outline, never a fill.
class Primary extends StatelessWidget {
  const Primary(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.h = 48,
    this.fs = 15,
    this.color = accent,
    this.border,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double h, fs;
  final Color color;
  final Color? border;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(double.infinity, h),
        foregroundColor: color,
        disabledForegroundColor: color,
        side: BorderSide(color: border ?? color),
        shape: const StadiumBorder(),
        textStyle: ts(fs, w: w5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: fs + 3), const SizedBox(width: 6)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}

Widget pageTitle(String kicker, String title, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker, style: ts(12, c: n500)),
            Text(title, style: ts(28, w: w5, ls: -0.02, h: 1.15)),
          ],
        ),
      ),
      ?trailing,
    ],
  ),
);

Widget page(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), children: children);

Color statusColor(HabitView v) => v.target == null ? n400 : (v.beat ? a300 : fail);

// ——— tabs ———

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) {
    final views = store.views;
    return page([
      pageTitle(
        todayLabel(DateTime.now()),
        'Habits',
        trailing: SizedBox.square(
          dimension: 40,
          child: IconButton.outlined(
            onPressed: () => openAdd(context),
            style: IconButton.styleFrom(
              side: const BorderSide(color: divider),
              foregroundColor: text,
            ),
            icon: const Icon(Ph.plus, size: 18),
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: n800),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a900, surface]),
        ),
        child: Row(
          children: [
            Text(
              '${views.where((v) => v.beat).length}/${views.length}',
              style: ts(26, w: w5, c: a300).copyWith(fontFeatures: tabular),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'have already beaten their ${store.prefs['beatBest']! ? 'best' : 'last interval'}. '
                'The rest fail if you slip now.',
                style: ts(12, c: n300, h: 1.35),
              ),
            ),
          ],
        ),
      ),
      if (views.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text('Nothing tracked yet. Tap + to start a clock.', style: ts(13, c: n500)),
        ),
      for (final v in views)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card2(
            pad: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            onTap: () => openDetail(context, v.habit.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: a900, borderRadius: BorderRadius.circular(10)),
                      child: Icon(iconOf(v.habit.icon), size: 17, color: a300),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(v.habit.name, style: ts(14, w: w5)),
                    ),
                    const Icon(PhFill.flame, size: 13, color: accent),
                    const SizedBox(width: 3),
                    Text('${v.streak}', style: ts(13, c: n400)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  fmt(v.el),
                  style: ts(26, w: w5, ls: -0.02).copyWith(fontFeatures: tabular),
                ),
                const SizedBox(height: 8),
                Bar(v.pct),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(v.statusText, style: ts(11.5, c: statusColor(v))),
                    ),
                    Text(v.targetText, style: ts(11.5, c: n500)),
                  ],
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}

class Stats extends StatelessWidget {
  const Stats({super.key});
  @override
  Widget build(BuildContext context) {
    final views = store.views, now = store.now;
    final pass = views.fold(0, (n, v) => n + v.outcomes.where((o) => o).length);
    final fails = views.fold(0, (n, v) => n + v.outcomes.where((o) => !o).length);
    final weekSlips = store.habits.fold(0, (n, h) => n + h.slips.where((t) => t > now - 7 * 24 * hour).length);
    final rate = pass / max(1, pass + fails);
    Widget stat(String n, Color c, String label) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: n,
            style: ts(17, w: w5, c: c),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
      style: ts(12, c: n400),
    );

    return page([
      pageTitle('All habits', 'Stats'),
      Card2(
        pad: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: rate,
                      strokeWidth: 7,
                      color: accent,
                      backgroundColor: fail.withValues(alpha: .55),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(rate * 100).round()}%', style: ts(22, w: w5)),
                      Text('pass rate', style: ts(10, c: n500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  stat(
                    '$pass',
                    text,
                    store.prefs['beatBest']! ? 'intervals that beat your best' : 'intervals longer than the one before',
                  ),
                  stat('$fails', fail, 'fails'),
                  stat('$weekSlips', text, 'slips in the last 7 days'),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text('Last 8 intervals per habit', style: ts(12, w: w5)),
      ),
      for (final v in views) ...[_StatCard(v), const SizedBox(height: 8)],
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.v);
  final HabitView v;
  @override
  Widget build(BuildContext context) {
    final o = v.outcomes, last8 = o.sublist(max(0, o.length - 8));
    final g = v.ints.length > 1 ? ((v.ints.last / v.ints.first - 1) * 100).round() : 0;
    final avg = v.ints.isEmpty ? '—' : fmt(v.ints.reduce((a, b) => a + b) ~/ v.ints.length);
    return Card2(
      pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => openDetail(context, v.habit.id),
      child: Column(
        children: [
          Row(
            children: [
              Icon(iconOf(v.habit.icon), size: 14, color: a300),
              const SizedBox(width: 8),
              Expanded(
                child: Text(v.habit.name, style: ts(13, w: w5)),
              ),
              Text('${g >= 0 ? '+' : ''}$g% since start', style: ts(12, c: g >= 0 ? a300 : fail)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
            child: Row(
              spacing: 6,
              children: [
                for (var i = 0; i < 8; i++)
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: switch (i - (8 - last8.length)) {
                          < 0 => n800,
                          final j => last8[j] ? accent : fail.withValues(alpha: .6),
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Best ${v.bestInterval == null ? '—' : fmt(v.bestInterval!)}', style: ts(11.5, c: n500)),
              Text('Avg $avg', style: ts(11.5, c: n500)),
            ],
          ),
        ],
      ),
    );
  }
}

class Settings extends StatelessWidget {
  const Settings({super.key});
  @override
  Widget build(BuildContext context) {
    const toggles = [
      ('beatBest', 'Beat my best time', 'Off: only the interval right before counts'),
      ('passAlert', 'Notify when I beat my bar', 'The moment the clock passes it'),
      ('nearAlert', 'Warn before the danger zone', "30 min before you'd beat it — hold on"),
      ('summary', 'Daily summary', '9:00 pass / fail report'),
      ('seconds', 'Show seconds on widgets', 'Under one hour only'),
      ('haptics', 'Haptic on log', 'Heavy buzz on a fail'),
    ];
    return page([
      pageTitle('Preferences', 'Settings'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: a900, borderRadius: BorderRadius.circular(14)),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Rule:',
                style: ts(12, w: w5),
              ),
              TextSpan(
                text:
                    ' an interval passes only if it is longer than '
                    '${store.prefs['beatBest']! ? 'your best interval so far' : 'the previous interval'}. '
                    'Equal or shorter is a fail and resets the streak.',
              ),
            ],
          ),
          style: ts(12, c: a200, h: 1.5),
        ),
      ),
      Card2(
        pad: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            for (final (key, label, sub) in toggles)
              InkWell(
                onTap: () => store.setPref(key, !store.prefs[key]!),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: ts(13.5, w: w5)),
                                const SizedBox(height: 1),
                                Text(sub, style: ts(11.5, c: n500)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _Toggle(store.prefs[key]!),
                        ],
                      ),
                    ),
                    const FadeRule(),
                  ],
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text('About', style: ts(12, w: w5)),
      ),
      Card2(
        pad: const EdgeInsets.symmetric(horizontal: 14),
        child: ListenableBuilder(
          listenable: Listenable.merge([appVersion, updateStatus]),
          builder: (context, _) => Column(
            children: [
              _InfoRow('Version', appVersion.value.isEmpty ? '—' : appVersion.value),
              const FadeRule(),
              InkWell(
                onTap: () => latest != null ? showUpdate(context) : checkForUpdate(),
                child: _InfoRow('Check for updates', updateStatus.value, icon: Ph.arrowsClockwise),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Primary(
        'Export history (CSV)',
        icon: Ph.export,
        h: 44,
        fs: 14,
        color: text,
        border: divider,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: await store.exportCsv()));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History copied as CSV')));
          }
        },
      ),
      const SizedBox(height: 8),
      Primary(
        'Reset all intervals',
        h: 44,
        fs: 14,
        color: const Color(0xFFF2A2A3),
        border: fail.withValues(alpha: .5),
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: surface,
              title: const Text('Reset all intervals?'),
              content: const Text('Every logged slip is deleted and all clocks restart now. This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: TextButton.styleFrom(foregroundColor: fail),
                  child: const Text('Reset'),
                ),
              ],
            ),
          );
          if (ok == true) await store.resetAll();
        },
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.sub, {this.icon});
  final String label, sub;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ts(13.5, w: w5)),
              const SizedBox(height: 1),
              Text(sub, style: ts(11.5, c: latest != null && icon != null ? a300 : n500)),
            ],
          ),
        ),
        if (icon != null) Icon(icon, size: 18, color: n500),
      ],
    ),
  );
}

Future<void> showUpdate(BuildContext context) => showDialog(
  context: context,
  builder: (c) => AlertDialog(
    backgroundColor: surface,
    title: Text('MyTrack ${latest!.version}'),
    content: SingleChildScrollView(
      child: Text(
        latest!.notes.isEmpty ? 'A new version is available.' : latest!.notes,
        style: ts(13, c: n300, h: 1.5),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')),
      TextButton(
        onPressed: () {
          Navigator.pop(c);
          downloadUpdate();
        },
        child: const Text('Download'),
      ),
    ],
  ),
);

class _Toggle extends StatelessWidget {
  const _Toggle(this.on);
  final bool on;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 42,
    height: 24,
    padding: const EdgeInsets.all(3),
    alignment: on ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: on ? a800 : n900,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: on ? accent : n700),
    ),
    child: Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: on ? a300 : n600, shape: BoxShape.circle),
    ),
  );
}
