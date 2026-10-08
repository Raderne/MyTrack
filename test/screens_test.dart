import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrack/logic.dart';
import 'package:mytrack/main.dart';
import 'package:mytrack/screens.dart';
import 'package:mytrack/store.dart';

// Renders every screen at phone size with in-memory habits (no DB) to catch layout errors.
void main() {
  testWidgets('screens render', (t) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    final now = store.now;
    store.habits = [
      Habit(1, 'Smoking', 'ph-cigarette', [
        for (final h in [20, 18, 16, 13, 10, 6, 3]) now - h * hour,
      ]),
      Habit(2, 'Sugar', 'ph-cookie', [now - 5 * hour]),
    ];
    for (final w in [
      const Home(),
      const Stats(),
      const Settings(),
      const Detail(1),
      const AddHabit(),
      Result(store.view(1)!),
      const Splash(),
    ]) {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: w),
        ),
      );
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull, reason: '${w.runtimeType}');
    }
  });

  testWidgets('splash fills the screen under loose constraints', (t) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    // AnimatedSwitcher (as in Shell) centers its child with loose constraints.
    await t.pumpWidget(
      const MaterialApp(
        home: AnimatedSwitcher(duration: Duration.zero, child: Splash()),
      ),
    );
    expect(t.getSize(find.byType(Splash)), const Size(360, 760));
    await t.pump(const Duration(seconds: 2));
  });
}
