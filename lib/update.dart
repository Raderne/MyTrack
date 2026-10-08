// Self-updates from GitHub releases: the newest release's APK is opened in the browser,
// which downloads it and hands it to Android's installer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const repo = 'Raderne/MyTrack';

class Release {
  Release(this.version, this.url, this.notes);
  final String version, url, notes;
}

final appVersion = ValueNotifier('');
final updateStatus = ValueNotifier('Tap to check GitHub for a newer version');
Release? latest;

/// True when version [a] ("1.2.10", optional leading v / +build) is newer than [b].
bool isNewer(String a, String b) {
  List<int> parts(String v) =>
      v.replaceFirst(RegExp('^v'), '').split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d > 0;
  }
  return false;
}

Future<Release?> _fetchNewer(String current) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
    req.headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close();
    if (res.statusCode == 404) return null; // no releases published yet
    if (res.statusCode != 200) throw HttpException('GitHub answered ${res.statusCode}');
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final tag = j['tag_name'] as String;
    if (!isNewer(tag, current)) return null;
    final apk = (j['assets'] as List).cast<Map<String, dynamic>>().where((a) => '${a['name']}'.endsWith('.apk'));
    return Release(
      tag.replaceFirst(RegExp('^v'), ''),
      apk.isEmpty ? j['html_url'] as String : apk.first['browser_download_url'] as String,
      (j['body'] as String?)?.trim() ?? '',
    );
  } finally {
    client.close();
  }
}

Future<Release?> checkForUpdate() async {
  updateStatus.value = 'Checking…';
  try {
    final info = await PackageInfo.fromPlatform();
    appVersion.value = '${info.version} (${info.buildNumber})';
    latest = await _fetchNewer(info.version);
    updateStatus.value = latest == null
        ? "You're on the latest version"
        : 'Version ${latest!.version} is available — tap to download';
  } catch (_) {
    updateStatus.value = "Couldn't reach GitHub — tap to retry";
  }
  return latest;
}

Future<void> downloadUpdate() => launchUrl(Uri.parse(latest!.url), mode: LaunchMode.externalApplication);
