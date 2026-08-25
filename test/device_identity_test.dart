import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_vpn/services/identity/device_identity.dart';

void main() {
  group('генерация кода', () {
    test('формат NEXA-XXXX-XXXX-XXXX-XXXX', () {
      final code = DeviceIdentity.generate();
      expect(
        RegExp(r'^NEXA-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')
            .hasMatch(code),
        isTrue,
        reason: 'получено: $code',
      );
    });

    test('тело кода — ровно 16 символов', () {
      final body = DeviceIdentity.generate()
          .replaceAll('NEXA', '')
          .replaceAll('-', '');
      // 16 символов по алфавиту из 25 знаков — около 74 бит.
      // Короче делать нельзя: код открывает все покупки владельца.
      expect(body.length, 16);
    });

    test('используются только знаки из алфавита без похожих символов', () {
      for (var i = 0; i < 200; i++) {
        final body = DeviceIdentity.generate()
            .replaceAll('NEXA-', '')
            .replaceAll('-', '');
        for (final ch in body.split('')) {
          expect(DeviceIdentity.alphabet.contains(ch), isTrue,
              reason: 'посторонний символ "$ch"');
        }
        // Похожие знаки исключены: код диктуют голосом и пишут от руки.
        expect(body, isNot(contains('O')));
        expect(body, isNot(contains('0')));
        expect(body, isNot(contains('I')));
        expect(body, isNot(contains('1')));
        expect(body, isNot(contains('L')));
        expect(body, isNot(contains('S')));
        expect(body, isNot(contains('5')));
      }
    });

    test('1000 генераций без единого повтора', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        seen.add(DeviceIdentity.generate());
      }
      expect(seen.length, 1000);
    });
  });

  group('чтение введённого кода', () {
    test('принимает код как есть', () {
      const code = 'NEXA-A3C4-D6E7-F9G3-H4J6';
      expect(DeviceIdentity.normalise(code), code);
    });

    test('терпит неряшливый ввод: регистр, пробелы, нет дефисов и префикса',
        () {
      const canonical = 'NEXA-A3C4-D6E7-F9G3-H4J6';
      const messy = [
        'nexa-a3c4-d6e7-f9g3-h4j6',
        'NEXA A3C4 D6E7 F9G3 H4J6',
        'NEXAA3C4D6E7F9G3H4J6',
        'a3c4d6e7f9g3h4j6',
        '  A3C4-D6E7-F9G3-H4J6  ',
      ];
      for (final input in messy) {
        expect(DeviceIdentity.normalise(input), canonical,
            reason: 'не разобрал: "$input"');
      }
    });

    test('отклоняет неверную длину', () {
      for (final bad in ['NEXA-A3C4', 'A3C4D6E7', 'A3C4D6E7F9G3H4J6X', '']) {
        expect(DeviceIdentity.normalise(bad), '',
            reason: 'принял негодный код: "$bad"');
        expect(DeviceIdentity.isValid(bad), isFalse);
      }
    });

    test('отклоняет символы вне алфавита', () {
      // Здесь стоят O, I, 0, 1 — те самые похожие знаки. Принять их значило бы
      // молча открыть доступ по коду, которого владелец не выдавал.
      for (final bad in [
        'NEXA-OOOO-IIII-0000-1111',
        'NEXA-A3C4-D6E7-F9G3-H4JO',
      ]) {
        expect(DeviceIdentity.normalise(bad), '',
            reason: 'принял: "$bad"');
      }
    });

    test('код активации подписки не подходит как идентификатор', () {
      // Код активации — 8 символов и стоит одну подписку. Идентификатор — 16
      // и стоит все покупки. Если бы короткий код подошёл, любой купивший
      // подписку получил бы чужой аккаунт.
      expect(DeviceIdentity.normalise('NEXA-MHJQ-3JWX'), '');
      expect(DeviceIdentity.isValid('NEXA-MHJQ-3JWX'), isFalse);
    });

    test('свой же сгенерированный код всегда читается обратно', () {
      for (var i = 0; i < 100; i++) {
        final code = DeviceIdentity.generate();
        expect(DeviceIdentity.normalise(code), code);
        expect(DeviceIdentity.isValid(code), isTrue);
      }
    });
  });
}
