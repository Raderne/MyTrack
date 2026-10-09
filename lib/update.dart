// Self-updates from GitHub releases: downloads the release APK built for this phone's CPU and hands it
// to Android's installer (MainActivity's "mytrack/update" channel). Android only installs it over this
// app if it's signed with the same key, so a tampered download can't replace the app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const repo = 'Raderne/MyTrack';
const _channel = MethodChannel('mytrack/update');

class Release {
  Release(this.version, this.page, this.notes, this.apk);
  final String version, page, notes;

  /// Download URL of the APK for this phone; null if the release has none that runs here.
  final String? apk;
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

/// The asset for the first of [abis] (the phone's, most preferred first) that the release has, as built by
/// release.yml (`mytrack-X.Y.Z-<abi>.apk`). Falls back to a single universal APK, as older releases had.
String? pickApk(List<Map<String, dynamic>> assets, List<String> abis) {
  final apks = assets.where((a) => '${a['name']}'.endsWith('.apk')).toList();
  for (final abi in abis) {
    for (final a in apks) {
      if ('${a['name']}'.endsWith('-$abi.apk')) return a['browser_download_url'] as String;
    }
  }
  const known = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
  final universal = apks.where((a) => !known.any((k) => '${a['name']}'.endsWith('-$k.apk')));
  return universal.isEmpty ? null : universal.first['browser_download_url'] as String;
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
    final abis = (await _channel.invokeListMethod<String>('abis')) ?? const [];
    return Release(
      tag.replaceFirst(RegExp('^v'), ''),
      j['html_url'] as String,
      (j['body'] as String?)?.trim() ?? '',
      pickApk((j['assets'] as List).cast<Map<String, dynamic>>(), abis),
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
        : 'Version ${latest!.version} is available — tap to update';
  } catch (_) {
    updateStatus.value = "Couldn't reach GitHub — tap to retry";
  }
  return latest;
}

HttpClient? _download;

/// Downloads the update, reporting 0..1 (or null while the size is unknown), then opens the installer.
/// With no APK for this phone, opens the release page instead.
Future<void> installUpdate(void Function(double?) onProgress) async {
  final r = latest!;
  if (r.apk == null) {
    await launchUrl(Uri.parse(r.page), mode: LaunchMode.externalApplication);
    return;
  }
  final file = File('${await _channel.invokeMethod<String>('updatesDir')}/mytrack-${r.version}.apk');
  final client = _download = HttpClient();
  try {
    final res = await (await client.getUrl(Uri.parse(r.apk!))).close(); // follows GitHub's redirect to its CDN
    if (res.statusCode != 200) throw HttpException('Download failed (${res.statusCode})');
    final total = res.contentLength, sink = file.openWrite();
    var got = 0;
    try {
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        onProgress(total > 0 ? got / total : null);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && got != total) throw const HttpException('Download was cut off');
  } catch (_) {
    if (await file.exists()) await file.delete(); // never hand a partial APK to the installer
    rethrow;
  } finally {
    client.close();
    _download = null;
  }
  await _channel.invokeMethod('install', {'path': file.path});
}

void cancelUpdate() => _download?.close(force: true);
