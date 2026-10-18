# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MyTrack is a bad-habit interval tracker: every gap between slips must be longer than the bar before it, or it's a fail.
Flutter + SQLite (`sqflite`), **Android only**. Design source: `bad-habits-tracking-app/project/Bad Habits.dc.html` (not in the repo).

## Commands

```bash
flutter run
flutter analyze                                  # CI runs this; must be clean
flutter test                                     # CI runs this
flutter test test/logic_test.dart                # one file
flutter test --plain-name "screens render"       # one test by name
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin widget tests (WidgetsTest.kt)
```

## Architecture

Flat `lib/`, no state-management package. Data flows one way:

- `logic.dart` — pure interval rules, no Flutter imports. `Habit.slips` is a list of epoch ms where **the first entry is when the clock started and every later entry is a slip**. `HabitView(habit, now, best:)` derives intervals, bars, outcomes, streak, target. `best` = beat the longest interval so far; otherwise beat the previous one (the `beatBest` pref).
- `store.dart` — global `store` singleton (`ChangeNotifier`) over SQLite (`habits`, `slips`, `prefs` tables; slips cascade on habit delete). Every mutation re-reads everything via `_load()`, then calls `sync()`. A 1-second timer updates `now` and notifies, so all clocks redraw. `init(path:, tick: false)` is the test hook.
- `system.dart` — everything leaving the app. `syncSystem` is non-incremental: it cancels and reschedules **all** notifications and pushes a JSON snapshot to the home widgets on every change. It no-ops until `initSystem` has run.
- `main.dart` — theme color constants, icon map (`iconOf`), shared widgets, `Shell` (splash → `Tabs`), Home/Stats/Settings tabs, and `openUri` which routes `mytrack://open?id=N` / `mytrack://log?id=N` deep links from notifications and widgets. `screens.dart` holds Detail, slip logging, Result, AddHabit.
- `update.dart` — self-updater: checks GitHub `Raderne/MyTrack` latest release and offers its `.apk` (no Play Store).
- `ph.dart` — Phosphor icon codepoints (fonts in `assets/fonts`).

### Dart ↔ Kotlin duplication

`android/app/src/main/kotlin/com/mytrack/mytrack/Widgets.kt` renders four home-screen widgets (Ring, Streak, Quick, List) from the JSON written by `widgetState()` in `system.dart`, and refreshes itself each minute. It **re-implements the interval/status/format logic from `logic.dart`** and hardcodes colors and icon codepoints. Changing rules, copy, the JSON shape, colors, or widget class names must be mirrored on both sides (`_widgets` list in `system.dart` names the providers).

Widget-picker preview PNGs are regenerated with `tool/widget_previews.py` (see its header; needs the design bundle and Chrome).

## Tests

- `logic_test.dart` / `update_test.dart` — pure logic.
- `screens_test.dart` — sets `store.habits` in memory (no DB) and pumps every screen at 360×760 to catch layout overflows.
- `live_update_test.dart` — real store on a temp SQLite file via `sqflite_common_ffi`; DB IO must run inside `t.runAsync`.

## Releases

Pushing a `v*.*.*` tag on `develop` triggers `.github/workflows/release.yml`: checks the tag matches `pubspec.yaml` `version:`, runs analyze + tests, builds a release-signed APK (rejects debug-signed) and publishes it with notes extracted from `CHANGELOG.md` by `scripts/changelog-section.mjs`. Per release: move `[Unreleased]` notes under `## [X.Y.Z] - date`, bump `version: X.Y.Z+N` (`+N` must always increase). Signing setup is in `README.md`.

## Conventions

Code is deliberately minimal and terse; deliberate shortcuts are marked with `// ponytail:` comments naming the ceiling. Match that style.
