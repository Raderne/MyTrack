import 'package:flutter_test/flutter_test.dart';
import 'package:mytrack/update.dart';

void main() {
  test('isNewer', () {
    expect(isNewer('v1.0.1', '1.0.0'), isTrue);
    expect(isNewer('1.10.0', '1.9.9'), isTrue);
    expect(isNewer('v1.0.0', '1.0.0'), isFalse);
    expect(isNewer('1.0.0+5', '1.0.0'), isFalse); // build number alone isn't a release
    expect(isNewer('1.0', '1.0.1'), isFalse);
    expect(isNewer('2', '1.9.9'), isTrue);
  });

  test("pickApk: the APK for the phone's preferred ABI", () {
    Map<String, String> a(String name) => {'name': name, 'browser_download_url': 'https://x/$name'};
    final split = [a('mytrack-1.0.2-armeabi-v7a.apk'), a('mytrack-1.0.2-arm64-v8a.apk'), a('mytrack-1.0.2-x86_64.apk')];

    expect(pickApk(split, ['arm64-v8a', 'armeabi-v7a', 'armeabi']), 'https://x/mytrack-1.0.2-arm64-v8a.apk');
    expect(pickApk(split, ['armeabi-v7a', 'armeabi']), 'https://x/mytrack-1.0.2-armeabi-v7a.apk');
    expect(pickApk(split, ['x86_64', 'arm64-v8a']), 'https://x/mytrack-1.0.2-x86_64.apk');
    expect(pickApk(split, ['mips']), isNull); // nothing that runs here
    expect(pickApk([a('mytrack-1.0.0.apk')], ['arm64-v8a']), 'https://x/mytrack-1.0.0.apk'); // older universal release
    expect(pickApk([a('notes.txt')], ['arm64-v8a']), isNull);
  });
}
