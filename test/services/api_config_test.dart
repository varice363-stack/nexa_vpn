import 'package:flutter_test/flutter_test.dart';
import 'package:morok_vpn/services/api/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('resolvedBaseUrl returns non-empty string', () {
      final url = ApiConfig.resolvedBaseUrl;
      expect(url, isNotEmpty);
    });

    test('timeout is reasonable', () {
      expect(ApiConfig.timeout.inSeconds, greaterThan(0));
      expect(ApiConfig.timeout.inSeconds, lessThanOrEqualTo(30));
    });
  });
}
