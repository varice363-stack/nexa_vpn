import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:morok_vpn/domain/repositories/key_storage.dart';
import 'package:morok_vpn/repositories/subscription_repository_impl.dart';
import 'package:morok_vpn/services/api/api_client.dart';
import 'package:morok_vpn/services/api/api_exception.dart';
import 'package:morok_vpn/services/api/token_storage.dart';

/// Приглашение друга со стороны приложения.
///
/// Программа (08.10.2026): друг вводит код — получает неделю доступа.
/// Процентов с оплаты нет. Тесты держат то, что видит человек: адрес запроса,
/// разбор срока и честную ошибку вместо «что-то пошло не так».

class _MemoryKeyStorage implements KeyStorage {
  final Map<String, String> rows = {'morok_auth_token': 'jwt'};
  @override
  Future<void> write(String key, String value) async => rows[key] = value;
  @override
  Future<String?> read(String key) async => rows[key];
  @override
  Future<void> delete(String key) async => rows.remove(key);
  @override
  Future<bool> has(String key) async => rows.containsKey(key);
}

void main() {
  group('applyReferral', () {
    test('отправляет код на /billing/referral/apply и разбирает срок',
        () async {
      Uri? calledUri;
      Map<String, dynamic>? sentBody;
      final expires = DateTime.utc(2026, 10, 15, 12, 0);
      final client = ApiClient(
        tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
        httpClient: MockClient((request) async {
          calledUri = request.url;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'status': 'TRIAL',
              'expiresAt': expires.toIso8601String(),
              'referralDays': 7,
              'extended': false,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = SubscriptionRepositoryImpl(api: client);

      final state = await repo.applyReferral('MOROK-AAAA-BBBB-CCCC-DDDD');

      expect(calledUri?.path, endsWith('/billing/referral/apply'));
      expect(sentBody?['code'], 'MOROK-AAAA-BBBB-CCCC-DDDD');
      expect(state.expiresAt?.toUtc(), expires);
      expect(state.isTrialActive, isTrue);
    });

    test('отказ сервера доходит до человека словами сервера', () async {
      final client = ApiClient(
        tokenStorage: TokenStorage(storage: _MemoryKeyStorage()),
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Приглашение уже использовано на этом устройстве'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = SubscriptionRepositoryImpl(api: client);

      await expectLater(
        repo.applyReferral('MOROK-AAAA-BBBB-CCCC-DDDD'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('уже использовано'),
          ),
        ),
      );
    });
  });
}
