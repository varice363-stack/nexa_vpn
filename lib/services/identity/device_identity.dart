import 'dart:math';

/// Идентификатор владельца приложения — вместо логина и пароля.
///
/// Формат: `NEXA-XXXX-XXXX-XXXX-XXXX` — 16 символов, ~76 бит.
///
/// Почему так, а не регистрация по почте:
///  * почту нужно где-то хранить, а хранилище можно изъять или потерять;
///  * серверу вообще незачем знать, кто именно пользуется VPN;
///  * код рождается на устройстве и никуда не отправляется, пока человек
///    сам не решит его использовать.
///
/// Тот же подход у Mullvad: случайный номер вместо аккаунта.
///
/// Алфавит без похожих знаков: нет `0`/`O`, `1`/`I`/`L`, `5`/`S`, `8`/`B`,
/// `2`/`Z` — человек диктует код голосом и переписывает от руки, а значит
/// ошибка распознавания дороже пары лишних символов.
abstract final class DeviceIdentity {
  static const String prefix = 'NEXA';
  static const String alphabet = '34679ACDEFGHJKMNPQRTUVWXY';
  static const int groupSize = 4;
  static const int groupCount = 4;

  /// Полная длина тела кода без префикса и дефисов.
  static int get bodyLength => groupSize * groupCount;

  /// Создаёт новый код на криптостойком генераторе.
  ///
  /// `Random.secure()` берёт случайность у операционной системы. Обычный
  /// `Random()` предсказуем по времени запуска — для кода, открывающего
  /// все покупки, это недопустимо.
  static String generate() {
    final rnd = Random.secure();
    final groups = <String>[];
    for (var g = 0; g < groupCount; g++) {
      final buf = StringBuffer();
      for (var i = 0; i < groupSize; i++) {
        buf.write(alphabet[rnd.nextInt(alphabet.length)]);
      }
      groups.add(buf.toString());
    }
    return '$prefix-${groups.join('-')}';
  }

  /// Приводит введённый код к каноническому виду.
  ///
  /// Терпимо к тому, как люди реально вводят: нижний регистр, пробелы,
  /// пропущенные дефисы, отсутствующий префикс. Возвращает пустую строку,
  /// если код не подходит по длине — тогда вызывающий код обязан отказать.
  static String normalise(String input) {
    final cleaned = input
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final body =
        cleaned.startsWith(prefix) ? cleaned.substring(prefix.length) : cleaned;

    if (body.length != bodyLength) return '';

    // Символ не из алфавита означает опечатку либо чужой формат кода.
    for (final ch in body.split('')) {
      if (!alphabet.contains(ch)) return '';
    }

    final groups = <String>[];
    for (var i = 0; i < body.length; i += groupSize) {
      groups.add(body.substring(i, i + groupSize));
    }
    return '$prefix-${groups.join('-')}';
  }

  /// Проверяет, что строка — корректный идентификатор.
  static bool isValid(String input) => normalise(input).isNotEmpty;
}
