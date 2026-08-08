/// Secure storage for secrets: auth tokens, saved VPN credentials,
/// subscription receipts.
///
/// Implementation: `flutter_secure_storage` (Keychain / Keystore / DPAPI /
/// WebCrypto). Never store secrets in [ConfigRepository].
abstract class KeyStorage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<bool> has(String key);
}
