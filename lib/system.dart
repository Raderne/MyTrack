// Everything that leaves the app: scheduled notifications and home-screen widget data.
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/timezone.dart' as tz;

import 'logic.dart';
import 'main.dart' show iconOf;

final _notes = FlutterLocalNotificationsPlugin();
AndroidFlutterLocalNotificationsPlugin? get _android =>
    _notes.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'intervals',
    'Intervals',
    channelDescription: 'Beaten intervals, danger-zone warnings and the daily summary',
    color: Color(0xFF9184D9),
  ),
);

var _ready = false;

const _widgets = ['RingWidget', 'StreakWidget', 'QuickWidget', 'ListWidget'];

/// [onOpen] gets `mytrack://open?id=N` or `mytrack://log?id=N` from a tapped notification or widget.
Future<void> initSystem(void Function(Uri) onOpen) async {
  void open(String? s) {
    if (s != null) onOpen(Uri.parse(s));
  }

  await _notes.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
    onDidReceiveNotificationResponse: (r) => open(r.payload),
  );
  final launch = await _notes.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) open(launch!.notificationResponse?.payload);

  HomeWidget.widgetClicked.listen((u) => open(u?.toString()));
  open((await HomeWidget.initiallyLaunchedFromHomeWidget())?.toString());

  await _android?.requestNotificationsPermission();
  _ready = true;
}

/// Rebuilds every scheduled notification and pushes fresh state to the widgets.
/// Called after any change, so nothing here has to be incremental.
Future<void> syncSystem(List<Habit> habits, Map<String, bool> prefs) async {
  if (!_ready) return; // initSystem's caller syncs once it's done
  final now = DateTime.now().millisecondsSinceEpoch;
  final best = prefs['beatBest']!;
  final views = [for (final h in habits) HabitView(h, now, best: best)];

  await HomeWidget.saveWidgetData(
    'state',
    jsonEncode({
      'seconds': prefs['seconds'],
      'habits': [
        for (final v in views)
          {
            'id': v.habit.id,
            'name': v.habit.name,
            'icon': iconOf(v.habit.icon).codePoint,
            'last': v.habit.slips.last,
            'target': v.target,
            'base': v.streak - (v.beat ? 1 : 0),
            'label': best ? 'Best' : 'Last',
          },
      ],
    }),
  );
  for (final w in _widgets) {
    await HomeWidget.updateWidget(qualifiedAndroidName: 'com.mytrack.mytrack.$w');
  }

  await _notes.cancelAll();
  final exact = await _android?.canScheduleExactNotifications() ?? false;
  Future<void> at(int id, int when, String title, String body, int habitId) => _notes.zonedSchedule(
    id: id,
    scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, when),
    notificationDetails: _details,
    androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    title: title,
    body: body,
    payload: habitId < 0 ? null : 'mytrack://open?id=$habitId',
  );

  for (final v in views) {
    final t = v.target, last = v.habit.slips.last, name = v.habit.name;
    if (t == null) continue;
    if (prefs['passAlert']! && last + t + 1000 > now) {
      await at(
        v.habit.id * 4 + 1,
        last + t + 1000,
        '$name: interval beaten',
        'You passed ${fmt(t)}. Every minute from here raises the next bar.',
        v.habit.id,
      );
    }
    if (prefs['nearAlert']! && last + t - 30 * minute > now) {
      await at(
        v.habit.id * 4 + 2,
        last + t - 30 * minute,
        '$name: 30 min to go',
        'Hold on — 30 more minutes beats your ${v.barName} (${fmt(t)}).',
        v.habit.id,
      );
    }
  }

  if (prefs['summary']! && habits.isNotEmpty) {
    // ponytail: a week of precomputed summaries; fine because any slip reschedules them all.
    final today = DateTime.now();
    for (var d = 0; d < 8; d++) {
      final when = DateTime(today.year, today.month, today.day + d, 9).millisecondsSinceEpoch;
      if (when <= now) continue;
      final (beat, pass, fail) = summaryAt(habits, when, best: best);
      await at(
        1000000 + d,
        when,
        'Daily summary',
        '$beat/${habits.length} beating their ${best ? 'best' : 'last interval'}. Last 24h: $pass passed, $fail failed.',
        -1,
      );
    }
  }
}
