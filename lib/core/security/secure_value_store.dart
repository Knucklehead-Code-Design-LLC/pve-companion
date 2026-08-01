import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);

  Future<void> write({required String key, required String value});

  Future<void> delete(String key);
}

class KeychainSecureValueStore implements SecureValueStore {
  KeychainSecureValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}
