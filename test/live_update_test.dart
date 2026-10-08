import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrack/logic.dart';
import 'package:mytrack/main.dart';
import 'package:mytrack/store.dart';
import 'package:mytrack/system.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// The real store on a throwaway SQLite file: changes must show on screen without leaving it.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> freshStore(WidgetTester t, [List<String> names = const []]) => t.runAsync(() async {
    await store.init(path: '${Directory.systemTemp.createTempSync('mytrack').path}/t.db', tick: false);
    for (final n in names) {
      await store.addHabit(n, 'ph-hand', DateTime.now().millisecondsSinceEpoch - 2 * hour);
    }
  });

  /// Taps, then alternates real time (for the store's database IO) with frames until it all lands.
  Future<void> tapAndSave(WidgetTester t, Finder f) async {
    await t.tap(f);
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pumpAndSettle();
    }
  }

  testWidgets('a settings toggle flips on screen right away', (t) async {
    final semantics = t.ensureSemantics();
    await freshStore(t);
    await t.pumpWidget(const MaterialApp(home: Tabs()));
    await t.tap(find.text('Settings'));
    await t.pumpAndSettle();

    final summary = find.byKey(const ValueKey('pref-summary'));
    expect(t.getSemantics(summary), isSemantics(isToggled: false));
    await tapAndSave(t, summary);
    expect(store.prefs['summary'], isTrue);
    expect(t.getSemantics(summary), isSemantics(isToggled: true));
    semantics.dispose();
  });

  testWidgets('a deleted habit leaves the Habits list right away', (t) async {
    await freshStore(t, ['Smoking', 'Sugar']);
    await t.pumpWidget(const MaterialApp(home: Tabs()));
    expect(find.text('Smoking'), findsOneWidget);

    await t.tap(find.text('Smoking'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete habit'));
    await t.pumpAndSettle();
    await tapAndSave(t, find.text('Delete'));

    expect(find.text('Smoking'), findsNothing);
    expect(find.text('Sugar'), findsOneWidget);
  });

  testWidgets('home-screen widgets stop getting a deleted habit', (t) async {
    await freshStore(t, ['Smoking', 'Sugar']);
    final smoking = store.habits.first.id;
    await t.runAsync(() => store.deleteHabit(smoking));

    final ids = [for (final h in widgetState(store.views, store.prefs)['habits'] as List) (h as Map)['id']];
    expect(ids, isNot(contains(smoking)));
    expect(ids, hasLength(1));
  });
}
