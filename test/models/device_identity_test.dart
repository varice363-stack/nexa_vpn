import 'package:flutter_test/flutter_test.dart';
import 'package:morok_vpn/services/identity/device_identity.dart';

void main() {
  group('DeviceIdentity.generate', () {
    test('produces MOROK-XXXX-XXXX-XXXX-XXXX format', () {
      final code = DeviceIdentity.generate();
      expect(code, matches(RegExp(r'^MOROK-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
    });

    test('generates different codes each time', () {
      final codes = <String>{};
      for (int i = 0; i < 100; i++) {
        codes.add(DeviceIdentity.generate());
      }
      expect(codes.length, 100);
    });

    test('uses only allowed alphabet (no 0/O, 1/I/L, 2/Z, 5/S, 8/B)', () {
      final forbidden = {'0', 'O', '1', 'I', 'L', '2', 'Z', '5', 'S', '8', 'B'};
      for (int i = 0; i < 50; i++) {
        final code = DeviceIdentity.generate();
        // Извлекаем тело без префикса MOROK-
        final body = code.substring(6).replaceAll('-', '');
        for (final ch in body.split('')) {
          expect(forbidden, isNot(contains(ch)),
              reason: 'Character $ch should not be in generated code');
        }
      }
    });
  });

  group('DeviceIdentity.normalise', () {
    test('accepts lowercase input', () {
      final result = DeviceIdentity.normalise('morok-abcd-efgh-ijkl-mnop');
      expect(result, isNotEmpty);
      expect(result, startsWith('MOROK-'));
    });

    test('accepts input without hyphens', () {
      final result = DeviceIdentity.normalise('MOROKABCDEFGHIJKLMNOP');
      expect(result, isNotEmpty);
      expect(result, startsWith('MOROK-'));
    });

    test('accepts input without prefix', () {
      final result = DeviceIdentity.normalise('ABCDEFGHIJKLMNOP');
      expect(result, isNotEmpty);
      expect(result, startsWith('MOROK-'));
    });

    test('accepts input with spaces', () {
      final result = DeviceIdentity.normalise('MOROK-ABCD EFGH IJKL MNOP');
      expect(result, isNotEmpty);
    });

    test('returns empty for invalid length', () {
      expect(DeviceIdentity.normalise('MOROK-ABC'), isEmpty);
      expect(DeviceIdentity.normalise(''), isEmpty);
    });

    test('handles whitespace around input', () {
      final result = DeviceIdentity.normalise('  MOROK-ABCD-EFGH-IJKL-MNOP  ');
      expect(result, isNotEmpty);
    });
  });

  group('DeviceIdentity.isValid', () {
    test('valid code returns true', () {
      final code = DeviceIdentity.generate();
      expect(DeviceIdentity.isValid(code), isTrue);
    });

    test('invalid code returns false', () {
      expect(DeviceIdentity.isValid(''), isFalse);
      expect(DeviceIdentity.isValid('invalid'), isFalse);
    });
  });
}
