import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'logic.dart';
import 'system.dart';

/// App state backed by SQLite. Ticks once a second so every clock on screen moves.
class Store extends ChangeNotifier {
  late Database _db;
  List<Habit> habits = [];
  int now = DateTime.now().millisecondsSinceEpoch;
  final prefs = <String, bool>{
    'beatBest': true,
    'passAlert': true,
    'nearAlert': true,
    'summary': false,
    'seconds': true,
    'haptics': true,
  };

  /// [path] and [tick] exist for tests: a throwaway database, and no 1-second timer.
  Future<void> init({String? path, bool tick = true}) async {
    _db = await openDatabase(
      path ?? p.join(await getDatabasesPath(), 'mytrack.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE habits(id INTEGER PRIMARY KEY, name TEXT NOT NULL, icon TEXT NOT NULL)');
        await db.execute(
          'CREATE TABLE slips(id INTEGER PRIMARY KEY, '
          'habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE, '
          "at INTEGER NOT NULL, triggers TEXT NOT NULL DEFAULT '', note TEXT NOT NULL DEFAULT '')",
        );
        await db.execute('CREATE INDEX slips_habit_at ON slips(habit_id, at)');
        await db.execute('CREATE TABLE prefs(key TEXT PRIMARY KEY, value INTEGER NOT NULL)');
      },
    );
    await _load();
    if (!tick) return;
    Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    });
  }

  Future<void> _load() async {
    final slips = <int, List<int>>{};
    for (final r in await _db.query('slips', columns: ['habit_id', 'at'], orderBy: 'at')) {
      slips.putIfAbsent(r['habit_id'] as int, () => []).add(r['at'] as int);
    }
    habits = [
      for (final r in await _db.query('habits', orderBy: 'id'))
        Habit(r['id'] as int, r['name'] as String, r['icon'] as String, slips[r['id']] ?? [now]),
    ];
    for (final r in await _db.query('prefs')) {
      prefs[r['key'] as String] = r['value'] == 1;
    }
    now = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    sync();
  }

  void sync() => syncSystem(habits, prefs).catchError((Object e) => debugPrint('sync failed: $e'));

  List<HabitView> get views => [for (final h in habits) HabitView(h, now, best: prefs['beatBest']!)];
  HabitView? view(int id) => views.where((v) => v.habit.id == id).firstOrNull;

  Future<int> addHabit(String name, String icon, int startedAt) async {
    final id = await _db.transaction((tx) async {
      final id = await tx.insert('habits', {'name': name, 'icon': icon});
      await tx.insert('slips', {'habit_id': id, 'at': startedAt});
      return id;
    });
    await _load();
    return id;
  }

  Future<void> logSlip(int habitId, int at, List<String> triggers, String note) async {
    await _db.insert('slips', {'habit_id': habitId, 'at': at, 'triggers': triggers.join(';'), 'note': note});
    await _load();
  }

  Future<void> setPref(String key, bool value) async {
    prefs[key] = value;
    notifyListeners();
    await _db.insert('prefs', {'key': key, 'value': value ? 1 : 0}, conflictAlgorithm: ConflictAlgorithm.replace);
    sync();
  }

  Future<void> deleteHabit(int id) async {
    await _db.delete('habits', where: 'id = ?', whereArgs: [id]); // slips go with it (ON DELETE CASCADE)
    await _load();
  }

  /// Wipes every interval; each habit's clock restarts now.
  Future<void> resetAll() async {
    final at = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((tx) async {
      await tx.delete('slips');
      for (final h in habits) {
        await tx.insert('slips', {'habit_id': h.id, 'at': at});
      }
    });
    await _load();
  }

  Future<String> exportCsv() async {
    String q(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
    final rows = await _db.rawQuery(
      'SELECT h.name, s.at, s.triggers, s.note FROM slips s '
      'JOIN habits h ON h.id = s.habit_id ORDER BY h.id, s.at',
    );
    return [
      'habit,time,triggers,note',
      for (final r in rows)
        [
          q(r['name']),
          DateTime.fromMillisecondsSinceEpoch(r['at'] as int).toIso8601String(),
          q(r['triggers']),
          q(r['note']),
        ].join(','),
    ].join('\n');
  }
}

final store = Store();
