import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Защита от возврата выдуманного: обещаний, которые приложение не выполняет,
/// и макетов, которые выдавали себя за настоящие функции.
///
/// Это проверка исходного текста, а не поведения. Поведение проверяют
/// остальные тесты; этот файл не даёт снова вписать в интерфейс то, что
/// было удалено как фейк.
const _userTextForbidden = <String>[
  'Безлимитный трафик', // триал ограничен 2 ГБ
  'безлимита и качества', // подсказка Premium: качество не гарантируем
  'оптимизированы для высокой скорости', // ничем не измеряется
  'Premium-план расширяет', // лимит устройств не применяется
  'до 3 устройств', // лимит устройств не применяется
  'до 5 устройств', // лимит устройств не применяется
  'в 4K', // гарантии качества нет
];

const _codeForbidden = <String>[
  'SOCKS5 Shield', // защиты паролем не существует
  'socks5-shield',
  'Device is clean', // проверки root/отладчика были заглушками
  'securityServiceProvider',
  'SecurityService',
  'RootDetectionService',
  'DebuggerDetectionService',
  'AntiTamperService',
  'demoSeedSessions', // выдуманная история
  '_seedDemo',
  'PremiumPlan', // статический каталог с выдуманными ценами
  'canAddDevice', // лимит устройств из таблицы тарифов
  'subscribe(PremiumPlan', // локальная имитация оплаты
  'kServers', // встроенный каталог серверов
];

List<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('app_localizations')) // сгенерированные файлы
    .toList();

void main() {
  test('пользовательские тексты не содержат снятых обещаний', () {
    final sources = [
      File('lib/l10n/app_ru.arb'),
      File('lib/l10n/app_en.arb'),
      File('lib/data/datasources/static_content.dart'),
    ];
    final hits = <String>[];
    for (final f in sources) {
      final text = f.readAsStringSync();
      for (final phrase in _userTextForbidden) {
        if (text.contains(phrase)) hits.add('${f.path}: «$phrase»');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('в коде нет удалённых фейков и мёртвых моделей', () {
    final hits = <String>[];
    for (final f in _dartFiles()) {
      final text = f.readAsStringSync();
      for (final token in _codeForbidden) {
        if (text.contains(token)) hits.add('${f.path}: «$token»');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
