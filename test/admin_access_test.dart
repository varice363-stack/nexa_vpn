import 'package:flutter_test/flutter_test.dart';

import 'package:nexa_vpn/models/access_key.dart';
import 'package:nexa_vpn/models/auth_user.dart';

/// The admin area can mint codes that are sold for money, so the important
/// property is not that it works — it is that it is unreachable for everyone
/// except the owner. These tests pin down the role parsing and the code
/// field the screen depends on.

void main() {
  group('UserRole parsing — the gate the admin area relies on', () {
    test('reads the backend ADMIN role', () {
      expect(UserRole.fromName('admin'), UserRole.admin);
    });

    test('unknown or missing roles fall back to plain user', () {
      // A parsing slip must never promote someone to admin.
      expect(UserRole.fromName(null), UserRole.user);
      expect(UserRole.fromName(''), UserRole.user);
      expect(UserRole.fromName('ADMIN'), UserRole.user);
      expect(UserRole.fromName('superuser'), UserRole.user);
      expect(UserRole.fromName('premium'), UserRole.premium);
    });

    test('a user parsed from backend JSON keeps its role', () {
      final admin = AuthUser.fromJson(const {
        'id': 'u1',
        'email': 'admin@nexavpn.app',
        'role': 'admin',
      });
      final normal = AuthUser.fromJson(const {
        'id': 'u2',
        'email': 'user@nexavpn.app',
        'role': 'user',
      });

      expect(admin.role, UserRole.admin);
      expect(normal.role, UserRole.user);
      // Only the admin passes the check both the route and screen use.
      expect(admin.role == UserRole.admin, isTrue);
      expect(normal.role == UserRole.admin, isFalse);
    });

    test('admin counts as premium but premium is not admin', () {
      const admin = AuthUser(
        id: 'u1',
        email: 'a@b.c',
        role: UserRole.admin,
      );
      const premium = AuthUser(
        id: 'u2',
        email: 'p@b.c',
        role: UserRole.premium,
      );

      expect(admin.isPremium, isTrue);
      expect(premium.isPremium, isTrue);
      // Paying for premium must not unlock code issuing.
      expect(premium.role == UserRole.admin, isFalse);
    });
  });

  group('AccessKey.code — what the admin screen shows and copies', () {
    test('reads the redemption code when the backend returns one', () {
      final key = AccessKey.fromJson(const {
        'id': 'k1',
        'name': 'Customer #1',
        'status': 'ACTIVE',
        'protocol': 'VLESS',
        'code': 'NEXA-7QK2-M4XP',
      });

      expect(key.code, 'NEXA-7QK2-M4XP');
    });

    test('is null for keys that carry no sellable code', () {
      final key = AccessKey.fromJson(const {
        'id': 'k2',
        'name': 'Subscription key',
        'status': 'ACTIVE',
        'protocol': 'VLESS',
      });

      expect(key.code, isNull);
    });
  });
}
