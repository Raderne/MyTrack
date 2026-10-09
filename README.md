# MyTrack

Bad-habit interval tracker: every gap between slips must be longer than the one before, or it's a fail.
Flutter + SQLite (`sqflite`), Android only. Design source: `bad-habits-tracking-app/project/Bad Habits.dc.html`.

```bash
flutter run
flutter test
```

## Releases (GitHub, not Google Play)

The app checks `https://api.github.com/repos/Raderne/MyTrack/releases/latest` on launch and in
Settings → About. When the tag is newer than the installed version it downloads the APK for the phone's CPU
(`mytrack-X.Y.Z-<abi>.apk`: arm64-v8a, armeabi-v7a or x86_64) and opens Android's installer.
Releases are built and published by [`.github/workflows/release.yml`](.github/workflows/release.yml)
when a `v*.*.*` tag is pushed.

### One-time setup

Create a signing key. Every release must be signed with it, or Android won't install the update over the
previous version. Back it up — losing it means uninstalling (and losing data) to update.

```bash
keytool -genkey -v -keystore android/app/mytrack.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mytrack
```

Give it to the workflow as repository secrets:

```bash
base64 -w0 android/app/mytrack.jks | gh secret set ANDROID_KEYSTORE_BASE64
```

```bash
gh secret set ANDROID_KEYSTORE_PASSWORD
```

```bash
gh secret set ANDROID_KEY_ALIAS --body mytrack
```

```bash
gh secret set ANDROID_KEY_PASSWORD
```

For local release builds, also create `android/key.properties` (git-ignored):

```properties
storeFile=mytrack.jks
storePassword=...
keyAlias=mytrack
keyPassword=...
```

### Each release

1. Move the `[Unreleased]` notes in `CHANGELOG.md` under a new `## [X.Y.Z] - date` heading.
   That section becomes the GitHub release notes and the app's update dialog.
2. Bump `version:` in `pubspec.yaml` to `X.Y.Z+N` (the `+N` must always increase).
3. Commit to `develop`, then tag and push:

```bash
git tag v1.0.1
```

```bash
git push origin develop v1.0.1
```

The workflow checks the tag matches `pubspec.yaml` and is on `develop`, runs analyze and tests, builds a
release-signed APK per CPU architecture (refusing debug-signed ones) and publishes them with the changelog notes.
To try a build without publishing, run the workflow manually (Actions → Release → Run workflow).
