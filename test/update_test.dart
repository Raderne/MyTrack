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
}
