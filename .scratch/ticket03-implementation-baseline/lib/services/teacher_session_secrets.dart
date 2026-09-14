import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PIN hanya disimpan dalam secure storage HP pembuat. Membaca nilainya
/// untuk ditampilkan memerlukan autentikasi perangkat terlebih dahulu.
abstract class TeacherSessionSecrets {
  Future<void> savePin(String sessionId, String pin);
  Future<String?> readPin(String sessionId);
  Future<bool> hasPin(String sessionId);
  Future<void> deletePin(String sessionId);

  /// Implementasi secure storage asli (flutter_secure_storage).
  static TeacherSessionSecrets secure() => _SecureStorageSecrets();

  /// Implementasi memori untuk pengujian.
  static TeacherSessionSecrets inMemory() => _InMemorySecrets();
}

class _SecureStorageSecrets implements TeacherSessionSecrets {
  const _SecureStorageSecrets();

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'teacher_pin_';

  @override
  Future<void> savePin(String sessionId, String pin) =>
      _storage.write(key: '$_prefix$sessionId', value: pin);

  @override
  Future<String?> readPin(String sessionId) =>
      _storage.read(key: '$_prefix$sessionId');

  @override
  Future<bool> hasPin(String sessionId) =>
      _storage.containsKey(key: '$_prefix$sessionId');

  @override
  Future<void> deletePin(String sessionId) =>
      _storage.delete(key: '$_prefix$sessionId');
}

class _InMemorySecrets implements TeacherSessionSecrets {
  final _pins = <String, String>{};

  @override
  Future<void> savePin(String sessionId, String pin) async {
    _pins[sessionId] = pin;
  }

  @override
  Future<String?> readPin(String sessionId) => Future.value(_pins[sessionId]);

  @override
  Future<bool> hasPin(String sessionId) async => _pins.containsKey(sessionId);

  @override
  Future<void> deletePin(String sessionId) async => _pins.remove(sessionId);
}
